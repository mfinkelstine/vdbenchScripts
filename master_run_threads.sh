#!/bin/bash

#----------- client list ------------
clients=( mc022 mc023 mc024 mc025 )

#----------- run params -------------
volume_size=400G
threads=16
interval=1


#for vols in {1,2,4,8,32,128}; do
for vols in {1,2}; do

let "write_data= $vols*40*1024*1024*1024+300*1024*1024*1024"
let "read_data=$write_data/2"

echo "volume of $write_data bytes"

#----------------- do a loop with all compression ratios
#for CP in {1.3,1.7,2.3,3.5,11}; do
	CP=2.3
	echo -e "Starting new run wih $CP"
	mdiskid=`ssh $1 -p 26 ""lsmdiskgrp |grep -v id | sed -r 's/^[^0-9]*([0-9]+).*$/\1/'""`
        echo -e "Removing mdiskgrp id : $mdiskid from $1"
        ssh $1 -p 26 svctask rmmdiskgrp -force $mdiskid

	if [[ $2 == "fab" ]] ;then
		echo "Running with FAB configuration 96 8 12 128 200 NOSCRUB COMPRESSED"
		ssh $1 -p 26 /home/mk_arrays_master fc raid10 sas_hdd 96 8 12 $vols 5000 NOSCRUB COMPRESSED
		#ssh $1 -p 26 /home/mk_arrays_master fc raid10 sas_hdd 168 8 21 32 200 NOSCRUB COMPRESSED
	else
		echo "Running with BFN configuration"
		#ssh $1 -p 26 /home/mk_vdisks fc 1 32 102400 0 COMPRESSED
		ssh $1 -p 26 /home/mk_vdisks fc 1 $vols 500000 0 COMPRESSED
		#ssh $1 -p 26 /home/mk_vdisks fc 1 32 102400 0 NOCACHE COMPRESSED
	fi
	sleep 60
	
#-------------  rescan multipath on clients
 
	for client in "${clients[@]}"; do
		ssh $client /etc/init.d/multipathd restart
		echo "found:"
		ssh $client /usr/global/scripts/rescan.pl
		echo " disks"
	done

#---------- setaffinity
#	ssh $1n1 -p 26 "echo \"read_out_q_limit 128\"> /data/rtcracecli"
#	ssh $1n2 -p 26 "echo \"read_out_q_limit 128\"> /data/rtcracecli"
# 	ssh $1n1 -p 26 /home/debug/rtc_moveaffinity ecmain
#	ssh $1n2 -p 26 /home/debug/rtc_moveaffinity ecmain
#	ssh $1n1 -p 26 /home/debug/rtc_setaffinity
#	ssh $1n2 -p 26 /home/debug/rtc_setaffinity
#	ssh $1n1 -p 26 "echo \"ra_max_read_size 65536\" > /data/rtcracecli"
#	ssh $1n2 -p 26 "echo \"ra_max_read_size 65536\" > /data/rtcracecli"

#-------------  create map of availiable disks
	echo " " > disk_list
	for client in "${clients[@]}"; do
		COUNT=1
		for LINE in `ssh $client fdisk -l |grep "Disk /dev/mapper"| awk '{print $2}' | sed s/://`; do
        		echo "sd=$client.$COUNT,hd=$client,lun=$LINE,openflags=o_direct,size=$volume_size,threads=$threads" >> disk_list
#			echo "" >> disk_list;
        		COUNT=$(( COUNT +1 ))
		done;
	done

#write  
	echo "
compratio=$CP
	
" > test
	for client in "${clients[@]}"; do
		echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> test
	done
	echo "
include=disk_list

wd=wd1,sd=*,xfersize=64k,rdpct=0,rhpct=0,seekpct=0
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=$write_data,warmup=360,interval=$interval
" >> test

	./vdbench -c -f test | tee out_$CP


#-------- take comp ratios
	./graphite_rtc_cr.py $1 | tee -a out_$CP
	sleep 120
#read
        echo "
compratio=$CP

" > test
        for client in "${clients[@]}"; do
                echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> test
        done
        echo "
include=disk_list

wd=wd1,sd=*,xfersize=64k,rdpct=100,rhpct=0,seekpct=0
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=$read_data,warmup=360,interval=$interval
" >> test

	./vdbench -c -f test | tee -a out_$CP

done
#get results to json
echo "results to JSON" 
./get_vdbench_res.pl -stand $1

done

