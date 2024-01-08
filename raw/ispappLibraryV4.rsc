# Function to collect pinging stats from device to $topdomain;
:global getPingingMetrics do={
    :global topDomain;
    :local avgRtt 0;
    :local minRtt 0;
    :local maxRtt 0;
    :local totalpingsreceived 0;
    :local totalpingssend 5;
    :local oneStepPercent (100 / $totalpingssend);
    :local percentage 100;
    :do {
      /tool flood-ping address=[:resolve $topDomain] count=$totalpingssend size=64 timeout=00:00:00.1 do={
        :if ($sent = $totalpingssend) do={  
            :set totalpingsreceived $received;
            :set avgRtt ($"avg-rtt");
            :set minRtt ($"min-rtt");
            :set maxRtt ($"max-rtt");
            :set percentage (100 - (($totalpingsreceived / $totalpingssend)*100))
        }
      }
      :return ({
        "host"="$topDomain";
        "avgRtt"=([:tonum $avgRtt]);
        "loss"=([:tonum $percentage]);
        "minRtt"=([:tonum $minRtt]);
        "maxRtt"=([:tonum $maxRtt])
      });
    } on-error={
      :return ({
        "host"="$topDomain";
        "avgRtt"=([:tonum $avgRtt]);
        "loss"=([:tonum $percentage]);
        "minRtt"=([:tonum $minRtt]);
        "maxRtt"=([:tonum $maxRtt])
      });
    }
}
# get public ip
:global getPublicIp do={
  :do {
    :return [:tostr [:resolve myip.opendns.com server=208.67.222.222]];
  } on-error={
    :return "0.0.0.0";
  }
}
# Function to join all collectect metrics
:global getCollections do={
    :local cout ({});
    :global getSystemMetrics;
    :global getPingingMetrics;
    :global wapCollector;
    :global toJson;
    :global collectInterfacesMetrics;
    :global getCpuLoads;
    :local wapArray [$wapCollector];
    :local dhcpLeaseCount 0;
    :local systemArray [$getSystemMetrics];
    :local ifaceDataArray [$collectInterfacesMetrics];
    :local pings ({});
    :local gauge ({});
    :do {
        # count the number of dhcp leases
        :set dhcpLeaseCount [:len [/ip dhcp-server lease find]];
        # add IPv6 leases
        :set dhcpLeaseCount ($dhcpLeaseCount + [:len [/ipv6 address find]]);
    } on-error={
        :set dhcpLeaseCount $dhcpLeaseCount;
    }
    :set ($gauge->0) ({"name"="Total DHCP Leases"; "point"=$dhcpLeaseCount});
    :set ($pings->0) ([$getPingingMetrics]);
    :set cout {
        "ping"=$pings;
        "wap"=$wapArray;
        "interface"=$ifaceDataArray;
        "system"=$systemArray;
        "gauge"=$gauge
        };
    # :set cout [$toJon $cout]
    :return $cout;
};
# Function to remove special chars (\n, \r, \t) from strings;
# usages:
#   :put [$removeSpecialCharacters  [:tostr "Hello\nWorld!\r\t"]]
#   :put [:toarray [$removeSpecialCharacters ([/tool fetch url="https://cloudflare.com/cdn-cgi/trace" mode=http as-value output=user]->"data") t=";"]];
:global removeSpecialCharacters do={
  :local inputString $1;
  :local splitern $n;
  :local spliters $s;
  :local splitert $t;
  :local cleanString "";
  :local charcode "";
  :local lastidx 0;
  :local char [:convert [:tostr $inputString] to=hex];
  :for i from=2 to=[:len $char] step=2 do={
    :set charcode [:pick $char $lastidx $i];
    :if ($charcode != "0a" && $charcode != "0d" && $charcode != "09") do={
        :set cleanString ($cleanString . $charcode);
    } else={
        :if (any$splitern) do={
            :set cleanString ($cleanString . [:convert [:tostr $splitern] to=hex]);
        }
        :if (any$splitern) do={
            :set cleanString ($cleanString . [:convert [:tostr $splitern] to=hex]);
        }
        :if (any$splitert) do={
            :set cleanString ($cleanString . [:convert [:tostr $splitert] to=hex]);
        }
    }
    :set lastidx $i;
  }
  :return [:convert $cleanString from=hex];
}

