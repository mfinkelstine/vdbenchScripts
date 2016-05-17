#!/bin/bash
echo "

compratio=$1

hd=mc001,system=localhost,vdbench=/root/vdbench,user=root
hd=mc002,system=mc002.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root
hd=mc003,system=mc003.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root
hd=mc004,system=mc004.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root

include=disk_list

wd=wd1,sd=sd*,xfersize=64k,rdpct=100,rhpct=0,seekpct=0
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=$2,interval=$3
"
