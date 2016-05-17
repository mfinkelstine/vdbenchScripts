#!/bin/bash
#for CP in {1.3,1.7,2.3,3.5,11}; do
	CP=2.3
	mdiskid=`ssh $1 -p 26 ""lsmdiskgrp |grep -v id | sed -r 's/^[^0-9]*([0-9]+).*$/\1/'""`
        echo -e "Removing mdiskgrp id : $mdiskid from $1"
        ssh $1 -p 26 svctask rmmdiskgrp -force $mdiskid

	ssh $1 -p 26 /home/mk_vdisks fc 1 32 1024000 0 COMPRESSED
#	ssh $1 -p 26 /home/mk_vdisks fc 1 32 102400 0
#	ssh $1 -p 26 /home/mk_vdisks fc 1 32 102400 0 NOCACHE COMPRESSED
	sleep 60
	
	for i in {31..34}; do ssh wl$i /etc/init.d/multipathd restart ;done
	for i in {31..34}; do ssh wl$i /usr/global/scripts/rescan.pl ;done

	./disk_list.sh > disk_list

#write
	#cat disk_list > test	
	./write_run.sh $CP > test
	./vdbench -c -f test | tee out_$CP

	./graphite_rtc_cr.py $1 | tee -a out_$CP
	sleep 120
#read
	#cat disk_list > test
        ./read_run.sh $CP > test
#        ./vdbench -c -f test | tee -a out_$CP

	ssh $1n1 -p 26 'echo ctr_dump /tmp/counters > /data/rtcracecli'
	scp -P 26 $1n1:/tmp/counters ./counters_n1_$CP

	ssh $1n2 -p 26 'echo ctr_dump /tmp/counters > /data/rtcracecli'
	scp -P 26 $1n2:/tmp/counters ./counters_n2_$CP

#done
