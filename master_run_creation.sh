#!/bin/bash

#----------- client list ------------
clients=( wl9 wl10 wl11 wl12  )
test_type=$3
ports=$2
#----------- run params -------------
volume_size=40G
threads=4
write_data=3000g
read_data=1000g
interval=10
block_size=64k 
vol_num=64

#-------------  delete old clients
                ssh $1 -p 26 "i=\"0\"; while [ 1 -lt \`lshost|wc -l\` ]; do svctask rmhost -force \$i; i=\$[\$i+1]; done"
#-------------  add clients
if [ $test_type eq "csop" ] ; then
		if [[ $ports == "4" ]] ; then
            if ! ssh $c /usr/global/scripts/qla_show_wwpn.sh | grep -i -c Up == "$ports" ;then
                echo "$c have port offline "$(ssh $c /usr/global/scripts/qla_show_wwpn.sh | grep -i down)
                exit
            fi
			echo "choosed 4 ports design"
			ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a4478:21000024ff3a4479:21000024ff3a4482:21000024ff3a4483 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl9 -type generic
			ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a464c:21000024ff3a464d:21000024ff3a4458:21000024ff3a4459 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl10 -type generic
			ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff499742:21000024ff499743:21000024ff38c86c:21000024ff38c86d -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl11 -type generic
			ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a45aa:21000024ff3a45ab:21000024ff3a406a:21000024ff3a406b -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl12 -type generic
		else
			#ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a4478:21000024ff3a4482 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl9 -type generic
			#ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a464c:21000024ff3a4458 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl10 -type generic
			#ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff499742:21000024ff38c86c -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl11 -type generic
			#ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a45aa:21000024ff3a406a -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl12 -type generic
			echo "choosed 2 ports design"
			ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a4478 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl90 -type generic
			ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a464c -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl100 -type generic
			ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff499742 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl110 -type generic
			ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a45aa -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl120 -type generic
			# like csop
			ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a4482 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl91 -type generic
			ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a4458 -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl101 -type generic
			ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff38c86c -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl111 -type generic
			ssh $1 -p 26 svctask mkhost -fcwwpn 21000024ff3a406a -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name wl121 -type generic

		fi
elif [ $test_type eq "vdbench" ]; then
    for c in ${clients[@]};
    do  
        echo "Connecting full vdbench ports"
        wwpn=`ssh $c /usr/global/scripts/qla_show_wwpn.sh |sort | head -2`
        echo "Creating host $c on $1"
        wwpn=`ssh $c /usr/global/scripts/qla_show_wwpn.sh | sort | grep Up | awk '{print $1}' | tr "\n" ":"| sed -e 's|\:$||g'`
        ssh $1 -p 26 svctask mkhost -fcwwpn $wwpn  -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name $c -type generic
        ec

    done
else

fi

function addHosts(){
    for c in ${clients[@]};
    do  
        echo "Creating host $c on $1"
        wwpn=`ssh $c /usr/global/scripts/qla_show_wwpn.sh | sort | grep Up | awk '{print $1}' | tr "\n" ":"| sed -e 's|\:$||g'`
        #wwpn=`ssh $c /usr/global/scripts/qla_show_wwpn.sh | grep Up | awk '{print $1}' | tr "\n" ":"| sed -e 's|\:$||g'`
        ssh $1 -p 26 svctask mkhost -fcwwpn $wwpn  -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name $c -type generic
    done

}

exit
#------------ clear log
		echo "Cleaning logs"
		ssh $1 -p 26 svctask clearerrlog -force


#----------------- do a loop with all compression ratios
	mdiskid=`ssh $1 -p 26 ""lsmdiskgrp |grep -v id | sed -r 's/^[^0-9]*([0-9]+).*$/\1/'""`
        echo -e "Removing mdiskgrp id : $mdiskid from $1"
        ssh $1 -p 26 svctask rmmdiskgrp -force $mdiskid
#	
	ssh $1 -p 26 ls /home/mk_arrays_master
	if [[ $? == 0 ]]; then
		echo "Running with FAB configuration"
		#ssh $1 -p 26 /home/mk_arrays_master fc raid10 sas_hdd 168 8 21 $vol_num 500 NOSCRUB COMPRESSED
		ssh $1 -p 26 /home/mk_arrays_master fc raid10 sas_hdd 96 8 12 128 200 NOSCRUB COMPRESSED
		#ssh $1 -p 26 /home/mk_arrays_master fc raid10 sas_hdd 96 8 12 128 200 NOSCRUB
	else
		echo "Running with BFN configuration"
		#ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num 50000 0
		ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num 40000 0 
		#ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num 500000 0 COMPRESSED
#		ssh $1 -p 26 /home/mk_vdisks fc 1 $vol_num 500000 0 NOCACHE COMPRESSED
	fi
	sleep 60

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

