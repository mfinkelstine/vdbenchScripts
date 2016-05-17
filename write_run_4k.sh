#!/bin/bash
echo "

compratio=$1

hd=wl31,system=localhost,vdbench=/root/vdbench,user=root
hd=wl32,system=wl32.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root
hd=wl33,system=wl33.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root
hd=wl34,system=wl34.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root

include=disk_list

wd=wd1,sd=sd*,xfersize=4k,rdpct=0,rhpct=0,seekpct=0
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=500g,interval=10
"
