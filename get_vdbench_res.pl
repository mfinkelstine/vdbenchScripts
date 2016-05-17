#!/usr/bin/perl

use strict;
use warnings;
#use Excel::Writer::XLSX;

use Getopt::Long;
use Excel::Writer::XLSX;
use Cwd;
use File::Find;
use File::Basename;
use Data::Dumper;

#my $config{debug} = 0;
my @results_files;
my %dirResutls = ();
my %vdbench_results;
my %storageInfo;
my %config;
my %ratio = (
				1.3 => "30",
                1.7 => "50",
                2.3 => "63",
                3.5 => "75",
                11 => "93"
            );
my %cell_id = (
				"30" => "20",
                "50" => "21",
                "63" => "22",
                "65" => "23",
                "93" => "24",
			);

my %hardwareType = (
              "T5H"   => "V5000",
			  "300"   => "V7000",
			  "CG8C1" => "CG8",
			  "CG8C2" => "CHUBBIE",
			  "DH8"   => "BFN",
			  "500"   => "FAB1"
			  );

my %dirResults;

sub build_tree($) {
	use File::Find::Rule;

	my $path = shift;
	print "Directory stracture tree\nfull path $path\n\n\n";
	$config{"abspath"} = $path;

    my @dirStracture = `find $path -maxdepth 1 -type d `;
    foreach my $d (@dirStracture) {
        chomp($d);
        my $basename = basename($d);
        if ( $basename =~ /k$/){
            $config{'directory'}{$basename} = $d;
        }
    }
	print "directory stracture found \n". $config{"abspath"}."\n" if $config{verbose};
	print Dumper $config{'directory'} if $config{debug};
}

sub filelist($){
    my $path = shift;
	@results_files = ();
	print "getting files from path [ $path ]";
    opendir(RESULTS,$path) or die $!;
    while (my $file =readdir(RESULTS)) {
        next unless ( -f "$path/$file");
        next unless ( $file =~ m/out_/);
        push(@results_files ,$file);
    }
	close RESULTS;
	if ($config{debug}) {

		foreach (@results_files){
			print "\n[DEBUG]  ".$_;
		}
	}
}