# Function to get wanIp
# usage:
#   :put [$getWanIp]
:global getWanIp do={
    # WAN Port IP Address
    :local wanIp;
    # Check for PPPoE interface
    :local pppoeInterface [/interface pppoe-client find where running=yes disabled=no]
    :if ([:len $pppoeInterface] > 0) do={
      :set wanIp [ip address get [find where interface=[/interface pppoe-client get ($pppoeInterface->0) name]] address]
    } else={
      # Check for DHCP client
      :local dhcpClientIp [/ip dhcp-client get [find where status=bound] address]
      :if ([:len $dhcpClientIp] > 0) do={
        :set wanIp $dhcpClientIp;
      } else={
        # Check for IP address on the first Ethernet interface
        # get the first running ether interface name and find the matched ip address in that same vlan
        :set wanIp [:tostr [/ip address get [ find where interface=[/interface get ([find where running=yes type=ether]->0) name]] address]];
        # If none of the above, try using external service to determine public IP
        :if ([:len $wanIp] = 0) do={
          :set wanIp "";
        }
      }
    }
    :return [:pick $wanIp 0 [:find $wanIp "/"]];
}
# Function to construct update request
:global getUpdateBody do={
  :global getCollections;
  :global rosTsSec;
  :global getWanIp;
  :global toJson;
  :local upTime [/system resource get uptime];
  :local runcount 1;
  :set upTime [$rosTsSec $upTime];
  :if ([:len [/system script find where name~"ispappUpdate"]] > 0) do={
    :set runcount [/system script get ispappUpdate run-count];
  }
  :return [$toJson ({
    "collectors"=[$getCollections];
    "wanIp"=[$getWanIp];
    "uptime"=([:tonum $upTime]);
    "sequenceNumber"=$runcount
  })];
}
# Function to send update request and get back update response
# usage:
#   :local update ([$sendUpdate]); if ($update->"status") do={ :put ($update->"output"->"parsed"); }  
:global sendUpdate do={
  :global ispappHTTPClient;
  :global getUpdateBody;
  :global connectionFailures;
  :local response ({});
  :local requestBody "{}";
  :do {
    :set requestBody [$getUpdateBody];
    :set response [$ispappHTTPClient m=post a=update b=$requestBody];
    :return {
      "status"=true;
      "output"=$response;
    };
  } on-error={
    :log info ("HTTP Error, no response for /update request to ISPApp, sent " . [:len $requestBody] . " bytes.");
    :set connectionFailures ($connectionFailures + 1);
    :error "HTTP error with /update request, no response receieved.";
    :return {
      "status"=false;
      "reason"=$response;
    };
  }
}
# Function toperform speedtest and send results back to bandwith end point
:global SpeedTest do={
  :global ispappHTTPClient;
  :global toJson;
  :do {
    :local txAvg 0 
    :local rxAvg 0 
    :local txDuration 
    :local rxDuration 
    :local ds [/system clock get date];
    :local currentTime [/system clock get time];
    :set currentTime ([:pick $currentTime 0 2].[:pick $currentTime 3 5].[:pick $currentTime 6 8])
    :set ds ([:pick $ds 7 11].[:pick $ds 0 3].[:pick $ds 4 6])
    /tool bandwidth-test protocol=tcp direction=transmit address=$ipbandswtestserver user=$btuser password=$btpwd duration=5s do={
      :set txAvg ($"tx-total-average");
      :set txDuration ($"duration")
      }
    /tool bandwidth-test protocol=tcp direction=receive address=$ipbandswtestserver user=$btuser password=$btpwd duration=5s do={
    :set rxAvg ($"rx-total-average");
    :set rxDuration ($"duration")
    }
    :local results {
      "date"="$ds";
      "time"="$currentTime",
      "txAvg"="$txAvg";
      "rxAvg"="$rxAvg";
      "rxDuration"="$rxDuration";
      "txDuration"="$txDuration"
    };
    :local jsonResult [$toJson $results];
    :log debug ($jsonResult);
    :local result [$ispappHTTPClient a=bandwidth m=post b=$jsonResult];
    :put ($result);
  } on-error={
    :log info ("HTTP Error, no response for speedtest request with command error to ISPApp.");
  }
}
# Function to fetch Upgrade script and execute it
:global execActions do={
  :if ($a = "upgrade") do={
    :global topDomain;
    :global SpeedTest;
    :global login;
    :global topKey;
    :global topServerPort;
    :local upgradeUrl ("https://" . $topDomain . ":" . $topServerPort . "/v1/host_fw?login=" . $login . "&key=" . $topKey);
    :do {
          /tool fetch check-certificate=yes url="$upgradeUrl" output=file dst-path="ispapp-upgrade.rsc";
          /import "/ispapp-upgrade.rsc";
    } on-error={
      :error "HTTP error downloading upgrade file";
    }
    :return "";
  }
  :if ($a = "reboot") do={
    /system reboot;
    :return "";
  }
  :if ($a = "executeSpeedtest") do={
    :put [$SpeedTest];
    :return "";
  }
  :return "usage:\n\t \$execActions  a=<upgrade|reboot>";
}

