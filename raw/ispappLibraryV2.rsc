
# for checking purposes
:global ispappLibraryV2 "ispappLibraryV2 loaded";
# Function to get timestamp in seconds, minutes, hours, or days
# save it in a global variable to get diff between it and the current timestamp.
# synctax:
#       :put [$getTimestamp <s|m|d|h> <your saved timestamp variable to get diff>]
:global getTimestamp do={
    :local format $1;
    :local out;
    :local time2parse [:timestamp]
    :local w [:find $time2parse "w"]
    :local d [:find $time2parse "d"]
    :local c [:find $time2parse ":"]
    :local p [:find $time2parse "."]
    :local weeks [:pick $time2parse 0 [$w]]
    :set $weeks [:tonum ($weeks * 604800)]
    :local days [:pick $time2parse ($w + 1) $d]
    :set days [:tonum ($days * 86400)]
    :local hours [:pick $time2parse ($d + 1) $c]
    :set hours [:tonum ($hours * 3600)]
    :local minutes [:pick $time2parse ($c + 1) [:find $time2parse ($c + 3)]]
    :set minutes [:tonum ($minutes * 60)]
    :local seconds [:pick $time2parse ($c + 4) $p]
    :local rawtime ($weeks+$days+$hours+$minutes+$seconds)
    :local current ($weeks+$days+$hours+$minutes+$seconds)
    :global lastTimestamp $lastTimestamp;
    if ([:typeof $2] = "num") do={
        :set lastTimestamp $2;
    }
    :if ($format = "s") do={
      :local diff ($rawtime - $lastTimestamp);
      :set out { "current"=$current; "diff"=$diff;}
      :global lastTimestamp $rawtime;
      :return $out;
    } else={
      :if ($format = "m") do={
           :local diff (($rawtime - $lastTimestamp)/60);
           :set out { "current"=$current; "diff"=$diff }
           :global lastTimestamp $rawtime;
           :return $out;
      } else={
        :if ($format = "h") do={
           :local diff (($rawtime - $lastTimestamp)/3600);
           :set out { "current"=$current; "diff"=$diff }
           :global lastTimestamp $rawtime;
           :return $out;
        } else={
          :if ($format = "d") do={
               :local diff (($rawtime - $lastTimestamp)/86400);
               :set out { "current"=$current; "diff"=$diff }
               :global lastTimestamp $rawtime;
               :return $out;
          } else={
              :local diff ($rawtime - $lastTimestamp);
              :set out { "current"=$current; "diff"=$diff }
              :global lastTimestamp $rawtime;
              :return $out;
          }
        }
      }
    }
}
# Function to collect all information needed yo be sent to config endpoint
# usage: 
#   :put [$getAllConfigs <interfacesinfos array>] 
# result will be in this format:
#      ("{"clientInfo":"$topClientInfo", "osVersion":"$osversion", "hardwareMake":"$hardwaremake",
#     "hardwareModel":"$hardwaremodel","hardwareCpuInfo":"$cpu","os":"$os","osBuildDate":$osbuilddate
#     ,"fw":"$topClientInfo","hostname":"$hostname","interfaces":[$ifaceDataArray],"wirelessConfigured":[$wapArray],
#     "webshellSupport":true,"bandwidthTestSupport":true,"firmwareUpgradeSupport":true,"wirelessSupport":true}");

