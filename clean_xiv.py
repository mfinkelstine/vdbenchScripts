#!/usr/bin/python

XCLI="/xiv/tools/bin-wrap/xcli.py"

import os
import sys
import subprocess as sp

def get_storage_info(kind):
    results = sp.Popen([XCLI, kind, '-z'], stdout=sp.PIPE).stdout.read()
    return results

def split_output(indata):
    results = []
    for line in indata.split('\n'):
        if not ('are defined' in line):
           data = line.split(' ')[0]
           if data != '' :
               results.append(data)
    return results

def del_command(kind, data):
    print "Deleting " + kind + " : " + data
    command = "  " + XCLI + ' ' + kind + '_delete ' + kind + '=' + data + ' -y'
    print command
    os.system(command)

def delete_volumes():
    devs = split_output(get_storage_info('vol_list'))
    if not devs:
        print "No Volume(s) to delete."
        return
    for vol in devs:
        data = sp.Popen([XCLI, 'vol_mapping_list', 'vol=' + vol, '-z'], stdout=sp.PIPE).stdout.read()
        vhosts = split_output(data)
        for host in vhosts:
            print 'UnMapping ' + vol + ' from ' + host
            cm = XCLI + ' unmap_vol host=' + host + ' vol=' + vol
            print (cm)
            os.system(cm)
        del_command('vol', vol)

def delete_pools():
    pools = split_output(get_storage_info('pool_list'))
    if not pools:
        print "No Pool(s) to delete."
        return
    for pool in pools:
        del_command('pool', pool)

def delete_hosts():
    hosts = split_output(get_storage_info('host_list'))
    if not hosts:
        print "No Host(s) to delete."
        return
    for host in hosts:
        del_command('host', host)

def delete_cluster():
    clusters = split_output(get_storage_info('cluster_list'))
    if not clusters:
        print "No Cluster(s) to delete."
        return
    for cluster in clusters:
        del_command('cluster', cluster)

def main (args):
    if not args:
        args = 'all'
    else:
        args = args[0]
    if args in ['all', 'vols']:
        delete_volumes()
    if args in ['all', 'pools']:
        delete_pools()
    if args in ['all', 'hosts']:
        delete_hosts()
    if args in ['all', 'clusters']:
        delete_cluster() 

if __name__ == "__main__":
    main(sys.argv[1:])