sub trim($) {
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub usage () {
	print "Usage : $0 -stand [name] [-d] [-h] [-path]\n";
}

if ( @ARGV == 0 ) {
	print "Error : no parameters gave...\n";
	usage();
	exit;
}

GetOptions(
	'stand=s' 	=> \$config{standName},
	'cmp=s'   	=> \$config{cmp},
	'path=s'  	=> \$config{absPath},
	'qd=s'    	=> \$config{qd},
	'type=s'    => \$config{type},
	'd'	  		=> \$config{debug},
	'v'	  		=> \$config{verbose},
	'h'       	=> sub { usage(); exit; },
);
#print "config file [ ".$config{jsonConfigFile}."]\n";

$storageInfo{standNameType} = $config{standName} ;
$storageInfo{standName} = $config{standName} ;

sub collectStorageInfo($){

	if ( -e $config{jsonConfigFile}){
#		use JSON::Parse 'parse_json';
        use JSON;
        local $/;
        $/ = undef;
        open( my $json_handle , '<' , $config{jsonConfigFile} ) or die "Unable to read file $config{jsonConfigFile} $! \n";
        my $json = <$json_handle>;
        my $j = decode_json $json;
	 $storageInfo{svc_version}   = $j->{SVC_Version};
	 $storageInfo{svc_build}     = $j->{SVCBuilds};
	 $storageInfo{mdisk_count}   = $j->{noOfDisks};
	 $storageInfo{raid_level}    = $j->{Raid};
	 $storageInfo{raceMQCount}   = $j->{MultiRace};
	 $storageInfo{clients_count} = $j->{ClientsNum};
	 $storageInfo{DT}            = $j->{diskType};
	 $storageInfo{BE}            = $j->{backend};
	 $storageInfo{STH}            = $j->{STH};

	 $storageInfo{standName}   = $j->{stand};
	 if ( ! $storageInfo{STH} ){ $storageInfo{STH} = `ssh -p 26 root\@$storageInfo{standName} sainfo lshardware  | grep hardware | awk '{print \$NF}'` ;       chomp $storageInfo{STH} ; }
	 $storageInfo{ThreadsPerClient} = $j->{ThreadsPerClient};
	 $storageInfo{vdisk_size}       = $j->{vdiskSize};
	 $storageInfo{raceMQverion}     = $j->{RaceMQVersion};
	 $storageInfo{LunPerClient}     = $j->{LunPerClient};
	 $storageInfo{resultsType}      = $j->{ResultsType};
	 $storageInfo{coleto_level}     = $j->{coleto_level};
	 $storageInfo{clients_name}     = $j->{Clients};
	 $storageInfo{Coletos}     = $j->{coleto};
	 $storageInfo{clientMgmt}  = $j->{ClientMgmt};
	 $storageInfo{testType}    = $j->{testType};
	 $storageInfo{testmode}    = $j->{testmode};
	 $storageInfo{FCperClient} = $j->{FCperClient};
	 $config{standName}   = $j->{stand};
	$storageInfo{standNameType} = $j->{stand};
     $storageInfo{vdisk_count} = $j->{vdiskCount};
     $storageInfo{mdisk_size}  = $j->{totalDisks};

	#    print Dumper %config;
	} else {
    	print "Starting data extraction...\n";
	    $storageInfo{STH} = `ssh -p 26 root\@$storageInfo{standName} sainfo lshardware  | grep hardware | awk '{print \$NF}'` ;       chomp $storageInfo{STH} ;
	    $storageInfo{version} = `ssh -p 26 root\@$storageInfo{standName} lssystem | grep code | awk '{print \$2" "\$3" "\$4}'`;       chomp $storageInfo{version};
	    $storageInfo{raceMQverion} = `ssh -p 26 root\@$storageInfo{standName} /data/race/rtc_racemqd -v | grep race | awk '{print \$2}'` ;    chomp $storageInfo{raceMQverion} ;
	    $storageInfo{Coletos} = "";
	    $storageInfo{BE} = 'NONE' ;
	   	$storageInfo{DT} = 'NONE' ;
	   	$storageInfo{raid_level} = 'NONE';
		my $hostList = ();
		$hostList = `ssh -p 26 root\@$storageInfo{standName} lshost -nohdr | awk '{print \$1}'`;
    	if ($storageInfo{STH} eq "CG8" || $storageInfo{STH} eq "DH8") {
	    	$storageInfo{mdisk_count} = `ssh -p 26 root\@$storageInfo{standName} lsmdisk | grep managed | wc -l`;    	                chomp $storageInfo{mdisk_count};
		    $storageInfo{mdisk_size} = `ssh -p 26 root\@$storageInfo{standName} lsmdisk  | tail -n 1 | awk '{print \$7}'`;              	chomp $storageInfo{mdisk_size};
	    	$storageInfo{backend} = `ssh -p 26 root\@$storageInfo{standName} lscontroller  | tail -n 1 | awk '{print \$2}'`;    	        chomp $storageInfo{backend};
	    	$storageInfo{BE} = $storageInfo{backend} ;
    	}#4
		else{#5
		    $storageInfo{mdisk_count} = `ssh -p 26 root\@$storageInfo{standName} lsdrive | grep online | wc -l` ;                       chomp $storageInfo{mdisk_count};
		    $storageInfo{mdisk_size} = `ssh -p 26 root\@$storageInfo{standName} lsdrive | grep online | tail -n 1 | awk '{print \$5'}` ;	chomp $storageInfo{mdisk_size} ;
		    $storageInfo{backend} = `ssh -p 26 root\@$storageInfo{standName} lsdrive 10 | grep RPM | awk '{print \$NF}'` ;    	        chomp $storageInfo{backend} ;
		    $storageInfo{DT} = $storageInfo{backend} ;
	    	$storageInfo{raid_level} = `ssh -p 26 root\@$storageInfo{standName} lsmdisk 0 | grep raid_level | awk '{print \$NF}'` ;	    chomp $storageInfo{raid_level} ;
	    	$storageInfo{BE} = 'NONE' ;
		}#5

		$storageInfo{MultiRace} = `ssh -p 26 root\@$storageInfo{standName} ps -efL | grep race | awk '\$10 ~/racemqAd/ { racemqAd++  } \$10 ~ /racemqBd/ { racemqBd++  } \$10 ~ /rtc_racemqd/ { rtc_racemqd++  }END { if ( racemqAd < 2 || racemqBd < 2 && rtc_racemqd == 0  ) {print "1"} else { print "2"  }  } '`;
    	$storageInfo{vdisk_count} = `ssh -p 26 root\@$storageInfo{standName} lsvdisk | grep online | wc -l`;                          chomp $storageInfo{vdisk_count} ;
	    $storageInfo{vdisk_size} = `ssh -p 26 root\@$storageInfo{standName} lsvdisk | grep online | tail -n 1 | awk '{print \$8}'`;   chomp $storageInfo{vdisk_size};
		$storageInfo{vdisk_size} =~ s!\..*!!g;
	    $storageInfo{vdbench_dataset} = ( $storageInfo{vdisk_count} *  $storageInfo{vdisk_size}) ;
		$storageInfo{ThreadsPerClient} = `cat $config{testFilesPath}"/1.3_disk_list"| sed 's/.*threads=//g' | uniq` ; $storageInfo{ThreadsPerClient} = trim($storageInfo{ThreadsPerClient});
#

#my $CC_Card = `ssh -p 26 root\@$Stand \"echo \"log_dump /tmp/racelog.txt\" > /data/rtcracecli\"; ssh -p 26 root\@$Stand cat /tmp/racelog.txt |grep accelerators | awk '{print \$1}'|awk -F= '{print \$2}'`;
#chomp $CC_Card ;

#my $CC_level = `ssh -p 26 root\@$Stand \"echo \"log_dump /tmp/racelog.txt\" > /data/rtcracecli\"; ssh -p 26 root\@$Stand cat /tmp/racelog.txt |grep comp_level | awk '{print \$1}'|awk -F= '{print \$2}'`;
#chomp $CC_level ;

    	print "---> $config{testResultsPath}/out_2.3 \n";
	    $storageInfo{clients_name} = `cat $config{testResultsPath}/out_2.3 |head -n 50 | grep host= |awk '{print \$7}'|awk -F= '{print \$2}'`;  chomp($storageInfo{clients_name});
	    $storageInfo{clients_name} =~ s/\n/,/g;
	    $storageInfo{clients_count} = `ssh -p 26 root\@$storageInfo{standName} lshost |grep -E 'online|degraded'| wc -l`;             chomp $storageInfo{clients_count};
	#my @ClientsNumber = (split(',', $storageInfo{clients_name})) ;
	#$storageInfo{clients_count} = scalar @ClientsNumber ;
	    $storageInfo{LunPerClient} = ( $storageInfo{vdisk_count} /  $storageInfo{clients_count} ) ;
    	$storageInfo{blockSize} = `cat $config{testResultsPath}/out_2.3 | grep avg | head -n 1 |awk '{print \$4}'`; chomp $storageInfo{blockSize};

		$storageInfo{hostsWWPNCount} = 0;
		foreach my $host (split ' ', $hostList){#6
			$storageInfo{hostWWPN} = `ssh -p 26 root\@$storageInfo{standName} lshost $host | grep WWPN | wc -l`;
			$storageInfo{hostsWWPNCount} = ( $storageInfo{hostWWPN}+$storageInfo{hostsWWPNCount});
			if ( ! $storageInfo{hostWWPN} % 2  ){#7
				print "Wrong WWPN Count on storage total count [ ".$storageInfo{hostsWWPNCount}." ]";
				exit(102);
			}#7
		}#6
		$storageInfo{FCperClient} = ( $storageInfo{hostsWWPNCount} / $storageInfo{clients_count} );

	    if ($storageInfo{STH} eq "CG8") {#8
		    my $cpu = `ssh -p 26 root\@$storageInfo{standName} sainfo lshardware  | grep cpu_count | awk '{print \$NF}'` ;
	    	chomp $cpu ;
		    if ($cpu == 1) { $storageInfo{standNameType} .= " - CG8" ; }
		    if ($cpu == 2) { $storageInfo{standNameType} .= " - CHUBBIE Node" ; }
	    }else{
		    if ($storageInfo{STH} eq "DH8") { $storageInfo{standNameType} .= " - BFN" ; }
	    	elsif ($storageInfo{STH} eq "500" ) { $storageInfo{standNameType} .= " - FAB1" ; }
	    	elsif ($storageInfo{STH} eq "T5H" ) { $storageInfo{standNameType} .= " - V5000 TB5" ; }
	    	else { $storageInfo{standNameType} .= " - V7000" ; }
	    }#8
    	( $storageInfo{svc_version}, $storageInfo{svc_build} ) = (split(' ', $storageInfo{version}))[0,2] ;
	    $storageInfo{svc_build} =~ s/\)//g ;
	    $storageInfo{raceMQverion} =~ s/v//g ;
	    my @Raceversion = (split('\.', $storageInfo{raceMQverion})) ;
	    $storageInfo{raceBrance} = $Raceversion[0] . '.' . $Raceversion[1] ;
	    $storageInfo{mdisk_size} =~ s/GB// ;
	    $storageInfo{mdisk_size} =~ s/TB// ;
	    if ( $storageInfo{DT} eq "10000" ) { $storageInfo{DT} = "10K" ; }
	    if ( $storageInfo{DT} eq "15000" ) { $storageInfo{DT} = "15K" ; }
	}
    print "Stand data extraction status: DONE\n";
}
sub vdbenchCollectResults($){

    my $files_path = shift;
	print "\ncollecting vdbench results from " . $files_path."\n";
    $storageInfo{blockSize} = `cat $config{testResultsPath}/out_2.3 | grep avg | head -n 1 |awk '{print \$4}'`; chomp $storageInfo{blockSize};
	foreach my $f (@results_files){
        my $working_file = $files_path."/".$f;
		print "\nworing on file [".$working_file."]\n" if ( $config{verbose} );
        $f =~ s|[^\d.]||g;
        my @cmp = grep { $_ =~ /$f/ } keys %ratio;
        my $cmp = $ratio{$cmp[0]};
        #my $fsize = -s $working_file;
        next if (int( -s $working_file) < 10640) ;

		if ( $config{debug} ) {print "[DEBUG] test interval [\"\ncat $working_file |grep interval| head -n 1| awk '{print \$1 \$2 \$3}'\n\"]" };
        $vdbench_results{$cmp}{"date_".$cmp} = `cat $working_file |grep interval| head -n 1| awk '{print \$1 \$2 \$3}'`; chomp($vdbench_results{$cmp}{"date_".$cmp});
		if ( $config{verbose} ) { print "[ VERBOSE ] date : ".$vdbench_results{$cmp}{"date_".$cmp}."\n";}

		if ( $config{debug} ) {print "[ DEBUG ]compration ratio [ \"cat $working_file | grep CompRatio| awk '{print \$2}'\n\" ]"};
        $vdbench_results{$cmp}{"cmp_rate_".$cmp} = `cat $working_file | grep CompRatio| awk '{print \$2}'`;  chomp($vdbench_results{$cmp}{"cmp_rate_".$cmp});
		if ( $config{verbose} ) { print "[ VERBOSE ]  : ".$vdbench_results{$cmp}{"cmp_rate_".$cmp}."\n";}

		if ( $config{debug} ) { print "[ DEBUG ] write average \ncat $working_file | grep avg_ | head -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'\n"};
        $vdbench_results{$cmp}{"write_".$cmp} = `cat $working_file | grep avg_ | head -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`; chomp($vdbench_results{$cmp}{"write_".$cmp});
		if ( $config{verbose} ) { print "[ VERBOSE ]results : ".$vdbench_results{$cmp}{"write_".$cmp}."\n";}

		if ( $config{debug}) {print "[ DEBUG ]read average \ncat $working_file | grep avg_ | tail -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'\n"};
        $vdbench_results{$cmp}{"read_".$cmp} = `cat $working_file | grep avg_ | tail -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`; chomp($vdbench_results{$cmp}{"read_".$cmp});
		if ( $config{verbose} ) { print "results : ".$vdbench_results{$cmp}{"read_".$cmp}."\n";}

		if ( $config{debug}) {print "vdbench start time \ncat $working_file | grep \"Starting RD\" | head -n 1| awk '{print \$1}'| awk -F. '{print \$1}'\n";}
        $vdbench_results{$cmp}{"st_".$cmp} = $vdbench_results{$cmp}{"date_".$cmp}." ".`cat $working_file | grep "Starting RD" | head -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`; chomp($vdbench_results{$cmp}{"st_".$cmp});
		if ( $config{verbose} ) { print "results : ".$vdbench_results{$cmp}{"st_".$cmp}."\n";}

		if ( $config{debug}) {print "compration ratio \ncat $working_file | grep avg_ | tail -n 1| awk '{print \$1}'| awk -F. '{print \$1}'\n"};
        $vdbench_results{$cmp}{"et_".$cmp} = $vdbench_results{$cmp}{"date_".$cmp}." ".`cat $working_file | grep avg_ | tail -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`; chomp($vdbench_results{$cmp}{"et_".$cmp});
		if ( $config{verbose} ) { print "results : ".$vdbench_results{$cmp}{"et_".$cmp}."\n";}

        print "\nfile_name out_$f compration $cmp \n" if ( $config{debug} );
        print Dumper($vdbench_results{$cmp}) if ($config{debug}) ;
    }
}

