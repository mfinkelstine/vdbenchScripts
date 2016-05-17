#!/bin/bash

#----------- client list ------------
clients=( mc022 mc023 mc024 mc025  )

#----------- run params -------------
volume_size=$2
threads=4   #16
write_data=800g
read_data=800g
interval=10
block_size=$3 #54
vol_num=64 #128



multipath_command="/etc/init.d/multipathd"

#-------------  delete old clients
                ssh $1 -p 26 "i=\"0\"; while [ 1 -lt \`lshost|wc -l\` ]; do svctask rmhost -force \$i; i=\$[\$i+1]; done"
#-------------  add clients
		ssh $1 -p 26 svctask mkhost -fcwwpn 21000024FF5AED09:21000024FF5AED08:21000024FF4AD3E8:21000024FF4AD3E9 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name mc022 -type generic
		ssh $1 -p 26 svctask mkhost -fcwwpn 21000024FF4AD358:21000024FF4AD359:21000024FF5AEF5E:21000024FF5AEF5F -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name mc023 -type generic
		ssh $1 -p 26 svctask mkhost -fcwwpn 21000024FF4AD43C:21000024FF4AD43D:21000024FF5AEFEE:21000024FF5AEFEF -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name mc024 -type generic
		ssh $1 -p 26 svctask mkhost -fcwwpn 21000024FF499756:21000024FF499757:21000024FF5AAC40:21000024FF5AAC41 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name mc025 -type generic
#------------ clear log
		echo "Cleaning logs"
		ssh $1 -p 26 svctask clearerrlog -force
let volgb=(volume_size*1024)
let randgb=(volume_size*vol_num)

#----------------- do a loop with all compression ratios
#for CP in {1.3,1.7,2.3,3.5,11}; do
#for CP in {2.3,3.5}; do
	CP=2.3
#------------- LOGS
prepare="out_prepare_$CP"
rRAND100="out_rr100_$CP"
rwRAND7030="out_rwr7030_$CP"
rwRAND5050="out_rw5050_$CP"
wRAND100="out_wRAMD100_$CP"

#-------------

	mdiskid=`ssh $1 -p 26 ""lsmdiskgrp |grep -v id | sed -r 's/^[^0-9]*([0-9]+).*$/\1/'""`
        echo -e "Removing mdiskgrp id : $mdiskid from $1"
        ssh $1 -p 26 svctask rmmdiskgrp -force $mdiskid
#	
#---------- remove FC module	
	for client in "${clients[@]}"; do
		ssh $client "$multipath_command stop ; multipath -F" 
		ssh $client rmmod qla2xxx -f
	done
#---------- build disks

	ssh $1 -p 26 ls /home/mk_arrays_master
	if [[ $? == 0 ]]; then
		echo "Running with FAB configuration"
		#ssh $1 -p 26 /home/mk_arrays_master fc raid10 sas_hdd 168 8 21 $vol_num 500 NOSCRUB COMPRESSED
		ssh $1 -p 26 /home/mk_arrays_master fc raid10 sas_hdd 96 8 12 128 200 NOSCRUB COMPRESSED
	else
		echo "Running with BFN configuration"
		#ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num 50000 0
		ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num $volgb 0 COMPRESSED
		#ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num 500000 0 COMPRESSED
		#ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num 500000 0 NOCACHE COMPRESSED
	fi
	sleep 60

#-------------  rescan multipath on clients
 
	for client in "${clients[@]}"; do
		ssh $client /sbin/modprobe -i qla2xxx
		ssh $client /etc/init.d/multipathd restart
		echo "found:"
		ssh $client /root/vdbench/rescan.pl
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

#------------- Change vdisk cache disable/enable
	#deisable=`ssh $1 -p 26 ls /home/make_all_vdisks_cache_disabled`
	#if [[ $? == 0 ]] ; then
		echo -e "Changing the vdisk to cache disable \n"
		ssh $1 -p 26 /home/make_all_vdisks_cache_disabled
	#else
	#	echo -e "vDisk cache disable does not exists\n";
	#	exit 1;
	#fi
#------------- create map of availiable disks
	echo " " > disk_list
	for client in "${clients[@]}"; do
		COUNT=1
		for LINE in `ssh $client fdisk -l |grep "Disk /dev/mapper"| awk '{print $2}' | sed s/://`; do
        		echo "sd=$client.$COUNT,hd=$client,lun=$LINE,openflags=o_direct,size=$volume_size"g",threads=$threads" >> disk_list
#			echo "" >> disk_list;
        		COUNT=$(( COUNT +1 ))
		done;
	done

#------------  TEST#1 100% sequential write ( prepare )
echo "Starting 100% sequantial write " >$prepare
	echo "
compratio=$CP
messagescan=no
" > test_seq
	for client in "${clients[@]}"; do
		echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> test_seq
	done
	echo "
include=disk_list

