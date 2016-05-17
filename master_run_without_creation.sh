#!/bin/bash

#----------- client list ------------
clients=( wl9 wl10 wl11 wl12  )
ports=$2
#----------- run params -------------
volume_size=400G
threads=16
write_data=3000g
read_data=1000g
interval=10
block_size=64k 
vol_num=32

#----------------- do a loop with all compression ratios
#for CP in {1.3,1.7,2.3,3.5,11}; do
for CP in 3.5 ; do
	mdiskid=`ssh $1 -p 26 ""lsmdiskgrp |grep -v id | sed -r 's/^[^0-9]*([0-9]+).*$/\1/'""`
        echo -e "Removing mdiskgrp id : $mdiskid from $1"
        ssh $1 -p 26 svctask rmmdiskgrp -force $mdiskid
#	
#---------- remove FC module	
#	for client in "${clients[@]}"; do
#		ssh $client rmmod qla2xxx -f
#	done
#---------- build disks

	ssh $1 -p 26 ls /home/mk_arrays_master
	if [[ $? == 0 ]]; then
		echo "Running with FAB configuration"
		#ssh $1 -p 26 /home/mk_arrays_master fc raid10 sas_hdd 168 8 21 $vol_num 500 NOSCRUB COMPRESSED
		ssh $1 -p 26 /home/mk_arrays_master fc raid10 sas_hdd 96 8 12 128 200 NOSCRUB COMPRESSED
	else
		echo "Running with BFN configuration"
		#ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num 50000 0
		ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num 500000 0 COMPRESSED
#		ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num 500000 0 NOCACHE COMPRESSED
	fi
	sleep 60

	ssh ${1}n1 -p 26 /home/debug/rtc_stopseq
	ssh ${1}n2 -p 26 /home/debug/rtc_stopseq

#-------------  rescan multipath on clients
 
	for client in "${clients[@]}"; do
		ssh $client /sbin/modprobe -i qla2xxx
		if ssh $client cat "/etc/redhat-release | grep 7" ; then
			echo "Linux higher or equal to release 7"
			ssh $client service multipathd restart
		else
			echo "Linux lower then release 7"
			ssh $client /etc/init.d/multipathd restart
		fi
		echo "found:"
		ssh $client /root/vdbench/rescan.pl
		echo " disks"
	done

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
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=$write_data,warmup=360,interval=$interval
" >> test

	./vdbench -c -f test | tee out_$CP


#-------- take comp ratios
#	./graphite_rtc_cr.py $1 | tee -a out_$CP
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
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=$read_data,warmup=360,interval=$interval
" >> test

	./vdbench -c -f test | tee -a out_$CP

done

#./get_vdbench_res.pl --stand=$1 -d

