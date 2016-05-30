#!/bin/bash
WRITE="write_test_"
READ="read_test_"
# 
# declaration satge:
#
declare -A vdbench_params
declare -A log
declare -A directoryStracture
declare -A vdbenchResultsLog
declare -A vdbench
declare -A storageInfo
declare -A compressionRatio=( [1.3]="30" [1.7]="50"  [2.3]="65" [3.5]="75" [11]="92" )
declare -A vdbenchResults
# color shcames
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
end=$'\e[0m'
#
#directoryStracture[absPath]="benchmark_results"
#directoryStracture[bas]="benchmark_results"
log[timestamp]=$(date +%y%m%d_%H%M%S)
log[debug]="/tmp/vdbench.benchmark.debug.${log[timestamp]}.log"
log[verbose]="/tmp/vdbench.benchmark.verbose.${log[timestamp]}.log"
log[error]="/tmp/vdbench.benchmark.error.${log[timestamp]}.log"
log[results]="/tmp/vdbench.benchmark.${log[timestamp]}.log"
log[info]="/tmp/vdbench.benchmark.info.${log[timestamp]}.log"
log[logOutput]="vdbench.global.log"
vdbenchResultsLog[writetest]="write_test_"
vdbenchResultsLog[readtest]="read_test_"
vdbenchResultsLog[out]="out_"
storageInfo[json]="storageInfo.json"

#printf "test time stemp %s\n" ${log[timestamp]}

parse_parameter() {

if [[ $# < 1 ]]; then
    usage
    exit
fi

while [[ $# > 1 ]]
do
    key="${1}"
    shift
    #echo -e "${key}"
    case "${key}" in      
        -vs | -volsize )
            #volsize="$1"
            storageInfo[volsize]="$1"
            shift
            ;;
        -vn | --volnum )
            storageInfo[volnum]="$1"
            shift
            ;;
        -s | --stand-name )
            storageInfo[stand_name]="$1"
            shift
            ;;
        -c | -clients)
            vdbench_params[clients]="$1"
            shift
            ;;
        -th | --threads )
            #thrades="$1"
            vdbench[threads]="$1"
            shift
            ;;
        -bs | -blocksize )
            #blocksize=( $1 )
            vdbench[blocksize]=$1
            shift
            ;;
        -i | --interval )
            #interval="$1"
            vdbench[interval]="$1"
            shift
            ;;
        -rd | --readdata )
            #read_data="$1"
            vdbench[readdata]="$1"
            shift
            ;;
        -wd | --writedata )
            #write_data="$1"
            vdbench[write_data]="$1"
            shift
            ;;
        -d | -debug )
            log[debug]="true"
            #debug="true"
            shift
            ;;
        -v | -verbose )
            log[verbose]="true"
            #verbose="true"
            shift
            ;;
        -vu | --volsizeunit )
            #volsizeunit="$1"
            storageInfo[volsizeunit]="$1"
            shift
            ;;
        -t | -type )
            #type="$1"
            storageInfo[type]="$1"
            shift
            ;;
        -vt | -voltype )
            #voltype="$1"
            storageInfo[voltype]="$1"
            shift
            ;;
        -rt | -raidtype)
            storageInfo[raidtype]="$1"
            shift
            ;;
        -cr | -cmprun )
            vdbench[cmprun]="$1"
            shift
            ;;
        -cleanenv )
            vdbench_params[cleanenv]="true"
            shift
            ;;
        -sleep )
            vdbench_params[sleep]="$1"
            shift
            ;;
        -r | -dry )
            log[dry]="true"
            shift
            ;;
        -path )
            directoryStracture[absPath]="$1"
            #echo "${directoryStracture[absPath]} "
            shift
            ;;
        --help )
            usage
            ;;
        #*)
        #    usage
	#		;;
    esac
done
}

usage(){
echo -e "\
\tUsage:

\t $(basename $0) [ -c | --stand-name <storage name> ] [ -t | --type <xiv|svc> ] [ -c | --clients <client list> ]  \r
\t[ -vs | --volsize <size> ] [ -vn | --volnum <vol number> ] [ -vu | --volsizeunit <GB|GiB> ] [ -vt | --voltype <cmp|fa> ] \r
\t[ -rd | --readdata <size> ] [ -wd | --writedata <size> ] [ -th | --threads <number> ] [ -bs | --blocksize <blocksize> ] \r
\t[ -cr | --cmprun <comp ratio> ] \r
\t[  -d | --debug ] [ -v | --verbose  ] 

 Storage Arguments :
   -s  | --stand-name  stand name   : <no defaults>
   -c  | --clients     clients test : <no defaults most>
   -t  | --type        storage type : <default svc>
   -vs | --volsize     volume size  : <default 488>
   -vn | --volnum      number of volume : <default 128>
   -vu | --volsizeunit size unit type : < t|g|m > <default g >
   -vt | --voltype     run type compression or fully allocation : <default cmp>
   -rd | --raidtype    raid type for volume creation : <default raid10>

 Vdbench Arguments :
   -wd | --writedata   write data from storage : <default 3000g>
   -rd | --readdata    read data from storage : <default 1000g>
   -th | --threads     threads per lun : <default 4>
   -bs | --blocksize   test blocksize  : <default 4k,8k,16k,32k etc> full scale
   -cr | --cmprun      test compression ratio : <default 30,50,65 etc> full scale
   -i  | --interval    test results interval output display <defaul 10 sec>
 Vdbench extra options:
   --seekpct           
   --sleep              default 180 seconds
 other parameters :
  --mail              send results by mail : <default RTC_SVC>
  --xlsx              create excel file : <default disable>
  --upload            upload json file to par if no errors found
  --path              set results path
 debug info :
  -d | --debug        default false
  -v | --verbose      default false 
  -r | --dry      default false


Example: Creating 128 volums of 488 GB and attaching them 'wl9 wl10 wl11'\r

$(basename $0) -s rtc02t --volnum 128 --volsize 488  -c \"wl9 wl10 wl11\" -type svc"
}

