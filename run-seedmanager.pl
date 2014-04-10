#!/usr/bin/perl

#    This file is part of IFMI PoolManager.
#
#    PoolManager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#

use warnings;
use strict;

require '/opt/ifmi/sm-common.pl';
require '/opt/ifmi/smnotify.pl';

my $conf = &getConfig;
my %conf = %{$conf};

use Proc::PID::File;
if (Proc::PID::File->running()) {
  # one at a time, please
  print "Another run-seedmanager is running.\n";
  exit(0);
}

# Start profile on boot

if ($conf{settings}{do_boot} == 1) {
  my $uptime = `cat /proc/uptime`;
  $uptime =~ /^(\d+)\.\d+\s+\d+\.\d+/;
  my $rigup = $1;
  if (($rigup < 300)) {
#    my $xcheck = `ps -eo command | grep -cE ^/usr/bin/X`;
    my $mcheck = `ps -eo command | grep -cE [P]M-miner`;
    if ($xcheck == 1 && $mcheck == 0) {
      &startCGMiner;
   }
  } 
}

#  broadcast node status
if ($conf{farmview}{do_bcast_status} == 1) { 
 &bcastStatus;
}

# Email 
if ($conf{monitoring}{do_email} == 1) { 
  if (-f "/tmp/smnotify.lastsent") {
    if (time - (stat ('/tmp/smnotify.lastsent'))[9] > ($conf{email}{smtp_min_wait} -10)) {
      &doEmail;
    }
  } else { &doEmail; }
}

# Graphs should be no older than 5 minutes
my $graph = "/var/www/IFMI/graphs/smsummary.png";
if (-f $graph) {
  if (time - (stat ($graph))[9] > 290) { 
    exec('/opt/ifmi/smgraph.pl'); 
  }
} else { 
  exec('/opt/ifmi/smgraph.pl'); 
}


