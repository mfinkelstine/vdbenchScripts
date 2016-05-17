#!/usr/bin/perl

use strict;
use warnings;
use Excel::Writer::XLSX;
#use Spreadsheet::WriteExcel;
use Getopt::Long;

my $block_size = "256k";
my $Storage;
my $LogDir;
my %sheet;
my @comp;
my $logfile;
my $Write;
my $Read;
my $res_write;
my $res_read;
my $Date;
my $start_time;
my $end_time;

sub usage {
        print "VDBench Test Results\n";
        print "vdbench.pl -s storage_name -l log_directory \n";
        print "Example: vdbench -s xiv_name -l 090415.11111\n";
        exit;
}

GetOptions(
        's=s' => \$Storage,
        'l=s' => \$LogDir,
        ) or die usage() ;

#---Get Param from XIV
my $xcli = "ssh $Storage xcli.py";
my $xiv_ver = `$xcli version_get -z`;
chomp $xiv_ver;
my $n_disks = `$xcli vol_list -z |wc -l`;
chomp $n_disks;
my $vdisk_size =`$xcli vol_list -z -f size|tail -1`;
chomp $vdisk_size;
my $race_ver = `ssh $Storage /xiv/tools/race_debug_dump log |grep "NetComp Version" | awk '{print \$5}'|sed 's/)//'`;
chomp $race_ver;
my @clients = `$xcli host_list -z -f name`;
chomp @clients;
my $clients = join " ",@clients;

my %compre = (
	1   => "0%",
        1.3 => "30%",
        1.7 => "50%",
        2.3 => "65%",
        3.5 => "70%",
        11  => "90%",
);

my $LogPatch = "/root/vdbench/logs/";
my @vdtest = `ls -ltr  $LogPatch$LogDir|grep -v total|awk '{print \$NF}'`;
chomp @vdtest;

#---Create Excel
#my $workbook = Excel::Writer::XLSX->new( 'xiv_res_new.xlsx' );
my $workbook = Excel::Writer::XLSX->new( "xiv_res_$Storage\_$LogDir.xlsx" );
my $worksheet = $workbook->add_worksheet('Data Set');

#---Create Format's
my $format = $workbook->add_format( border => 1, underline => 0, color => 'black', align => 'left', valign => 'top', bold  => 1);
my $format1 = $workbook->add_format( pattern => 1, border => 1, underline => 0, align => 'center', valign => 'top', bold => 1, bg_color  => 'orange' );
my $format2 = $workbook->add_format( center_across => 1, border => 1,  bold  => 1 );
my $format3 = $workbook->add_format( pattern => 1, border => 1, underline => 0, align => 'center', valign => 'top', bold => 1, bg_color  => 'green' );

#---Create First Sheet
$worksheet->set_column( 0, 0, 10 );
$worksheet->set_column( 0, 1, 30 );
$worksheet->write( "A1", "Stand",$format2 );
$worksheet->write( "A2", "Stand Name",$format );
$worksheet->write( "B2", $Storage ,$format2 );
$worksheet->write( "A3", "Stand Type", $format );
$worksheet->write( "A4", "No. of Disks", $format );
$worksheet->write( "A5", "XIV  version", $format );
$worksheet->write( "B5", $xiv_ver, $format2 );
$worksheet->write( "A6", "RACE version", $format );
$worksheet->write( "B6", $race_ver, $format2 );
$worksheet->write( "A7", "Date", $format );
$worksheet->write( "A8", "Data Set", $format1 );
$worksheet->write( "A9", "Number of vdisks", $format );
$worksheet->write( "B9", $n_disks, $format2 );
$worksheet->write( "A10", "vdisk size (GB)", $format );
$worksheet->write( "B10", $vdisk_size, $format2 );
$worksheet->write( "A11", "Total Dataset (GB)", $format );
$worksheet->write( "A12", "Write Dataset (GB)", $format );
$worksheet->write( "A13", "Read Dataset (GB)", $format );
$worksheet->write( "A14", "Clients", $format1 );
$worksheet->write( "B14", $clients, $format2 );
$worksheet->write( "A15", "Number of clients", $format );
$worksheet->write( "A16", "Threads/client", $format );

