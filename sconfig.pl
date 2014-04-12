#!/usr/bin/perl
# IFMI SeedManager configuration file editor. 
#    This file is part of IFMI SeedManager.
#
#    SeedManager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.   

 use strict;
 use warnings;
 use YAML qw( DumpFile LoadFile );
 use CGI qw(:cgi-lib :standard);

my $version = "0.9.0";
my $conffile = "/opt/ifmi/seedmanager.conf";
if (! -f $conffile) { 
  my $nconf = {
  	monitoring => {
   		monitor_hash_lo => '200',
  		monitor_reject_hi => '3',
      monitor_hardware_hi => '50',
      do_email => '0',
  	},
  	miners => {
      0 => {
    		mconfig => 'Default',
        mpath => '/opt/miners/cgminer/cgminer',
    		mopts => '--api-listen',
  	   	savepath => '/opt/ifmi/cgminer.conf',
      },
  	},
    settings => {
      cgminer_port => '4028',
      current_mconf => '0',
      running_mconf => '0',
      do_boot => '1',
    },
  	display => {
  		miner_loc => 'Undisclosed Location',
  		status_css => 'default.css',
  		graphcolors => 'smgraph.colors',
  		usehashavg => '0',
      smversion => "$version",
  	},
      farmview => {
      do_bcast_status => '1',
      status_port => '54545',
    },
    email => {
      smtp_to => 'root@localhost', 
      smtp_host => 'localhost',
      smtp_from => 'seedmanager@localhost',
      smtp_port => '25',
      smtp_tls => '1',
      smtp_ssl => '1',
      smtp_auth_user => '',
      smtp_auth_pass => '',
      smtp_min_wait => '300',
    }

  };
  DumpFile($conffile, $nconf); 
}

