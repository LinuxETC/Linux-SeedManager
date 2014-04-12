#!/usr/bin/perl
#    This file is part of IFMI SeedManager.
#
#    SeecManager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#

use warnings;
use strict;
use RRDs;
use IO::Socket::INET;
use YAML qw( LoadFile );

my $login = (getpwuid $>);
die "must run as root" if ($login ne 'root');

require '/opt/ifmi/sm-common.pl';

my $conf = &getConfig;
my %conf = %{$conf};
my $PICPATH = "/var/www/IFMI/graphs/";
my $DBPATH = "/opt/ifmi/rrdtool/";
my $ERR = RRDs::error;

my $colorfile = "/var/www/IFMI/themes/" . ${$conf}{display}{'graphcolors'}; 
my $gconf = LoadFile($colorfile) if (-f $colorfile);
my $hashcolor = "#0033FF";
$hashcolor = $gconf->{hashcolor} if (defined ($gconf->{hashcolor}));
my $wucolor = "#4876FFcc"; 
$wucolor = $gconf->{wucolor} if (defined ($gconf->{wucolor}));
my $acccolor = "#32CD32cc";
$acccolor = $gconf->{acccolor} if (defined ($gconf->{acccolor}));
my $rejcolor = "#EEEE00";
$rejcolor = $gconf->{rejcolor} if (defined ($gconf->{rejcolor}));
my $stfcolor = "#777777cc";
$stfcolor = $gconf->{stfcolor} if (defined ($gconf->{stfcolor})); 
my $fontcolor = "#000000";
$fontcolor = $gconf->{fontcolor} if (defined ($gconf->{fontcolor}));
my $errorcolor = "#FF0000cc";
$errorcolor = $gconf->{errorcolor} if (defined ($gconf->{errorcolor})); 
my $fontfam = "Helvetica";
$fontfam = $gconf->{fontfam} if (defined ($gconf->{fontfam}));

#ASCs 
my $ispriv = &CGMinerIsPriv; 
if ($ispriv eq "S") {

  my $asccount = &getCGMinerASCCount;
  for (my $i=0;$i<$asccount;$i++)
  {
    my $gnum = $i; 
    my $GDB = $DBPATH . "asc" . $gnum . ".rrd";
    if (! -f $GDB) { 
      RRDs::create($GDB, "--step=300", 
      "DS:hash:GAUGE:600:U:U",
      "DS:shacc:DERIVE:600:0:U",
      "DS:hwe:COUNTER:600:U:U",
      "RRA:LAST:0.5:1:288", 
      );
      die "graph failed: $ERR\n" if $ERR;
    }

    my $ghash = "0"; my $ghwe = "0"; my $gshacc = "0"; 
    my $res = &sendAPIcommand("asc",$i);
    if ($res =~ m/MHS\sav=(\d+\.\d+),/) {
    	$ghash = $1 * 1000;
    }
    if ($res =~ m/Accepted=(\d+),/) {
    	$gshacc = $1;
    }
    if ($res =~ m/Hardware\sErrors=(\d+),/) {
    	$ghwe = $1;
    }

  RRDs::update($GDB, "--template=hash:shacc:hwe", "N:$ghash:$gshacc:$ghwe");
  die "graph failed: $ERR\n" if $ERR;

  RRDs::graph("-P", $PICPATH . "asc$gnum.png",
   "--title","24 Hour Summary",
   "--vertical-label","Hashrate K/hs",
   "--right-axis-label","Shares Acc. x10",
   "--right-axis",".1:0",
   "--start","now-1d",
   "--end", "now",
   "--width","700","--height","200",
   "--color","BACK#00000000",
   "--color","CANVAS#00000000",
   "--color","FONT$fontcolor",
   "--border","1", 
   "--font","DEFAULT:0:$fontfam",
   "--font","WATERMARK:4:$fontfam",
   "--slope-mode", "--interlaced",
   "DEF:gdhash=$GDB:hash:LAST",
   "DEF:gdshacc=$GDB:shacc:LAST",
   "DEF:gdhwe=$GDB:hwe:LAST",
   "CDEF:gcshacc=gdshacc,60,*",
   "VDEF:gvshacc=gcshacc,AVERAGE",
   "CDEF:gccshacc=gdshacc,6000,*",
   "COMMENT:<span font_desc='10'>ASC $gnum</span>",
   "TEXTALIGN:left",
   "AREA:gdhash$hashcolor: Hashrate",
   "AREA:gccshacc$acccolor: Shares Accepted / Min",
   "GPRINT:gvshacc:%2.2lf",
   "COMMENT:                 ",
   "TICK:gdhwe$errorcolor:-0.1: HW error",
   );
  die "graph failed: $ERR\n" if $ERR;
  }
}