# Functions to submit cmds to ispappConsole
:global submitCmds do={
  :global cmdsarray;
  :local added 0;
  if ([:typeof $1] != "array") do={
    :log error "Cmds comming from update response can't be submited";
    :return 0;
  };
  :local nextindex 0; 
  if (!any$cmdsarray) do={
    :set cmdsarray ({});
  } else={
    :set nextindex ([:len $cmdsarray]);
  }
  :foreach i,command in=$1 do={
    if (!any[:find [:tostr $command] "Err.Rais"]) do={
      :local cmd ($command->"cmd");
      :local stderr ($command->"stderr");
      :local stdout ($command->"stdout");
      :local uuidv4 ($command->"uuidv4");
      :local wsid ($command->"ws_id");
      :local cmdtraited false;
      :foreach i,scmd in=$cmdsarray do={
        if ($scmd->"uuidv4" = $uuidv4) do={
          :set cmdtraited true;
        }
      }
      :delay 1s;
      if (!$cmdtraited) do={
        :set ($cmdsarray->$nextindex) ({
          "cmd"=$cmd;
          "stderr"=$stderr;
          "stdout"=$stdout;
          "uuidv4"=$uuidv4;
          "ws_id"=$wsid;
          "executed"=false
        });
        :set added ($added + 1);
      }
    }
    :set nextindex ([:len $cmdsarray]);
  }
  :return "$added Commands was sent for processing ~\n";
}