# Take care of business
my $conferror = 0; my $mailerror = "";
my $mconf = LoadFile( $conffile );
if (-o $conffile) {
  my $curver = $mconf->{display}->{smversion};
  $mconf->{display}->{smversion} = $version if ($version ne $curver);
  our %in;
  if (&ReadParse(%in)) {
    my $nhl = $in{'hashlo'};
    if((defined $nhl) && ($nhl ne "")) {
      $nhl = "200" if (! ($nhl =~ m/^\d+?$/));
      $mconf->{monitoring}->{monitor_hash_lo} = $nhl;
    }
    my $nrh = $in{'rejhi'};
    if((defined $nrh) && ($nrh ne "")) {
      $nrh = "3" if (! ($nrh =~ m/^(\d+)?\.?\d+?$/));
      $mconf->{monitoring}->{monitor_reject_hi} = $nrh;
    }
    my $nhh = $in{'hwhi'};
    if((defined $nhh) && ($nhh ne "")) {
      $nhh = "50" if (! ($nhh =~ m/^\d+?$/));
      $mconf->{monitoring}->{monitor_hardware_hi} = $nhh;
    }
    my $doe = $in{'emaildo'};
    $mconf->{monitoring}->{do_email} = $doe if((defined $doe) && ($doe ne ""));

    my $ncmc = $in{'setmconf'};
    $mconf->{settings}->{current_mconf} = $ncmc if ((defined $ncmc) && ($ncmc ne ""));

    my $msettings = $in{'msettings'};
    if ((defined $msettings) && ($msettings ne "")) {
      my $currname = $in{'currname'};
      my $nmname = $in{'nmname'}; 
      my $nmp = $in{'nmp'};
      my $nmo = $in{'nmo'};
      my $nsp = $in{'nsp'};
      if ($nmname ne "") {
        my $ncheck = 0; 
        for (keys %{$mconf->{miners}}) {    
          if ($nmname eq $mconf->{miners}->{$_}->{mconfig}) {
            $mconf->{miners}->{$_}->{mpath} = $nmp if ($nmp ne "");            
            $mconf->{miners}->{$_}->{mopts} = $nmo if ($nmo ne "");
            $mconf->{miners}->{$_}->{savepath} = $nsp if ($nsp ne "");
            $ncheck++;
          } 
        } 
        if ($ncheck == 0) {
          if ($nmp ne "") { 
            my $newm = (keys %{$mconf->{miners}}); $newm++; 
            $mconf->{miners}->{$newm}->{mconfig} = $nmname;
            $mconf->{miners}->{$newm}->{mpath} = $nmp;
            $nmo = "--api-listen" if ($nmo eq "");
            $mconf->{miners}->{$newm}->{mopts} = $nmo;
            $nsp = "/opt/ifmi/$nmname.conf" if ($nsp eq "");
            $mconf->{miners}->{$newm}->{savepath} = $nsp;        
            if (!-f $nsp) {
              my $cdata; 
              $cdata .= "{\n"; 
              $cdata .= '"pools" : [' . "\n";
              $cdata .= "  {\n"; 
              $cdata .= '    "url" : "stratum+tcp://mine.coinshift.com:3333",' . "\n";
              $cdata .= '    "user" : "1JBovQ1D3P4YdBntbmsu6F1CuZJGw9gnV6",' . "\n";
              $cdata .= '    "pass" : "x"' . "\n";
              $cdata .= "  }\n";
              $cdata .= "],\n";
              $cdata .= '"api-listen" : true,' . "\n" . '"api-allow" : "W:127.0.0.1",' . "\n";
              $cdata .= '"scrypt" : true,' . "\n" . '"kernel-path" : "/usr/local/bin"' . "\n";
              $cdata .= "}\n";
              open my $cfgin, '>>', $nsp;
              print $cfgin $cdata;
              close $cfgin; 
            }
            $mconf->{settings}->{current_mconf} = $newm;
          } else {
            $conferror = 2;
          }
        }
      } else {   
        for (keys %{$mconf->{miners}}) {
          if ($currname eq $mconf->{miners}->{$_}->{mconfig}) {
            $mconf->{miners}->{$_}->{mpath} = $nmp if ($nmp ne "");
            $mconf->{miners}->{$_}->{mopts} = $nmo if ($nmo ne "");
            $mconf->{miners}->{$_}->{savepath} = $nsp if ($nsp ne "");
          } 
        }
      }
      $nmname = ""; $currname = ""; $msettings = "";
    }

    my $mdel = $in{'deletem'};
    if ((defined $mdel) && ($mdel ne "")) {
      if ($mdel != 0) {
        delete $mconf->{miners}->{$mdel};
        $mconf->{settings}->{current_mconf} = 0;
      }
    }

    my $ndb = $in{'doboot'};
    $mconf->{settings}->{do_boot} = $ndb if ((defined $ndb) && ($ndb ne ""));

    my $nap = $in{'nap'};
    if((defined $nap) && ($nap ne "")) {
      $nap = "4028" if (! ($nap =~ m/^\d+?$/));    
      $mconf->{settings}->{cgminer_port} = $nap;
    }

    my $iht = $in{'installht'};
    `sudo /opt/ifmi/mcontrol installht` if ((defined $iht) && ($iht eq "installht")); 

    my $uup = $in{'uup'};
    if((defined $uup) && ($uup ne "")) {
      my $uuser = $in{'huser'};
      `sudo /usr/bin/htpasswd -b /var/htpasswd $uuser $uup`;
      $uup = "";
    }

    my $nup = $in{'nup'};
    if((defined $nup) && ($nup ne "")) {
      my $nuser = $in{'nun'};
      `sudo /usr/bin/htpasswd -b /var/htpasswd $nuser $nup`;
      $nup = "";
    }

    my $dun = $in{'duser'};
    if((defined $dun) && ($dun ne "")) {
      `sudo /usr/bin/htpasswd -D /var/htpasswd $dun`;
    }

    my $nml = $in{'nml'};
    $mconf->{display}->{miner_loc} = $nml if((defined $nml) && ($nml ne ""));
    my $nscss = $in{'scss'};
    $mconf->{display}->{status_css} = $nscss if(defined $nscss);
    my $ngcf = $in{'gcf'};
    $mconf->{display}->{graphcolors} = $ngcf if(defined $ngcf);
    my $nha = $in{'hashavg'};
    $mconf->{display}->{usehashavg} = $nha if(defined $nha);

    my $cgraphs = $in{'cgraphs'};
    if ((defined $cgraphs) &&($cgraphs ne "")) {
      `sudo /opt/ifmi/smcontrol cleargraphs`;
      $cgraphs = "";
    }

    $mconf->{display}->{smversion} = $version if ($mconf->{display}->{smversion} eq "");

    my $nbcast = $in{'bcast'};
    $mconf->{farmview}->{do_bcast_status} = $nbcast if((defined $nbcast) && ($nbcast ne ""));
    my $nbp = $in{'nbp'};
    if(defined $nbp) {
      $nbp = "54545" if (! ($nbp =~ m/^\d+?$/));    
      $mconf->{farmview}->{status_port} = $nbp;
    }

    my $nst = $in{'mailto'};
    $mconf->{email}->{smtp_to} = $nst if ((defined $nst) && ($nst ne ""));
    my $nsf = $in{'mailfrom'};
    $mconf->{email}->{smtp_from} = $nsf if ((defined $nsf) && ($nsf ne ""));
    my $nsh = $in{'mailhost'};
    $mconf->{email}->{smtp_host} = $nsh if ((defined $nsh) && ($nsh ne ""));
    my $nsmp = $in{'mailport'};
    if ((defined $nsmp) && ($nsmp ne "")) {
      $nsmp = "25" if (! ($nsmp =~ m/^\d+?$/));
      $mconf->{email}->{smtp_port} = $nsmp;
    }
    my $nssl = $in{'mailssl'};
    $mconf->{email}->{smtp_ssl} = $nssl if (defined $nssl);
    my $ntls = $in{'mailtls'};
    $mconf->{email}->{smtp_tls} = $ntls if (defined $ntls);
    my $nsau = $in{'authuser'};
    $mconf->{email}->{smtp_auth_user} = $nsau if ((defined $nsau) && ($nsau ne ""));
    my $nsap = $in{'authpass'};
    $mconf->{email}->{smtp_auth_pass} = $nsap if ((defined $nsap) && ($nsap ne ""));
    my $nmw = $in{'mailwait'};
    if ((defined $nmw) && ($nmw ne "")) {
      $nmw = "5" if (! ($nmw =~ m/^\d+?$/));
      $nmw = $nmw * 60; 
      $mconf->{email}->{smtp_min_wait} = $nmw;
    }
    my $se = $in{'sendemail'};
    if (defined $se) {
      require '/opt/ifmi/smnotify.pl';
      my $currsettings = "Email Settings:\n";
      $currsettings .= "- Email To: " . $mconf->{email}->{smtp_to} . "\n";
      $currsettings .= "- Email From: " . $mconf->{email}->{smtp_from} . "\n";
      $currsettings .= "- SMTP Host: " . $mconf->{email}->{smtp_host} . "\n";
      $currsettings .= "- SMTP port: " . $mconf->{email}->{smtp_port} . "\n";
      $currsettings .= "- Email Frequency: " . $mconf->{email}->{smtp_min_wait} / 60 . "minutes\n";
      $currsettings .= "- Auth User: " . $mconf->{email}->{smtp_auth_user} . "\n";
      $currsettings .= "\nMonitoring Settings: \n";
      $currsettings .= "- Low Hashrate: " . $mconf->{monitoring}->{monitor_hash_lo} . "Kh/s\n"; 
      $currsettings .= "- High Reject Rate: " . $mconf->{monitoring}->{monitor_reject_hi} . "%\n"; 
      
      $mailerror = &sendAnEmail("TEST",$currsettings);
  }
      
    DumpFile($conffile, $mconf); 
  }
} else { 
  $conferror = 1; 
}

