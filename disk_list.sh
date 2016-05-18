#!/bin/bash
clients=( $1 )
disklist=$2
debug=no

if [ -z "$disklist" ] ; then
    disklist=disk_list
fi

if [ -s $disklist ] ; then
    cat /dev/null > $disklist
fi


threads=4

for h in ${clients[@]} ; 
do 
    volume_size=$(ssh $h multipath -l | grep size  | uniq |awk '{print $1}' | sed -e 's/.*=//g')
    
    echo $h volume size [ $volume_size ] ; 
    count=1
    for dev in `ssh $h multipath -l|grep "2145" | awk '{print \$1}'`
    do
        #echo $dev
        device="/dev/mapper/$dev"
	if [[ $debug == "yes" ]] ; then
		echo "sd=$h.$count,hd=$h,lun=$device,openflags=o_direct,size=$volume_size,threads=$threads" | tee -a $disklist
	else 
        	echo "sd=$h.$count,hd=$h,lun=$device,openflags=o_direct,size=$volume_size,threads=$threads" >> $disklist
	fi 
        count=$(( count+1 ))
    done

done
