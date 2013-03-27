#!/usr/bin/perl
##
# Adam Hock
# May 4, 2006
# check_ac.pl
# ahock@ittc.ku.edu
#############
use Net::SNMP;
use Getopt::Std;
use lib "/usr/lib/nagios/plugins/";
use utils qw(%ERRORS &print_revision &support &usage);

no strict;

my %options = ();
getopt("VhrHwc",\%options);

my %data = ();

if ($options{V}) {
  print_revision($PROGNAME, '$Revision: 1.0 $');
  exit  $ERRORS{'OK'};
}

if ($options{h}) {
  print_help();
  exit $ERRORS{'OK'};
}

sub print_usage () {
  print "Usage: $0 -w <Tw,Hw> -c <Tc,Hc> -r <read_community> -H <host_ip>\n";
  print "	[-w <Temperature,Humidity>]\n";
  print "	[-c <Temperature,HUmidity>]\n";
  print "	[-r <read_community>]\n";
  print "	[-H <ip>]\n";
}

sub print_help () {
  print_revision($PROGNAME, '$Revision: 1.0 $');
  print "\n";
  print "This plugin reports temp on Liebert AC's \n";
  print "by Liebert Inc. \n";
  print "\n";
  print_usage();
  print "\n";
  print "Example: $0 -w 95 -c 90 -r read -H 172.27.120.1\n";
  print "\n";
}

#Get community for SNMP or Set read
if ( $options{r} ) {
  $SNMP_COMMUNITY = $options{r};

}else {
  $SNMP_COMMUNITY = "read";
} 

#Get host information (ip address)
if ( ! $options{H} ) {
  print_usage();
  exit $ERRORS{'OK'};
}else {
  $SNMP_TARGET = $options{H};
}

#Ranges Warning levels
if ( ! $options{w} ) {
  print_usage();
  exit $ERRORS{'OK'};
}else {
 #Warning 
  @warning = split(/,/,$options{w});
  $warningTemp = $warning[0];
  $warningHum = $warning[1];
}

#Ranges Critical levels
if ( ! $options{c} ) {
  print_usage();
  exit $ERRORS{'OK'};
}else {
 #Critical
  @critical = split(/,/,$options{c});
  $criticalTemp = $critical[0];
  $criticalHum = $critical[1];
}

#known oid's
%oid = (
     'acSetPointTemp'	=> '1.3.6.1.4.1.476.1.42.3.4.1.2.1.0',
     'acSetPointHum'    => '1.3.6.1.4.1.476.1.42.3.4.2.2.1.0',
     'acTemp'	=> '1.3.6.1.4.1.476.1.42.3.4.1.2.3.1.3.1',
     'acHum'	=> '1.3.6.1.4.1.476.1.42.3.4.2.2.3.1.3.1',

    );

######
#MAIN#
######

$ENV{'MIBS'}="ALL";  #Load all available MIBs
#Collect the data using Net::SNMP for perl
($session,$error) = Net::SNMP->session (-hostname => $SNMP_TARGET, 
                                        -community => $SNMP_COMMUNITY,
                                        -version => "2c");
die "session error: $error" unless ($session);


foreach $elem (keys %oid) {
  $response=$session->get_request($oid{$elem});
  die "request error: ".$session->error unless (defined $response). "\n";
  $data{$elem} = $response->{$oid{$elem}};
}

print Dumper(%data);

#Set up some boundries
$wT = $data{acSetPointTemp} + $warningTemp;
$cT = $data{acSetPointTemp} + $criticalTemp;

$wH = $data{acSetPointHum} + $warningHum;
$cH = $data{acSetPointHum} + $criticalHum;

#Check Tempurature Status
if($data{acTemp} >= $wT && $data{acTemp} < $cT) {
  print "WARNING: [Temp: $data{acTemp} F]\n";
  exit $ERRORS{'WARNING'};
}

if($data{acTemp} >= $cT) {
  print "CRITICAL: [Temp: $data{acTemp} F]\n";
  exit $ERRORS{'CRITICAL'};
}

#Check Humidity Status
if($data{acHum} >= $wH && $data{acHum} < $cH) {
 print "WARNING: [Humidity: $data{acHum}%]\n";
 exit $ERRORS{'WARNING'};
}

if($data{acHum} >= $cH) {
 print "CRITICAL: [Humidity: $data{acHum}%]\n";
 exit $ERRORS{'CRITICAL'};
} 

#If everything is OK
if($data{acTemp} < $wT && $data{acHum} < $wH) {
  print "OK: [Tempurature and Humidity: $data{acTemp}F $data{acHum}%]\n";
  exit $ERRORS{'OK'};
} 
