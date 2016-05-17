#!/bin/bash

#----------- client list ------------
clients=( mc022 )
#clients=( mc022 mc023 mc024 mc025  )

#----------- run params -------------
volume_size=400G
threads=16
#write_data=3000g
#read_data=1000g
#write_data=400g
#read_data=400g
interval=10
block_size=$2 #54
vol_num=$4 #128
#vol_num=1 #128
#vol_num=128 #128
#----------- qlogic params ---------
mod_name="qla2xxx"
qlogicMax=$3
CP=$5

let "write_data= $vol_num*40*1024*1024*1024+300*1024*1024*1024"
let "read_data=$write_data/2"


echo "Running vdbench configuration "
echo "stand [ $1 ] BlockSize [ $block_size ] qd [ $qlogicMax ] nvolumes [ $vol_num ] cmp [ $CP ]"
echo "write data [ $write_data ] read_data [ $read_data ]"


if tty -s ; then
        COLUMNS=$(tput cols)
        R_MARGIN=30
        SUCCESS='[\\033[2\;32mSUCCESS\\033[m]\ '
        FAILED='[\\033[1\;31mFAILED!\\033[m]\\a'
        WARNING='[\\033[0\;33mWARNING\\033[m]\\a'
        MOVE_TO_COL=$(echo -en "\033[${COLUMNS}G\033[${R_MARGIN}D")
else
        SUCCESS='[SUCCESS]'
        FAILED='[FAILED!]'
        WARNING='[WARNING]'
        MOVE_TO_COL='\\t '
        function tput () { builtin true ; }
fi
#----------- Misc functions -----------

function echo_success () { eval echo -e "${MOVE_TO_COL} ... ${SUCCESS}"; }
function echo_failure () { eval echo -e "${MOVE_TO_COL} ... ${FAILED}";  }
function echo_warning () { eval echo -e "${MOVE_TO_COL} ... ${WARNING}"; }



#echo "running with block size=$block_size"
#echo "running with qlogic qdepth=$qlogicMax"

#-------------  delete old clients
                ssh $1 -p 26 "i=\"0\"; while [ 1 -lt \`lshost|wc -l\` ]; do svctask rmhost -force \$i; i=\$[\$i+1]; done"
#-------------  add clients
		ssh $1 -p 26 svctask mkhost -fcwwpn 21000024FF5AED09:21000024FF5AED08:21000024FF4AD3E8:21000024FF4AD3E9 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name mc022 -type generic
		#ssh $1 -p 26 svctask mkhost -fcwwpn 21000024FF4AD358:21000024FF4AD359:21000024FF5AEF5E:21000024FF5AEF5F -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name mc023 -type generic
		#ssh $1 -p 26 svctask mkhost -fcwwpn 21000024FF4AD43C:21000024FF4AD43D:21000024FF5AEFEE:21000024FF5AEFEF -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name mc024 -type generic
		#ssh $1 -p 26 svctask mkhost -fcwwpn 21000024FF499756:21000024FF499757:21000024FF5AAC40:21000024FF5AAC41 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name mc025 -type generic
#------------ clear log
		echo "Cleaning logs"
		ssh $1 -p 26 svctask clearerrlog -force


#----------------- do a loop with all compression ratios
#for CP in {1.3,1.7,2.3,3.5,11}; do
#	CP=2.3
	mdiskid=`ssh $1 -p 26 ""lsmdiskgrp |grep -v id | sed -r 's/^[^0-9]*([0-9]+).*$/\1/'""`
        echo -e "Removing mdiskgrp id : $mdiskid from $1"
        ssh $1 -p 26 svctask rmmdiskgrp -force $mdiskid
#	
#---------- remove FC module	
#	for client in "${clients[@]}"; do
#		ssh $client rmmod qla2xxx -f
#	done
#---------- build disks

	ssh $1 -p 26 "ls /home/mk_arrays_master 2&>1 /dev/null"
	if [[ $? == 0 ]]; then
		echo -n "Running with FAB configuration"
		ssh $1 -p 26 "/home/mk_arrays_master fc raid10 sas_hdd 96 8 12 128 200 NOSCRUB COMPRESSED 1> /dev/null"  && { echo_success; } || { echo_failure; exit ; }
	else
		echo -n "Running with BFN configuration"
		ssh $1 -p 26 "/home/mk_vdisks fc 1 $vol_num 500000 0 COMPRESSED 1> /dev/null"  && { echo_success; } || { echo_failure; exit ; }
	fi
	sleep 60

#-------------  rescan multipath on clients
        if [[ -n $qlogicMax ]] ; then
                MOD_OPTIONS="ql2xmaxqdepth=$qlogicMax"
                echo "Setting New qdepth ${MOD_NAME} ${MOD_OPTIONS}"
        else
                MOD_OPTIONS="ql2xmaxqdepth=128"
                echo "using default qdepth ${MOD_NAME} ${MOD_OPTIONS}"
        fi

        for client in "${clients[@]}"; do
                echo -n "Host name  : $client";echo ""
		if [[ `ssh $client "cat /sys/module/qla2xxx/parameters/ql2xmaxqdepth"` -ne "$qlogicMax" ]] ; then
			echo -n "Removing all previous multipath devices again ( multipath -F ):"
                        ssh $client "multipath -F  1> /dev/null" && { echo_success ; } || { echo_failure ; exit ; }
			echo -n "Multipath Service is Stopped :"
			ssh $client "/etc/init.d/multipathd stop 1> /dev/null" && { echo_success ; } || { echo_failure ; exit ; }
			echo -n "Qlogic module Removed : "
			ssh $client "/sbin/rmmod qla2xxx -f 1> /dev/null" && { echo_success; } || { echo_failure ; exit ; }
			if [ "$?" -eq "1" ] ; then
				echo "Failure to unload qla module"
				exit
			fi
			echo -n "Loading QLogic Module with qdepth [ ${MOD_OPTIONS} ] :  "
			ssh $client "/sbin/modprobe ${mod_name} ${MOD_OPTIONS}" && { echo_success; } || { echo_failure; exit ; }
		fi
                echo -n "Restarting multipath service :"
                ssh $client "/etc/init.d/multipathd restart 1> /dev/null" && { echo_success ; } || { echo_failure; exit ; }
                echo -n "Total vdisk found : "
                ssh $client "/root/vdbench/rescan.pl"
                echo ""
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

#done

./get_vdbench_resm.pl --stand=$1 --qd=$qlogicMax --cmp=$CP --nvol=$vol_num -d


ssh $1 -p 26 svctask rmmdiskgrp -force 0
