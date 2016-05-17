#!/usr/bin/perl
#
use Getopt::Long;
use MIO::CMD;
 

$Storage = "";
@clients;
#$BlockSize = "";
@BS = "";
$CP;
$NumVolume = "";
$Thread = "";
$VDLog;
$VDLogFile;
$LogPath;
$LogDir; 
$Volume_size = "290";
#----------- client list ------------
#@hosts=(wl9 , wl10 , wl11 , wl12);
@hosts=(wl9 , wl10, mc011 , mc030 , mc031 , mc032);


#--------Function--------
sub UnmStrVol;
sub DelStrVol;
sub StopMultipatd;
sub CleanHosts;
sub DelPool;
sub CreatePool;
sub CrVolMap;
sub RescanHosts;
sub DiskList;
sub Write_Test;
sub Read_Test;
sub CreateLogFile($$);
sub SendMail;
sub RunVdbWrite;
sub RunVdbRead;

sub usage {
        print "VDBench Test\n";
        print "vdbench.pl -s xiv_name -b block_size -v number_of_volumes -t number_of_threads \n";
        print "Example: vdbench -s xiv_name -b 4k -v 100 -t 4\n";
        print "vdbench.pl -s xiv_name -bs block_size -v number_of_volumes per hosts -t number_of_threads \n";
        print "Example: vdbench -s xiv_name -bs \"4k 32k\" -v 100 -t 4\n";
        exit;
}

GetOptions(
        's=s' => \$Storage,
#       'b=s' => \$BlockSize,
        'bs=s' => \$BS,
        'v=s' => \$NumVolume,
        't=s' => \$Thread,
        ) or die usage() ;

#---------- Check if all parameters exist --------------
if (defined $Storage && $Storage eq "") { &usage ;};
#if (defined $BlockSize && $BlockSize eq "") { &usage ;};
if (defined $BS && $BS eq "") { &usage ;};
if ($BS !~ m/k/) { &usage ;};
if (defined $NumVolume && $NumVolume eq "") { &usage ;};
if (defined $Thread && $Thread eq "") { &usage ;};

print "\e[1;31mVDBENCH test Storage:$Storage Block Size:$BS Number of Volumes:$NumVolume Treads:$Thread\e[0m\n";
print "\e[1;31mHosts : @hosts\e[0m\n";

#--- Send mail ------------------
sub  SendMail {
	unlink ('/tmp/mail.log');
	open (M,'>>/tmp/mail.log');
	print M "Vdbench test   Storage:$Storage\n";
	print M "               Block Size:$BS\n"; 
	print M "               Number of Volumes:$NumVolume\n";
	print M "               Treads:$Thread\n";
	print M "               Hosts : @hosts\n";
	print M "               Log Directory : $LogDir\n";
	close M;
	`mail -s "Vdebench Test on XIV $Storage"  josefs\@il.ibm.com < /tmp/mail.log`;
}

#-- XCLI
$xcli = "ssh -i /root/.ssh/id_rsa_devel root\@$Storage xcli.py";


#-------- Check Host WWN -------
#foreach $host (@hosts) {
#
#	@wwn = `ssh $host "cat /sys/class/fc_host/host[0-9]*/port_name \| sed s/^0*.//g"`;
#	chomp @wwn;
#	$num_wwn = @wwn;
#	print "Number wwn's in host $num_wwn\n";
#	print "@wwn\n";
#}

##################### Clean All Enviroment #########################
#-------- Get All Clients  Connected to Storage ----------
@clients = `$xcli host_list -z -f name`;
chomp @clients;
print "!!!! @clients !!!!\n";

#---------- Unmap  Storage Volumes -----------
sub UnmStrVol {
        print  "Unmap All volumes.......\n";
        foreach $client (@clients) {
                @volume = `$xcli mapping_list host=$client -f volume -z`;
                chomp @volume;
		print "----Vol @volume\n";
                foreach $volume (@volume) {
                        `$xcli unmap_vol host=$client vol=$volume > /tmp/unmap.out`;
                        print "Unmap $volume on Host: $client\n";
                }
        }
}

#---------- Delete Storage Volumes -----------
sub DelStrVol {
	print  "Delete All volumes.......\n";
	foreach $client (@clients) {
		@volume = `$xcli vol_list -z -f name`;
		chomp @volume;
		foreach $volume (@volume) {
			`$xcli vol_delete vol=$volume -y  > /tmp/del_vol.out`;
			print "Delete $volume \n";
		}	
	}
}

