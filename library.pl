#!/usr/bin/perl -w
#
#
##############################################################################################
#                                                                                            #
# Program:              library.pl                                                           #
# Author:               Jerald Sheets                                                        #
# Initial Version:      0.98                                                                 #
# Changelog:            01/04/10        Initial Release                                      #
#                                                                                            #
############################################################################################## 
#                                                                                            #
# Purpose:  This perl script is meant to run on a pair of StorNext MDC servers.  It          #
#           does a couple things.  First, it checks how many fsstate prcesses are            #
#           running, and sets the status to yellow for 3 or 4 and red for 5 or more.         #
#           Generally speaking, if you have this many fsstate processes running, it          #
#           could be that Stornext is hung, and you need to have a look.  Next, it           #
#           runs fsstate and looks for how many drives are in one of three specific          #
#           states (IN USE, FREE, or DELAYED) and counts those up.  Then, it outputs         #
#           The amount in NCV format for use in Xymon.  Finally, by setting up the           #
#           Xymon server to do so, it will graph the number of tapes in a particular         #
#           state and provide averages over time.                                            #
#                                                                                            #
##############################################################################################
#                                                                                            #
# Deployment:  Take the library.pl script, and place it into $HOBBITCLIENTHOME/ext           #
#              In the $HOBBITCLIENTHOME/etc/clientlaunch.cfg place the following at          #
#              the end of the file:                                                          #
#                                                                                            #
#                  # MDC Fsstate Data Collector.  This is a test module to report            #
#                  # the current state of the libraries and the fsstate command.             #
#                  [fsstate]                                                                 #
#                       ENVFILE $HOBBITCLIENTHOME/etc/hobbitclient.cfg                       #
#                       CMD $HOBBITCLIENTHOME/ext/library.pl                                 #
#                       LOGFILE $HOBBITCLIENTHOME/logs/library.log                           #
#                       INTERVAL 3m                                                          #
#                                                                                            #
#              Once you have done this, do the following on your Xymon Server:               #
#                                                                                            #
#              At the end of your $HOBBITSERVERHOME/etc/hobbitserver.cfg file,               #
#              add the following at the end of your "TEST2RRD" line:                         #
#                                                                                            #
#                   library=ncv                                                              #
#                                                                                            #
#              Next, add the following lines immediately below the "TEST2RRD"                #
#              line.                                                                         #
#                                                                                            #
#                   # This defines the custom graphs specified in the above TEST2RRD section #
#                   NCV_library="Active:GAUGE,Free:GAUGE,Delayed:GAUGE"                      #
#                                                                                            #
#              In the "GRAPHS" line in the same file, place "library" at the end             #
#              of the other entries.                                                         #
#                                                                                            #
#              Finally, define the graphs for these values in the Xymon graphs               #
#              configuration $HOBBITSERVERHOME/etc/hobbitgraph.cfg  like so:                 #
#                                                                                            #
#                   # MDC Controller Drive Status Graphs                                     #
#                   [library]                                                                #
#                       TITLE Library Drive Utilization                                      #
#                       YAXIS Number of Drives                                               #
#                       DEF:active=library.rrd:Active:AVERAGE                                #
#                       DEF:free=library.rrd:Free:AVERAGE                                    #
#                       DEF:delayed=library.rrd:Delayed:AVERAGE                              #
#                       LINE2:active#00CCCC:Active Drives                                    #
#                       LINE2:free#09801D:Free Drives                                        #
#                       LINE2:delayed#FF0000:Delayed Drives                                  #
#                       COMMENT:\n                                                           #
#                       GPRINT:active:LAST:Active Drives \: %5.1lf%s (cur)                   #
#                       GPRINT:active:MAX: \: %5.1lf%s (max)                                 #
#                       GPRINT:active:MIN: \: %5.1lf%s (min)                                 #
#                       GPRINT:active:AVERAGE: \: %5.1lf%s (avg)\n                           #
#                       GPRINT:free:LAST:Free Drives \: %5.1lf%s (cur)                       #
#                       GPRINT:free:MAX: \: %5.1lf%s (max)                                   #
#                       GPRINT:free:MIN: \: %5.1lf%s (min)                                   #
#                       GPRINT:free:AVERAGE: \: %5.1lf%s (avg)\n                             #
#                       GPRINT:delayed:LAST:Delayed Drives \: %5.1lf%s (cur)                 #
#                       GPRINT:delayed:MAX: \: %5.1lf%s (max)                                #
#                       GPRINT:delayed:MIN: \: %5.1lf%s (min)                                #
#                       GPRINT:delayed:AVERAGE: \: %5.1lf%s (avg)\n                          #
#                                                                                            #
#              If all goes well, you will get a library column on your MDC servers.  It      #
#              will display the Active, Free, and Delayed tape drives and will graph each    #
#              one.                                                                          #
#                                                                                            #
##############################################################################################

