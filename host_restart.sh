#!/bin/bash

hosts=( wl9 wl10 wl11 wl12)

echo "restarting hosts"
for h in ${hosts[@]} ; do
    ssh $h shutdown -r now 
done
host_count=${#hosts[@]}
whil true:
do

    for h in ${hosts[@]}
    do
        ssh $h uptime 
        if [ $? == 1 ] ; then
            echo "host still doen";
            hostsStatus[$h]="done"
        else
            hostsStatus[$h]="up"
        fi
    done
    echo "checking host stats"
    

done