checking_params()
{

if [[ ! ${storageInfo[stand_name]} ]];then
	printf "ERRROR : STORAGE NOT DEFINED!!!!!! \n "
	usage
	exit
fi
if [[ ! ${vdbench_params[clients]}  ]];then
	printf "ERRROR : CLIENTS NOT DEFINED!!!!!! \n "
	usage
	exit
fi
if [[ ! ${storageInfo[volsizeunit]} ]];then
	storageInfo[volsizeunit]="g"
fi
if [[ ! ${storageInfo[volnum]} ]];then
	storageInfo[volnum]="128"
fi
if [[ ! ${vdbench[threads]} ]] ; 
then
    vdbench["threads"]="4"
fi
if [[ ! ${vdbench[blocksize]} ]]; then
    vdbench[blocksize]=""1024k" "512k" "256k" "128k" "64k" "32k" "16k" "8k" "4k""
	#printf "setting default value to [ blocksize ] %s \n " "${vdbench_params[blocksize]}"
fi
if [[ ! ${storageInfo[volsize]} ]];then
	storageInfo[volsize]="488"
fi
if [[ ! ${storageInfo[vol_num]} ]];then
	storageInfo[vol_num]="128"
fi
if [[ ! ${vdbench[interval]} ]];then
	vdbench[interval]="10"
fi
if [[ ! ${vdbench[read_data]} ]];then
	vdbench[read_data]="1000g"
fi
if [[ ! ${vdbench[write_data]} ]];then
	vdbench[write_data]="3000g"
fi
if [[ ! ${vdbench[cmprun]} ]]; then
	vdbench[cmprun]=" "1.3" "1.7" "2.3" "3.5" "11" "
fi
if [[ ! ${log[debug]} ]];then
	log[debug]="false"
	printf "debug not defined %s\n" ${log[debug]}
fi
if [[ ! ${log[verbose]} ]];then
	log[verbose]="false"
	printf "verbose not defined %s\n" ${log[verbose]}
fi
if [[ ! ${log[dry]} ]];then
	log[dry]="false"
	#printf "dry mode set only display only output %s\n" ${log[dry]}
fi
if  [[ ! ${directoryStracture[absPath]} ]]; then
    #printf " the path did not configured ..... strange !!!!"
    directoryStracture[absPath]="benchmark_results"
fi
if [[ ! ${storageInfo[voltype]} ]];then
#	storageInfo[voltype]="cmp"
	storageInfo[voltype]="COMPRESSED"
fi
if [[ ! ${storageInfo[raidType]} ]] ; then
	storageInfo[raidType]="raid10"
fi
if [[ ! ${vdbench_params[sleep]} ]] ; then
    vdbench_params[sleep]="180"
fi
if [[ ! $vdbench_params[cleanenv]} ]]; then
    vdbench_params[cleanenv]="true"
fi
}

