#!/usr/bin/perl

use strict;
use warnings;
#use Excel::Writer::XLSX;

use Getopt::Long;

my $InFile;
my $Config;

my $Mode ;

my $StartDataPoint = 0;
my $StartTest      = 0;
my $StartTestTime  = "";
my $EndTestTime    = "";
my $Sum            = 0;
my $Count          = 0;

my %Tests;
my %Iops;
my %Times;

my $Debug = 0;

my $Stand;
my $StandName ;
my $StandType ;
my ($qd,$cmp,$nvol);

sub trim($) {
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub usage () {
	print "Usage : $0 -stand [name] [-d] [-h]\n";
}

if ( @ARGV == 0 ) {
	print "Error : no parameters gave...\n";
	usage();
	exit;
}

GetOptions(
	'stand=s' => \$Stand,
	'cmp=s'   => \$cmp,,
	'qd=s'    => \$qd,
	'nvol=s'  => \$nvol,
	'd'	  => \$Debug,
	'h'       => sub { usage(); exit; },
);

if ( !defined $Stand ) {
	print "Stand name is missing\n";
	exit;
}

$StandName = $Stand ;

print "Starting data extraction...\n";

my $STH = `ssh -p 26 root\@$Stand sainfo lshardware  | grep hardware | awk '{print \$NF}'` ;
chomp $STH ;

my $Version = `ssh -p 26 root\@$Stand lssystem | grep code | awk '{print \$2" "\$3" "\$4}'`;
chomp $Version;

my $Race = `ssh -p 26 root\@$Stand /data/race/rtc_racemqd -v | grep race | awk '{print \$2}'` ;
chomp $Race ;

my $Coletos = "";

my $BE = 'NONE' ;
my $DT = 'NONE' ;
my $Raid = 'NONE';

my ($Mdisks, $MdiskSize, $Backend) ;
if ($STH eq "CG8" || $STH eq "DH8") {
	$Mdisks = `ssh -p 26 root\@$Stand lsmdisk | grep managed | wc -l`;
	chomp $Mdisks;
	
	$MdiskSize = `ssh -p 26 root\@$Stand lsmdisk  | tail -n 1 | awk '{print \$7}'`;
	chomp $MdiskSize;
	
	$Backend = `ssh -p 26 root\@$Stand lscontroller  | tail -n 1 | awk '{print \$2}'`;
	chomp $Backend;
	$BE = $Backend ;
}else{
	$Mdisks = `ssh -p 26 root\@$Stand lsdrive | grep online | wc -l` ;
	chomp $Mdisks ;
	
	$MdiskSize = `ssh -p 26 root\@$Stand lsdrive | grep online | tail -n 1 | awk '{print \$5'}` ;
	chomp $MdiskSize ;
	
	$Backend = `ssh -p 26 root\@$Stand lsdrive 10 | grep RPM | awk '{print \$NF}'` ;
	chomp $Backend ;
	$DT = $Backend ;
	
	$Raid = `ssh -p 26 root\@$Stand lsmdisk 0 | grep raid_level | awk '{print \$NF}'` ;
	chomp $Raid ;

	$BE = 'NONE' ;
}

my $NoOfclients = `ssh -p 26 root\@$Stand lshost |grep -E 'online|degraded'| wc -l`;
chomp $NoOfclients;

#my $CC_Card = `ssh -p 26 root\@$Stand \"echo \"log_dump /tmp/racelog.txt\" > /data/rtcracecli\"; ssh -p 26 root\@$Stand cat /tmp/racelog.txt |grep accelerators | awk '{print \$1}'|awk -F= '{print \$2}'`;
#chomp $CC_Card ;

#my $CC_level = `ssh -p 26 root\@$Stand \"echo \"log_dump /tmp/racelog.txt\" > /data/rtcracecli\"; ssh -p 26 root\@$Stand cat /tmp/racelog.txt |grep comp_level | awk '{print \$1}'|awk -F= '{print \$2}'`;
#chomp $CC_level ;

my $Clients = `cat out_2.3 |head -n 50 | grep host= |awk '{print \$7}'|awk -F= '{print \$2}'`;
chomp($Clients);
$Clients =~ s/\n/,/g;

my $BlockSize = `cat out_2.3 | grep avg | head -n 1 |awk '{print \$4}'`; chomp $BlockSize;

print "Stand data extraction status: DONE\n";

# 30
my $Date_30 = `cat out_1.3 |grep interval| head -n 1| awk '{print \$1 \$2 \$3}'`; chomp $Date_30;
my $CMP_Rat_30 = `cat out_1.3 | grep CompRatio| awk '{print \$2}'`; chomp $CMP_Rat_30;
my $write_30 = `cat out_1.3 | grep avg_ | head -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`; chomp $write_30;
my $read_30 = `cat out_1.3 | grep avg_ | tail -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`; chomp $read_30;
my $st_30 = $Date_30." ".`cat out_1.3 | grep "Starting RD" | head -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`; chomp $st_30;
my $et_30 = $Date_30." ".`cat out_1.3 | grep avg_ | tail -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`; chomp $et_30;

# 50
my $Date_50 = `cat out_1.7 |grep interval| head -n 1| awk '{print \$1 \$2 \$3}'`; chomp $Date_50;
my $CMP_Rat_50 = `cat out_1.7 | grep CompRatio| awk '{print \$2}'`; chomp $CMP_Rat_50;
my $write_50 = `cat out_1.7 | grep avg_ | head -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`; chomp $write_50;
my $read_50 = `cat out_1.7 | grep avg_ | tail -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`; chomp $read_50;
my $st_50 = $Date_50." ".`cat out_1.7 | grep "Starting RD" | head -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`; chomp $st_50;
my $et_50 = $Date_50." ".`cat out_1.7 | grep avg_ | tail -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`; chomp $et_50;

# 63
my $Date_63 = `cat out_2.3 |grep interval| head -n 1| awk '{print \$1 \$2 \$3}'`; chomp $Date_63;
my $CMP_Rat_63 = `cat out_2.3 | grep CompRatio| awk '{print \$2}'`; chomp $CMP_Rat_63;
my $write_63 = `cat out_2.3 | grep avg_ | head -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`; chomp $write_63;
my $read_63 = `cat out_2.3 | grep avg_ | tail -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`; chomp $read_63;
my $st_63 = $Date_63." ".`cat out_2.3 | grep "Starting RD" | head -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`; chomp $st_63;
my $et_63 = $Date_63." ".`cat out_2.3 | grep avg_ | tail -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`; chomp $et_63;

# 75
my $Date_75 = `cat out_3.5 |grep interval| head -n 1| awk '{print \$1 \$2 \$3}'`; chomp $Date_75;
my $CMP_Rat_75 = `cat out_3.5 | grep CompRatio| awk '{print \$2}'`; chomp $CMP_Rat_75;
my $write_75 = `cat out_3.5 | grep avg_ | head -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`; chomp $write_75;
my $read_75 = `cat out_3.5 | grep avg_ | tail -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`; chomp $read_75;
my $st_75 = $Date_75." ".`cat out_3.5 | grep "Starting RD" | head -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`; chomp $st_75;
my $et_75 = $Date_75." ".`cat out_3.5 | grep avg_ | tail -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`; chomp $et_75;

# 93
my $Date_93 = `cat out_11 |grep interval| head -n 1| awk '{print \$1 \$2 \$3}'`; chomp $Date_93;
my $CMP_Rat_93 = `cat out_11 | grep CompRatio| awk '{print \$2}'`; chomp $CMP_Rat_93;
my $write_93 = `cat out_11 | grep avg_ | head -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`; chomp $write_93;
my $read_93 = `cat out_11 | grep avg_ | tail -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`; chomp $read_93;
my $st_93 = $Date_93." ".`cat out_11 | grep "Starting RD" | head -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`; chomp $st_93;
my $et_93 = $Date_93." ".`cat out_11 | grep avg_ | tail -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`; chomp $et_93;



#foreach my $line (`grep "host[0-9]: " /home/perfauto/outputs/$Config/$Date/stdout.log`) {
	
#}

my $Vdisks = `ssh -p 26 root\@$Stand lsvdisk | grep online | wc -l`;
chomp $Vdisks;

my $VdiskSize = `ssh -p 26 root\@$Stand lsvdisk | grep online | tail -n 1 | awk '{print \$8}'`;
chomp $VdiskSize;
my $dataSet = $Vdisks * ( split( '\.', $VdiskSize ) )[0];

if ($STH eq "CG8") {
	my $cpu = `ssh -p 26 root\@$Stand sainfo lshardware  | grep cpu_count | awk '{print \$NF}'` ;
	chomp $cpu ;
	if ($cpu == 1) { $Stand .= " - CG8" ; }
	if ($cpu == 2) { $Stand .= " - CHUBBIE Node" ; }
}else{
	if ($STH eq "DH8") { $Stand .= " - BFN" ; }
	elsif ($STH eq "500" ) { $Stand .= " - FAB1" ; }
	else { $Stand .= " - V7000" ; }
}

my $index = "";
my $files = 0;

#system("clear");
print "Running in debug mode" if ($Debug);

my $FirstRow = 13;
my %testsresults ;
my $testsresultsInd = 0 ;



my ($SVCVer, $SVCBuild) = (split(' ', $Version))[0,2] ;
$SVCBuild =~ s/\)//g ;
$Race =~ s/v//g ;
my @Raceversion = (split('\.', $Race)) ;
my $RaceBrance = $Raceversion[0] . '.' . $Raceversion[1] ;
$MdiskSize =~ s/GB// ; 
$MdiskSize =~ s/TB// ; 
if ( $DT eq "10000" ) { $DT = "10K" ; }
if ( $DT eq "15000" ) { $DT = "15K" ; }
my @ClientsNumber = (split(',', $Clients)) ;
my $ClientsNum = scalar @ClientsNumber ;

