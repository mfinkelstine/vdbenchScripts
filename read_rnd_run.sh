#!/bin/bash
echo "
        
wd=wd2,sd=sd*,xfersize=16k,rdpct=100,rhpct=0,seekpct=100,pattern=/root/vdbench_full/patterns/1MB.$1p
rd=run2,wd=wd2,iorate=max,elapsed=20m,interval=60

"
