#!/usr/bin/python
import argparse
__author__ = 'nixCraft'

parser = argparse.ArgumentParser(description='This is a demo script by nixCraft.')
parser.add_argument('-i','--input', help='Input file name',required=True)
parser.add_argument('-o','--output',help='Output file name', required=True)
args = parser.parse_args()
# show values ##
print ("Input file: %s" % args.input )
print ("Output file: %s" % args.output )

