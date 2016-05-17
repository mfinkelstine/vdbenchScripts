#!/bin/bash

#----------- client list ------------
clients=( $2 )
#clients=( wl21 wl22 wl23 wl24  )
#----------- run params -------------

volume_size=400G
vol_size=""
threads=4
write_data=3000g
read_data=1000g
interval=10
block_size=64k 
vol_num=128

#----------------- do a loop with all compression ratios
#for CP in {3.5,11}; do
CP=11
#for CP in {1.3,1.7,2.3,3.5,11}; do
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
messagescan=no
	
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
	./graphite_rtc_cr.py $1 | tee -a out_$CP
	sleep 120
#read
        echo "
compratio=$CP
messagescan=no
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

./get_vdbench_res.pl --stand=$1 -d