print_params() 
{
logger "info" "==[ vdbenchResultsLog ]==[ array parameters ]=========="
for f in ${!vdbenchResultsLog[@]}; do logger "info" "   $f |${vdbenchResultsLog[$f]}" ; done
logger "info" "directoryStracture array parameters"
for f in ${!directoryStracture[@]}; do logger "info" "  $f |${directoryStracture[$f]}" ; done
logger "info" "vdbench array parameters"
for f in ${!vdbench[@]}; do logger "info" " $f |${vdbench[$f]}" ; done
logger "info" "storageInfo array parameters"
for f in ${!storageInfo[@]}; do logger "info" "$f |${storageInfo[$f]}" ; done
logger "info" "vdbenchRelogsultsLog array parameters"
for f in ${!log[@]}; do logger "info" " $f |${log[$f]}" ; done 
logger "info" "vdbench_params array parameters"
for param  in ${!vdbench_params[@]} ; do logger "info" "    $param |${vdbench_params[$param]}" ; done

}
function logger(){
	type=$1
    ouput=$2
    o1=""
    o2=""
	if [[ $type == "debug" ]]; then		
		if [[ ${log[debug]} == "true" ]] ; then printf "[%s] [$red%s  $end] [%s] %s\n" "`date '+%d/%m/%y %H:%M:%S:%2N'`" "DEBUG" "$red${FUNCNAME[1]}$end" "$ouput" | tee -a ${log[debug]}; fi
	elif [[ $type == "info" ]] ; then
		printf "[%s] [$grn%s   $end] %s\n" "`date '+%d/%m/%y %H:%M:%S:%2N'`" "INFO" "$ouput" | tee -a ${log[info]}
	elif [[ $type == "error" ]] ; then
		printf "[%s] [$yel%s     $end] [%s] %s\n" "`date '+%d/%m/%y %H:%M:%S:%2N'`" "ERROR" "$red${FUNCNAME[1]}$end" "$ouput" | tee -a ${log[error]}
	elif [[ $type == "fetal" ]] ; then	
        printf "[%s] [$red%s  $end] [%s] %s\n" "`date '+%d/%m/%y %H:%M:%S:%2N'`" "FETAL" "$red${FUNCNAME[1]}$end" "$ouput" | tee -a ${log[debug]}
	elif [[ $type == "ver" ]] ; then
		if [[ ${log[verbose]} == "true" ]] ; then printf "[%s] [$blu%s$end] [%s] %s\n" "`date '+%d/%m/%y %H:%M:%S:%2N'`" "VERBOSE" "$red${FUNCNAME[1]}$end" "$ouput" | tee -a ${log[verbose]} ;fi
    elif [[ $type == "results" ]]; then 
        typo=`echo ${type^^}`
        o1=`echo ${ouput%;*}`
        o2=`echo ${ouput#*;}`
        printf "[%s] [$grn%s$end] %15s %s25\n" "`date '+%d/%m/%y %H:%M:%S:%2N'`" "$typo" "$o1" "$o2" | tee -a ${log[info]}
	elif [[ ! $type =~ "debug|ver|error|info|results" ]] ; then
		printf "[%s] %s\n" "`date '+%d/%m/%y %H:%M:%S:%2N'`" "$type" 	
    fi

}
function debug(){
    [ ${log[debug]} == "true"  ] && $@
}

function removeStorageHosts() {
	logger "info" "Removing Existing hosts : "$(ssh -p 26 ${storageInfo[stand_name]} lshost -nohdr | awk '{print $2}' | tr "\n" "," | sed -e 's/,$//g')

    if [[ ${log[debug]} == "true" ]] ; then 
		logger "debug" "ssh -p 26 ${storageInfo[stand_name]} \"i=\"0\"; while [ 1 -lt \`lshost|wc -l\` ]; do echo -e \"host_id \$i \n \"; svctask rmhost -force \$i; i=\$[\$i+1]; done\" "
	else
		ssh -p 26 ${storageInfo[stand_name]} "i=\"0\"; while [ 1 -lt \`lshost|wc -l\` ]; do svctask rmhost -force \$i; i=\$[\$i+1]; done"
	fi
	sleep 2
}
function hostRescan(){
    logger "info" "rescaning hosts vdisk per client ${storageInfo[vdiskPerClient]} "
	for c in ${vdbench_params[clients]}; do
        ssh $c /usr/global/scripts/rescan_all.sh &> ${log[globalLog]}
        hostDeviceCount=`ssh $c multipath -ll|grep -c mpath`
        logger "info" "[ $c ] vdisks found : [ $hostDeviceCount ]"
		
		if [[ ${storageInfo[vdiskPerClient]} -ne $hostDeviceCount || -z $hostDeviceCount ]] ; then 
			logger "fetal" "!!!!! ERROR | unbalanced devices on host $red$c$end | device count [ $red$hostDeviceCount$end ] | ERROR !!!!!" 
			exit
		fi
    done
    
}
function converCompretionRatio() {
	local cmp=$1	
	printf "%s" ${compressionRatio[$cmp]}	
}

