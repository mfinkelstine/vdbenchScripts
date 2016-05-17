#!/bin/bash
echo "

wd=wd1,sd=sd*,xfersize=16k,rdpct=0,rhpct=0,seekpct=100,range=(40,50),pattern=/root/vdbench_full/patterns/1MB.$1p
rd=run1,wd=wd1,iorate=max,warmup=0,elapsed=20m,interval=60

"