sub vdbenchCreateJsonFile(){

$storageInfo{bs_sort} = ( $storageInfo{blockSize} / 1024 )."k";
#print "Block Size : ".$storageInfo{bs_sort}. "\n";
#print "Storage Name    : ".$storageInfo{standName}. "\n";
#print "Storage version : ".$storageInfo{svc_version}. "\n";
#print "Storage build   : ".$storageInfo{svc_build}. "\n";
#print " \ndate ".$vdbench_results{"30"}{"st_30"}."build ".$storageInfo{svc_build}.".json\n";
#$vdbench_results{"startTest"} = $vdbench_results{"30"}{"st_30"};
#$vdbench_results{"startTest"} =~ s/://g;
my $json_file = "vdbench_results.".$storageInfo{standName}."_".( $storageInfo{blockSize} / 1024 )."k_".$vdbench_results{30}{st_30}.".json";
$json_file =~ s/://g;
$json_file =~ s/ |,/_/g;
#my $json_file = "vdbench_results.".$storageInfo{standName}.".".$($storageInfo{blockSize}/1024)."k.".$vdbench_results{"30"}{"st_30"}.".json";
unlink($json_file) if ( -e $json_file );

open ( my $vdb_fh, ">>$json_file") || die "Can not open json file\n" ;
print $vdb_fh "{
\t\"startTime\":      	\"$vdbench_results{30}{st_30}\",
\t\"endTime\":        	\"$vdbench_results{93}{et_93}\",
\t\"ResultsType\":    	\"DEV\",
\t\"testType\":       	\"IOZONE\",
\t\"stand\":          	\"$storageInfo{standName}\",
\t\"SVC_Version\":    	\"$storageInfo{svc_version}\",
\t\"SVCBuilds\":      	\"$storageInfo{svc_build}\",
\t\"backend\":        	\"$storageInfo{BE}\",
\t\"diskType\":       	\"$storageInfo{DT}\",
\t\"noOfDisks\":        \"$storageInfo{mdisk_count}\",
\t\"totalDisks\":       \"$storageInfo{mdisk_size}\",
\t\"Raid\":             \"$storageInfo{raid_level}\",
\t\"RaceBranchType\":   \"$storageInfo{raceBrance}\",
\t\"RaceMQVersion\":    \"$storageInfo{raceMQverion}\",
\t\"MultiRace\":        \"$storageInfo{raceMQCount}\",
\t\"testmode\":       	\"CMP\",
\t\"vdiskCount\":     	\"$storageInfo{vdisk_count}\",
\t\"vdiskSize\":      	\"$storageInfo{vdisk_size}\",
\t\"coleto\":         	\"$storageInfo{Coletos}\",
\t\"coleto_level\":   	\"2\",
\t\"blocksize\":      	\"$storageInfo{bs_sort}\",
\t\"ClientMgmt\":     	\"NONE\",
\t\"Clients\":        	\"$storageInfo{clients_name}\",
\t\"ClientsNum\":     	\"$storageInfo{clients_count}\",
\t\"ThreadsPerClient\": \"$storageInfo{ThreadsPerClient}\",
\t\"LunPerClient\":     \"$storageInfo{LunPerClient}\",
\t\"FCperClient\":      \"$storageInfo{FCperClient}\"\n,";

    vdbenchResultsToJson($vdb_fh);
    close $vdb_fh;

	print "\n\nResults Files for blocksize [ ".$storageInfo{bs_sort}." ]";
	print "\njson File name : ".$json_file."\n";
    system("cat $json_file\n") if ($config{debug});
#
#    system("scp $json_file 9.151.185.23:/mnt/v7k/par_imports/vdbench/");
}

