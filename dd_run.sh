#!/bin/bash

i="0"

while [ $i -lt 6553600 ]; do

	dd if=/root/vdbench/pattern_file of=/dev/mapper/$1 bs=64k count=15 seek=$i oflag=direct
	dd if=/dev/mapper/$1 of=/dev/null bs=64k count=15 skip=$i
	i=$[$i+15]	

done