#---Create Excel
sub excel {
	#%sheet;
	foreach my $vdtest (@vdtest){
		$sheet{$vdtest} = $workbook->add_worksheet($vdtest);
		$sheet{$vdtest}->set_column( 0, 0, 20 );
		$sheet{$vdtest}->write( "A1", "Block Size", $format3 );
        	$sheet{$vdtest}->write( "B1", $vdtest , $format3 );
		$sheet{$vdtest}->merge_range( 'A2:M2', "Results", $format1 );
		$sheet{$vdtest}->write( "A3", "Compression ratio", $format );
	        $sheet{$vdtest}->write( "A4", "Operation", $format );
       		$sheet{$vdtest}->write( "A5", "Write" , $format );
        	$sheet{$vdtest}->write( "A6", "Read" , $format );
        	$sheet{$vdtest}->write( "A7", "Start Time", $format );
        	$sheet{$vdtest}->write( "A8", "End Time" , $format );

		my $x = 1;
        	my $y = 2;
		@comp = `ls -1 $LogPatch$LogDir/$vdtest/ |grep OUT |awk -F"_" '{print \$8}' |sed s/.result.log//g`;
		chomp  @comp;
		foreach my $comp (@comp) {
			$logfile = `ls -1 $LogPatch$LogDir/$vdtest/ |grep "_$comp.res"`;
                        chomp $logfile;
                        $Write = `cat $LogPatch$LogDir/$vdtest/$logfile | grep avg_ | head -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`;
                        chomp $Write;
                        $Read = `cat $LogPatch$LogDir/$vdtest/$logfile | grep avg_ | tail -n 1| awk -F'avg_' '{print \$2 }'| awk '{print \$3}'`;
                        chomp $Read;
			# Error $res_write = `cat $LogPatch$LogDir/$vdtest/$logfile | grep avg_ | head -n 1| awk '{print \$7 }'`;
			$res_write = `cat $LogPatch$LogDir/$vdtest/$logfile | grep avg_ | head -n 1| awk '{print \$(NF-5)}'`;
			chomp $res_write;
			# Error $res_read = `cat $LogPatch$LogDir/$vdtest/$logfile | grep avg_ | tail -n 1| awk '{print \$8 }'`;
			$res_read = `cat $LogPatch$LogDir/$vdtest/$logfile | grep avg_ | tail -n 1| awk '{print \$(NF-6)}'`;
			chomp $res_read;	
			$Date = `cat $LogPatch$LogDir/$vdtest/$logfile |grep interval| head -n 1| awk '{print \$1 \$2 \$3}'`; 
			chomp $Date;
			$start_time = $Date." ".`cat $LogPatch$LogDir/$vdtest/$logfile  | grep "Starting RD" | head -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`;
                        chomp $start_time;
			$end_time = $Date." ".`cat $LogPatch$LogDir/$vdtest/$logfile | grep avg_ | tail -n 1| awk '{print \$1}'| awk -F. '{print \$1}'`;
			chomp $end_time;
			$sheet{$vdtest}->merge_range( 2, $x, 2, $y, $compre{$comp}, $format2);
			$sheet{$vdtest}->write( 3, $x,'Throughput', $format );
			$sheet{$vdtest}->write( 3, $y,'Latency', $format );
			$sheet{$vdtest}->write( 4, $x, $Write , $format);
			$sheet{$vdtest}->write( 5, $x, $Read , $format);
			$sheet{$vdtest}->write( 4, $y, $res_write , $format);
			$sheet{$vdtest}->write( 5, $y, $res_read , $format);
			$sheet{$vdtest}->merge_range( 6, $x, 6, $y, $start_time, $format);
                        $sheet{$vdtest}->merge_range( 7, $x, 7, $y, $end_time, $format);
			$x += 2;
			$y += 2;
			undef $Write;
			undef $Read;	
			undef $res_write;
			undef $res_read;
			undef $start_time;
			undef $end_time;	
		}	
	}
}
&excel;
$workbook->close;