sub vdbenchResultsToJson($) {

    my $fh = shift;
    my %vdbecnOutputCount = (
        "30" => "1",
        "50" => "2",
        "63" => "3",
        "75" => "4",
        "93" => "5"
    );

	my $lastElement = (keys %vdbench_results)[-1];
	my (@compRatio , $compRatCount,$k);
    foreach my $cmp (keys %vdbench_results) {
    	if ( $cmp eq $lastElement ){
		#print "This is the last hash element [ ".$cmp."]";
			@compRatio = grep { $_ =~ /$cmp/ } keys %vdbecnOutputCount;
        	$compRatCount = $vdbecnOutputCount{$compRatio[0]};
        	my $krvalue = "";
			my $cmpLastElement = (keys $vdbench_results{$cmp})[-1];
        	foreach $k ( keys $vdbench_results{$cmp} ){
				if ( $cmpLastElement eq $k ){
					$krvalue = $k;
            		$krvalue =~ s/\_\d+//g;
            			if ( $krvalue eq "cmp_rate" ){
               	 			$krvalue = "iozone".$compRatCount;
            			} else {
               				$krvalue = $krvalue."".$compRatCount;
            			}
						print $fh "\t\"$krvalue\":\t\"$vdbench_results{$cmp}{$k}\"\n" ;

				}else{
            		$krvalue = $k;
            		$krvalue =~ s/\_\d+//g;
            			if ( $krvalue eq "cmp_rate" ){
               	 			$krvalue = "iozone".$compRatCount;
            			} else {
               				$krvalue = $krvalue."".$compRatCount;
            			}
						print $fh "\t\"$krvalue\":\t\"$vdbench_results{$cmp}{$k}\",\n" ;
				}
			}


		} else {
			@compRatio = grep { $_ =~ /$cmp/ } keys %vdbecnOutputCount;
        	$compRatCount = $vdbecnOutputCount{$compRatio[0]};
        	my $krvalue = "";
        	foreach $k ( keys $vdbench_results{$cmp}){
            	$krvalue = $k;
            	$krvalue =~ s/\_\d+//g;
            	if ( $krvalue eq "cmp_rate" ){
               	 	$krvalue = "iozone".$compRatCount;
            	} else {
               		$krvalue = $krvalue."".$compRatCount;
            	}
            	print $fh "\t\"$krvalue\":\t\"$vdbench_results{$cmp}{$k}\",\n" ;
        	}
    	}
	}
    print $fh "}" ;
}