:global getAllConfigs do={
    :do {
        :global rosTimestringSec;
        :global toJson;
        :global topClientInfo;
        :local data;
        :local buildTime [/system resource get build-time];
        :local osbuilddate [$rosTimestringSec $buildTime];
        :local interfaces;
        foreach k,v in=[/interface/find] do={
            :local Name [/interface get $v name];
            :local Mac [/interface get $v mac-address];
            :local DefaultName [:parse "/interface get \$1 default-name"];
            :set ($interfaces->$k) {
                "if"=$Name;
                "mac"=$Mac;
                "defaultIf"=[$DefaultName $v]
            };
        }
        :set osbuilddate [:tostr $osbuilddate];
        :set data {
            "clientInfo"=$topClientInfo;
            "osVersion"=[/system resource get version];
            "hardwareMake"=[/system resource get platform];
            "hardwareModel"=[/system resource get board-name];
            "hardwareCpuInfo"=[/system resource get cpu];
            "osBuildDate"=[$rosTimestringSec [/system resource get build-time]];
            "hostname"=[/system identity get name];
            "os"=[/system package get 0 name];
            "wirelessConfigured"=$1;
            "webshellSupport"=true;
            "firmwareUpgradeSupport"=true;
            "wirelessSupport"=true;
            "interfaces"=$interfaces;
            "security-profiles"=$2;
            "bandwidthTestSupport"=true;
            "fw"=$topClientInfo
        };
        :local json [$toJson $data];
        :log info "Configs body json created with success (getAllConfigsFigs function -> true).";
        :return {"status"=true; "json"=$json};
    } on-error={
        :log error "faild to build config json object!";
        :return {"status"=false; "reason"="faild to build config json object!"};
    }
}

# Function to check if credentials are ok
# get last login state and save it for avoiding server loading 
# syntax:
#       :put [$loginIsOk] \\ result: true/false
:global loginIsOk do={
    # check if login and password are correct
    # :global loginIsOkLastCheck $loginIsOkLastCheck;
    # if (!any $loginIsOkLastCheck) do={
    #     :global loginIsOkLastCheck ([$getTimestamp]->"current");
    # } else={
    #     :local difft ([$getTimestamp s $loginIsOkLastCheck]->"diff") ;
    #     if ($difft < -30) do={
    #         :return $loginIsOkLastCheckvalue;
    #     } 
    # }
    # :if (any $TopVariablesDiagnose) do={
    #     :local resTopCheck [$TopVariablesDiagnose];
    #     :log info [:tostr $resTopCheck]
    # }
    :global loginIsOkLastCheckvalue;
    :global topDomain;
    :global topListenerPort;
    :global login;
    :global topKey;
    if (!any $loginIsOkLastCheckvalue) do={
        :set loginIsOkLastCheckvalue false;
    }
    :do {
        # :set loginIsOkLastCheck ([$getTimestamp]->"current");
        :local res [/tool fetch url="https://$topDomain:$topListenerPort/update?login=$login&key=$topKey" mode=https check-certificate=yes output=user as-value];
        :set loginIsOkLastCheckvalue ($res->"status" = "finished");
        :log info "check if login and password are correct completed with responce: $loginIsOkLastCheckvalue";
        :return $loginIsOkLastCheckvalue;
    } on-error={
        :log info "check if login and password are correct completed with responce: error";
        :set loginIsOkLastCheckvalue false;
        :return $loginIsOkLastCheckvalue;
    }
};
# a function to persist variables in a script called ispapp_credentials
:global savecredentials do={
  :global topKey;
  :global topDomain;
  :global topClientInfo;
  :global topListenerPort;
  :global topServerPort;
  :global topSmtpPort;
  :global txAvg;
  :global rxAvg;
  :global ipbandswtestserver;
  :global btuser;
  :global btpwd;
  :global librarylastversion;
  /system/script/remove [/system/script/find where name~"ispapp_credentials"]
  :local cridentials "\n:global topKey $topKey;\r\
    \n:global topDomain $topDomain;\r\
    \n:global topClientInfo $topClientInfo;\r\
    \n:global topListenerPort $topListenerPort;\r\
    \n:global topServerPort $topServerPort;\r\
    \n:global topSmtpPort $topSmtpPort;;
    \n:global txAvg 0;\r\
    \n:global rxAvg 0;\r\
    \n:global ipbandswtestserver $ipbandswtestserver;\r\
    \n:global btuser $btuser;\r\
    \n:global librarylastversion $librarylastversion;\r\
    \n:global btpwd $btpwd;"
  /system/script/add name=ispapp_credentials source=$cridentials
  :log info "ispapp_credentials updated!";
  :return "ispapp_credentials updated!";
}
:put "\t V2 Library loaded! (;";
# Function to collect data necessary to update request
:global getcollectUpDataVal do={
    :local systemArray ({
        "load"={
            "one"=$cpuLoad;
            "five"=$cpuLoad;
            "fifteen"=$cpuLoad;
            "processCount"=$processCount
            };
        "memory"={
            "total"=$totalMem;
            "free"=$freeMem;
            "buffers"=$memBuffers;
            "cached"=$cachedMem
            };
        "disks":[$diskJsonString];
        "connDetails":{
            "connectionFailures"=$connectionFailures
        }
    });
}