# function to parse commands from web terminal
:global executeCmds do={
  :global cmdsarray;
  :global execCmd;
  :global base64EncodeFunct;
  :global toJson;
  :global ispappHTTPClient;
  :local output "";
  :local out ({});
  :local cmdJsonData "";
  :local object ({});
  :local lenexecuted 0;
  :local runcount 1;
  :if ([:len [/system script find where name~"ispappUpdate"]] > 0) do={
    :set runcount [/system script get ispappUpdate run-count];
  }
  if ([:len $cmdsarray] > 0) do={
    :foreach i,cmd in=$cmdsarray do={
      if ($cmd=>"executed" = false) do={
        :set output [$execCmd ($cmd->"cmd") ($cmd->"uuidv4")];
        :set object ({
          "cmd"=($cmd->"cmd");
          "uuidv4"=($cmd->"uuidv4");
          "ws_id"=($cmd->"ws_id");
          "sequenceNumber"=$runcount;
          "executed"=true
        }+$output);
        :set cmdJsonData [$toJson $object];
        :local nextidx [:len $out];
        :set ($out->$nextidx) ([$ispappHTTPClient a=cmdresponse m=post b=$cmdJsonData]->"status");
        :set ($cmdsarray->$i) $object;
        :set lenexecuted ($lenexecuted + 1);
      }
    } 
  }
  if ([:len $cmdsarray] > 5) do={
    :set $cmdsarray [:pick $cmdsarray ([:len $cmdsarray] - 5) ([:len $cmdsarray])]; 
  }
  :return {
    "responses"=$out;
    "msg"="$lenexecuted commands was executed with success."
  };
};
# Function to exec a cmd for ROS older than 7.8 and newer ones too
# usage: :put [$execCmd "/ip address print" "uuid"];
# return: {"stderr"=...; "stdout"=...}
:global execCmd do={
  :global cmpversion;
  :global base64EncodeFunct;
  :local output "error timeout!";
  :local parsedcmd;
  :local timeout 30;
  :local wait 0;
  :local cmd $1;
  :local outputFilename "_filename_.txt";
  :global scriptname;
  if ([:len $2] > 0) do={
    :set outputFilename ($2 . "ispappCommandOutput.txt");
    :set scriptname ($2 . "ispappCommand");
  } else={
    :set output [$base64EncodeFunct stringVal="❌ no uuidv4 with command!"];
    :return {"stderr"="$output"; "stdout"=""};
  }
  :do {
    :set parsedcmd [:parse ($cmd)]; # check if cmd have correct syntax
    if ([:len [/system script find name~"$scriptname"]] = 0) do={
      /system script add name="$scriptname" source="$cmd";
    } else={
       /system script set [find name~"$scriptname"] source="$cmd";
    }
    :local jobid [:execute script={/system script run "$scriptname";} file=$outputFilename];
    :delay 2s;
    # :put ([:len [/system script job find where script~"$scriptname"]] > 0 && $wait <= $timeout);
    :while ([:len [/system script job find where script~"$scriptname"]] > 0 && $wait <= $timeout) do={
      :local remains ($timeout - $wait);
      :put "waiting $remains seconds more for job with id:$jobid";
      :delay 1s;
      :set wait ($wait + 1);
    }
    if ($wait > $timeout && [:len [/file get $outputFilename size]] = 0) do={
      :do { /system script job remove $jobid } on-error={}
      /file remove [find where name~"$outputFilename"];
      /system script remove [find where name~"$scriptname"];
      :set output [$base64EncodeFunct stringVal=$output];
      :return {"stderr"="$output"; "stdout"=""};
    } else={
      :set output [/file get $outputFilename contents];
      :set output [$base64EncodeFunct stringVal=$output];
      /file remove [find where name~"$outputFilename"];
      /system script remove [find where name~"$scriptname"];
      if ([:len $output] = 0) do={
        :set output [$base64EncodeFunct stringVal="✅ Executed with success"];
      }
      :return {"stderr"=""; "stdout"="$output"};
    }
  } on-error={
    :set output [$base64EncodeFunct stringVal="❌ Command can't be executed"];
    /file remove [find where name~"$outputFilename"];
    /system script remove [find where name~"$scriptname"];
    :return {"stderr"="$output"; "stdout"=""};
  }
}
# Function to back up router config and sent result back vi an email
:global ConfigBackup do={
  :global rosTimestringSec;
  :do {
      # get the unix timestamp
      :global lastLocalConfigurationBackupSendTs;
      # non documented typeof value of nothing happens when you delete an environment variable, RouterOS 6.49.7
      if ([:typeof $lastLocalConfigurationBackupSendTs] = "nil" || [:typeof $lastLocalConfigurationBackupSendTs] = "nothing") do={
        # set first value
        :set lastLocalConfigurationBackupSendTs 0;
      }
      :local currentTimestring ([/system clock get date] . " " . [/system clock get time]);
      :local currentTs [$rosTimestringSec $currentTimestring];
      :local lastBackupDiffSec ($currentTs - $lastLocalConfigurationBackupSendTs);
      #:log info ("lastBackupDiffSec", $lastBackupDiffSec);
      if ($lastBackupDiffSec > 60 * 60 * 12) do={
        # send a new local configuration backup every 12 hours
        :log info ("sending new local configuration backup");
        :execute {
          # set last backup time
          :local lastLocalConfigurationBackupSendTimestring ([/system clock get date] . " " . [/system clock get time]);
          :global lastLocalConfigurationBackupSendTs [$rosTimestringSec $lastLocalConfigurationBackupSendTimestring];
          # send backup
          # run the script and place the output in a known file
          :local scriptJobId [:execute script={/export terse;} file=ispappBackup.txt];
          # wait 10 minutes for the export to finish
          :delay 600s;
          :global login;
          :global simpleRotatedKey;
          :global topDomain;
          :global topSmtpPort;
          /tool e-mail send server=($topDomain) from=($login . "@" . $simpleRotatedKey . ".ispapp.co") to=("backup@" . $topDomain) port=($topSmtpPort) file="ispappBackup.txt" subject="c" body="{}";
        };
      }
  } on-error={
    :log info ("ISPApp, error with configuration backups.");
  }
};

