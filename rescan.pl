#!/usr/bin/perl

###############################################################################
#                                                                             #
# This script scan for Fiber LUNs without restarting Linux                    #
# The input parameters are :  None                                            #
#                                                                             #
#  Author       : Avi Liani                                                   #
#  Created Date : 30.10.2012                                                  #
#  Version      : 1.0 1                                                       #
#                                                                             #
#  Change Log :                                                               #
#                                                                             #
#  Date        Name             Change                                        #
#  ==========  ===============  ============================================  #
#  30.10.2012  Avi Liani        Initial version                               #
#  10.01.2013  Avi Liani        run the scan twice                            #
#                                                                             #
###############################################################################

sub  Rescan() {
	opendir(NS, "/sys/class/scsi_host");
	@ns=readdir(NS);
	closedir(NS);
	shift @ns;
	shift @ns;
	
	foreach $ns(@ns) {
		open(DAT,">/sys/class/scsi_host/$ns/scan") || die("Cannot Open File");
		print DAT "- - -";
		close(DAT);
		sleep 1 ;
	}
}

for (1..2) { Rescan() ; sleep 5 ; }
my $res = `multipath -r | grep size | wc -l`  ;
chomp $res ;
print $res ;

exit $res ;