sub xlsxCreateXIVHeader($){
	my %ex = shift;
	$ex{worksheet}->write( "B3", "Stand Name",$ex{format} );
	$ex{worksheet}->write( "B4", "XIV Version",$ex{format} );

}
sub xlsxCreateSVCHeader($){

	my %ex = %{shift()};

	$ex{worksheet}->write( "B3", "Stand Name/Type",$ex{format} );
	$ex{worksheet}->write( "B4", "BackEnd Storage",$ex{format} );
	$ex{worksheet}->write( "B5", "No. of MDisks"  ,$ex{format} );
	$ex{worksheet}->write( "B6", "SVC Version"    ,$ex{format} );
	$ex{worksheet}->write( "B7", "Race Version"   ,$ex{format} );
	$ex{worksheet}->write( "B8", "Test Date"      ,$ex{format} );
	# Data Set
	#
	#
	#
	$ex{worksheet}->write( "B10", "vdisk count"        ,$ex{format} );
	$ex{worksheet}->write( "B11", "vdisk size (GB)"    ,$ex{format} );
	$ex{worksheet}->write( "B12", "Total data set (GB)",$ex{format} );
	# Clisnts info

	$ex{worksheet}->write( "B14", "No. of clients" ,$ex{format} );
	$ex{worksheet}->write( "B15", "Threads/Client" ,$ex{format} );
	$ex{worksheet}->write( "B16", "File Size"      ,$ex{format} );
	$ex{worksheet}->write( "B17", "Block size"     ,$ex{format} );
	# Test results information

	$ex{worksheet}->write( "B20", "Real Compression Ratio"  ,$ex{format} );
	$ex{worksheet}->write( "B21", "Compression ratio"       ,$ex{format} );
	$ex{worksheet}->write( "B22", "Operation"               ,$ex{format} );
	$ex{worksheet}->write( "B23", "Write (MB/sec)"          ,$ex{format} );
	$ex{worksheet}->write( "B24", "Read (MB/sec)"           ,$ex{format} );
	$ex{worksheet}->write( "B25", "Start Test"              ,$ex{format} );
	$ex{worksheet}->write( "B26", "End Test"                ,$ex{format} );

}
sub xlsxAddResults($;$) {

	my %vdResults = %{shift()};
	my %ex = %{shift()};
	my %cell_num =
	(
          'cmp_rate_' 	=> '20',
          'write_' 		=> '23',
          'read_' 		=> '24',
          'st_' 		=> '25',
          'et_' 		=> '26'
	);
	my $letter_count = 'D';
	foreach my $data ( sort keys %vdResults ){

		my $letter = $letter_count."21";
		#print  $data." ".$letter."\n";
		$ex{worksheet}->write( $letter, $data."%"  ,$ex{format} );
		foreach my $rValue ( keys %cell_num ){
			my $v = $rValue.$data;
			my $dataLetter  = $letter_count."".$cell_num{$rValue};
			if ($config{debug}) { print "\t".$dataLetter."\t".$v."\t".$cell_num{$rValue}."\t".$vdResults{$data}{$v}."\n"; }

			$ex{worksheet}->write( $dataLetter, $vdResults{$data}{$v}  ,$ex{format} );
		}
		$letter_count++;
	}
	#	$ex{worksheet}->write( "D20", "Real Compression Ratio"  ,$ex{format} );



}
sub vdbenchCreateEXCEL() {
	my %exCreate;
	$storageInfo{startTestTime} = $vdbench_results{"30"}{"st_30"};
#---Create Excel
#my $workbook = Excel::Writer::XLSX->new( 'xiv_res_new.xlsx' );
	#
	#my $workbook = Excel::Writer::XLSX->new( "vdbench_results_".$storageInfo{standName}.".xlsx" );
	my $xlsx_file = "vdbench_results.".$storageInfo{standName}.".".($storageInfo{blockSize}/1024)."k.".$vdbench_results{"30"}{"st_30"}.".xlsx";
	$xlsx_file =~ s/://g;
	$xlsx_file =~ s/ |,/_/g;
	print "excel file ".$xlsx_file."\n";

	$exCreate{workbook} = Excel::Writer::XLSX->new( $xlsx_file );
	$exCreate{worksheet} = $exCreate{workbook}->add_worksheet('Data Set');

#---Create Format's
	$exCreate{format}  = $exCreate{workbook}->add_format( border => 2, underline => 0, color => 'black', align => 'left', valign => 'top', bold  => 1);
	$exCreate{format1} = $exCreate{workbook}->add_format( pattern => 1, border => 1, underline => 0, align => 'center', valign => 'top', bold => 1, bg_color  => 'orange' );
	$exCreate{format2} = $exCreate{workbook}->add_format( center_across => 1, border => 1,  bold  => 1 );
	$exCreate{format3} = $exCreate{workbook}->add_format( pattern => 1, border => 1, underline => 0, align => 'center', valign => 'top', bold => 1, bg_color  => 'green' );
	$exCreate{merge_format} = $exCreate{workbook}->add_format(
        center_across => 1,
        bold          => 1,
        size          => 15,
        pattern       => 1,
        border        => 6,
        color         => 'white',
        fg_color      => 'green',
        border_color  => 'yellow',
        align         => 'vcenter',
    );

	my $resultsCount = keys %vdbench_results;
	$exCreate{startLetter} = "D";
	$exCreate{endLetter}   = "D";
	$exCreate{mergedCells} = "d1:d2";
	if ($resultsCount > 1 ){
		$exCreate{merge_range} = 0 ;
		#print "\ntotal keys found on vdbecnh_results are " . $resultsCount."\n";
		for (2..$resultsCount){
			$exCreate{endLetter}++;
		}

		$exCreate{merge_range} = 1 ;
		print "end Letter is " . $exCreate{endLetter}."\n" if ( $config{debug} );
	}

#---Create First Sheet
	$exCreate{worksheet}->set_column( 'A:A', 5  );
	$exCreate{worksheet}->set_column( 'B:B', 28  );
	$exCreate{worksheet}->set_column( 'C:C', 3  );
	$exCreate{worksheet}->set_column( 'D:D', 17  );
	#
	# marge cell
	#print "Creating ".$exCreate{startLetter}.'9:'.$exCreate{endLetter}.'9';
	$exCreate{worksheet}->merge_range( $exCreate{startLetter}.'9:'.$exCreate{endLetter}.'9', 'Data Set', $exCreate{merge_format} );
	$exCreate{worksheet}->merge_range( $exCreate{startLetter}.'13:'.$exCreate{endLetter}.'13', "Clients Info" ,$exCreate{merge_format} );
	$exCreate{worksheet}->merge_range( $exCreate{startLetter}.'19:'.$exCreate{endLetter}.'19', "Test Results"  ,$exCreate{merge_format} );
#	$exCreate{worksheet}->set_column( 'B:D' , 28  );
#	$exCreate{worksheet}->set_row( 8, 35  );
	#
	# data set information
	#
	if ( lc($config{type}) =~ "xiv" ) {
		xlsxCreateXIVHeader(\%exCreate);
		$exCreate{worksheet}->write( "B5", $storageInfo{xiv_ver}, $exCreate{format2} );

	}elsif ( lc($config{type}) =~ "svc" ) {
		xlsxCreateSVCHeader(\%exCreate);
		if ( $exCreate{merge_range} ) {
	#		print "adding merge cells to excell ",$exCreate{endLetter};
			$exCreate{worksheet}->merge_range( 'D3:'.$exCreate{endLetter}.'3',  $storageInfo{standNameType},$exCreate{format2} );
			$exCreate{worksheet}->merge_range( 'D4:'.$exCreate{endLetter}.'4',  $storageInfo{backend}, $exCreate{format2} );
			$exCreate{worksheet}->merge_range( 'D5:'.$exCreate{endLetter}.'5',  $storageInfo{mdisk_count}." x ".$storageInfo{mdisk_size}."GB", $exCreate{format2} );
			$exCreate{worksheet}->merge_range( 'D6:'.$exCreate{endLetter}.'6',  $storageInfo{svc_version}." (".$storageInfo{svc_build}.")", $exCreate{format2} );
			$exCreate{worksheet}->merge_range( 'D7:'.$exCreate{endLetter}.'7',  $storageInfo{raceMQverion}, $exCreate{format2} );
			$exCreate{worksheet}->merge_range( 'D8:'.$exCreate{endLetter}.'8',  $storageInfo{startTestTime}, $exCreate{format2} );

			#$exCreate{worksheet}->merge_range( 'D8'. $exCreate{endLetter}.'8',  $vdbench_results{"30"}{"st_30"}, $exCreate{format2} );

			$exCreate{worksheet}->merge_range( 'D10:'.$exCreate{endLetter}.'10', $storageInfo{vdisk_count}, $exCreate{format2} );
			$exCreate{worksheet}->merge_range( 'D11:'.$exCreate{endLetter}.'11',  $storageInfo{vdisk_size}, $exCreate{format2} );
#			$exCreate{worksheet}->merge_raege( 'D11:'.$exCreate{endLetter}.'11', $storageInfo{vdisk_size}."GB", $exCreate{format2} );
			$exCreate{worksheet}->merge_range( 'D12:'.$exCreate{endLetter}.'12', ($storageInfo{vdisk_count} * $storageInfo{vdisk_size} )."GB", $exCreate{format2} );
			$exCreate{worksheet}->merge_range( 'D14:'.$exCreate{endLetter}.'14', $storageInfo{clients_count}." (".$storageInfo{clients_name}.")" , $exCreate{format2} );
			$exCreate{worksheet}->merge_range( 'D15:'.$exCreate{endLetter}.'15',  $storageInfo{ThreadsPerClient}, $exCreate{format2} );
			$exCreate{worksheet}->merge_range( 'D16:'.$exCreate{endLetter}.'16', "N/A", $exCreate{format2} );
			$exCreate{worksheet}->merge_range( 'D17:'.$exCreate{endLetter}.'17', ( $storageInfo{blockSize} / 1024 )."k", $exCreate{format2} );
			$exCreate{worksheet}->set_column( 'D:'.$exCreate{endLetter}, 17.87  );

		}else{
			$exCreate{worksheet}->write( "D3",  $storageInfo{standNameType},$exCreate{format2} );
			$exCreate{worksheet}->write( "D4",  $storageInfo{backend}, $exCreate{format2} );
			$exCreate{worksheet}->write( "D5",  $storageInfo{mdisk_count}." x ".$storageInfo{mdisk_size}."GB", $exCreate{format2} );
			$exCreate{worksheet}->write( "D6",  $storageInfo{svc_version}." (".$storageInfo{svc_build}.")", $exCreate{format2} );
			$exCreate{worksheet}->write( "D7",  $storageInfo{raceMQverion}, $exCreate{format2} );
			$exCreate{worksheet}->write( "D8",  $vdbench_results{30}{st_30}, $exCreate{format2} );
			# Data set information:
			#
			$exCreate{worksheet}->write( "D10", $storageInfo{vdisk_count}, $exCreate{format2} );
			$exCreate{worksheet}->write( "D11", $storageInfo{vdisk_size}."GB", $exCreate{format2} );
			$exCreate{worksheet}->write( "D12", ($storageInfo{vdisk_count} * $storageInfo{vdisk_size} )."GB", $exCreate{format2} );
			# Clients Info
			#
			$exCreate{worksheet}->write( "D14", $storageInfo{clients_count}." (".$storageInfo{clients_name}.")" , $exCreate{format2} );
			#$exCreate{worksheet}->write( "D14", $storageInfo{clients_count} , $exCreate{format2} );
			$exCreate{worksheet}->write( "D15", "N/A" , $exCreate{format2} );
			$exCreate{worksheet}->write( "D16", "N/A", $exCreate{format2} );
			$exCreate{worksheet}->write( "D17", ($storageInfo{blockSize} /1024 )."k", $exCreate{format2} );
		}
		xlsxAddResults(\%vdbench_results,\%exCreate);


	}else{
		print "No Storage Type were defined.";
	}
$exCreate{workbook}->close;

}


