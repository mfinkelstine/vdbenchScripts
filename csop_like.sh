#!/bin/bash

#----------- client list ------------
clients=( wl9 wl10 wl11 wl12  )

#----------- run params -------------
volume_size=40G
threads=16
interval=10
block_size=64k #54
vol_num=64 #128

#-------------  delete old clients
                ssh $1 -p 26 "i=\"0\"; while [ 1 -lt \`lshost|wc -l\` ]; do svctask rmhost -force \$i; i=\$[\$i+1]; done"
#-------------  add clients
		ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a4478:21000024ff3a4479:21000024ff3a4482:21000024ff3a4483 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl9  -type generic
		ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a464c:21000024ff3a464d:21000024ff3a4458:21000024ff3a4459 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl10 -type generic
		ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff499742:21000024ff499743:21000024ff38c86c:21000024ff38c86d -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl11 -type generic
		ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a45aa:21000024ff3a45ab:21000024ff3a406a:21000024ff3a406b -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl12 -type generic
#------------ clear log
		echo "Cleaning logs"
		ssh $1 -p 26 svctask clearerrlog -force


#----------------- do a loop with all compression ratios
	mdiskid=`ssh $1 -p 26 ""lsmdiskgrp |grep -v id | sed -r 's/^[^0-9]*([0-9]+).*$/\1/'""`
        echo -e "Removing mdiskgrp id : $mdiskid from $1"
        ssh $1 -p 26 svctask rmmdiskgrp -force $mdiskid

	ssh $1 -p 26 ls /home/mk_arrays_master
	if [[ $? == 0 ]]; then
		echo "Running with FAB configuration"
		#ssh $1 -p 26 /home/mk_arrays_master fc raid10 sas_hdd 168 8 21 $vol_num 500 NOSCRUB COMPRESSED
		ssh $1 -p 26 /home/mk_arrays_master fc raid10 sas_hdd 96 8 12 128 200 NOSCRUB COMPRESSED
	else
		echo "Running with BFN configuration"
		ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num 40960 0 COMPRESSED
	fi
	sleep 60

#-------------  rescan multipath on clients
 
	for client in "${clients[@]}"; do
		ssh $client /usr/global/scripts/delvol.pl -mp /mnt/lun
#		ssh $client /sbin/modprobe -i qla2xxx
#		ssh $client service multipathd restart
		echo -e "found: \c"
		ssh $client /usr/global/scripts/rescan.pl
		echo " disks"
	done

#-------------  create map of availiable disks
	echo " " > disk_list
	for client in "${clients[@]}"; do
		COUNT=1
		for LINE in `ssh $client fdisk -l |grep "Disk /dev/mapper"| awk '{print $2}' | sed s/://`; do
        		echo "sd=$client.$COUNT,hd=$client,lun=$LINE,openflags=o_direct,size=$volume_size,threads=$threads" >> disk_list
        		COUNT=$(( COUNT +1 ))
		done;
	done

        echo "
compratio=2.3

" > test
        for client in "${clients[@]}"; do
                echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> test
        done
        echo "
include=disk_list

wd=wd1,sd=*,xfersize=$block_size,rdpct=100,rhpct=0,seekpct=0
rd=prepare,sd=*,xfersize=4k,rdpct=0,seekpct=0,iorate=max,elapsed=100h,interval=10,maxdata=1
rd=chunk_100,sd=*,xfersize=4k,rdpct=100,seekpct=100,iorate=curve,curve=(10-100,10),elapsed=10m,interval=10,pause=2m
rd=chunk_70,sd=*,xfersize=4k,rdpct=70,seekpct=100,iorate=max,elapsed=10m,interval=10,pause=2m
rd=chunk_50,sd=*,xfersize=4k,rdpct=50,seekpct=100,iorate=max,elapsed=10m,interval=10,pause=2m
rd=chunk_0,sd=*,xfersize=4k,rdpct=0,seekpct=100,iorate=max,elapsed=10m,interval=10,pause=2m
rd=random_100,sd=*,xfersize=4k,rdpct=100,seekpct=0,iorate=max,elapsed=10m,interval=10,pause=2m
rd=random_70,sd=*,xfersize=4k,rdpct=70,seekpct=0,iorate=max,elapsed=10m,interval=10,pause=2m
rd=random_50,sd=*,xfersize=4k,rdpct=50,seekpct=0,iorate=max,elapsed=10m,interval=10,pause=2m
rd=random_0,sd=*,xfersize=4k,rdpct=0,seekpct=0,iorate=max,elapsed=10m,interval=10,pause=2m

" >> test

./vdbench -c -f test | tee -a out_$CP


