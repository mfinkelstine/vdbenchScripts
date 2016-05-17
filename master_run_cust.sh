#!/bin/bash

#----------- client list ------------
#clients=( $2 )
clients=( wl9 wl10 wl11 wl12  )

Server="rtcsvc16"

#----------- run params -------------

volume_size=60G
threads=16
write_data=7000g
read_data=3000g
interval=10
block_size=64k 
vol_num=128

#-------------  delete old clients
echo "Removing Existing hosts : "$(ssh -p 26 $Server lshost -nohdr | awk '{print $2}' | tr "\n" "," )
ssh $Server -p 26 "i=\"0\"; while [ 1 -lt \`lshost|wc -l\` ]; do svctask rmhost -force \$i; i=\$[\$i+1]; done"

#-------------  add clients
echo "Creating hosts"
for c in ${clients[@]}
do
    echo "Creating host $c on $Server"
    wwpn=`ssh $c /usr/global/scripts/qla_show_wwpn.sh | grep Up | awk '{print $1}' | tr "\n" ":"| sed -e 's|\:$||g'`
    ssh $Server -p 26 svctask mkhost -fcwwpn $wwpn  -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name $c -type generic
done

#------------ clear log
echo "Cleaning logs"
ssh $Server -p 26 svctask clearerrlog -force


#----------------- do a loop with all compression ratios
#for CP in {1.3,1.7,2.3,3.5,11}; do
for CP in 2.3 ; do
	echo -e "================================== compression $CP ======================================"
	echo -e "============[ SVC Version ]===[ $(ssh $Server -p 26 cat /compass/version) ]===================" 
	echo -e "============[ SVC Build   ]===[ $(ssh $Server -p 26 cat /compass/vrmf) ]======================" 
	mdiskid=`ssh $Server -p 26 ""lsmdiskgrp |grep -v id | sed -r 's/^[^0-9]*([0-9]+).*$/\1/'""`
	echo -e "Removing mdiskgrp id : $mdiskid from $Server"
	ssh $Server -p 26 svctask rmmdiskgrp -force $mdiskid

#---------- remove FC module	
#	for client in "${clients[@]}"; do
#		ssh $client rmmod qla2xxx -f
#	done
#---------- build disks

	ssh $Server -p 26 ls /home/mk_arrays_master >/dev/null
	if [[ $? == 0 ]]; then
		echo "Running with FAB configuration"
#        ssh -p 26 $Server /home/mk_arrays_master fc raid5 sas_hdd 238 8 32 128 400 COMPRESSED NOFMT AUTOEXP >/dev/null
        ssh -p 26 $Server /home/mk_arrays_master fc raid5 sas_hdd 224 8 32 128 409 COMPRESSED NOFMT NOCACHE NOSCRUB >/dev/null
	else
		echo "Running with BFN configuration"
		#echo "ssh $Server -p 26 /home/mk_vdisks fc 1 $vol_num 409600 0 NOFMT COMPRESSED AUTOEXP >/dev/null"
		ssh $Server -p 26 /home/mk_vdisks fc 1 $vol_num 102400 0 NOFMT COMPRESSED AUTOEXP >/dev/null
	fi
	sleep 60


#-------------  rescan multipath on clients
 
    for client in "${clients[@]}"; do
#    if ssh $client cat "/etc/redhat-release | grep 7" 1>/dev/null ; then
#        echo "unloading qla2xxx module"
#        ssh $client modprobe -v -r qla2xx >/dev/null
#        sleep 2
#		echo "Linux higher or equal to release 7"
#		ssh $client service multipathd restart >/dev/null
#	else
#        echo "unloading qla2xxx module"
#        ssh $client modprobe -v -r qla2xxx >/dev/null
#        sleep 2
#		echo "Linux lower then release "
#		ssh $client /etc/init.d/multipathd restart >/dev/null
#	fi
#	echo "reload qla2xxx"
#    ssh $client modprobe -i qla2xxx >/dev/null
        
	    echo -e "rescan on $client found: \c"
	    #ssh $client /root/vdbench/device_delete.sh
        #ssh $client multipath -F
        ssh $client /usr/global/scripts/rescan_all.sh 2>/dev/null
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
messagescan=no
	
" > Write_test
	for client in "${clients[@]}"; do
		echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> Write_test
	done
	echo "
include=disk_list

wd=wd1,sd=*,xfersize=$block_size,rdpct=0,rhpct=0,seekpct=0
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=$write_data,warmup=360,interval=$interval
" >> Write_test

	./vdbench -c -f Write_test | tee out_$CP


#-------- take comp ratios
	./graphite_rtc_cr.py $Server | tee -a out_$CP
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

#	./vdbench -c -f test | tee -a out_$CP

done

./get_vdbench_res.pl --stand=$Server -d

