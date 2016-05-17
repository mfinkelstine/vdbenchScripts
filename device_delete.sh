#!/bin/bash

exclude=$(df | grep "^/dev"| awk '{print $1}'|sed -e 's|[0-9]$||g' -e 's|\/dev\/||g' |uniq)
mpath_devicelist=$(multipath -ll | egrep -v "^[a-z|A-Z]|^mpath|^size|policy"| awk '{print $3}')


for blk_dev in /sys/block/sd* ; do

dev_name=$(basename $blk_dev)
delete_dev=$blk_dev/device/delete

	if [[ $exclude == *$dev_name* ]]; then
		echo "[ $dev_name ] is local file system EXCLUDED"
	elif [ ! -w $delete_dev ]; then
		echo "[ $dev_name ] does not exist on the system"
	else
		echo  1 > $delete_dev
	fi 
done
