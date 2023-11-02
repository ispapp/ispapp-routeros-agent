
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
    if (!any $lastTimestamp) do={
        :global lastTimestamp $rawtime;
    }
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
        :local data {
            "clientInfo"=$topClientInfo;
            "osVersion"=[/system resource get version];
            "hardwareMake"=[/system resource get platform];
            "hardwareModel"=[/system resource get board-name];
            "hardwareCpuInfo"=[/system resource get cpu];
            "osBuildDate"=[$rosTimestringSec [/system resource get build-time]];
            "fw"=$topClientInfo;
            "interfaces"=$interfaces;
            "hostname"=[/system identity get name];
            "os"=[/system package get 0 name];
            "wirelessConfigured"=$1;
            "webshellSupport"=true;
            "firmwareUpgradeSupport"=true;
            "wirelessSupport"=true;
            "bandwidthTestSupport"=true
        };
        :local json [$toJson $data];
        :log info "Configs body json created with success (getAllConfigsFigs function -> true).";
        :return {"status"=true; "json"=$json};
    } on-error={
        :log error "faild to build config json object!";
        :return {"status"=false; "reason"="faild to build config json object!"};
    }
}
