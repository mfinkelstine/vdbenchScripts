#!/bin/bash
clients=( wl13 wl14 wl15 wl16 )

for h in ${clients[@]} ; 
do 
    echo $h ; 
    count=1
    for dev in `ssh $h multipath -l|grep "2145" | awk '{print \$1}'`
    do
        #echo $dev
        device="/dev/mapper/$dev"
        echo "sd=$h.$count,hd=$h,lun=$device,openflags=o_direct,size=volume_size,threads=$threads"
        count=$(( count+1 ))
    done

done