# Summary

my $SDB = $DBPATH . "ssummary.rrd";
if (! -f $SDB){ 
  RRDs::create($SDB, "--step=300", 
  "DS:mhash:GAUGE:600:U:U",
  "DS:mwu:GAUGE:600:U:U",
  "DS:mshacc:DERIVE:600:0:U",
  "DS:mshrej:DERIVE:600:0:U",
  "DS:mfb:COUNTER:600:U:U",
  "DS:mhwe:COUNTER:600:U:U",
  "RRA:LAST:0.5:1:288", 
  );
  die "graph failed: $ERR\n" if $ERR;
} 

my $sumres = &sendAPIcommand("summary","");

my $mhashav = "0";my $mfoundbl = "0";my $maccept = "0";my $mreject = "0";my $mhwerrors = "0";my $mworkutil = "0";
if ($sumres =~ m/MHS\sav=(\d+\.\d+),/g) {
  $mhashav = $1 * 1000;
}
if ($sumres =~ m/Found\sBlocks=(\d+),/g) {
  $mfoundbl =$1;
}
if ($sumres =~ m/Accepted=(\d+),/g) {
  $maccept = $1;
}
if ($sumres =~ m/Rejected=(\d+),/g) {
  $mreject = $1;
}
if ($sumres =~ m/Hardware\sErrors=(\d+),/g) {
  $mhwerrors = $1;
}
if ($sumres =~ m/Work\sUtility=(\d+\.\d+),/g) {
  $mworkutil = $1;
}
RRDs::update($SDB, "--template=mhash:mwu:mshacc:mshrej:mfb:mhwe", "N:$mhashav:$mworkutil:$maccept:$mreject:$mfoundbl:$mhwerrors");
die "graph failed: $ERR\n" if $ERR;

my $mname = `hostname`;
chomp $mname;
RRDs::graph($PICPATH . "smsummary.png",
 "--title","24 Hour Summary for $mname",
 "--vertical-label","Hashrate / WU",
 "--right-axis-label","Shares Acc / Rej",
 "--right-axis",".01:0",
 "--start","now-1d",
 "--end","now",
 "--width","700","--height","150",
 "--color","BACK#00000000",
 "--color","CANVAS#00000000",
 "--color","FONT$fontcolor", 
 "--border","0",
 "--font","DEFAULT:0:$fontfam",
 "--font","WATERMARK:.1:$fontfam",
 "--slope-mode", "--interlaced",
 "DEF:mdhash=$SDB:mhash:LAST",
 "DEF:mdwu=$SDB:mwu:LAST",
 "DEF:mdshacc=$SDB:mshacc:LAST",
 "DEF:mdshrej=$SDB:mshrej:LAST",
 "DEF:mdhwe=$SDB:mhwe:LAST",
 "DEF:mdfb=$SDB:mfb:LAST",
 "CDEF:mchash=mdhash",
 "VDEF:mvhash=mchash,LAST",
 "CDEF:mcwu=mdwu",
 "VDEF:mvwu=mcwu,LAST",
 "CDEF:mcshacc=mdshacc,6000,*",
 "CDEF:mccshacc=mdshacc,60,*",
 "VDEF:mvshacc=mccshacc,AVERAGE",
 "CDEF:mcshrej=mdshrej,60,*",
 "CDEF:mccshrej=mdshrej,6000,*",
 "VDEF:mvshrej=mcshrej,AVERAGE",
 "VDEF:mvfb=mdfb,LAST",
 "TEXTALIGN:left",
 "AREA:mchash$hashcolor: Hashrate",
 "AREA:mcwu$wucolor: WU",
 "TICK:mdfb$stfcolor:-0.1: Found Block",
 "TICK:mdhwe$errorcolor:-0.1: HW Error",
 "AREA:mcshacc$acccolor: Avg. Shares Acc. / Min",
 "GPRINT:mvshacc:%2.2lf  ",
 "AREA:mccshrej$rejcolor: Avg. Shares Rej. / Min",
 "GPRINT:mvshrej:%2.2lf  ",
 );