# Carry on
print header();
my $miner_name = `hostname`;
chomp $miner_name;
print start_html( -title=>'SM - ' . $miner_name . ' - Settings',
				  -style=>{-src=>'/IFMI/themes/' . $mconf->{display}->{status_css}} );


print "<div id='showdata'><br>";
print "<a href='seedstatus.pl'> << Back to Overview</a><br>";
print "<a href='seedstatus.pl?miner='> << Back to Miner details page</a>";
print "<br></div>";

print "<div id='content'><table class=settingspage>";
print "<tr><td colspan=2 align=center>";
print "<table class=title><tr><td class=bigger>SeedManager Configuration for $miner_name</td><tr>";
if ($mailerror ne "") {
  if ($mailerror =~ m/success/i) {
    print "<tr><td colspan=2 bgcolor='green'><font color='white'>Test Email Sent Successfully</font></td><tr>";
  } elsif ($mailerror =~ m/^(.+)/) {
    my $errmsg = $1;
    print "<tr><td class=error colspan=2>$errmsg</td><tr>";
  }
}
if ($conferror == 1) {
  print "<tr><td class=error colspan=2>SeedManager cannot write to its config!";
  print "<br>Please ensure /opt/ifmi/seedmanager.conf is owned by the webserver user.</td><tr>";
}
if ($conferror == 2) {
  print "<tr><td class=error colspan=2>No Miner Path specified!</td><tr>";
}

