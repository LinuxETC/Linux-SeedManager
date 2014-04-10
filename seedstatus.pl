#!/usr/bin/perl
#    This file is part of IFMI SeedManager.
#
#    SeedManager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#

use warnings;
use strict;
use CGI qw(:cgi-lib :standard);
use feature qw(switch);
use YAML qw( DumpFile );

require '/opt/ifmi/sm-common.pl';
my $conf = &getConfig;
my %conf = %{$conf};
my $conffile = "/opt/ifmi/seedmanager.conf";

# Take care of business
&ReadParse(our %in);

my $zreq = $in{'zero'};
if (defined $zreq) {
  &zeroStats;
  $zreq = "";
}

my $preq = $in{'swpool'};
if (defined $preq) {
  &switchPool($preq);
  $preq = "";
}

my $apooln = $in{'npoolurl'};
my $apoolu = $in{'npooluser'};
my $apoolp = $in{'npoolpw'};
if (defined $apooln) {
  my $pmatch = 0;
  my @pools = &getCGMinerPools(1);
  if (@pools) {
    for (my $i=0;$i<@pools;$i++) {
      my $pname = ${$pools[$i]}{'url'};
      $pmatch++ if ($pname eq $apooln);
    }
  }
  if ($pmatch eq 0) {
    &addPool($apooln, $apoolu, $apoolp);
    &saveConfig();
    $apooln = ""; $apoolu = ""; $apoolp = "";
  } 
}
my $dpool = $in{'delpool'};
if (defined $dpool) {
  &delPool($dpool);
  &saveConfig();
  $dpool = "";
}

my $mstop = $in{'mstop'};
if (defined $mstop) { 
	&stopCGMiner();
  $mstop = ""; 
}

my $mstart = $in{'mstart'};
if (defined $mstart) { 
  `sudo /opt/ifmi/smcontrol start`;
  $mstart = ""; 
}
my $restart = $in{'startnm'};
if (defined $restart) {
	&stopCGMiner(); 
	my $snmc = $in{'startnm'};
	${$conf}{settings}{current_mconf} = $snmc;
	DumpFile($conffile, $conf); 
	$snmc = "";
	sleep 3;
	`sudo /opt/ifmi/smcontrol start`;
}

my $reboot = $in{'reboot'};
if (defined $reboot) { 
  `sudo /opt/ifmi/smcontrol boot`;
}  

my $qval = $in{'qval'};
if (defined $qval) {
  my $qpool = $in{'qpool'};
  &quotaPool($qpool, $qval);
  &saveConfig();
  $qval = ""; $qpool = "";
}

my $gdig = $in{'gdig'};
if (defined $gdig) {
 &setASCDisable($gdig);
 &saveConfig();
 $gdig = "";
}

my $geng = $in{'geng'};
if (defined $geng) {
 &setASCEnable($geng);
 &saveConfig();
 $geng = "";
}

my $npalias = $in{'npalias'};
if (defined $npalias) {
	my $paurl = $in{'paurl'};
	my $acount = 0;
 	for (keys %{$conf{pools}}) {
		if ($paurl eq ${$conf}{pools}{$_}{url}) {
			${$conf}{pools}{$_}{alias} = $npalias;
			$acount++;
		}
	}
	if ($acount == 0) {	
	 	my $newa = (keys %{$conf{pools}}); $newa++; 
	 	${$conf}{pools}{$newa}{alias} = $npalias;
	 	${$conf}{pools}{$newa}{url} = $paurl;
	}
	DumpFile($conffile, $conf); 
	$npalias = ""; $paurl = "";
}	

my $ncmc = $in{'setmconf'};
if (defined $ncmc) {
	${$conf}{settings}{current_mconf} = $ncmc;
	DumpFile($conffile, $conf); 
	$ncmc = "";
}

my $npn = $in{'pnotify'};
if (defined $npn) {
	my $poolnum = $in{'poolnum'};
	${$conf}{pools}{$poolnum}{pnotify} = $npn;
	DumpFile($conffile, $conf); 
	$npn = "";
}

my $prl = $in{'pnotifyl'};
if ((defined $prl) && ($prl ne "")) {
	my $poolnum = $in{'poolnum'};
	${$conf}{pools}{$poolnum}{pool_reject_hi} = $prl;
	DumpFile($conffile, $conf); 
	$prl = "";
}

# Now carry on

my $miner_name = `hostname`;
chomp $miner_name;
my $iptxt;
my $nicget = `/sbin/ifconfig`; 
  while ($nicget =~ m/(\w\w\w?\w?\d)\s.+\n\s+inet addr:(\d+\.\d+\.\d+\.\d+)\s/g) {
  $iptxt = $2; 
}

my $q=CGI->new();

my $showasc = -1;
my $showpool = -1;
my $showminer = -1;

if (defined($q->param('asc')))
{
	$showasc = $q->param('asc');
}
if (defined($q->param('pool')))
{
	$showpool = $q->param('pool');
}
if (defined($q->param('miner')))
{
	$showminer = 0;
}

my $url = "?";

if ($showasc > -1)
{
	$url .= "asc=$showasc&";
}
if ($showpool > -1)
{
	$url .= "pool=$showpool&";
}
if ($showminer > -1)
{
	$url .= "miner=$showminer&";
}

