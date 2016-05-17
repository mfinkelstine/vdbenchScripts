#!/bin/bash

#----------- client list ------------
clients=( wl13 wl14 wl15 wl16 )

#----------- run params -------------
volume_size=400G
threads=16
write_data=1500g
read_data=1500g
interval=10
block_size=64k

#----------------- do a loop with all compression ratios
for CP in {1.3,1.7,2.3,3.5,11}; do
#for CP in {1.7,3.5}; do
#	CP=11
	mdiskid=`ssh $1 -p 26 ""lsmdiskgrp |grep -v id | sed -r 's/^[^0-9]*([0-9]+).*$/\1/'""`
        echo -e "Removing mdiskgrp id : $mdiskid from $1"
        ssh $1 -p 26 svctask rmmdiskgrp -force $mdiskid

	if [[ $2 == "fab" ]] ;then
		echo "Running with FAB configuration"
		ssh $1 -p 26 /home/mk_arrays_master fc raid10 sas_hdd 168 8 21 128 500 NOSCRUB COMPRESSED
		#ssh $1 -p 26 /home/mk_arrays_master fc raid10 sas_hdd 168 8 21 32 200 NOSCRUB COMPRESSED
	else
		echo "Running with BFN configuration"
		#ssh $1 -p 26 /home/mk_vdisks fc 1 32 102400 0 COMPRESSED
		ssh $1 -p 26 /home/mk_vdisks fc 1 128 500000 0 COMPRESSED
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

wd=wd1,sd=*,xfersize=$block_size,rdpct=0,rhpct=0,seekpct=0
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=$write_data,warmup=180,interval=$interval
" >> test

	./vdbench -v -f test | tee out_$CP


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

wd=wd1,sd=*,xfersize=$block_size,rdpct=100,rhpct=0,seekpct=0
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=$read_data,interval=$interval
" >> test

	./vdbench -v -f test | tee -a out_$CP

#	ssh $1n1 -p 26 'echo ctr_dump /tmp/counters > /data/rtcracecli'
#	scp -P 26 $1n1:/tmp/counters ./counters_n1_$CP

#	ssh $1n2 -p 26 'echo ctr_dump /tmp/counters > /data/rtcracecli'
#	scp -P 26 $1n2:/tmp/counters ./counters_n2_$CP

done