print "</table><br></td></tr>";
print "<tr><td colspan=2 align=center>";

print "<table class=settings><tr><td class=header>Miner Profile</td><td class=header>";
my $currentm = $mconf->{settings}->{current_mconf};
my $currname = $mconf->{miners}->{$currentm}->{mconfig};
print "<form name=deletem method=post>$currname <input type='submit' value='Delete'>";
print "<input type='hidden' name='deletem' value='$currentm'></form>";
print "</td><td class=header>";
print "<form name=currentm method=post><select name=setmconf>";
for (keys %{$mconf->{miners}}) {
  my $mname = $mconf->{miners}->{$_}->{mconfig};
  if ($currentm eq $_) {
    print "<option value=$_ selected>$mname</option>";
  } else { 
    print "<option value=$_>$mname</option>";
  }
}
print "<input type='submit' value='Select'>";
print "</select></form>";

print "<td class=header><form name=msettings method=post>";
print "<input type='submit' value='Update'>";
print "<input type='hidden' name='msettings' value='msettings'> ";
print "<input type='hidden' name='currname' value='$currname'> ";
print " <input type='text' placeholder='enter name for new profile' name='nmname'></td><tr>";
my $miner_path = $mconf->{miners}->{$currentm}->{mpath};
print "<tr><td>Miner Path</td><td colspan=2>$miner_path</td>";
print "<td><input type='text' size='45' placeholder='/path/to/miner' name='nmp'></td></tr>";
my $savepath = $mconf->{miners}->{$currentm}->{savepath}; 
print "<tr><td>Miner Config<br><i><small>Click to edit</small></i></td>";
print "<td colspan=2><small>--config</small> ";
print "<a href='/cgi-bin/confedit.pl' target='_blank'>$savepath</a></td>";
print "<td><input type='text' size='45' placeholder='/opt/ifmi/cgminer.conf' name='nsp'>";
my $miner_opts = $mconf->{miners}->{$currentm}->{mopts};
print "<tr><td>Miner Options</td><td colspan=2>$miner_opts</td>";
print "<td><input type='text' size='45' placeholder='--api-listen' name='nmo'></td></tr>";
print "</form></td></tr>";
print "</table><br>";

print "<tr><td align=center>";

print "<table class=settings><tr><td colspan=3 class=header>Password Manager</td>";
if (! `grep AuthUserFile /etc/apache2/sites-available/default-ssl`) {
  print "<tr><td><i>htpasswd is not installed.</i></td>";
  print "<td><form name=installht method=post>";
  print "<input type='hidden' name='installht' value='installht'>";
  print "<input type='submit' value='Install'></form></td></tr>";
} else {
  my $loggedin = $ENV{REMOTE_USER};
  $loggedin = "not logged in" if ($loggedin eq "");
  my @users;
  my $ufile = "/var/htpasswd";
  open (my $uin, $ufile);
  while (my $line = <$uin>) {
    push @users,$1 if ($line =~ m/^(\w+):.+/);
  }    
  close $uin;
  print "<tr><td>Current User: $loggedin</td><td colspan=2>";
  if (@users > 1) {
    print "<form name=udel method=post>";
    print "<select name=duser>";
      foreach my $user (@users) {
        if ("$user" ne "$loggedin") {
          print "<option value=$user>$user</option>";
        }
      }
    print "</select><input type='submit' value='Delete'></form>";
  }
  print "</td></tr>";  
  print "<form name=pupdate method=post><tr>";
  print "<td><select name=huser>";
  foreach my $user (@users) {
    if ("$user" eq "$loggedin") {
        print "<option value=$user selected>$user</option>";
      } else { 
        print "<option value=$user>$user</option>";
      }
  }
  print "</select></td>";
  print "<td><input type='text' placeholder='pass' name='uup'></td>";
  print "<td><input type='submit' value='Change'></form></td></tr>";
  print "<tr><td><form name=nhuser method=post>";
  print "<input type='text' placeholder='name' name='nun' required></td>";
  print "<td><input type='text' placeholder='pass' name='nup' required></td>";
  print "<td><input type='submit' value='New'></form></td></tr>";
}  
print "</table><br>";

print "</td><td align=center>";

