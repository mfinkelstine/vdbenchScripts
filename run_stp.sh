#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "need stand name"
    exit 1
fi

for BS in {4k,16k,32k,64k,256k}; do

	echo "Running with block size=$BS and stand $1"
	/root/vdbench/master_run_stp.sh $1 $BS > /root/vdbench/current_run_$BS 2>&1

done

echo "Running with 4kB random write scenario"
./master_run_stp_4kw.sh $1

exit 0
