#!/bin/bash

for cp in 1.7 2.3 ; do
	for vd in 1 4 8 ; do
		for qd in 32 48 ; do
			echo "Running master_run_wpp.sh rtcsvc11 64k $qd with nVdisk $vd cmp $cp"
			./master_run_wwpp.sh rtcsvc11 64k $qd $vd $cp
			sleep 300 
		done
	done
done