print "<form name=miscsettings method=post>";
print "<table class=settings><tr><td colspan=2 class=header>Misc. Miner Settings</td>";
print "<td class=header><input type='submit' value='Save'></td><tr>";
my $doboot = $mconf->{settings}->{do_boot};
print "<tr><td>Start on Boot</td><td><i>Start the loaded profile at boot time?</i></td>";
if ($doboot==1) {
  print "<td><input type='radio' name='doboot' value=1 checked>Yes ";
  print "<input type='radio' name='doboot' value=0>No </td></tr>";
} else { 
  print "<td><input type='radio' name='doboot' value=1>Yes ";
  print "<input type='radio' name='doboot' value=0 checked>No </td></tr>"; 
}
my $minerport = $mconf->{settings}->{cgminer_port};
print "<tr><td>API port</td><td><i>Defaults to 4028 if unset</i></td>";
print "<td>$minerport <input type='text' size='4' placeholder='4028' name='nap'></td></tr>";
print "</table></form><br>";

print "</td></tr><tr><td rowspan=2 align=center valign=top>";
print "<form name=monitoring method=post>";
print "<table class=monitor><tr><td colspan=2 class=header>Monitoring Settings</td>";
print "<td class=header><input type='submit' value='Save'></td><tr>";

my $hashlo = $mconf->{monitoring}->{monitor_hash_lo};
print "<tr><td>Low Hashrate</td><td>$hashlo Kh/s</td>";
print "<td><input type='text' size='3' placeholder='200' name='hashlo'></td></tr>";

my $rejhi = $mconf->{monitoring}->{monitor_reject_hi};
print "<tr><td>High Reject Rate</td><td>$rejhi%</td>";
print "<td><input type='text' size='2' placeholder='3' name='rejhi'></td></tr>";

my $hwhi = $mconf->{monitoring}->{monitor_hardware_hi};
print "<tr><td>High Hardware Errors</td><td>$hwhi</td>";
print "<td><input type='text' size='2' placeholder='50' name='hwhi'></td></tr>";

my $emaildo = $mconf->{monitoring}->{do_email};
print "<tr><td>Send Email</td>";
if ($emaildo==1) {
  print "<td colspan=2><input type='radio' name='emaildo' value=1 checked>Yes ";
  print "<input type='radio' name='emaildo' value=0>No </td></tr>";
} else { 
  print "<td colspan=2><input type='radio' name='emaildo' value=1>Yes ";
  print "<input type='radio' name='emaildo' value=0 checked>No </td></tr>"; 
}

if ($emaildo==1) {
  my $mailto = $mconf->{email}->{smtp_to};
  print "<tr><td>Email To:</td><td>$mailto</td>";
  print "<td><input type='text' placeholder='user\@email.com' name='mailto'></td></tr>";
  my $mailfrom = $mconf->{email}->{smtp_from};
  print "<tr><td>Email From:</td><td>$mailfrom</td>";
  print "<td><input type='text' placeholder='seedmanager\@email.com' name='mailfrom'></td></tr>";
  my $mailhost = $mconf->{email}->{smtp_host};
  print "<tr><td>SMTP Host</td><td>$mailhost</td>";
  print "<td><input type='text' placeholder='smtp.email.com' name='mailhost'></td></tr>";
  my $mailport = $mconf->{email}->{smtp_port};
  print "<tr><td>SMTP Port</td><td>$mailport</td>";
  print "<td><input type='text' size='5' placeholder='587' name='mailport'></td></tr>";
  my $mailwait = ($mconf->{email}->{smtp_min_wait} / 60);
  print "<tr><td>Email Frequency</td><td>$mailwait minutes</td>";
  print "<td><input type='text' size='5' placeholder='5' name='mailwait'></td></tr>";
  my $mailssl = $mconf->{email}->{smtp_ssl};
  print "<tr><td>Use SSL?</td>";
  if ($mailssl==1) {
    print "<td colspan=2><input type='radio' name='mailssl' value=1 checked>Yes ";
    print "<input type='radio' name='mailssl' value=0>No </td></tr>";
    my $authuser = $mconf->{email}->{smtp_auth_user};
    print "<tr><td>Auth User</td><td>$authuser</td>";
    print "<td><input type='text' placeholder='mailuser' name='authuser'></td></tr>";
    my $authpass = $mconf->{email}->{smtp_auth_pass};
    my $authshow = "*******" if (defined $authpass);
    print "<tr><td>Auth Pass</td><td>$authshow</td>";
    print "<td><input type='password' placeholder='mailpassword' name='authpass' autocomplete='off'></td></tr>";
    my $mailtls = $mconf->{email}->{smtp_tls};
    print "<tr><td>Use TLS?</td>";
    if ($mailtls==1) {
      print "<td colspan=2><input type='radio' name='mailtls' value=1 checked>Yes ";
      print "<input type='radio' name='mailtls' value=0>No </td></tr>";
    } else { 
      print "<td colspan=2><input type='radio' name='mailtls' value=1>Yes ";
      print "<input type='radio' name='mailtls' value=0 checked>No </td></tr>"; 
    }
  } else { 
    print "<td colspan=2><input type='radio' name='mailssl' value=1>Yes ";
    print "<input type='radio' name='mailssl' value=0 checked>No </td></tr>"; 
  }
  print "</form><form name=testemail method=post><tr><td colspan=2>Send a Test Email</td><td>";
  print "<input type=submit name='sendemail' value='Send' method=post></td></tr></form>";
}
print "</table><br>";

