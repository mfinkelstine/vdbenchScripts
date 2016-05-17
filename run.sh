#!/bin/bash

#----------- client list ------------
clients=( mc022 mc023 mc024 mc025  )

#----------- run params -------------
volume_size=400G
threads=16
write_data=500g
read_data=500g
interval=10
block_size=64k #54
vol_num=128 #128

#----------------- do a loop with all compression ratios
	CP=2.3

#-------------  rescan multipath on clients
 

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
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=$read_data,warmup=360,interval=$interval
" >> test

	./vdbench -c -f test | tee -a out_$CP

#	ssh $1n1 -p 26 'echo ctr_dump /tmp/counters > /data/rtcracecli'
#	scp -P 26 $1n1:/tmp/counters ./counters_n1_$CP

#	ssh $1n2 -p 26 'echo ctr_dump /tmp/counters > /data/rtcracecli'
#	scp -P 26 $1n2:/tmp/counters ./counters_n2_$CP

done

./get_vdbench_res.pl --stand=$1 -d

ssh $1 -p 26 svctask rmmdiskgrp -force 0
