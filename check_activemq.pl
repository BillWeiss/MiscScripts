#!/usr/bin/perl

# Check_ActiveMQ
# Original author:
# © 2012 -- Sig-I/O Automatisering -- mark@sig-io.nl
#
# I'm forking this thing to make it substantially less strange.
# The original author had some hardcoded values and a cron implementation,
# which I don't think we need to just check a queue.  I'm adding some
# command-line arguments for everything we need.
# -- Bill Weiss <bill@backstopsolutions.com>

use XML::Simple;
use Getopt::Std;
use strict;

my $verbose = 0;
my $warnlimit = 5;
my $criticallimit = 10;
my $targetqueue;
my $store;
my $memory;
my $temp;
my $url;
my $queue;
my $data;
my %options = ();
getopts("w:c:u:q:vh", \%options);

## trivial option parsing
if ($options{v}) {
  $verbose++;
}

if ($options{w}) {
  $warnlimit = $options{w};
}

if ($options{c}) {
  $criticallimit = $options{c};
}

if ($options{u}) {
  $url = $options{u};
} else {
  print "UNKNOWN: Must pass in a url (-u)\n";
  exit 3;
}

if ($options{q}) {
  $targetqueue = $options{q};
} else {
  print "UNKNOWN: Must pass in a queue to monitor (-q)\n";
  exit 3;
}
## end trivial option parsing

my $dump = qx|/usr/bin/curl -s $url|;
my $xmldata = XMLin($dump);

while ( ($queue, $data) = each(%{$xmldata->{queue}}) ) {
  next if $queue ne $targetqueue;

  my $numinqueue = $data->{stats}->{size};

  if ($numinqueue >= $criticallimit ) {
    print "CRITICAL: ${numinqueue} items in queue ${targetqueue}!\n";
    exit 2;
  } elsif ($numinqueue >= $warnlimit) {
    print "WARNING: ${numinqueue} items in queue ${targetqueue}!\n";
    exit 1;
  } else {
    print "OK: ${numinqueue} items in queue ${targetqueue}\n";
    exit 0;
  }
}

## if we've gotten here, it means we haven't seen the queue.  Dang.
print "UNKNOWN: Queue ${targetqueue} not found in ${url}\n";
exit 3;
