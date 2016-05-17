#!/usr/bin/python
import getopt
import sys
import re
import json
#import vdbench
import pprint



"""
Usage: master_scale_test.py [OPTION]...
Options:
  -h,  --help            Prints this message
  -q,  --quiet           Disables logging to console
  -d,  --debug           Print debug information
       --pidfile=[FILE]  Combined with --daemon creates a pid file
  -p,  --port=[PORT]     Override default/configured port to listen on
       --datadir=[PATH]  Override folder (full path) as location for
                         storing database, config file, cache, and log files
                         Default SickRage directory
       --config=[FILE]   Override config filename for loading configuration
                         Default config.ini in SickRage directory or
                         location specified with --datadir
	   --blocksize       block size to use ex' [ '4k 8k 16k 32k 64k 128k 256k 512k 1m' ]
	   --comp_ratio      compression ratio to use ex' [ '30 50 65 75 83 93' ]
	   --write_data      total write data
	   --read_data       total read  data
"""

version = '1.0'
verbose = False

# global parameters:
blocksize = [ "4k", "8k", "16k", "32k", "64k", "128k","256k", "512k" ,"1m" ]
comp_ratio = {
	'30': '1.3',
	'50': '1.7',
	'63': '2.3',
	'75': '3.5',
	'93': '11'
}
dataset= {
		"write": "3000g",
		"read": " 2000g"
		}


js = 'example_json_file.json'
opts = {}

def usage():
	print "Values inside the function:\
Naval Fate.\
\
Usage:\
  naval_fate.py ship new <name>...\
  naval_fate.py ship <name> move <x> <y> [--speed=<kn>]\
  naval_fate.py ship shoot <x> <y>\
  naval_fate.py mine (set|remove) <x> <y> [--moored | --drifting]\
  naval_fate.py (-h | --help)\
  naval_fate.py --version\
\
Options:\
  -h --help     Show this screen.\
  --version     Show version.\
  --speed=<kn>  Speed in knots [default: 10].\
  --moored      Moored (anchored) mine.\
  --drifting    Drifting mine.\
\
"
#class vdbench(object):
#
#    def ___init___(self):
#        self.debug      = False
#        self.verbose    = False
#        self.help       = False
#        self.blocksize  = {}
#        self.compratio  = {}
#        self.quiet      = False
#        self.log_dir 	= None
#        self.console_logging = True

def parsing_cli_arguments():
	print "Start extracting cli arguments\n"
	try:
		opts, _ = getopt.getopt(
				sys.argv[1:], 'hqdpv::',
				['help', 'verbose', 'debug' ,'blocksize=','bs=', 'writedata', 'readdata' , 'cmp=' , 'compratioi=','type=','clients=','stand=','stor=' ]
		)
	except getopt.GetoptError:
		sys.exit(help_message())

	for option, value  in opts:
		print "argv option is %s"%option
		# print the help menu
		if option in ( '-h' , '--help'):
			sys.exit(self.help_message())
		# adding verbose to the output
		if option in ( '-v' , '--verbose'):
			verbose = True
			test_defenitions["verbose"] = True
			print "verbose is %s"%test_defenitions["verbose"]
		# adding debug information to output
		if option in ( '-d' , '--debug'):
			test_defenitions["debug"] = True
			print "debug status is : %s "%test_defenitions['debug']
		# block size
		if option in ( '--blocksize', '--bs'):
			value = re.sub(" ", "," , str(value))
			#value.replace(" ",",")
			values = ','.join(str(n) for n in value )
			test_defenitions["block_size"] = values
			print "blocksize status is : %s values %s"%(test_defenitions['block_size'], value)
		# compression ratio
		if option in ( '--cmp' , '--compratio'):
			test_defenitions["comp_ratio"] = str(value)
		# run the test on quite mode
		if option in ( '-q' , '--quiet'):
			test_defenitions["quiet"] = True
		if option in ( '--type'):
			test_defenitions["stand_type"] = value
		# adding stand name
		if option in ( '--stand', '--stor'):
			test_defenitions["stand_name"] = value
		#adding write data
		if option in ( '--writedata', '--write'):
			test_defenitions["writedata"] = str(value)
		#adding read data
		if option in ( '--readdata', '--read'):
			test_defenitions["readdata"] = str(value)




def help_message():
	"""
	Print help message for commandline options
	"""
   	help_msg = __doc__
   	help_msg = help_msg.replace('SickBeard.py', sickbeard.MY_FULLNAME)
   	help_msg = help_msg.replace('SickRage directory', sickbeard.PROG_DIR)
   	return help_msg


test_defenitions = {}

if __name__ == '__main__':
	parsing_cli_arguments()
	#vdbench.start()
