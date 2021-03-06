#!/bin/bash

#----------- client list ------------
clients=( $2 )
#clients=( wl21 wl22 wl23 wl24  )
#----------- run params -------------

volume_size=488G
vol_size=""
threads=$3
write_data=3000g
read_data=1000g
interval=3
block_size=64k 
vol_num=128

#------ test defenitions -----
WRITE="write_test_"
READ="read_test_"

if [[ $threads == "" ]] ; 
then
    threads=16
fi

#-------------  delete old clients
echo "Removing Existing hosts : "$(ssh -p 26 $1 lshost -nohdr | awk '{print $2}' | tr "\n" "," )
ssh $1 -p 26 "i=\"0\"; while [ 1 -lt \`lshost|wc -l\` ]; do svctask rmhost -force \$i; i=\$[\$i+1]; done"
#-------------  add clients
echo "Creating hosts"
for c in ${clients[@]}
do
    echo "Creating host $c on $1"
    wwpn=`ssh $c /usr/global/scripts/qla_show_wwpn.sh | grep Up | awk '{print $1}' | tr "\n" ":"| sed -e 's|\:$||g'`
    ssh $1 -p 26 svctask mkhost -fcwwpn $wwpn  -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name $c -type generic 2>/dev/null
done
#------------ clear log
		echo "Cleaning logs"
		ssh $1 -p 26 svctask clearerrlog -force
#--- create results directory
svcVersion=$(ssh $1 -p 26 cat /compass/version )
svcBuild=$(ssh $1 -p 26 cat /compass/vrmf )
results_path="vdbench_benchmark_test"
rpath="$results_path/$(date +%y%m%d_%H%M%S)/$svcBuild/$svcVersion/"
test_results="$results_path/$(date +%y%m%d_%H%M%S)/$svcBuild/$svcVersion/test_results"
test_files="$results_path/$(date +%y%m%d_%H%M%S)/$svcBuild/$svcVersion/test_files"
test_data="$results_path/$(date +%y%m%d_%H%M%S)/$svcBuild/$svcVersion/output_data"

if [ ! -d "$rpath" ] ; then
    mkdir -p $test_results
    mkdir -p $test_files
    mkdir -p $test_data
fi

for bs in 1m 512k 256k 128k 64k 32k 16k 8k 4k ; do

#----------------- do a loop with all compression ratios
for CP in {1.3,1.7,2.3,3.5,11}; do

output_file=$test_results/"out_$CP"
disk_file=$CP"_disk_list"

write_test_file=$test_files/$CP"_write"
read_test_file=$test_files/$CP"_read"


disk_list=$test_files/$disk_file

test_info="vdbench_benchmark_information_$CP.log"

echo -e "===[ test parameters ]===================================================================
Compration ratio      : [ $CP          ]
Total Volume          : [ $vol_num     ]
Volume size           : [ $volume_size ]
Total threads per lun : [ $threads     ]
Total write data      : [ $write_data  ]
Total read data       : [ $read_data   ]
Test Block Size       : [ $bs        ]
===[ Storage information ]======================================================================
SVC Version           : [ $svcVersion ]
SVC Build             : [ $svcBuild ]
===[ directory stracture ]=====================================================================
test results          : [ $test_results ]
test files directory  : [ $test_files   ]
output test data      : [ $test_data  ]
output file           : [ $output_file  ]
" | tee -a  $rpath/$test_info


mdiskid=`ssh $1 -p 26 ""lsmdiskgrp |grep -v id | sed -r 's/^[^0-9]*([0-9]+).*$/\1/'""`
echo -e "Removing mdiskgrp id : $mdiskid from $1" | tee -a $rpath/$test_info
ssh $1 -p 26 svctask rmmdiskgrp -force $mdiskid

	ssh $1 -p 26 ls /home/mk_arrays_master >/dev/null
	if [[ $? == 0 ]]; then
		echo "Running with FAB configuration"
#        ssh -p 26 $1 /home/mk_arrays_master fc raid5 sas_hdd 238 8 32 128 400 COMPRESSED NOFMT AUTOEXP >/dev/null
        array_drive=8
        number_of_drive=$(ssh -p 26 $1 lsdrive -nohdr | wc -l)
        number_of_mdisk_group=$(( $number_of_drive / $array_drive ))
        ssh -p 26 $1 /home/mk_arrays_master fc raid10 sas_hdd $number_of_drive $array_drive $number_of_mdisk_group $vol_num 500 COMPRESSED NOFMT NOSCRUB >> $rpath/$test_info
	else
		echo "Running with BFN configuration"
		#echo "ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num 409600 0 NOFMT COMPRESSED AUTOEXP >/dev/null"
		ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num 495600 0 NOFMT COMPRESSED AUTOEXP >> $rpath/$test_info
	fi
	sleep 60


#-------------  rescan multipath on clients
 
    for client in "${clients[@]}"; do
        echo -e "++ rescan on $client +++++++++++++++++++++++++++++ " | tee -a $rpath/$test_info
        ssh $client /usr/global/scripts/rescan_all.sh >> $rpath/$test_info
        echo "Total mpath disks " $(ssh $client multipath -l | grep -c mpath) | tee -a $rpath/$test_info
    done

#-------------  create map of availiable disks
	echo " " > $disk_list 
	for client in "${clients[@]}"; do
		COUNT=1
		for LINE in `ssh $client fdisk -l |grep "Disk /dev/mapper"| awk '{print $2}' | sed s/://`; do
        		echo "sd=$client.$COUNT,hd=$client,lun=$LINE,openflags=o_direct,size=$volume_size,threads=$threads" >> $disk_list
        		COUNT=$(( COUNT +1 ))
		done;
	done

#write  
	echo "
compratio=$CP
messagescan=no
	
" > $write_test_file
	for client in "${clients[@]}"; do
		echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> $write_test_file
	done
	echo "
include=$disk_list

wd=wd1,sd=*,xfersize=$bs,rdpct=0,rhpct=0,seekpct=0
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=$write_data,warmup=360,interval=$interval
" >> $write_test_file

	./vdbench -c -f $write_test_file  -o $test_data/output_$CP | tee -a $output_file


#-------- take comp ratios
	./graphite_rtc_cr.py $1 | tee -a $output_file
	sleep 120
#read
        echo "
compratio=$CP
messagescan=no
" > $read_test_file
        for client in "${clients[@]}"; do
                echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> $read_test_file
        done
        echo "
include=$disk_list

wd=wd1,sd=*,xfersize=$bs,rdpct=100,rhpct=0,seekpct=0
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=$read_data,warmup=360,interval=$interval
" >> $read_test_file

	./vdbench -c -f $read_test_file -o $test_data/output_$CP | tee -a $output_file

done

./get_vdbench_res.pl --stand=$1 -d $test_results
done 