# collect cpu load and calculates avrg of 5 and 15
:global getCpuLoads do={
  :do {
    :global cpularray;
    :local Array5 [:pick $cpularray 0 5];
    :local Array15 [:pick $cpularray 0 15];
    :local someArray5 0;
    :local someArray15 0;
    :foreach k in=$Array15 do={ :set someArray15 ($k+$someArray15); }
    :foreach k in=$Array5 do={ :set someArray5 ($k+$someArray5); }
    :set cpularray ($cpularray, [:tonum [/system resource get cpu-load]]);
    :set cpularray [:pick $cpularray ([:len $cpularray] - 15) [:len $cpularray]];
    :return {
      "cpuLoadOne"=[/system resource get cpu-load];
      "cpuLoadFive"=($someArray5 / [:len $Array5]);
      "cpuLoadFifteen"=($someArray15 / [:len $Array15])
    }
    :log debug "ispappAvgCpuCollector complete";
  } on-error={
    :return {
      "cpuLoadOne"=[/system resource get cpu-load];
      "cpuLoadFive"=[/system resource get cpu-load];
      "cpuLoadFifteen"=[/system resource get cpu-load]
    }
    :log error "ispappAvgCpuCollector did not complete with success!";
  }
}
# Function to collect metric from each interface and format them as array
# usage:
#    :put [$collectInterfacesMetrics]
:global collectInterfacesMetrics do={
  :local cout ({});
  :foreach i,iface in=[/interface find] do={
    :set ($cout->$i) {
    "if"=[/interface get $iface name];
    "recBytes"=[/interface get $iface rx-byte];
    "recPackets"=[/interface get $iface rx-packet];
    "recErrors"=[/interface get $iface rx-error];
    "recDrops"=[/interface get $iface rx-drop];
    "sentBytes"=[/interface get $iface tx-byte];
    "sentPackets"=[/interface get $iface tx-packet];
    "sentErrors"=[/interface get $iface tx-error];
    "sentDrops"=[/interface get $iface tx-drop];
    "carrierChanges"=[/interface get $iface link-downs];
    "macs"=[:len [/ip arp find where interface=$ifaceName]]
    }
  }
  :return $cout;
}
# Function to collect wireless interface stations metrics 
# look for wapCollector function for more usage details;
:global getWirelessStas do={
  :local staout ({});
  :local wIfNoise 0;
  :local wStaNoise 0;
  :local wStaRssi 0;
  :local wStaSig0 0;
  :local wStaSig1 0;
  :local wIfSig1 0;
  :local wIfSig0 0;
  :global rosTsSec;
  :foreach i,wStaId in=[/interface wireless registration-table find where interface=$1] do={
        :local wStaMac ([/interface wireless registration-table get $wStaId mac-address]);
        :local wStaRssi ([/interface wireless registration-table get $wStaId signal-strength]);
        :set wStaRssi ([:pick $wStaRssi 0 [:find $wStaRssi "dBm"]]);
        :set wStaRssi ([:tonum $wStaRssi]);
        :set wStaNoise ($wStaRssi - [:tonum [/interface wireless registration-table get $wStaId signal-to-noise]]);
        :set wStaSig0 ([:tonum [/interface wireless registration-table get $wStaId signal-strength-ch0]]);
        :set wStaSig1 ([:tonum [/interface wireless registration-table get $wStaId signal-strength-ch1]]);
        if ([:len $wStaSig1] = 0) do={
          :set wStaSig1 0;
        }
        :local wStaExpectedRate ([/interface wireless registration-table get $wStaId p-throughput]);
        :local wStaAssocTime ([/interface wireless registration-table get $wStaId uptime]);
        # convert the associated time to seconds
        :local assocTimeSplit [$rosTsSec $wStaAssocTime];
        :set wStaAssocTime $assocTimeSplit;
        # set the interface values
        :set wIfNoise ($wIfNoise + $wStaNoise);
        :set wIfSig0 ($wIfSig0 + $wStaSig0);
        :set wIfSig1 ($wIfSig1 + $wStaSig1);
        :local wStaIfBytes ([/interface wireless registration-table get $wStaId bytes]);
        :local wStaIfSentBytes ([:pick $wStaIfBytes 0 [:find $wStaIfBytes ","]]);
        :local wStaIfRecBytes ([:pick $wStaIfBytes 0 [:find $wStaIfBytes ","]]);
        :local wStaDhcpName ([/ip dhcp-server lease find where mac-address=$wStaMac]);
        if ($wStaDhcpName) do={
          :set wStaDhcpName ([/ip dhcp-server lease get $wStaDhcpName host-name]);
        } else={
          :set wStaDhcpName "";
        }
        :local newSta;
        :set ($staout->$i) {
          "mac"=$wStaMac;
          "expectedRate"=$wStaExpectedRate;
          "assocTime"=$wStaAssocTime;
          "noise"=$wStaNoise;
          "signal0"=$wStaSig0;
          "signal1"=$wStaSig1;
          "rssi"=$wStaRssi;
          "sentBytes"=$wStaIfSentBytes;
          "recBytes"=$wStaIfRecBytes;
          "info"=$wStaDhcpName
        };
      }
    :local count [:len $staout];
    if ($count = 0) do={
      :set count 1;
    }
    :set wIfNoise (-$wIfNoise / $count)
    :return {
      "stations"=$staout;
      "noise"=$wIfNoise;
      "signal0"=$wIfSig0;
      "signal1"=$wIfSig1
    };
}
# Function to collect cap-man managed interface stations metrics 
# look for wapCollector function for more usage details;
:global getCapsStas do={
  :local staout ({});
  :local wIfNoise 0;
  :local wStaNoise 0;
  :local wStaRssi 0;
  :local wStaSig0 0;
  :local wStaSig1 0;
  :local wIfSig1 0;
  :local wIfSig0 0;
  :global rosTsSec;
  :foreach i,wStaId in=[/caps-man registration-table find where  interface=$1] do={
      :local wStaMac ([/caps-man registration-table get $wStaId mac-address]);
      :local wStaRssi ([/caps-man registration-table get $wStaId signal-strength]);
      :set wStaRssi ([:pick $wStaRssi 0 [:find $wStaRssi "dBm"]]);
      :set wStaRssi ([:tonum $wStaRssi]);
      :local wStaNoise ([/caps-man registration-table get $wStaId signal-to-noise]);
      :set wStaNoise ($wStaRssi - [:tonum $wStaNoise]);
      :local wStaSig0 ([/caps-man registration-table get $wStaId signal-strength-ch0]);
      :set wStaSig0 ([:tonum $wStaSig0]);
      :local wStaSig1 ([/caps-man registration-table get $wStaId signal-strength-ch1]);
      :set wStaSig1 ([:tonum $wStaSig1]);
      if ([:len $wStaSig1] = 0) do={
        :set wStaSig1 0;
      }
      :local wStaExpectedRate ([/caps-man registration-table get $wStaId p-throughput]);
      :local wStaAssocTime ([/caps-man registration-table get $wStaId uptime]);
      # convert the associated time to seconds
      :local assocTimeSplit [$rosTsSec $wStaAssocTime];
      :set wStaAssocTime $assocTimeSplit;
      # set the interface values
      :set wIfNoise ($wIfNoise + $wStaNoise);
      :set wIfSig0 ($wIfSig0 + $wStaSig0);
      :set wIfSig1 ($wIfSig1 + $wStaSig1);
      :local wStaIfBytes ([/caps-man registration-table get $wStaId bytes]);
      :local wStaIfSentBytes ([:pick $wStaIfBytes 0 [:find $wStaIfBytes ","]]);
      :local wStaIfRecBytes ([:pick $wStaIfBytes 0 [:find $wStaIfBytes ","]]);
      :local wStaDhcpName ([/ip dhcp-server lease find where mac-address=$wStaMac]);
      if ($wStaDhcpName) do={
        :set wStaDhcpName ([/ip dhcp-server lease get $wStaDhcpName host-name]);
      } else={
        :set wStaDhcpName "";
      }
      :local newSta;
      :set ($staout->$i) {
        "mac"=$wStaMac;
        "expectedRate"=$wStaExpectedRate;
        "assocTime"=$wStaAssocTime;
        "noise"=$wStaNoise;
        "signal0"=$wStaSig0;
        "signal1"=$wStaSig1;
        "rssi"=$wStaRssi;
        "sentBytes"=$wStaIfSentBytes;
        "recBytes"=$wStaIfRecBytes;
        "info"=$wStaDhcpName
      };
  }
  :local count [:len $staout];
  if ($count = 0) do={
    :set count 1;
  }
  :set wIfNoise (-$wIfNoise / $count)
  :return {
    "stations"=$staout;
    "noise"=$wIfNoise;
    "signal0"=$wIfSig0;
    "signal1"=$wIfSig1
  };
}
# Function to wap interfaces metrics (work on progress ...)
# usage:
#   :put [$wapCollector]
:global wapCollector do={
  :local cout ({});
  :if (([/caps-man manager print as-value]->"enabled")) do={
    :foreach i,wIfaceId in=[/caps-man interface find] do={
      :local ifName [/caps-man interface get $wIfaceId name]; 
      :local staout [$getWirelessStas $ifName];
      :local stations ({});
      :if ([:len ($staout->"stations")] > 0) do={
        :set stations ($staout->"stations");
      }
      :set ($cout->$i) {
        "stations"=$stations;
        "interface"=$ifName;
        "ssid"=[/caps-man interface get $wIfaceId configuration.ssid];
        "noise"=($staout->"noise");
        "signal0"=($staout->"signal0");
        "signal1"=($staout->"signal1")
        };
    }
  } else={
    :if ([:len [/interface/wireless/find]] > 0) do={
      :foreach i,wIfaceId in=[/interface wireless find] do={
        :local ifName [/interface wireless get $wIfaceId name]; 
        :local staout [$getWirelessStas $ifName]
        :local stations ({});
        :if ([:len ($staout->"stations")] > 0) do={
          :set stations ($staout->"stations");
        }
        :set ($cout->$i) {
          "stations"=$stations;
          "interface"=$ifName;
          "ssid"=[/interface wireless get $wIfaceId ssid];
          "noise"=($staout->"noise");
          "signal0"=($staout->"signal0");
          "signal1"=($staout->"signal1")
          };
      }
    } else={
      # todo 
      :foreach i,wIfaceId in=[/interface wifiwave2 find] do={
        :set ($cout->$i) {
        "stations"=({});
        "interface"=[/interface wifiwave2 get $wIfaceId name];
        "ssid"=[/interface wifiwave2 get $wIfaceId configuration.ssid];
        "noise"=-1;
        "signal0"=-1;
        "signal1"=-1
        };
      }
    }
  }
  :return $cout;
}