#chdir "/root" ;

#my $json_file = "vdbench_results.$StandName.$st_30.json";
my $json_file = "vdbench_results.$StandName.qd_$qd.cmp_$cmp.nvol_$nvol.json";
$json_file =~ s/:| //g;

open (JSONF, ">$json_file") || die "Can not open json file\n" ;
print JSONF "
{
    \"startTime\":\"$st_30\",
    \"endTime\":\"$et_93\",
    \"ResultsType\":\"DEV\",
    \"testType\":\"IOZONE\",
    \"stand\":\"$StandName\",
    \"SVC_Version\":\"$SVCVer\",
    \"SVCBuilds\":\"$SVCBuild\",
    \"backend\":\"$BE\",
    \"diskType\":\"$DT\",
    \"noOfDisks\":\"$Mdisks\",
    \"totalDisks\":\"$MdiskSize\",
    \"Raid\":\"$Raid\",
    \"RaceBranchType\":\"$RaceBrance\",
    \"RaceMQVersion\":\"$Race\",
    \"testmode\":\"CMP\",
    \"vdiskCount\":\"$Vdisks\",
    \"vdiskSize\":\"$VdiskSize\",
    \"coleto\":\"$Coletos\",
    \"coleto_level\":\"2\",
    \"blocksize\":\"$BlockSize\",
    \"ClientMgmt\":\"NONE\",
    \"Clients\":\"$Clients \",
    \"ClientsNum\":\"$ClientsNum\",
    \"iozone1\":\"$CMP_Rat_30\",
    \"write1\":\"$write_30\",
    \"read1\":\"$read_30\",
    \"st1\":\"$st_30\",
    \"et1\":\"$et_30\",
    \"iozone2\":\"$CMP_Rat_50\",
    \"write2\":\"$write_50\",
    \"read2\":\"$read_50\",
    \"st2\":\"$st_50\",
    \"et2\":\"$et_50\",
    \"iozone3\":\"$CMP_Rat_63\",
    \"write3\":\"$write_63\",
    \"read3\":\"$read_63\",
    \"st3\":\"$st_63\",
    \"et3\":\"$et_63\",
    \"iozone4\":\"$CMP_Rat_75\",
    \"write4\":\"$write_75\",
    \"read4\":\"$read_75\",
    \"st4\":\"$st_75\",
    \"et4\":\"$et_75\",
    \"iozone5\":\"$CMP_Rat_93\",
    \"write5\":\"$write_93\",
    \"read5\":\"$read_93\",
    \"st5\":\"$st_93\",
    \"et5\":\"$et_93\"
}
" ;
close JSONF ;

print "   json file is : $json_file\n" ;

system("cat $json_file") if ($Debug);

system("scp $json_file 9.151.185.23:/mnt/v7k/par_imports/vdbench/");

exit;

