# Function to collect pinging stats from device to $topdomain;
:global getPingingMetrics do={
    :global topDomain;
    :local avgRtt 0;
    :local minRtt 0;
    :local maxRtt 0;
    :local totalpingsreceived 0;
    :local totalpingssend 5;
    :do {
        :local res [/tool flood-ping count=5 size=64 address=[:resolve $topDomain] as-value];
        :set totalpingsreceived ($res->"received");
        :set avgRtt ($res->"avg-rtt");
        :set minRtt ($res->"min-rtt");
        :set maxRtt ($res->"max-rtt");
    } on-error={
      :put ("TOOL FLOOD_PING ERROR");
    }
    :local oneStepPercent (100 / $totalpingssend);
    :local percentage 0;
    for i from=0 to=($totalpingssend-1) do={
      if ($i < $totalpingsreceived) do={
        :set percentage ($percentage + $oneStepPercent);
      }
    }
    :set percentage (100 - $percentage);
    :return ({
        "host"="$topDomain";
        "avgRtt"=([:tonum $avgRtt]);
        "loss"=([:tonum $percentage]);
        "minRtt"=([:tonum $minRtt]);
        "maxRtt"=([:tonum $maxRtt])
    });
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
  :if ([:len [/system/script/find where name~"ispappUpdate"]] > 0) do={
    :set runcount [/system/script/get ispappUpdate run-count];
  }
  :return [$toJson ({
    "collectors"=[$getCollections];
    "wanIp"=[$getWanIp];
    "uptime"=([:tonum $upTime]);
    "sequenceNumber"=$runcount
  })];
}
# Function to send update request and get back update responce
# usage:
#   :local update ([$sendUpdate]); if ($update->"status") do={ :put ($update->"output"->"parsed"); }  
:global sendUpdate do={
  :global ispappHTTPClient;
  :global getUpdateBody;
  :global connectionFailures;
  :local responce ({});
  :local requestBody "{}";
  :do {
    :set requestBody [$getUpdateBody];
    :set responce [$ispappHTTPClient m=post a=update b=$requestBody];
    :return {
      "status"=true;
      "output"=$responce;
    };
  } on-error={
    :log info ("HTTP Error, no response for /update request to ISPApp, sent " . [:len $requestBody] . " bytes.");
    :set connectionFailures ($connectionFailures + 1);
    :error "HTTP error with /update request, no response receieved.";
    :return {
      "status"=false;
      "reason"=$responce;
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
    :return;
  }
  :if ($a = "reboot") do={
    /system reboot;
    :return;
  }
  :if ($a = "executeSpeedtest") do={
    :put [$SpeedTest];
  }
  :return "usage:\n\t \$execActions  a=<upgrade|reboot>";
}
:put "\t V4 Library loaded! (;";