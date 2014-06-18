#!/usr/bin/perl -w

#use strict;
#use Data::Dumper;

# My variables and commands
my($DEBUG)	= "0";
my($inuse)	= `/usr/adic/TSM/bin/fsstate |grep "IN USE"|grep libraryb|wc -l`;
my($free)	= `/usr/adic/TSM/bin/fsstate |grep "FREE"|grep libraryb|wc -l`;
my($delayed)	= `/usr/adic/TSM/bin/fsstate |grep "DELAYED"|grep libraryb|wc -l`;
my($masterFile) = '/usr/adic/install/.active_snfs_server';
my($isMaster)   = "";

# Xymon Variables
$ENV{BBPROG}	= "library_b.pl";
my($TESTNAME)   = "libraryb";
my($BBHOME)	= $ENV{BBHOME};
my($BB)		= $ENV{BB};
my($BBDISP)	= $ENV{BBDISP};
my($BBVAR)	= $ENV{BBVAR};
my($MACHINE)    = $ENV{MACHINE};
my($DATE)	= localtime;
my($COLOR)	= "clear";
my($MSG)	= "";
my($HEAD)	= "";
my($DATA)	= "";

# Invoke debug routine if flag is set above
if ($DEBUG == 1){
   $BBHOME	|= "/tmp";
   $BB    	 = "/bin/echo";
   $BBDISP	|= "127.0.0.1";
   $BBVAR	|= "/tmp";
   $MACHINE	|= "test.host.cvf";
}

# Fsstate Processes - sanity check
my($FSCMD)	= `/bin/ps -ef |grep fsstate |grep -v grep |wc -l`;

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
   my($ACTIVE) 	= "$inuse";
   my($OPEN) 	= "$free";
   my($WAIT) 	= "$delayed";
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