print header;
if ($url eq "?")
{
	print start_html( -title=>'SM - ' . $miner_name . ' - Status', 
		-style=>{-src=>'/IFMI/themes/' . $conf{display}{status_css}},  
		-head=>$q->meta({-http_equiv=>'REFRESH',-content=>'30'})  
		);
}
else
{
	$url .= "tok=1";
	print start_html( -title=>'SM - ' . $miner_name . ' - Status', 
		-style=>{-src=>'/IFMI/themes/' . $conf{display}{status_css}},  
		-head=>$q->meta({-http_equiv=>'REFRESH',-content=>'30; url=' . $url })  
	  );
}

# pull info
my $version = &getCGMinerVersion;
my $ispriv = &CGMinerIsPriv; 
my @ascs = &getFreshASCData(1);
my @pools = &getCGMinerPools(1);
my @summary = &getCGMinerSummary;
my @mconfig = &getCGMinerConfig; 
my $UHOH = "false";
$UHOH = "true" if (!(@pools) && !(@summary) && !(@ascs)); 

# do ASCs
my $aput; my $a1put; my $asput; my $agimg; 
my @nodemsg; my @ascmsg;
my $problems = 0;
my $okascs = 0;
my $problemascs = 0;

if (@ascs) {
	$a1put .= "<TABLE id='asccontent'><TR class='header'><TD class='header'>ASC</TD>";
	$a1put .= "<TD class='header'>Status</TD>";
	$a1put .= "<TD class='header'>Rate</TD>";
	$a1put .= "<TD class='header'>Pool</TD>";
	$a1put .= "<TD class='header' colspan=2>Accept/Reject</TD>";
	$a1put .= "<TD class='header'>I</TD>";
	$a1put .= "<TD class='header'>HW</TD></tr>";

	for (my $i=0;$i<@ascs;$i++) {
	  my $aput;

	  my $ghealth = $ascs[$i]{'status'}; 
	  if ($ghealth ne "Alive") {
			$problems++;
			push(@nodemsg, "ASC $i is $ghealth");
			if ($i == $showasc) {
				push(@ascmsg, "$ghealth");
				$asput .= "<tr><td>Status:</td><td class='error'>$ghealth</td>";
			}
		}	else {
			if ($i == $showasc) {
				$asput .= "<tr><td>Status:</td><td>$ghealth</td>";	
			}		
	 	}	

		if ($i == $showasc) {
			if ($ascs[$i]{'enabled'} eq "Y") {  	  
		    $asput .= "<td>Enabled</td>";
			  $asput .= "<td><form name='gdisable' method='POST'>";
			  $asput .= "<input type='hidden' name='gdig' value='$i'>";
			  $asput .= "<input type='submit' value='Disable'> ";
			} else { 
		    $asput .= "<td>Disabled</td>"; 
			  $asput .= "<td><form name='genable' method='POST'>";
			  $asput .= "<input type='hidden' name='geng' value='$i'>";
			  $asput .= "<input type='submit' value='Enable'> ";
			}
	    $asput .= "</form></td></tr>";
		}

		my $ghashrate = $ascs[$i]{'hashrate'}; 
		$ghashrate = $ascs[$i]{'hashavg'} if ($ghashrate eq "");
		$ghashrate = $ascs[$i]{'hashavg'} if ($conf{display}{usehashavg} >0); 
		if ($ghashrate < $conf{monitoring}{monitor_hash_lo})
		{
			$problems++;
			push(@nodemsg, "ASC $i is below minimum hash rate");
			if ($i == $showasc)
			{
				push(@ascmsg, "Below minimum hash rate");
			}	
			$aput .= "<td class='error'>";
		}
		else
		{
			$aput .= '<td>';
		}	
		$aput .= sprintf("%d", $ghashrate) . " Kh/s</TD>";

			my $shorturl;
	    my $poolurl = $ascs[$i]{'pool_url'};
	    if ((defined $poolurl) && ($poolurl =~ m/.+\@(.+)/)) {
	      $poolurl = $1;
	    }	
	    if ((defined $poolurl) && ($poolurl =~ m|://(\w+-?\w+\.)?(\w+-?\w+\.\w+:\d+)|)) {
	       $shorturl = $2;
	    }
	 	$shorturl = "N/A" if (! defined $shorturl); 
	    if ($i == $showasc) {
	        $asput .= "<tr><td>Pool:</td><td colspan=3>" . $poolurl  . "</td>";
	    }
		$aput .= "<td>" . $shorturl . "</td>";


		my $gsha = $ascs[$i]{'shares_accepted'}; $gsha = 0 if ($gsha eq "");
		my $gshi = $ascs[$i]{'shares_invalid'}; $gshi = 0 if ($gshi eq "");
		$aput .= '<TD>' . $gsha . " / " . $gshi . '</TD>';		
		if ($gsha > 0)
		{
			my $rr = $ascs[$i]{'shares_invalid'}/($ascs[$i]{'shares_accepted'} + $ascs[$i]{'shares_invalid'})*100 ;		
			if ($rr > ${$conf}{monitoring}{monitor_reject_hi})
			{
				$problems++;
				push(@nodemsg, "ASC $i is above maximum reject rate");
				if ($i == $showasc)
				{
					push(@ascmsg, "Above maximum reject rate");
			        $asput .= "<tr><td>Total MH:</td><td>" . $ascs[$i]{'total_mh'} . "</td>";
					$asput .= "<td>Shares A/R:</td><td class='error'>" .  $ascs[$i]{'shares_accepted'} . ' / ' . $ascs[$i]{'shares_invalid'} . ' (' . sprintf("%-2.2f%", $rr) . ")</td></tr>";
				}			
				$aput .= "<td class='error'>";
			}
			else
			{
				if ($i == $showasc)
				{
			    $asput .= "<tr><td>Total MH:</td><td>" . $ascs[$i]{'total_mh'} . "</td>";
					$asput .= "<td>Shares A/R:</td><td>" .  $ascs[$i]{'shares_accepted'} . ' / ' . $ascs[$i]{'shares_invalid'} . ' (' . sprintf("%2.2f%%", $rr) . ")</td></tr>";
				}			
				$aput .= '<td>';
			}		
			$aput .= sprintf("%2.2f%%", $rr);
		}
		else
		{
			if ($i == $showasc)
			{
					$asput .= "<tr><td>Shares A/R:</td><td>" .  $ascs[$i]{'shares_accepted'} . ' / ' . $ascs[$i]{'shares_invalid'} . "</td></tr>";
			}
			
			$aput .= '<td>N/A';
		}	
		$aput .= "</TD>";
		
		my $aschwe;
	  my $ghwe = $ascs[$i]{'hardware_errors'};	
		if ($ghwe > ${$conf}{monitoring}{monitor_hardware_hi}) { 
		  $problems++;
		  push(@nodemsg, "ASC $i has hardware errors");
		  if ($i == $showasc) {
			push(@ascmsg, "Hardware errors");
		  }
		  $aschwe = "<td class='error'>" . $ghwe . "</td>";
		} else { 
		  $ghwe = "N/A" if ($ghwe eq ""); 
		  $aschwe = "<td>" . $ghwe . "</td>";
		}
	    $aput .= $aschwe;
		
		$aput .= "</TR>";


		if ($i == $showasc)
		{
	    push(@ascmsg, "ASC $i has Hardware Errors") if ($ghwe > ${$conf}{monitoring}{monitor_hardware_hi});		
			$asput .= "<td>HW Errors:</td>" . $aschwe . "</tr>"; 
			$agimg = "<br><img src='/IFMI/graphs/asc$i.png'>";
		}
			
		my $ascurl = "?";	

		$ascurl .= "asc=$i";
		
		if ($problems)
		{
			$aput = '<TR><TD class="bigger"><A href="' . $ascurl . '">' . $i . '</TD><TD class=error><img src=/IFMI/error24.png></td>' . $aput;
			$problemascs++;
		}
		else
		{
			$aput = '<TR><TD class="bigger"><A href="' . $ascurl . '">' . $i . '</TD><TD><img src=/IFMI/ok24.png></td>' . $aput;
			$okascs++;
		}
		$a1put .= $aput;
		$problems = 0;
	}
	$a1put .= "</table>";
}

my $mstrategy; my $mfonly; my $mscant; my $mqueue; my $mexpiry; 
if (@mconfig) {
	for (my $i=0;$i<@mconfig;$i++) {
		$mstrategy = ${$mconfig[0]}{'strategy'};
		$mfonly = ${$mconfig[0]}{'fonly'};
		$mscant = ${$mconfig[0]}{'scantime'};
		$mqueue = ${$mconfig[0]}{'queue'};
		$mexpiry = ${$mconfig[0]}{'expiry'};
	}
}

my $mcontrol;
$mcontrol .= "<table id='mcontrol'><tr>";
my $surl = "?"; $surl .= 'miner=$i';
$mcontrol .= '<TD class="bigger"><A href="' . $surl . '">Miner</a></td>';
my $mname; my $mvers; my $avers; 
if ($version =~ m/(\w+?)=(\d+\.\d+\.\d+),API=(\d+\.\d+)/) {
	$mname = $1;
  $mvers = $2; 
  $avers = $3; 
} 
my $getmlinv; my $mlinv; my $msput; my $minerate; my $mineacc; my $minerej; my $minewu; my $minehe; 
my $melapsed;
if (@summary) {
  for (my $i=0;$i<@summary;$i++) {
    $melapsed = ${$summary[$i]}{'elapsed'};
    my $mrunt = sprintf("%d days, %02d:%02d.%02d",(gmtime $melapsed)[7,2,1,0]) if (defined $melapsed);
    my $mratem = ${$summary[$i]}{'hashrate'};
    $mratem = ${$summary[$i]}{'hashavg'} if (!defined $mratem);
    $mratem = ${$summary[$i]}{'hashavg'} if ($conf{display}{usehashavg} >0 ); 
    $minerate = sprintf("%.2f", $mratem) if (defined $mratem);
    $mineacc = ${$summary[$i]}{'shares_accepted'};
    $minerej = ${$summary[$i]}{'shares_invalid'};
    $minewu = ${$summary[$i]}{'work_utility'};
    $minehe = ${$summary[$i]}{'hardware_errors'};
    my $currentm = $conf{settings}{current_mconf};
 		my $currname = $conf{miners}{$currentm}{mconfig};
 		my $runningm	= $conf{settings}{running_mconf};
 		my $runname = $conf{miners}{$runningm}{mconfig};
  	if ($showminer == $i) {
	  	$msput .= "<tr><td colspan=4 class=big>Miner</td></tr>";
	  	if (defined $mname) {	
		  	$msput .= "<tr><td>Miner Version: </td><td>$mname $mvers</td>";
		 		$msput .= "<td colspan=2>$mstrategy Mode</td></tr>";
	 			$msput .= "<tr><td>Running Profile:  </td><td>$runname</td>";
	 			my $runpath = $conf{miners}{$runningm}{mpath};
	 			$msput .= "<td>Run Path: </td><td>$runpath</td></tr>";
		 	}
	 		$msput .= "<tr><td>Loaded Profile:  </td><td>$currname</td>";
			$msput .= "<td colspan=2><form name=currentm method=post><select name=setmconf>";
			for (keys %{$conf{miners}}) {
  			my $mname = $conf{miners}{$_}{mconfig};
  				if ($currentm eq $_) {
    				$msput .= "<option value=$_ selected>$mname</option>";
	  			} else { 
  	  			$msput .= "<option value=$_>$mname</option>";
  				}
				}
			$msput .= "<input type='submit' value='Select'>";
			$msput .= "</select></form></td></tr>";

			my $currconf = $conf{miners}{$currentm}{savepath};
			$msput .= "<tr><td>Loaded Config:  </td><td colspan=3>";
	    $msput .= "<a href='/cgi-bin/confedit.pl' target='_blank'>";
			$msput .= "$currconf</a></td></tr>";
			$mrunt = "Stopped" if (!defined $mrunt); 
	    $msput .= "<tr><td>Run time:</td><td>" . $mrunt . "</td>";
			if (defined $melapsed) {  	  
			  $msput .= "<td  colspan=2><form name='mstop' method='POST'><input type='hidden' name='mstop' value='stop'><input type='submit' value='Stop' onclick='this.disabled=true;this.form.submit();' > ";
			} else { 
			  $msput .= "<td  colspan=2><form name='mstart' method='POST'><input type='hidden' name='mstart' value='start'><input type='submit' value='Start' onclick='this.disabled=true;this.form.submit();' > ";
			}
			$msput .= "</form></tr>";
			$msput .= "</table><table>";
			if (defined $melapsed) {  	  
				$msput .= "<tr><td colspan=4>Stats</td><tr>";
				my $mtm = ${$summary[$i]}{'total_mh'};
				my $minetm = sprintf("%.2f", $mtm); 
		    $msput .= "<tr><td>Total MH:</td><td>" . $minetm . "</td>";
				my $minefb = ${$summary[$i]}{'found_blocks'};
				$minefb = 0 if (!defined $minefb);
	      $msput .= "<td>Found Blocks:</td><td>" . $minefb . "</td></tr>";
				my $minegw = ${$summary[$i]}{'getworks'};
				$minegw = 0 if (!defined $minegw);
	      $msput .= "<tr><td>Getworks:</td><td>" . $minegw . "</td>";
				my $minedis = ${$summary[$i]}{'discarded'};
	      $minedis = 0 if (!defined $minedis);
	      $msput .= "<td>Discarded:</td><td>" . $minedis . "</td></tr>";
				my $minest = ${$summary[$i]}{'stale'};
				$minest = 0 if (!defined $minest);
	      $msput .= "<tr><td>Stale:</td><td>" . $minest . "</td>";
				my $minegf = ${$summary[$i]}{'get_failures'};
				$minegf = 0 if (!defined $minegf);
	      $msput .= "<td>Get Failures:</td><td>" . $minegf . "</td></tr>";
				my $minerf = ${$summary[$i]}{'remote_failures'};
				$minerf = 0 if (!defined $minerf);
	      $msput .= "<tr><td>Remote Fails:</td><td>" . $minerf . "</td>";
				my $minenb = ${$summary[$i]}{'network_blocks'};
				$minenb = 0 if (!defined $minenb);
	      $msput .= "<td>Network Blocks:</td><td>" . $minenb . "</td></tr>";
	      my $mdia = ${$summary[$i]}{'diff_accepted'};
				my $minedia = sprintf("%d", $mdia);
	      $msput .= "<tr><td>Diff Accepted:</td><td>" . $minedia . "</td>";
	      my $mdir = ${$summary[$i]}{'diff_rejected'};
				my $minedir = sprintf("%d", $mdir);
	      $msput .= "<td>Diff Rejected:</td><td>" . $minedir . "</td></tr>";
	      my $mds = ${$summary[$i]}{'diff_stale'};
				my $mineds = sprintf("%d", $mds);
	      $msput .= "<tr><td>Difficulty Stale:</td><td>" . $mineds . "</td>";
				my $minebs = ${$summary[$i]}{'best_share'};
				$minebs = 0 if (!defined $minebs);
	      $msput .= "<td>Best Share:</td><td>" . $minebs . "</td></tr></table>";
	    }
			$msput .= "<table><tr><td colspan=4><hr></td></tr>";
	  	$msput .= "<tr><td colspan=4 class=big>Node</td></tr>";
  		$getmlinv = `cat /proc/version`;
  		$mlinv = $1 if ($getmlinv =~ /version\s(.*?\s+\(.*?\))\s+\(/);
     	$msput .= "<tr><td colspan=2>Linux Version: " . $mlinv . "</td>";
			$msput .= "<form name='reboot' method='POST'><input type='hidden' name='reboot' value='reboot'>";
			$msput .= "<td colspan=2><input type='submit' value='Reboot' onclick='this.disabled=true;this.form.submit();' > ";
			$msput .= "</td></tr></form>";
  		$msput .= "<tr><td colspan=2>Host IP: $iptxt</td>";
			$msput .= '<td class=big colspan=2><A href=ssh://user@' . $iptxt . '>SSH to Host</a></td></tr>';
			$msput .= "<tr><td colspan=4><hr></td></tr>";
 			$msput .= "<tr><td class=big><a href='sconfig.pl'>SeedManager Configuration</a></td><td>";

  	} else {		
			if (defined $melapsed) { 
				$mcontrol .= "<td>$mname $mvers";
		  	$mcontrol .= "<br><small>$mstrategy Mode</small></td>";
			  $mcontrol .= "<td>Profile: $runname<br>";
		  	$mcontrol .= "<small>Run time: " . $mrunt . "</small></td>";
			  $mcontrol .= "<td><form name='mstop' method='POST'><input type='hidden' name='mstop' value='stop'><input type='submit' value='Stop' onclick='this.disabled=true;this.form.submit();' > </form>";
			  $mcontrol .= "<td><small>Switch Profile</small><br>";
				$mcontrol .= "<form name='startnm' method='post'><select name='startnm'>";
				for (keys %{$conf{miners}}) {
	  			my $mname = $conf{miners}{$_}{mconfig};
	  				if ($currentm eq $_) {
	    				$mcontrol .= "<option value=$_ selected>$mname</option>";
		  			} else { 
	  	  			$mcontrol .= "<option value=$_>$mname</option>";
	  				}
					}
				$mcontrol .= "<input type='submit' value='Restart'>";
				$mcontrol .= "</select></form></td>";
			} else { 
		  	$mcontrol .= "<td class='error'>Stopped</td>";
			  $mcontrol .= "<td><form name=currentm method=post>Profile: <select name=setmconf>";
				for (keys %{$conf{miners}}) {
  				my $mname = $conf{miners}{$_}{mconfig};
  				if ($currentm eq $_) {
    				$mcontrol .= "<option value=$_ selected>$mname</option>";
	  			} else { 
  	  			$mcontrol .= "<option value=$_>$mname</option>";
  				}
				}
				$mcontrol .= "<input type='submit' value='Select'>";
				$mcontrol .= "</select></form></td>";
			  $mcontrol .= "<td><form name='mstart' method='POST'><input type='hidden' name='mstart' value='start'><input type='submit' value='Start' onclick='this.disabled=true;this.form.submit();' > </form>";
			}
			$mcontrol .= "</td>";		
		}
  }
}

$mcontrol .= "</tr></table><br>";
my $p1sum; my $psum; my $psput; my @poolmsg; my $pgimg;
$p1sum .= "<table id='pcontent'>";

if ($ispriv eq "S") {
	$p1sum .= "<TR class='header'><TD class='header'>Pool</TD>";
	$p1sum .= "<TD class='header'>Pool URL</TD>";
	$p1sum .= "<TD class='header'>Alias</TD>";
	$p1sum .= "<TD class='header'>Worker</TD>" if ($avers > 1.16); 
	$p1sum .= "<TD class='header'>Status</TD>";
	$p1sum .= "<TD class='header' colspan=2>Accept/Reject</TD>";
	$p1sum .= "<TD class='header'>Active</TD>";
	$p1sum .= "<TD class='header' colspan=2>Priority</TD>" if ($mstrategy eq "Failover");
	$p1sum .= "<TD class='header' colspan=2>Quota (ratio or %)</TD>" if ($mstrategy eq "Load Balance"); 
	$p1sum .= "</TR>";
 	my @currorder;
	if (@pools) {
	  for (my $i=0;$i<@pools;$i++) {
			my $pimg = "<img src='/IFMI/timeout24.png'>";
	    $pimg = "<form name='pselect' method='POST'><input type='hidden' name='swpool' value='$i'><button type='submit'>Switch</button></form>" 
	    				if ($mstrategy eq "Failover");
    	my $pname = ${$pools[$i]}{'url'};
			my $pactive = 0; 
			for (my $g=0;$g<@ascs;$g++) {
				my $gurl = $ascs[$g]{'pool_url'}; 
				if ((defined $pname) && (defined $gurl) && ($pname eq $gurl)) {
					$pactive++;
				}
			}	
			$pimg = "<img src='/IFMI/ok24.png'>" if ($pactive >0);
	    my $pnum = ${$pools[$i]}{'poolid'};
	    my $pusr = ${$pools[$i]}{'user'};
	    my $pstat = ${$pools[$i]}{'status'};
	    my $pstatus;
	    if ($pstat eq "Dead") {
	      $problems++;
	      push(@nodemsg, "Pool $i is dead"); 
	      $pstatus = "<td class='error'>" . $pstat . "</td>";
	      $pimg = "<img src='/IFMI/error24.png'>";
		  	push(@poolmsg, "Pool is dead") if ($showpool == $i);	
	    } else {
	      $pstatus = "<td>" . $pstat . "</td>";
	    }
	    my $ppri = ${$pools[$i]}{'priority'};
	    my $pacc = ${$pools[$i]}{'accepted'};
	    my $prej = ${$pools[$i]}{'rejected'};
	    my $prr;
	    if ($prej ne "0") {
	       $prr = sprintf("%.2f", $prej / ($pacc + $prej)*100);
	    } else { 
		   $prr = "0.0";
	    }
	    my $prat; 
	   	my $poola; my $poolnum;
      for (keys %{$conf{pools}}) {
      	if ($pname eq ${$conf}{pools}{$_}{url}) {
      		$poola = ${$conf}{pools}{$_}{alias};
      		$poolnum = $_;
      	}
      }
      $poola = "n/a" if (!defined $poola); 
      $poolnum = 0 if (!defined $poolnum); 
      my $prhl = ${$conf}{pools}{$poolnum}{pool_reject_hi} if (defined ${$conf}{pools}{$poolnum}{pool_reject_hi}); 
			if ((defined $prhl) && ($prr > $prhl)) {
	      $problems++;
	      push(@nodemsg, "Pool $i reject ratio too high"); 
	  	  $prat = "<td class='error'>" . $prr . "%</td>";
	      push(@poolmsg, "Reject ratio is too high") if ($showpool == $i); 	
	    } else { 
	      $prat = "<td>" . $prr . "%</td>";
	    }
	    my $pquo = ${$pools[$i]}{'quota'};
	    
	    if ($showpool == $i) { 
	    	my $current; 
	      my $psgw = ${$pools[$i]}{'getworks'};
	      my $psw = ${$pools[$i]}{'works'}; 
	      my $psd = ${$pools[$i]}{'discarded'}; 
	      my $pss = ${$pools[$i]}{'stale'}; 
	      my $psgf = ${$pools[$i]}{'getfails'}; 
	      my $psrf = ${$pools[$i]}{'remotefailures'};
		  	if ($pactive >0) {
					$current = "Active";
	      } else { 
					$current = "Not Active  ";
	      }
	      $psput .= "<tr><form name='pdelete' method='POST'><td class='big' colspan=4>$current";
		  	if ($pactive == 0) {
	      	$psput .= "<input type='hidden' name='delpool' value='$i'><input type='submit' value='Remove this pool'>";
	      }
	      $psput .= "</form></td></tr>";
	      $psput .= "<tr><td>Mining URL:</td><td colspan=3>" . $pname . "</td></tr>";
				$psput .= "<tr><td>Alias:</td><td>$poola</td><td colspan=2>";
	      $psput .= "<form name='palias' method='POST'>";
				$psput .= "<input type='text' size='10' placeholder='pool alias' name='npalias'>";
				$psput .= "<input type='hidden' name='paurl' value='$pname'>";
				$psput .= "<input type='submit' value='Change'></form></td></tr>";
			  $pusr = "unknown" if (!defined $pusr);
	      $psput .= "<tr><td>Worker:</td><td colspan=3>" . $pusr . "</td></tr>";
	      $psput .= "<tr><td>Status: $pstatus</td>";
	      $psput .= "<td>Notify when Dead?</td>";
		  	my $pnotify = $conf{pools}{$poolnum}{pnotify};
		  	$psput .= "<form name=pnotify method=post><input type=hidden name='poolnum' value=$poolnum>";
		  	if ((defined $pnotify) && ($pnotify==1)) {
    	  	$psput .= "<td><input type='radio' name='pnotify' value=1 checked>Yes ";
    	  	$psput .= "<input type='radio' name='pnotify' value=0>No ";
  		  } else { 
     	  	$psput .= "<td><input type='radio' name='pnotify' value=1>Yes ";
    	  	$psput .= "<input type='radio' name='pnotify' value=0 checked>No "; 
  		  }
  		  $psput .= "<input type='submit' value='Save'></td></tr></form>";	      
	      $psput .= "<tr><td>Shares A/R:</td><td>" . $pacc . "/" . $prej . "</td>";
	      $psput .= "<td>Reject Ratio:</td>$prat</tr>";
	      if (!defined $prhl) {$prhl = "not set"} else {$prhl = "$prhl%"}
	      $psput .= "<tr><td colspan=2>Reject Ratio alert limit: </td>";
				$psput .= "<form name='pnotifyl' method='POST'>";
				$psput .= "<td>$prhl </td><td><input type='text' size='3' placeholder='3' name='pnotifyl'>";
				$psput .= "<input type='hidden' name='poolnum' value='$poolnum'>";
				$psput .= "<input type='submit' value='Change'></form></td></tr>";

	      $psput .= "<tr><td>Priority:</td><td>" . $ppri . "</td>";
	      $psput .= "<td>Quota:</td><td>" . $ppri . "</td></tr>";
	      $psput .= "<tr><td>Getworks:</td><td>" . $psgw . "</td>";
	      $psput .= "<td>Works:</td><td>" . $psw . "</td></tr>";
	      $psput .= "<tr><td>Discarded:</td><td>" . $psd . "</td>";
	      $psput .= "<td>Stale:</td><td>" . $pss . "</td></tr>";
	      $psput .= "<tr><td>Get Failures:</td><td>" . $psgf . "</td>";
	      $psput .= "<td>Rem Fails:</td><td>" . $psrf . "</td></tr>";
	      $pgimg = "<br><img src='/IFMI/graphs/spool$i.png'>";
	    } else {
	      my $purl = "?";
	      $purl .= "pool=$i";
	      $psum .= '<TR><TD class="bigger"><A href="' . $purl . '">' . $i . '</TD>';
	      $psum .= "<td>" . $pname . "</td>";
	      $psum .= "<td>" . $poola . "</td>";
	      if (length($pusr) > 20) { 
	        $pusr = substr($pusr, 0, 6) . " ... " . substr($pusr, -6, 6) if (index($pusr, '.') < 0);
	      }
	      $psum .= "<td>" . $pusr . "</td>" if ($avers > 1.16);
	      $psum .= $pstatus;
	      $psum .= "<td>" . $pacc . " / " . $prej . "</td>";
	      $psum .= $prat;
	      $psum .= "<td>" . $pimg . "</td>";
			  if ($mstrategy eq "Load Balance") {
	      	$psum .= "<td> " . $pquo . " </td>";
	      	$psum .= "<td><form name='pquota' method='POST'>";
	      	$psum .= "<input type='text' size='3' name='qval' required>";
	      	$psum .= "<input type='hidden' name='qpool' value='$i'>";
	      	$psum .= "<input type='submit' value='Set'></form></td>";
	      }
	     	$psum .= "<td>" . $ppri . "</td>" if ($mstrategy eq "Failover");
      	$psum .= "</tr>";
      }
	  }
	  $psum .= "<tr><form name='padd' method='POST'>";
	  $psum .= "<td colspan='2'><input type='text' size='45' placeholder='MiningURL:portnumber' name='npoolurl' required>";
	  $psum .= "</td><td colspan='2'><input type='text' placeholder='username.worker' name='npooluser' required>";
	  $psum .= "</td><td colspan='3'><input type='text' size='15' placeholder='worker password' name='npoolpw'>";
	  $psum .= "</td><td><input type='submit' value='Add'>"; 
	  $psum .= "</td></form>";
	  if ($mstrategy eq "Failover") {
		  $psum .= "<TD class='header' colspan=2></td>";	  			
	  }
	  if ($mstrategy eq "Load Balance") {
		  $psum .= "<TD class='header' colspan=2>Failover-Only:<br>$mfonly</td>";
	  }
		$psum .= "</tr>";

	} else { 
	  $psum .= "<TR><TD colspan='8'><big>Active Pool Information Unavailable</big></td></tr>";
	}
	$psum .= "</table><br>";
	$p1sum .= $psum;

} else { 
	if (defined $melapsed) { 
	  $p1sum .= "<TR><TD id=perror><p>The required API permissions do not appear to be available.<br>";
  	$p1sum .= "please ensure your miner.conf contains the following line:<br>";
  	$p1sum .= '"api-allow" : "W:127.0.0.1",';
  	$p1sum .= "</p></td></tr>";
  	$p1sum .= "</table><br>";
  }
}

# Overview starts here

print "<div id='overview'>";
print "<table><TR><TD>";
print "<table><TR><TD rowspan=2><div class='logo'><a href='https://github.com/starlilyth/Pi-SeedManager' target=_blank>";
print "</a></div></TD>";
print "<TD class='overviewid'>$miner_name<br><small>@ $iptxt</small></td>";
print "<td align='right'><form method='post' name='zero'>";
print "<input type='hidden' value='zero' name='zero' /><button type='submit' title='reset stats' class='reset-btn'/></form></td>";
print "<tr><TD class='overviewhash' colspan=2>";
$minerate = "0" if (!defined $minerate); 
print $minerate . " Mh/s</TD></tr></table></td>";
$mineacc = "0" if (!defined $mineacc); 
print "<TD class='overview'>" . $mineacc . " total accepted shares<br>";
$minerej = "0" if (!defined $minerej); 
print $minerej . " total rejected shares<br>";
if ($mineacc > 0)
{
 print sprintf("%.3f%%", $minerej / ($mineacc + $minerej)*100);
} else { 
 print "0"
}
print " reject ratio";

print "<TD class='overview'>";
if ($problemascs > 1){
  if ($problemascs == 1) {
  	print $problemascs . " ASC has problems<br>";
  } else {
	print $problemascs . " of " . @ascs . " ASCs have problems<br>";
  }
} else { 
  if ($okascs == 1) {
	print $okascs . " ASC is OK<br>";
  } else {
	print $okascs . " of " . @ascs . " ASCs are OK<br>";
  }
}
$minehe = "0" if (!defined $minehe); 
if ($minehe == 1) {
  print $minehe . " HW Error<br>";
} else {
  print $minehe . " HW Errors<br>";
}
$minewu = "0" if (!defined $minewu); 
print $minewu . " Work Utility<br>";
print "</td>";

# EXTRA HEADER STATS
print "<TD class='overview'>";
my $uptime = `uptime`;
my $rigup = $1 if ($uptime =~ /up\s+(.*?),\s+\d+\s+users?,/);
my $rigload = $1 if ($uptime =~ /average:\s+(.*?),/);
my $memfree = `cat /proc/meminfo | grep MemFree`; 
my $rmem = $1 if ($memfree =~ /^MemFree:\s+(.*?)\s+kB$/);
my $rigmem = sprintf("%.3f", $rmem / 1000000);  
print "Uptime: $rigup<br>";
print "CPU Load: $rigload<br>";
print "Mem free: $rigmem GB<br>";
# END EXTRA STATS

print "</TR></table></div>";

print "<div id=content>";

given(my $x) {
	when ($showasc > -1) {
		print "<div id='showdata'>";
		print "<table><tr colspan=2><td><A HREF=?";	
		print "tok=1> << Back to overview</A>";
		print "</td></tr>";	
		print "<tr><td class='header'>";	
		print "<table><tr><td class='bigger'>ASC $showasc<br>";	
		print sprintf("%d", $ascs[$showasc]{'hashrate'}) . " Kh/s</td></tr>";	
		print "<tr><td>";
		if (@ascmsg) {
			print "<img src='/IFMI/error.png'><p>";
			foreach my $l (@ascmsg) {
				print "$l<br>";
			}
		} else {
			print "<img src='/IFMI/ok.png'><p>";
			print "All parameters OK";
		}
		print "</td></tr></table>";

		print "</td><td><div id='sumdata'><table>$asput</table></div></td></tr>";	
		print "<tr><td colspan=2>$agimg</td></tr></table>";
		print "</div>";
	}
	when ($showpool > -1) {
        print "<div id='showdata'>";
        print "<table><tr><td colspan=2><A HREF=?";
        print "tok=1> << Back to overview</A>";
        print "</td></tr>";
        print "<tr><td class='header'>";
        print "<table><tr><td class='bigger'>Pool $showpool<br>";
        my $psacc = ${$pools[$showpool]}{'accepted'};
        my $psrej = ${$pools[$showpool]}{'rejected'};
		if ($psacc ne "0") { 
 	      print sprintf("%.2f%%", $psrej / ($psacc + $psrej)*100) . "</td></tr><tr><td>";
          print "reject ratio";
		} else {
		  print "0 Shares";
		}
		print "</td></tr><tr><td>";
        if (@poolmsg) {
                print "<p><img src='/IFMI/error.png'><p>";
                foreach my $l (@poolmsg)
                {
                        print "$l<br>";
                }
        } else {
                print "<p><img src='/IFMI/ok.png'><p>";
                print "All OK";
        }
   		print "</td></tr></table>";
		print "</td><td><div id='sumdata'><table>$psput</table></div></td></tr>";
		print "<tr><td colspan=2>$pgimg</td></tr></table>";
		print "</div>";
	}
	when ($showminer > -1) {
        print "<div id='showdata'>";
        print "<table><tr><td colspan=2><A HREF=?";
        print "tok=1> << Back to overview</A>";
        print "</td></tr>";
        print "<tr><td class='header'>";
        print "<table><tr><td class='bigger'>" . $miner_name . "<br>";
		if (($minerate ne "0") && ($minewu ne "0")) {
 	      print sprintf("%.1f%%", ($minewu / $minerate) / 10);
		} else { print "0"; }
		print "</td></tr><tr><td>Efficiency <br>(WU / Hashrate)</td></tr>"; 
		print "<tr><td>";
        if (@nodemsg) {
                print "<img src='/IFMI/error.png'><p>";
                foreach my $l (@nodemsg)
                {
                        print "$l<br>";
                }
        } else {
                print "<p><img src='/IFMI/ok.png'><p>";
                print "All OK";
        }
        my $release = $conf{display}{smversion};
   		print "</td></tr></table>";        
        print "</td><td><table>$msput</td></tr>";
        print "<tr><td colspan=4><hr></td></tr>";
        print "<tr><td colspan=4>SeedManager v$release New releases are available at ";
        print "<a href=https://github.com/starlilyth/Pi-SeedManager/releases target=_blank>GitHub</a>.<br>"; 
        print "<b>If you love SeedManager, please consider donating. </b>Thank you!<br> ";
        print "BTC: <a href='bitcoin://1JBovQ1D3P4YdBntbmsu6F1CuZJGw9gnV6'><b>1JBovQ1D3P4YdBntbmsu6F1CuZJGw9gnV6</b></a> <br>LTC: <b>LdMJB36zEfTo7QLZyKDB55z9epgN78hhFb</b><br>";
        print "</table></td></tr></table>";
    	print "</div>";
	}
	default {
	  print "<div class='data'>";

	  if ($UHOH eq "true") {
		print "<table><tr><td class=big><p>Uh Oh! No data could be retreived! Please check your configuration and try again.</p></td></tr></table>";
	  } else {
	    print $mcontrol;	
	    print $p1sum;
	    print $a1put if (defined $a1put);

		print "<br></div>";
		print "<div class=graphs>";	
		print "<table>";
		print "<tr><td align=left>";	
		my $img = "/var/www/IFMI/graphs/smsummary.png";
		if (-e $img) {
			print '<img src="/IFMI/graphs/smsummary.png">';
		} else {
			print "<font style='color: #999999; font-size: 10px;'>Summary graph not available yet.";
		}
		print "</td></tr></table>";
		print "</div>";	
	  }
	}
}

print "</body></html>";

