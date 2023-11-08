
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
:put "\t V2 Library loaded! (;";
# Function to send updates to host
# usage: 
#       :put [$HostDataUpdate] // result: {status=<bool>; bayload=<post_request_payload | none>, error_reason=<string>}
# params: none
# requirements: ispappLibraryV1 and ispappInit
# tasks performed by the function:
#   - collect data from the device and format it in json using the fuction toJson
#   - check updates comming from the host and apply them to device
#   - run cmds and return results
# :global HostDataUpdate do={
#     :local ssl [$prepareSSL];
#     :if (($ssl->"caStatus" = false) || ($ssl->"ntpStatus" = false)) do={
#         :log error [:tostr $ssl];
#     }
#     :if (![$loginIsOk]) do={
#         :log error [:tostr $login];
#         [$TopVariablesDiagnose];
#         :if (![$loginIsOk]) do={
#             :log error "login faild! check your topKey global variable!!";
#             :return { "status"=false; "error_reason"="login faild! check your topKey global variable" }
#         }
#     }
#     :local sequenceNumber [[:parse "/system/scheduler/get ispappUpdate run-count"]];
#     :local upTime [/system resource get uptime];
#     :local collectedData {
#         "collectors"={};
#         "wanIp"=;
#         "uptime"=$upTime;
#         "sequenceNumber"=$sequenceNumber;
#     };
    
# }

