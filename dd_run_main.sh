#!/bin/bash

LIST=`multipath -l |grep IBM | awk '{print $1}'`

for disk in $LIST; do
	
	cmd="/root/vdbench/dd_run.sh $disk"
	#echo $cmd
	nohup $cmd &

done