function removeMdiskGroup(){
    declare -a mdiskgrp
	mdiskgrp=`ssh -p 26 ${storageInfo[stand_name]} ""lsmdiskgrp |grep -v id | sed -r 's/^[^0-9]*([0-9]+).*$/\1/'""`
    if [[ ${#mdiskgrp[@]} > "0" && ! -z ${mdiskgrp[@]} ]] ; then
        if [[ ${log[debug]} =~ "true" ]]; then
    	    logger "debug" "removing mdisk groups from ${storageInfo[stand_name]} with groups id ${mdiskgrp[@]}"
            logger "debug" "ssh -p 26 ${storageInfo[stand_name]} ""lsmdiskgrp |grep -v id | sed -r 's/^[^0-9]*([0-9]+).*$/\1/'"""
        
        elif [[ ${log[verbose]} == "true" ]]; then            
            logger "ver" "removing mdisk groups from ${storageInfo[stand_name]}"
    		logger "ver" "command|ssh -p 26 ${storageInfo[stand_name]} ""lsmdiskgrp |grep -v id | sed -r 's/^[^0-9]*([0-9]+).*$/\1/'"""
            for mdiskgrpID in ${mdiskgrp[@]} ; do
                logger "info" "removing mdiskgroup ${mdiskgrpID}"
                ssh -p 26 ${storageInfo[stand_name]} "svctask rmmdiskgrp -force $mdiskgrpID"
            done
        else
            mdiskgrp=$(ssh -p 26 ${storageInfo[stand_name]} "mdiskgrp=( \$(lsmdiskgrp -nohdr | awk '{print \$1}' | xargs ))")
            logger "info" "removing mdisk groups from ${storageInfo[stand_name]}"
            logger "info" "total mdiskgroups ${#mdiskgrp[@]}"
            for mdiskgrpID in ${mdiskgrp[@]} ; do
                logger "info" "removing mdiskgroup ${mdiskgrpID}"
                ssh -p 26 ${storageInfo[stand_name]} "svctask rmmdiskgrp -force $mdiskgrpID"
            done
        fi
    else
        logger "info" "[ $blu${storageInfo[stand_name]}$end ] no mdisk groups to remove from the system" ;
    fi    
}

function createHosts() {
clients=${vdbench_params[clients]}
storageInfo[hostCount]=0
logger "info" "Creating hosts ${clients[@]}"

totalFC=0
declare -a hostStorage
for c in ${vdbench_params[clients]}
do
	storageInfo[hostCount]=$(( storageInfo[hostCount] + 1 ))
    wwpn=`ssh $c /usr/global/scripts/qla_show_wwpn.sh | grep Up | awk '{print $1}' | tr "\n" ":"| sed -e 's|\:$||g'`
    wwpnHostCount=`ssh $c /usr/global/scripts/qla_show_wwpn.sh | grep -c Up `
    totalFC=$(( totalFC + $wwpnHostCount ))
    logger "info"  "Adding host $c " 
    logger "ver"   " Host wwpn $wwpn" 
    logger "debug" " COMMAND \"ssh -p 26 ${storageInfo[stand_name]} svctask mkhost -fcwwpn $wwpn -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name $c -type generic 2>/dev/null\""
    
    ssh -p 26 ${storageInfo[stand_name]} svctask mkhost -fcwwpn $wwpn  -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name $c -type generic &>/dev/null
done
if [ $(( ${storageInfo[volnum]} % ${storageInfo[hostCount]} )) -ne "0" ]  ; then
    logger "fetal" "total volumes [ ${storageInfo[volnum]} ] is not devide with host count  [ ${storageInfo[hostCount]} ] " 
    exit
fi
storageInfo[vdiskPerClient]=$(( storageInfo[volnum] / storageInfo[hostCount]  ))
if [[ ${log[verbose]} == "true" ]] ; then logger "ver" "Total vdisk per client ${storageInfo[vdiskPerClient]}"  ; fi
}

function clearStorageLogs() {
	logger "info" "Cleaning Storage logs"
	ssh -p 26 ${storageInfo[stand_name]} svctask clearerrlog -force
}
function initLogger(){
logger "test"

}
function getStorageInfo(){
	logger "info" "${storageInfo[stand_name]} Collecting Storage Information"
	storageInfo[svcVersion]=$( ssh -p 26 ${storageInfo[stand_name]} cat /compass/version )
	logger "debug" "svc|version|command|\"ssh -p 26 ${storageInfo[stand_name]} cat /compass/version\" "
	logger "ver" "svc|version|ouput|${storageInfo[svcVersion]}" 

	storageInfo[svcBuild]=$( ssh -p 26 ${storageInfo[stand_name]} cat /compass/vrmf )
	logger "debug" "svc|build|command|\"ssh -p 26 ${storageInfo[stand_name]} cat /compass/vrmf\""
	logger "ver" "svc|build|output|${storageInfo[svcBuild]}"

	storageInfo[hardware]=$( ssh -p 26 ${storageInfo[stand_name]} sainfo lshardware | grep hardware | awk '{print $2}' )
	logger "debug" "svc hardware|command|\"ssh -p 26 ${storageInfo[stand_name]} sainfo lshardware | grep hardware | awk '{print \$2}'\"" 
	logger "ver" "svc|hardware|output|${storageInfo[hardware]}"

	if [[ $( ssh -p 26 ${storageInfo[stand_name]} lscontroller -nohdr | awk '{print $1}') == "" ]]; then
		storageInfo[backend]="none"
		logger "debug" "svc|backend|output|${storageInfo[backend]}"
		logger "debug" "svc|driveCount|command|\"ssh -p 26 ${storageInfo[stand_name]} lsdrive -nohdr | wc -l\""
		storageInfo[driveCount]=$( ssh -p 26 ${storageInfo[stand_name]} lsdrive -nohdr | wc -l )
		logger "ver" "svc|driveCount|output|${storageInfo[driveCount]}"
	else
		logger "debug" "svc|backend|command|\"ssh -p 26 ${storageInfo[stand_name]} sainfo lscontroller -nohdr| awk '{print \$1}'\"" 
		storageInfo[backend]=$( ssh stcon "/opt/FCCon/fcconnect.pl -op showconn -stor ${storageInfo[stand_name]} | grep Storage | awk '{print \$3}'" )
		logger "ver" "svc|backend|output|${storageInfo[backend]}"
	fi
}

function getStorageVolumes(){
	logger "debug" "svc|mdiskCount|command|\"ssh -p 26 ${storageInfo[stand_name]} lsmdisk -nohdr | wc -l\""
	storageInfo[mdiskCount]=$( ssh -p 26 ${storageInfo[stand_name]} lsmdisk -nohdr | wc -l )
	logger "ver" "svc|mdiskCount|output|${storageInfo[mdiskCount]}"

	logger "debug" "svc|mdiskSize|command|\"ssh -p 26 ${storageInfo[stand_name]} lsmdisk -nohdr | awk '{ print $7 }' | uniq | tr '\n' ' '\""
	storageInfo[mdiskSize]=$( ssh -p 26 ${storageInfo[stand_name]} lsmdisk -nohdr | awk '{ print $7 }' | uniq | tr '\n' ' ' )
	logger "ver" "svc|mdiskSize|output|${storageInfo[mdiskSize]}"
}

function vdbenchDirectoryResutls() {
	
	if [ -n "${directoryStracture[absPath]}" ] ; then
        log[resultsPath]="${directoryStracture[absPath]}/$bs"
	    logger "ver" "results path        : [ ${log[resultsPath]} ]"
	    createDirectory ${log[resultsPath]}
    
	    log[test_results]="${log[resultsPath]}/test_results"
	    logger "ver" "test results path   : [ ${log[test_results]} ]"
        createDirectory ${log[test_results]}
    
	    log[test_files]="${log[resultsPath]}/test_files"
	    logger "ver" "test files path     : [ ${log[test_files]} ]"
        createDirectory ${log[test_files]}
    
	    log[test_data]="${log[resultsPath]}/output_data"
	    logger "ver" "test data path      : [ ${log[test_data]} ]"
        createDirectory ${log[test_data]}
    else
        log[resultsPath]="${directoryStracture[absPath]}/${storageInfo[svcBuild]}/${storageInfo[svcVersion]}/${log[timestamp]}/$bs"
	    logger "ver" "results path        : [ ${log[resultsPath]} ]"
	    createDirectory ${log[resultsPath]}
    
	    log[test_results]="${log[resultsPath]}/test_results"
	    logger "ver" "test results path   : [ ${log[test_results]} ]"
        createDirectory ${log[test_results]}
    
	    log[test_files]="${log[resultsPath]}/test_files"
	    logger "ver" "test files path     : [ ${log[test_files]} ]"
        createDirectory ${log[test_files]}
    
	    log[test_data]="${log[resultsPath]}/output_data"
	    logger "ver" "test data path      : [ ${log[test_data]} ]"
        createDirectory ${log[test_data]}
    fi
}

function vdbenchMainDirectoryCreation(){

    if [ -n "${directoryStracture[absPath]}" ] ; then 
    	#logger "ver" "absulte path        : [ ${directoryStracture[absPath]} ]"
	    #createDirectory ${directoryStracture[absPath]}

	    log[logPath]="${directoryStracture[absPath]}"
	    logger "ver" "results path        : [ ${log[logPath]} ]"
	    createDirectory ${log[logPath]}

	    log[globalLog]="${log[logPath]}/${log[logOutput]}"
	    logger "ver" "globalLog file        : [ ${log[globalLog]} ]"
    else
	#directoryStracture[absPath]="benchmark_results"
	    logger "ver" "absulte path        : [ ${directoryStracture[absPath]} ]"
	    createDirectory ${directoryStracture[absPath]}

	    log[logPath]="${directoryStracture[absPath]}/${storageInfo[svcBuild]}/${storageInfo[svcVersion]}/${log[timestamp]}"
	    logger "ver" "results path        : [ ${log[logPath]} ]"
	    createDirectory ${log[logPath]}

	    log[globalLog]="${log[logPath]}/${log[logOutput]}"
	    logger "ver" "globalLog file        : [ ${log[globalLog]} ]"
    
    fi
}
function getvdbenchResults () {
	local testType=$1
	local cmp=$2
	ratio=$(converCompretionRatio $cmp)
    #logger "info" "compression ratio $ratio"
	stresults=$testType"_"$ratio"_"
	#May 29, 2016  interval        i/o   MB/sec   bytes   read     resp     read    write     resp     resp queue  cpu%  cpu%
    #                             rate  1024**2     i/o    pct     time     resp     resp      max   stddev depth sys+u   sys
	#13:38:41.062       331   13940.00  3485.00  262144   0.00   36.022    0.000   36.022   61.392    3.935 502.3   NaN   NaN
	if [ -f ${log[output_file]} ]; then
        logger "debug" "output results ${log[output_file]}"
		if [[ $testType == "write" ]] ; then
			st=$(cat ${log[output_file]} | egrep "Starting RD|avg_" | head -1)
			et=$(cat ${log[output_file]} | egrep "Starting RD|avg_" | head -2 | tail -1)
			writeStartTime=$(echo $st | sed -e 's/\..*//g')
			writeEndTime=$(echo $et | sed -e 's/\..*//g')
			declare -a writeTestResults=($(cat ${log[output_file]} | egrep "Starting RD|avg_" | head -2 | tail -1 | awk '{print $2" "$3" "$8 " "$9 }'))
			vdbenchResults["$stresults""iops"]="${writeTestResults[0]}"
			vdbenchResults["$stresults""mb"]="${writeTestResults[1]}" #MB throughut
			vdbenchResults["$stresults""rr"]="${writeTestResults[2]}" #read response
			vdbenchResults["$stresults""wr"]="${writeTestResults[3]}" #write response
			vdbenchResults["$stresults""startTest"]="${writeStartTime}"
			vdbenchResults["$stresults""endTest"]="${writeEndTime}"
            if [[ ${log[verbose]} == "true" ]]; then displayvdbehcnResults $stresults ; fi
            logger "info" "[RESULTS]$blu testType$end:$yel$testType$end ratio:$ratio |iops:${vdbenchResults[$stresults"iops"]} |throughut:${vdbenchResults[$stresults"mb"]}"

		elif [[ $testType == "read" ]]; then
			st=$(cat ${log[output_file]} | egrep "Starting RD|avg_" | tail -2 | head -1|sed -e 's/\..*//g')
			et=$(cat ${log[output_file]} | egrep "Starting RD|avg_" | tail -1 | sed -e 's/\..*//g')
			#printf "%10s %10s\n" $st $et
			declare -a readTestResults=($(cat ${log[output_file]} | egrep "Starting RD|avg_" | head -2 | tail -1 | awk '{print $2" "$3" "$8 " "$9 }'))		
			results=$(cat ${log[output_file]} | grep -B1 avg| tail -2)
			vdbenchResults["$stresults""iops"]="${readTestResults[0]}"
			vdbenchResults["$stresults""mb"]="${readTestResults[1]}"
			vdbenchResults["$stresults""rr"]="${readTestResults[2]}"
			vdbenchResults["$stresults""wr"]="${readTestResults[3]}"
			vdbenchResults["$stresults""startTest"]="${st}"
			vdbenchResults["$stresults""endTest"]="${et}"
            if [[ ${log[verbose]} == "true" ]]; then displayvdbehcnResults $stresults ; fi
            logger "info" "[RESULTS]$blu testType$end:$red$testType$end ratio:$ratio |iops:${vdbenchResults[$stresults"iops"]} |throughut:${vdbenchResults[$stresults"mb"]}"
		fi
	else
		logger "info" "output results does not exist${log[output_file]}"
	fi
}

function displayvdbehcnResults () {
	local typeResults=$1
	local compressionRatio=$2
    declare -A vr=( ["iops"]="i/o rate" ["mb"]="MB/sec" ["rr"]="read resp" ["wr"]="write resp" ["startTest"]="start test" ["endTest"]="end test"  )	
	#printf "%s\n" "function name     : ${FUNCNAME[0]}"
	for v in ${!vr[@]}; do
        logger "results" "${vr[$v]};${vdbenchResults[$typeResults$v]}"
	done	
}
function createDirectory() {
	directoryPath=$1
	if [ ! -d $directoryPath ] ; then
		logger "ver" "creating directory [ $directoryPath ]"
		mkdir -p $directoryPath
	fi

}
function vdbenchResultsFiles() {

	log[output_file]=${log[test_results]}/"out_$CP"
	logger "ver" "test output file        : [ ${log[output_file]} ]"
#	log[disk_file]=$CP"_disk_list"
	
	vdbench[write_test]=${log[test_files]}/$CP"_write"
	logger "ver" "vdbench write test file : [ ${vdbench[write_test]} ]"

	vdbench[read_test]=${log[test_files]}/$CP"_read"
	logger "ver" "vdbench read test file  : [ ${vdbench[read_test]} ]"
	#log[disk_list]=${log[test_files]}/$disk_file

	vdbench[disk_list]=${log[test_files]}/$CP"_disk_list"
	logger "ver" "vdbench disk list file  : [ ${vdbench[disk_list]} ]"

	log[test_info]=${log[resultsPath]}"/vdbench_benchmark_information_$CP.log"
	logger "ver" "test info file          : [ ${log[test_info]} ]"
}

function createStorageVolumes(){

removeMdiskGroup
logger "info" "Creating Storage Volumes on ${storageInfo[stand_name]}"

if [[ ${storageInfo[hardware]} =~ "T5H" || ${storageInfo[hardware]} =~ "500" ]]; then
    storageInfo[mkMasterArray]="/home/mk_arrays_master fc ${storageInfo[raidType]} sas_hdd "
	storageInfo[arrayGroup]=8
    storageInfo[driveCount]=$(ssh -p 26 ${storageInfo[stand_name]} lsdrive -nohdr | wc -l)
    storageInfo[numberMdiskGroup]=$(( ${storageInfo[driveCount]} / ${storageInfo[arrayGroup]} ))
	storageInfo[mkMasterArray]+="${storageInfo[driveCount]} ${storageInfo[arrayGroup]} ${storageInfo[numberMdiskGroup]} "
	storageInfo[mkMasterArray]+="${storageInfo[volnum]} ${storageInfo[volsize]} ${storageInfo[voltype]} NOFMT NOSCRUB"

    if [[ ${log[debug]} =~ "true" ]]; then
    	logger "debug" "Running with ${storageInfo[hardware]} configuration with ouput"
        logger "debug" "ssh -p 26 ${storageInfo[stand_name]} ${storageInfo[mkMasterArray]}"
    elif [[ ${log[verbose]} == "true" ]]; then
        logger "ver" "Running with ${storageInfo[hardware]} configuration with ouput"
		logger "ver" "command| ssh -p 26 ${storageInfo[stand_name]} ${storageInfo[mkMasterArray]}"
        ssh -p 26 ${storageInfo[stand_name]} ${storageInfo[mkMasterArray]} &> ${log[globalLog]}
    else
        logger "info" "Start Creating volumes on ${storageInfo[stand_name]}"
        ssh -p 26 ${storageInfo[stand_name]} ${storageInfo[mkMasterArray]} &> ${log[globalLog]}
    fi
elif [[ ${storageInfo[hardware]} =~ "DH8" || ${storageInfo[hardware]} =~ "CG8" ]]; then
    storageInfo[volsize]=$(( ${storageInfo[volsize]} * 1024 ))
    storageInfo[mkVdisk]="/home/mk_vdisks fc 1 ${storageInfo[volnum]} ${storageInfo[volsize]} "
    storageInfo[mkVdisk]+="0 NOFMT COMPRESSED AUTOEXP"
    
    if [[ ${log[debug]} =~ "true" ]]; then
    	logger "debug" "Running with ${storageInfo[hardware]} configuration with ouput"
        logger "debug" "ssh -p 26 ${storageInfo[stand_name]} ${storageInfo[mkVdisk]}"
    elif [[ ${log[verbose]} == "true" ]]; then
        logger "ver" "Running with ${storageInfo[hardware]} configuration with ouput"
		logger "ver" "command| ssh -p 26 ${storageInfo[stand_name]} ${storageInfo[mkVdisk]}"
        #ssh -p 26 ${storageInfo[stand_name]}  /home/mk_vdisks fc 1 ${storageInfo[volnum]} ${storageInfo[volsize]} 0 NOFMT COMPRESSED AUTOEXP &> ${log[globalLog]}
        ssh -p 26 ${storageInfo[stand_name]} ${storageInfo[mkVdisk]} &> ${log[globalLog]}
    else
        logger "info" "Start Creating volumes on ${storageInfo[stand_name]}"     
        ssh -p 26 ${storageInfo[stand_name]} ${storageInfo[mkVdisk]} &> ${log[globalLog]}
    fi    
fi
sleep 10


}

function vdbenchDeviceList() {
echo " " > ${vdbench[disk_list]}

for client in ${vdbench_params[clients]}; do
declare -a hostDeviceSize 
hostDeviceSize=$( ssh $client multipath -l | grep size | sed -e 's/ .*//g' -e 's/.*=//g'| uniq )

logger "ver" "vdbench sd output: ${hostDeviceSize[0]} - ${#hostDeviceSize[@]} " 
if [ ${#hostDeviceSize[@]} -gt "1" ]; then 
    logger "fetal" "!!!!! ERROR | unbalanced devices size on host $red$client$end | device count [ $red$hostDeviceSize$end ] | ERROR !!!!!"
    exit
fi


count=1
	for dev in `ssh $client multipath -l|grep "2145" | awk '{print \$1}'`; do
    	device="/dev/mapper/$dev"
    	if [[ ${log[debug]} == "true" ]]; then
            logger "debug" "vdbench sd output: sd=$client.$count,hd=$client,lun=$device,openflags=o_direct,size=${hostDeviceSize[0]},threads=${vdbench[threads]}"
            count=$(( count+1  ))
    	elif [[ ${log[verbose]} == "true" ]]; then
            logger "ver" "vdbench sd output: sd=$client.$count,hd=$client,lun=$device,openflags=o_direct,size=${hostDeviceSize[0]},threads=${vdbench[threads]}"
            echo  "sd=$client.$count,hd=$client,lun=$device,openflags=o_direct,size=${hostDeviceSize[0]},threads=${vdbench[threads]}" >> ${vdbench[disk_list]}
            count=$(( count+1  ))
        else
            echo  "sd=$client.$count,hd=$client,lun=$device,openflags=o_direct,size=${hostDeviceSize[0]},threads=${vdbench[threads]}" >> ${vdbench[disk_list]}
            count=$(( count+1  ))
        fi
    done
done
}

function vdbenchWriteTest(){
        echo "
compratio=$CP
messagescan=no

" > ${vdbench[write_test]}

for client in ${vdbench_params[clients]}; do
	if [[ ${log[debug]} == "true" ]]; then
    	logger "debug" "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> ${vdbench[write_test]}
	elif [[ ${log[verbose]} == "true" ]]; then
    	logger "debug" "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> ${vdbench[write_test]}
    	echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> ${vdbench[write_test]}
	else
    	echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> ${vdbench[write_test]}
	fi
done
echo "
include=${vdbench[disk_list]}

wd=wd1,sd=*,xfersize=$bs,rdpct=0,rhpct=0,seekpct=0
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=${vdbench[write_data]},warmup=360,interval=${vdbench[interval]}
" >> ${vdbench[write_test]}

    if [[ ${log[debug]} == 'true' ]]; then
        logger "debug" "log output file ${log[output_file]}"
        logger "debug" "./vdbench -c -f ${vdbench[write_test]} -o ${log[test_data]}/output_$CP | tee -a ${log[output_file]}"
	elif [[ ${log[verbose]} == "true" ]]; then
        logger "info" "running write benchmark"
        logger "ver" "./vdbench -c -f ${vdbench[write_test]} -o ${log[test_data]}/output_$CP | tee -a ${log[output_file]}"     
        `./vdbench -c -f ${vdbench[write_test]} -o ${log[test_data]}/output_$CP | tee -a ${log[output_file]}`
        if [[ $? -eq "127" ]]; then
            logger "fetal" "!!!!! ERROR | vdbench failed to run write operation | ERROR !!!!!"
            exit
        fi
    else
        logger "info" "running write benchmark"
        `./vdbench -c -f ${vdbench[write_test]} -o ${log[test_data]}/output_$CP >> ${log[output_file]}`
        if [[ $? -eq "127" ]]; then
            logger "fetal" "!!!!! ERROR | vdbench failed to run write operation | ERROR !!!!!"
            exit
        fi
    fi
}

function vdbenchReadTest(){
echo "
compratio=$CP
messagescan=no
" > ${vdbench[read_test]}

for client in ${vdbench_params[clients]}; do
	if [[ ${log[debug]} == "true" ]];then
    	logger "debug" " "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> ${vdbench[read_test]}"
	elif [[ ${log[verbose]} == "true" ]]; then
	    logger "ver" " "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> ${vdbench[read_test]}"
	    echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> ${vdbench[read_test]}
	else
    	echo "hd=$client,system=$client.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root" >> ${vdbench[read_test]}
	fi
done

echo "
include=${vdbench[disk_list]}

wd=wd1,sd=*,xfersize=$bs,rdpct=100,rhpct=0,seekpct=0
rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=${vdbench[read_data]},warmup=360,interval=${vdbench[interval]}
" >> ${vdbench[read_test]}

    if [[ ${log[debug]} == 'true' ]];then
        logger "debug" "executing read benchmark log output file ${log[output_file]}"
        logger "debug" "./vdbench -c -f ${vdbench[read_test]} -o ${log[test_data]}/output_$CP | tee -a ${log[output_file]}"

	elif [[ ${log[verbose]} == "true" ]]; then
        logger "ver" "./vbench -c -f ${vdbench[read_test]} -o ${log[test_data]}/output_$CP | tee -a ${log[output_file]}"
        `./vdbench -c -f ${vdbench[read_test]} -o ${log[test_data]}/output_$CP | tee -a ${log[output_file]}`
        if [[ $? -eq "127" ]]; then
            logger "fetal" "!!!!! ERROR | vdbench failed to run read operation | ERROR !!!!!"
            exit
        fi
    else
        logger "info" "running read benchmark"
        `./vdbench -c -f ${vdbench[read_test]} -o ${log[test_data]}/output_$CP >> ${log[output_file]}`
        if [[ $? -eq "127" ]]; then
            logger "fetal" "!!!!! ERROR | vdbench failed to run read operation | ERROR !!!!!"
            exit
        fi
    fi
}
function displayVdbenchResults() {
        path=/benchmark_results/7.6.1.1/124.4.1603211401000/160523_094004/64k/
        ${log[output_file]}
    
    
}
#function _info(){ echo }
#function _error(){ echo }
#function _verbose(){ echo }
#function _debug(){ echo }
###

# function jsonFile
# function storageInfo
# function createTestFile()
# function storageInfo()
# function send_email_results()
parse_parameter "$@"
checking_params 
if [[ ${log[debug]} == "true" ]]  ; then print_params ; fi
getStorageInfo
vdbenchMainDirectoryCreation
#removeStorageHosts
#removeMdiskGroup
#createHosts

for bs in ${vdbench[blocksize]}; do
	log[testCount]=1
#	createStorageVolumes
    #logger "info" "exit after function : createStorageVolumes" ; exit
	getStorageVolumes
	vdbenchDirectoryResutls
	#hostRescan
	for CP in ${vdbench[cmprun]} ; do
        rate=$( converCompretionRatio $CP )
		logger "info" "===[ ${log[testCount]} ]===[ blocksize | $bs ]====[ RATIO | $( converCompretionRatio $CP ) ]=============================================="
		vdbenchResultsFiles
		#vdbenchDeviceList
		#vdbenchWriteTest
        getvdbenchResults "write" $CP
		#vdbenchReadTest
        getvdbenchResults "read" $CP
		log[testCount]=$(( log[testCount] + 1 ))
	done
    #createJsonFile
    #uploadJsonFile
    #sendEmailReport
done
# log output example
# [21/10/16 19:10:22] [INFO] 
# [21/10/16 19:10:22] [ERROR] 
# [21/10/16 19:10:22] [VERBOSE]  
# [21/10/16 19:10:22] [DEBUG] 
