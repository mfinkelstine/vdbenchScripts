#!/bin/bash
clients=( $1 )

disklist="hostDevices"

if [ -s $disklist ] ; then
    cat /dev/null > $disklist
fi

threads=4
for h in ${clients[@]} ; 
do 
    echo $h ; 
    count=1
    for dev in `ssh $h multipath -l|grep "2145" | awk '{print \$1}'`
    do
        #echo $dev
        device="/dev/mapper/$dev"
        echo "sd=$h.$count,hd=$h,lun=$device,openflags=o_direct,size=volume_size,threads=$threads" | tee -a $disklist
        count=$(( count+1 ))
    done

done