#------ Stop Multipathd -----------

sub StopMultipatd {
	print "stop multipathd ...\n";
	sleep 5;
        foreach $client (@hosts) {
	        print "----$client\n";
       	 	`ssh $client /etc/init.d/multipathd stop`;
		print "End stop multipathd ...\n";
	}
}

#------- Clean Hosts ------
sub CleanHosts {
	print "Clean Hosts Multipath ...\n";
	foreach $client (@hosts) {
		print "----$client\n";
		`ssh $client /usr/global/scripts/delvol.pl -mp /mnt/lun`;
                sleep 3;
		`ssh $client /usr/global/scripts/delvol.pl -mp /mnt/lun`;
		#`ssh $client multipath -F`;
                #print "multipath -F\n";
		#`ssh $client /etc/init.d/multipathd stop`;
		#`ssh $client /etc/init.d/multipathd stop`;
		#print "systemctl stop multipathd\n";
		#sleep 3;
		#`ssh $client /root/vdbench/rescan.pl`;
		#`ssh $client pkill -9 multipath`;
		##`ssh $client dmsetup remove_all --force`;
		#print "dmsetup remove_all --force\n";
		`ssh $client rmmod qla2xxx`;
		#print "rmmod qla2xxx on $client\n";
		`ssh $client modprobe qla2xxx ql2xmaxqdepth=64`;
		#print "modprobe qla2xxx on $client\n";
		#`ssh $client /etc/init.d/multipathd start`;
	}	

}

#--------------Ummap Vol ,Delete Vol ,Delete Pool and  Clean Hosts
#&UnmStrVol;
#&DelStrVol;
#&CleanHosts;

#--------- Delete Pool ------------
sub DelPool {
	print "Start Delete Pool\n";
	`$xcli pool_delete pool=pool0 -y`;
	print "Deleted Pool\n";
}
################ Create  Test Env ##################

#---------- Create Pool ---------
sub CreatePool {
	print "Create Pool\n";
	$Fsize="240000";
	$Half="200000";
	#`$xcli pool_create pool=pool0 soft_size=$Fsize hard_size=0 snapshot_size=0 compress=yes`;
	`$xcli pool_create pool=pool0 soft_size=$Fsize hard_size=$Fsize snapshot_size=0`;
	#`$xcli pool_resize pool=pool0 soft_size=$Fsize  hard_size=$Half`;
}
#------- Create Volumes and Map------

sub CrVolMap {
print "Create Volumes\n";
#	foreach $host (@hosts) {
	foreach $host (@clients) {
		$LunID="1";
		for $VolNum (1..$NumVolume) {
			# COMPESSED -- YES `$xcli vol_create size=420 pool=pool0 vol=${host}_${VolNum} compressed=yes`;
			#`$xcli vol_create size=${Volume_size} pool=pool0 vol=${host}_${VolNum} compressed=yes`;
			`$xcli vol_create size=${Volume_size} pool=pool0 vol=${host}_${VolNum}`;
			print "Create volume : ${host}_${VolNum}\n";
			`$xcli map_vol vol=${host}_${VolNum} host=$host lun=$LunID`;
			$LunID++;
			print "Map Vol :${host}_${VolNum} to Host: $host\n";
		}
	print "Map Finished\n";
	}
}
#------------Rescan Hosts ----------

sub RescanMulti {
	print "@hosts\n";
	@cmd = qw( ssh {} /root/vdbench/rescan.pl );
	print "--- @cmd --\n";
	$cmd = MIO::CMD->new( map { $_ => \@cmd } @hosts );
	$result = $cmd->run( max => 32, log => \*STDERR, timeout => 300 );
	print "Done Multi Scan\n";
}