use strict;

# My variables and commands
my($DEBUG)      = "0";
my($inuse)      = `/usr/adic/TSM/bin/fsstate |grep "IN USE"|wc -l`;
my($free)       = `/usr/adic/TSM/bin/fsstate |grep "FREE"|wc -l`;
my($delayed)    = `/usr/adic/TSM/bin/fsstate |grep "DELAYED"|wc -l`;
my($masterFile) = '/usr/adic/install/.active_snfs_server';
my($isMaster)   = "";

# Xymon Variables
$ENV{BBPROG}    = "library.pl";
my($TESTNAME)   = "library";
my($BBHOME)     = $ENV{BBHOME};
my($BB)         = $ENV{BB};
my($BBDISP)     = $ENV{BBDISP};
my($BBVAR)      = $ENV{BBVAR};
my($MACHINE)    = $ENV{MACHINE};
my($DATE)       = localtime;
my($COLOR)      = "clear";
my($MSG)        = "";
my($HEAD)       = "";
my($DATA)       = "";

# Invoke debug routine if flag is set above
if ($DEBUG == 1){
   $BBHOME      |= "/tmp";
   $BB           = "/bin/echo";
   $BBDISP      |= "127.0.0.1";
   $BBVAR       |= "/tmp";
   $MACHINE     |= "test.host.cvf";
}

# Fsstate Processes - sanity check
my($FSCMD)      = `/bin/ps -ef |grep fsstate |grep -v grep |wc -l`;

if($FSCMD > 5){
   $HEAD = "MDC Fsstate Critical.\n";
   $MSG = "More than 5 fsstate processes detected.  MDC possibly hung.\n";
      sendRed();
      sendReport();
}elsif(($FSCMD == 3) || ($FSCMD == 4)){
   $HEAD = "MDC Fsstate Cautionary.\n";
   $MSG = "Fsstate instances rising.  Now 3 or 4 are active.\n";
      sendYellow();
      sendReport();
}


# Figure out if you're the master server or not
isMaster();

# If you are the master server, set the variable.  If not, update Xymon that "all is clear"
if($isMaster eq "yes"){
   getStats();
}else{
   # If you're here, you're not the master.  Set "clear" as the variable, and then send it on to the server, exiting normally.
   sendClear();
   sendReport();
   exit 0;
}


#################
## Subroutines ##
#################

# Determines if system is the master MDC Controller
sub isMaster {
   if(-e $masterFile){
      $isMaster = "yes";
   }else{
      $isMaster = "no";
   }
}

# Parses the output of "fsstate" and presents it to Xymon as appropriate values in NCV format
sub getStats {
   my($ACTIVE)  = "$inuse";
   my($OPEN)    = "$free";
   my($WAIT)    = "$delayed";
      head("Fsstate OK");
      msg("&green MDC Fsstate Normal");
      $DATA = "
      Active:$ACTIVE
      Free:$OPEN
      Delayed:$WAIT
              ";
   sendGreen();
   sendReport();
}

# In the event this is not the master server, this empties the variables and sends a "clear" to 
# the server for this host, preventing purple (no data) being sent to the server for this host. 
# All other statuses here simply set the color when called.
sub sendClear {
   $MSG = $DATA = $HEAD = '';
   $COLOR = 'clear';
}

sub sendRed {
   $COLOR = 'red';
}

sub sendYellow {
   $COLOR = 'yellow';
}

sub sendGreen {
   $COLOR = 'green';
}

# This runs the local bb instance and sends the report with all the values necessary to set 
# the Xymon server in the appropriate status
sub sendReport {
   $MACHINE =~ s/\./,/g;
      my($cmd) = "$BB $BBDISP \"status $MACHINE.$TESTNAME $COLOR $DATE $HEAD\n$DATA\n$MSG\"";
      system($cmd);
}

# Format the header 
sub head
{
    $HEAD = "@_";
}


# Clean up messaging a bit
sub msg
{
    $MSG .= join("\n", @_) . "\n";
}