print "</td><td align=center>";

print "<form name=farmview method=post>";
print "<table class=farmview><tr><td colspan=2 class=header>Farmview Settings</td>";
print "<td class=header><input type='submit' value='Save'></td><tr>";
my $bcast = $mconf->{farmview}->{do_bcast_status};
print "<tr><td>Broadcast Status</td>";
print "<td><i>Send Node Status?</i></td>";
if ($bcast==1) {
  print "<td><input type='radio' value=1 name='bcast' checked>Yes";
  print "<input type='radio' value=0 name='bcast'>No</td>";
} else { 
  print "<td><input type='radio' value=1 name='bcast'>Yes";
  print "<input type='radio' value=0 name='bcast' checked>No</td>";
}
print "</tr>";
my $statport = $mconf->{farmview}->{status_port};
print "<tr><td>Broadcast Port</td>";
print "<td><i>Port to send status on</i></td>";
print "<td>$statport <input type='text' size='5' placeholder='54545' name='nbp'></td></tr>";
print "</table></form>";

print "</td></tr><tr><td align=center>";

print "<form name=display method=post>";
print "<table class=display><tr><td colspan=2 class=header>Display Settings</td>";
print "<td class=header><input type='submit' value='Save'></td><tr>";
my $miner_loc = $mconf->{display}->{miner_loc};
print "<tr><td>Miner Location</td><td>$miner_loc</td>";
print "<td><input type='text' placeholder='Location text' name='nml'></td></tr>";

my $status_css = $mconf->{display}->{status_css};
print "<tr><td>Status CSS</td><td>$status_css</td>";
print "<td><select name=scss>";
my @csslist = glob("/var/www/IFMI/themes/*.css");
    foreach my $file (@csslist) {
    	$file =~ s/\/var\/www\/IFMI\/themes\///;
    	if ("$file" eq "$status_css") {
          print "<option value=$file selected>$file</option>";
        } else { 
          print "<option value=$file>$file</option>";
        }
    }
print "</select></td></tr>";

my $gcolors = $mconf->{display}->{graphcolors};
print "<tr><td>Graph Colors File</td><td>$gcolors</td>";
print "<td><select name=gcf>";
my @colorslist = glob("/var/www/IFMI/themes/*.colors");
    foreach my $file (@colorslist) {
    	$file =~ s/\/var\/www\/IFMI\/themes\///;
    	if ("$file" eq "$gcolors") {
          print "<option value=$file selected>$file</option>";
 		}else { 
          print "<option value=$file>$file</option>";
 		}
    }
print "</select></td></tr>";
my $hashavg = $mconf->{display}->{usehashavg};
print "<tr><td>Hashrate Display</td>";
print "<td><i>5sec average, or Overall (old style)</i></td>";
if ($hashavg==1) {
  print "<td><input type='radio' name='hashavg' value=0>5 sec";
  print "<input type='radio' name='hashavg' value=1 checked>Overall</td></tr>";
} else { 
  print "<td><input type='radio' name='hashavg' value=0 checked>5 sec";
  print "<input type='radio' name='hashavg' value=1>Overall</td></tr></form>";
}
  print "<form method=post><tr><td>Clear All Graphs</td>";
  print "<td><i></i></td>";
  print "<td><input type='hidden' name='cgraphs' value='cgraphs'><button type='submit'>Clear</button></td></tr>";
  print "</table></form>";

print "</td></tr>";

print "</table></div>";
print "</body></html>";
