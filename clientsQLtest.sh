#!/bin/bash

clients=( mc022 mc023 mc024 mc025 )
qlogicMax=$1

if tty -s ; then
        COLUMNS=$(tput cols)
        R_MARGIN=30
        SUCCESS='[\\033[2\;32mSUCCESS\\033[m]\ '
        FAILED='[\\033[1\;31mFAILED!\\033[m]\\a'
        WARNING='[\\033[0\;33mWARNING\\033[m]\\a'
        MOVE_TO_COL=$(echo -en "\033[${COLUMNS}G\033[${R_MARGIN}D")
else
        SUCCESS='[SUCCESS]'
        FAILED='[FAILED!]'
        WARNING='[WARNING]'
        MOVE_TO_COL='\\t '
        function tput () { builtin true ; }
fi


######################
### Misc functions ###
######################

function echo_success () { eval echo -e "${MOVE_TO_COL} ... ${SUCCESS}"; }
function echo_failure () { eval echo -e "${MOVE_TO_COL} ... ${FAILED}";  }
function echo_warning () { eval echo -e "${MOVE_TO_COL} ... ${WARNING}"; }


#-------------  rescan multipath on clients
        MOD_NAME="qla2xxx"
        if [[ -n $qlogicMax ]] ; then 

		MOD_OPTIONS="ql2xmaxqdepth=$qlogicMax"
		echo "Setting New qdepth ${MODE_NAME} ${MOD_OPTIONS}" 
	else
	
		qlogicMax=128
		MOD_OPTIONS="ql2xmaxqdepth=$qlogicMax"
		echo "using default qdepth ${MODE_NAME} ${MOD_OPTIONS}" 
	fi

        for client in "${clients[@]}"; do
		echo -n "Host name  : $client";echo ""
		if [[ `ssh $client "cat /sys/module/qla2xxx/parameters/ql2xmaxqdepth"` -ne "$qlogicMax" ]] ; then
			echo -n "Removing all previous multipath devices again ( multipath -F ):"
	                ssh $client "multipath -F  1> /dev/null" && { echo_success ; } || { echo_failure ; exit ; }
			echo -n "Multipath Service is Stopped :"
	                ssh $client "/etc/init.d/multipathd stop 1> /dev/null" && { echo_success ; } || { echo_failure ; exit ; }
			echo -n "Qlogic module Removed : "
                	ssh $client "/sbin/rmmod qla2xxx 1> /dev/null" && { echo_success; } || { echo_failure ; exit ; }
			if [ "$?" -eq "1" ] ; then
				echo "Failure to unload qla module"
				exit
			fi
			echo -n "Loading QLogic Module with qdepth [ ${MOD_OPTIONS} ] :  "
                	ssh $client "/sbin/modprobe ${MOD_NAME} ${MOD_OPTIONS}" && { echo_success; } || { echo_failure; exit ; }
		fi
		echo -n "Restarting multipath service :"
                ssh $client "/etc/init.d/multipathd restart 1> /dev/null" && { echo_success ; } || { echo_failure; exit ; }
                echo -n "Total vdisk found : "
#                ssh $client "/root/vdbench/rescan.pl"
		echo ""
        done
	#echo "Checking qdepth on clients"
#        for client in "${clients[@]}"; do
#                ssh $client "cat /sys/module/qla2xxx/parameters/ql2xmaxqdepth"
#	done

