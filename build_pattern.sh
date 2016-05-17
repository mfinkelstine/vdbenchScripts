#!/bin/bash

i="0"

while [ $i -lt 16 ]; do

	#dd if=/perf_tool/patterns/1MB.50p of=pattern bs=64k seek=$i count=1
	dd if=in_pattern of=pattern bs=64k skip=$i seek=$i count=1
	i=$[$i+1]
	dd if=/dev/urandom of=pattern bs=64k seek=$i count=1
	i=$[$i+1]

done