die "graph failed: $ERR\n" if $ERR;

# Pools

my $pres = &sendAPIcommand("pools","");
my $poid; my $pdata; 
while ($pres =~ m/POOL=(\d+),(.+?)\|/g) {
  $poid = $1; $pdata = $2; 
  my $PDB = $DBPATH . "spool$poid.rrd";
  if (! -f $PDB){ 
    RRDs::create($PDB, "--step=300", 
    "DS:plive:GAUGE:600:0:1",
    "DS:pshacc:DERIVE:600:0:U",
    "DS:pshrej:DERIVE:600:0:U",
    "DS:pstale:DERIVE:600:0:U",
    "DS:prfail:COUNTER:600:0:U",
    "RRA:LAST:0.5:1:288", 
    );
    die "graph failed: $ERR\n" if $ERR;
  } 
  my $pstat = "0"; my $plive = "0"; my $pacc = "0"; my $prej = "0"; my $pstale = "0"; my $prfails = "0";
  if ($pdata =~ m/Status=(.+?),/) {
    $pstat = $1; $plive = 0; 
    if ($pstat eq "Alive") {
      $plive = 1;
    }
  }
  if ($pdata =~ m/Accepted=(\d+),/) {
    $pacc = $1; 
  }
  if ($pdata =~ m/Rejected=(\d+),/) {
    $prej = $1; 
  }        
  if ($pdata =~ m/Stale=(\d+),/) {
    $pstale = $1; 
  }   
  if ($pdata =~ m/Remote Failures=(\d+),/) {
    $prfails = $1; 
  }  
  RRDs::update($PDB, "--template=plive:pshacc:pshrej:pstale:prfail", "N:$plive:$pacc:$prej:$pstale:$prfails");
  die "graph failed: $ERR\n" if $ERR;

  RRDs::graph("-P", $PICPATH . "spool$poid.png",
   "--title","24 Hour Summary",
   "--vertical-label","Shares Acc / Rej",
   "--start","now-1d",
   "--end", "now",
   "--width","700","--height","200",
   "--color","BACK#00000000",
   "--color","CANVAS#00000000",
   "--color","FONT$fontcolor",
   "--border","1",
   "--font","DEFAULT:0:$fontfam",
   "--font","WATERMARK:4:$fontfam",
   "--slope-mode", "--interlaced",
   "DEF:pdlive=$PDB:plive:LAST",
   "DEF:pdshacc=$PDB:pshacc:LAST",
   "DEF:pdshrej=$PDB:pshrej:LAST",
   "DEF:pdstale=$PDB:pstale:LAST",
   "DEF:pdrfail=$PDB:prfail:LAST",
   "CDEF:pcshacc=pdshacc,60,*",
   "VDEF:pvshacc=pcshacc,AVERAGE",
   "CDEF:pcshrej=pdshrej,60,*",
   "VDEF:pvshrej=pcshrej,AVERAGE",
   "CDEF:pcstale=pdstale,60,*",
   "VDEF:pvstale=pcstale,AVERAGE",
   "TEXTALIGN:left",
   "COMMENT:<span font_desc='10'>Pool $poid</span>",
   "AREA:pcshacc$acccolor: Shares Accepted / Min",
   "GPRINT:pvshacc:%2.2lf  ",
   "AREA:pcstale$stfcolor: Stales / Min",
   "GPRINT:pvstale:%2.2lf  ",
   "AREA:pcshrej$rejcolor: Shares Rejected / Min",
   "GPRINT:pvshrej:%2.2lf  ",
   "TICK:pdrfail$errorcolor:-0.1: Remote Failure",
   );
  die "graph failed: $ERR\n" if $ERR;
}