print "Running in debug mode \n" if ($config{debug});
if ( $config{absPath} ) {
    print "Working Directory $config{absPath}\n" if ($config{verbose}) ;
    build_tree($config{absPath});
    #dirTreeHash($config{absPath});
	#$config{testResultsPath}= $config{absPath}."/test_results";
	$config{jsonConfigFile} = $config{absPath}."/storageInfo.json";
	#$config{testFilesPath}  = $config{absPath}."/test_files";
	if ( ! -e $config{jsonConfigFile} ){
		print "StorageInfo file was not found \n";
		if ( !defined $config{standName} ) {
			print "Stand name is missing\n";
			exit(100);
		}
		if (  ! $config{type} ) {
			print "you most def -type [xiv|svc] ";
			exit(101);
		}
    	collectStorageInfo($config{absPath});
    	print Dumper(%storageInfo) if ($config{verbose});
			foreach my $key ( keys $config{directory}  ){
				print "working path ".$key ."\n";
				$config{testResultsPath}= $config{'directory'}{$key}."/test_results";
    			filelist($config{testResultsPath});
    			vdbenchCollectResults($config{testResultsPath});
    			vdbenchCreateJsonFile();
				vdbenchCreateEXCEL();
			}
		}else {

			print "StorageInfo file was found $config{jsonConfigFile}\n";
    		collectStorageInfo($config{absPath});
			foreach my $key ( keys $config{directory}  ){
				$config{testResultsPath}= $config{'directory'}{$key}."/test_results";
				print "working on $config{'directory'}{$key}\n";
				filelist($config{testResultsPath});
				vdbenchCollectResults($config{testResultsPath});
				vdbenchCreateJsonFile();
				vdbenchCreateEXCEL();
			}
		}
}else{
    $config{absPath}= cwd();
	$config{testResultsPath}= $config{absPath}."/test_results";
	$config{jsonConfigFile} = $config{absPath}."/storageInfo.json";
	$config{testFilesPath}  = $config{absPath}."/test_files";
    collectStorageInfo($config{absPath});
    print "Working Directory $config{absPath}\n";
    dirTreeHash($config{absPath});
	exit;
    filelist($config{testResultsPath});
    vdbenchCollectResults($config{testResultsPath});
    vdbenchCreateJsonFile();
}
exit;