wd=wd1,sd=*,xfersize=$block_size,rdpct=0,rhpct=0,seekpct=0
rd=run1,wd=wd1,iorate=max,elapsed=30m,maxdata=$write_data,warmup=360,interval=$interval
#rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=$write_data,warmup=360,interval=$interval
" >> test_seq
	echo "################################# 100% sequantial sequential write ( prepare )">> $prepare
	./vdbench -c -f test_seq | tee -a $prepare
#-------- take comp ratios
	#./graphite_rtc_cr.py $1 | tee -a out_$CP
	sleep 120
#------------- Change vdisk cache disable/enable
	deisable=`ssh $1 -p 26 ls /home/make_all_vdisks_cache_enabled`
	#if [[ $? == 0 ]] ; then
		echo -e "Changing the vdisk to cache enable \n"
		ssh $1 -p 26 /home/make_all_vdisks_cache_enabled
	#else
	#	echo -e "vDisk cache disable does not exists\n";
	#	exit 2
	#fi

#-------- TEST#2 100% Random Read 
echo "Starting 100% Random Read" >$rRAND100
 echo "
compratio=$CP
messagescan=no
" > test_100rr
        for client in "${clients[@]}"; do
                echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> test_100rr
        done
        echo "
include=disk_list

wd=wd1,sd=*,xfersize=$block_size,rdpct=100,rhpct=0,seekpct=100,range=(1,90)
rd=run1,wd=wd1,iorate=max,maxdata=$randgb"g",warmup=360,interval=$interval
#rd=run1,wd=wd1,iorate=max,elapsed=30m,maxdata=$write_data,warmup=360,interval=$interval
" >> test_100rr

	echo "################################# 100% Random Read">> $rRAND100
 ./vdbench -c -f test_100rr | tee -a $rRAND100


#-------- take comp ratios
        #./graphite_rtc_cr.py $1 | tee -a out_$CP
        sleep 120


# TEST#3 70/30 Read/Write Random
echo "Starting 70% Random Read 30% Random Write" >$rwRAND7030

echo "
compratio=$CP
messagescan=no
" > test_70_30rwr
        for client in "${clients[@]}"; do
                echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> test_70_30rwr
        done
        echo "
include=disk_list

wd=wd1,sd=*,xfersize=$block_size,rdpct=70,rhpct=0,seekpct=100,range=(1,90)
rd=run1,wd=wd1,iorate=max,maxdata=$randgb"g",warmup=360,interval=$interval
#rd=run1,wd=wd1,iorate=max,elapsed=30m,maxdata=$write_data,warmup=360,interval=$interval
" >> test_70_30rwr

	echo "################################# 70% Random Read 30% Random Write">> $rwRAND7030
 ./vdbench -c -f test_70_30rwr | tee -a $rwRAND7030


#-------- take comp ratios
        #./graphite_rtc_cr.py $1 | tee -a out_$CP
        sleep 120

# TEST#4 50/50 Read/Write Random
echo "Starting 50% Random Read 50% Random Write" >$rwRAND5050
 echo "
compratio=$CP
messagescan=no
" > test_50_50rwr
        for client in "${clients[@]}"; do
                echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> test_50_50rwr
        done
        echo "
include=disk_list

wd=wd1,sd=*,xfersize=$block_size,rdpct=50,rhpct=0,seekpct=100,range=(1,90)
rd=run1,wd=wd1,iorate=max,maxdata=$randgb"g",warmup=360,interval=$interval
#rd=run1,wd=wd1,iorate=max,elapsed=30m,maxdata=$write_data,warmup=360,interval=$interval
" >> test_50_50rwr
	echo "################################# 50% Random Read 50% Random Write">> $rwRAND5050
 ./vdbench -c -f test_50_50rwr | tee -a $rwRAND5050


#-------- take comp ratios
        #./graphite_rtc_cr.py $1 | tee -a out_$CP
        sleep 120



# TEST#5 100% Random Write 
echo "Starting 100% Random Write" >$wRAND100
 echo "
compratio=$CP
messagescan=no
" > test_100rw
        for client in "${clients[@]}"; do
                echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> test_100rw
        done
        echo "
include=disk_list

wd=wd1,sd=*,xfersize=$block_size,rdpct=0,rhpct=0,seekpct=100,range=(1,90)
rd=run1,wd=wd1,iorate=max,maxdata=$randgb"g",warmup=360,interval=$interval
#rd=run1,wd=wd1,iorate=max,elapsed=30m,maxdata=$write_data,warmup=360,interval=$interval
" >> test_100rw

	echo "################################# 100% Random Write">> $wRAND100
 ./vdbench -c -f test_100rw | tee -a $wRAND100


#-------- take comp ratios
        #./graphite_rtc_cr.py $1 | tee -a out_$CP
        sleep 120

#done

./get_vdbench_res.pl --stand=$1 -d

ssh $1 -p 26 svctask rmmdiskgrp -force 0
