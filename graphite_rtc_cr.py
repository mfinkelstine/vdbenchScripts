#!/usr/bin/python
import sys
import time
import os
import platform 
import subprocess
import re
from socket import socket

CARBON_SERVER = 'graphite.eng.rtca'
CARBON_PORT = 2003


if len(sys.argv) < 2:
    print "need the name of system"
    sys.exit(1)

def get_counters():
    lines = []
    command = "ssh "+sys.argv[1]+" -q -o ConnectTimeout=1 -o BatchMode=yes -o StrictHostKeyChecking=no -p 26 \" lsvdisk| awk '{print \$1}'|xargs -I {} lsvdisk -bytes {}|grep used_capacity\" "
    process = subprocess.Popen(command, stdout=subprocess.PIPE, shell=True)
    os.waitpid(process.pid, 0)
    output = process.stdout.read().strip().split("\n")
    now = int( time.time() )
    used_total = 0
    real_total = 0
    for line in output:
	   if line:
	   	data=line.split()
	   	if len(data) > 1:
			if data[0] == "used_capacity" and int(data[1]) > 3408384:
				used_total += int(data[1])
			if data[0] == "uncompressed_used_capacity" and int(data[1]) > 0:
				real_total += int(data[1])
    print used_total
    print real_total
    if used_total > 0 and real_total > 0:
    	message = 1-float(used_total)/real_total
    	print message
    else:
	    message = 0
    lines.append("%s %f %d" % (sys.argv[1]+".CompRatio",message,now))
    message = '\n'.join(lines) + '\n' #all lines must end in a newline
    return message

sock = socket()
try:
  sock.connect( (CARBON_SERVER,CARBON_PORT) )
except:
  print "Couldn't connect to %(server)s on port %(port)d, is carbon-agent.py running?" % { 'server':CARBON_SERVER, 'port':CARBON_PORT }
  sys.exit(1)

message = get_counters()
print "sending message\n"
print '-' * 80
print message
#sock.sendall(message)