# Function to get system version and compare to input version
# usage:
#       :put [$cmpversion] or :put [$cmpversion cmp="6.8"]
:global cmpversion do={
  :local thisversion [/system resource get version];
  :set thisversion [:pick $thisversion 0 [:find $thisversion " "]];
  :local cmp $1;
  if (!any$1) do={
    :set cmp $thisversion;
  }
  :local version do={
    :local v "";
    :for i from=0 to=[:len $1] do={
      :local char [:pick $1 $i ($i+1)];
      if (any[:tonum $char]) do={
        :set v ($v . $char);
      }
    }
    if ([:len $1] > [len $v]) do={
      :for i from=[len $v] to=[:len $1] do={ 
        :set v ($v . "0");
      }
    }
    :return [:tonum $v];
  }
  :return {
    "current"=([$version $thisversion]);
    "target"=([$version $cmp]);
    "compatible"=([$version $thisversion] >= [$version $cmp])
  }
};
# convert buit-time to timestamp
:global getTimestamp do={
  # Nov/09/2023 07:45:06 - input ›
  :if (!any$1) do={:return 0;}
  :global strcaseconv;
  :local pYear [:pick $1 7 11];
  :local pday [:pick $1 4 6];
  :local pmonth [:pick $1 0 3];
  :local phour [:pick $1 12 14];
  :local pminute [:pick $1 15 17];
  :local psecond [:pick $1 18 20];
  :local monthNames [:toarray "jan,feb,mar,apr,may,jun,jul,aug,sep,oct,nov,dec"];
  :local monthDays (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
  :local monthName ([$strcaseconv $pmonth]->"lower");
  :local monthNum ([:find $monthNames $monthName]);
  :put ($monthNum);
  :local month 0;
  :foreach i in=[:pick $monthDays 0 $monthNum] do={ :set month ($month + ([:tonum $1] * 86400)) };
  :local day (([:tonum $pday] - 1) * 86400)
  :local years ([:tonum $pYear] - 1970);
  :local leapy (([:tonum $pYear] - 1972) / 4);
  :local noleapy ($years - $leapy)
  if ((([:tonum $pYear] - 1970) % 4) = 2) do={
    :set leapy ($leapy - 1);
    if (($monthNum + 1) >= 2) do={ :set month ($month - 86400); }
  } else={ :set noleapy ($noleapy - 1) }
  :set years (($leapy * 31622400) + ($noleapy * 31536000))
  :local time ((([:tonum $phour] - 1)*3600)+(([:tonum $pminute] - 1)*60)+([:tonum $psecond]))
  :return ($month + $day + $years + $time);
}
:put "\t V4 Library loaded! (;";