sub RescanHosts {
	print "Rescan Hosts\n";
	foreach $host (@hosts) {
		print "Rescan host $host\n";
		`ssh $host /root/vdbench/rescan.pl`;
		$dm = `ssh $host multipath -l \|grep dm-\|wc \-l`;
		chomp $dm;

		print "----$dm---\n";
			if ( $dm ne $NumVolume ) { print "You Don't  Have a Same Volumes\n"; };
	}
}
#-------------Create Disk_List File --------------
sub DiskList {
	unlink ('/tmp/disk_list');
	open (F, '>>/tmp/disk_list');
	foreach $host (@hosts) {
		$count = "1";
		$volmapper=`ssh $host "multipath -l  |grep dm-"`;
		chomp $volmapper;
		foreach $line ( split( '\n', $volmapper)) {
			$diskid = ( split( ' ', $line ) )[0]; 
			print "$diskid\n";
			print F "sd=$host.$count,hd=$host,lun=/dev/mapper/$diskid,openflags=o_direct,size=200G,threads=$Thread\n";
			$count++;		
			}	
	}	
}

#-------------Create Write Test File ----------------
sub Write_Test {
	unlink ('/tmp/write_test');
	open (F, '>>/tmp/write_test');
	print F "compratio=${CP}\n";
	foreach $host (@hosts) {
                $count = "1";
		print F "hd=$host,system=$host.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root\n";
	}
	print F "include=/tmp/disk_list\n";
	print F "wd=wd1,sd=*,xfersize=$BS,rdpct=0,rhpct=0,seekpct=0\n";
	print F "rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=6000g,warmup=360,interval=10\n";
}

#-------------Create Read Test File ----------------
sub Read_Test {
        unlink ('/tmp/read_test');
        open (F, '>>/tmp/read_test');
        print F "compratio=$CP\n";
        foreach $host (@hosts) {
                $count = "1";
                print F "hd=$host,system=$host.eng.rtca,shell=ssh,vdbench=/root/vdbench,user=root\n";
        }
	print F "include=/tmp/disk_list\n";
	print F "wd=wd1,sd=*,xfersize=$BS,rdpct=100,rhpct=0,seekpct=0\n";
	print F "rd=run1,wd=wd1,iorate=max,elapsed=24h,maxdata=4000g,warmup=360,interval=10\n"
}


#-----------Log File -------------
#Passing $BS
$LogPath = "/root/vdbench/logs/";
$LogDir = `date '+%d.%m.%Y.%s'`;
chomp $LogDir;
print "Log Directory :$LogDir\n";

sub CreateLogFile ($$){
	$bs = shift;
	$cp = shift;
	$VDLogOut = "$LogPath$LogDir/$bs/vdbOutput.$CP/";
	$VDLog = "$LogPath$LogDir/$bs/";
	$VDDate = `date +'%Y%m%d_%H%M%S'`;
	chomp $VDDate;
	$VDLogFile = "OUT_${VDDate}_${Storage}_${NumVolume}disks_${bs}_${Thread}th_${cp}.result.log";
	print "$VDLogFile\n"; 
	`mkdir -p $LogPath$LogDir/$bs`; 
}

#---------------------- Running Write Test -----
sub RunVdbWrite {
	print "Running Write Test\n";
	print "Run Test \n";
	system ("./vdbench -c -f /tmp/write_test -o $VDLogOut |tee -a $VDLog$VDLogFile");
}

#----------- Runiing Read Test
sub RunVdbRead {
        print "Running Read Test\n";
        print "Run Test \n";
        system ("./vdbench -c -f /tmp/read_test -o $VDLogOut |tee -a $VDLog$VDLogFile");
}


#------Create Volume, Maping,Rescan all Hosts,Create Disk_List ------------

#&CrVolMap;
#&RescanMulti;
#Josef Dont Start &RescanHosts;
#&DiskList;
#&SendMail;

############## MAIN 
#----- Run Vdbench Compretion and Block Size
#@CP =  ( 1, 1.3, 1.7, 2.3, 3.5, 11  ); 
#@CP =  ( 1.3,  1.7, 2.3, 3.5, 11  ); 
@CP =  ( 11  ); 
@BS = split / /, $BS;
foreach $BS (@BS) {
	foreach $CP (@CP) {
		StopMultipatd;
		UnmStrVol;
		DelStrVol;
		CleanHosts;
		DelPool;
		CreatePool;
		CrVolMap;
		#&RescanMulti;
		RescanHosts;
		DiskList;
		print "START VD WRITE!!!\n";
		Write_Test;
		print "START VD READ!!!\n";	
		Read_Test;
        	CreateLogFile($BS,$CP);
		RunVdbWrite;
		RunVdbRead;
	}	
}
