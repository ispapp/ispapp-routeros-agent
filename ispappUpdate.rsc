/system script add dont-require-permissions=yes name=ispappUpdate owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
:local sameScriptRunningCount [:len [/system script job find script=ispappUpdate]];

if (\$sameScriptRunningCount > 1) do={
  :error (\"ispappUpdate script already running \" . \$sameScriptRunningCount . \" times\");
}
# include functions
:global rosTsSec;
:global Split;
# CMD and fastUpdate
:global updateSequenceNumber;
:global connectionFailures;
:global configScriptSuccessSinceInit;
:global updateScriptSuccessSinceInit;
:global rosMajorVersion;
:global rosTimestringSec;
:global topDomain;
:global topKey;
:global topListenerPort;
:global topServerPort;
:global topSmtpPort;
:global login;
:global ipbandswtestserver;
:global btuser;
:global btpwd;
:if ([:len \$topDomain] = 0 || [:len \$topKey] = 0 || [:len \$topListenerPort] = 0 || [:len \$topServerPort] = 0 || [:len \$topSmtpPort] = 0 || [:len \$login] = 0) do={
  /system script run ispappInit;
  :error \"required ISPApp environment variable was empty, running ispappInit\"
}
:global urlEncodeFunct;

:global simpleRotatedKey;

:global collectUpDataVal;
:if ([:len \$collectUpDataVal] = 0) do={
  :set collectUpDataVal \"{}\";
}

# WAN Port IP Address
:global wanIP;
:do {

  :do {
    :local gatewayStatus ([:tostr [/ip route get [:pick [find dst-address=0.0.0.0/0 active=yes] 0] gateway-status]]);

    #:put \"gatewayStatus: \$gatewayStatus\";

    # split the gateway status into
    # IP/NM, reachable status, via, interface
    :local gwStatusArray [\$Split \$gatewayStatus \" \"];
    #:put \"\$gwStatusArray\";

    # get ip address and netmask as IP/Netmask
    :local lenGwStatusArray 0;
    :foreach i in=\$gwStatusArray do={
      :set lenGwStatusArray (\$lenGwStatusArray + 1);
    }
    :local tempIpv4String [/ip address get [:pick [/ip address find interface=(\$gwStatusArray->(\$lenGwStatusArray-1))] 0] address];
    # split by /
    :local wanIpv4Arr [\$Split \$tempIpv4String \"/\"];
    # set the wan ip
    :set wanIP (\$wanIpv4Arr->0);
  } on-error={
    :local tmpGateway ([:tostr [/ip route get [:pick [find dst-address=0.0.0.0/0 active=yes]] gateway ] ]);
    :local getInterfaceName ([:tostr [/ip arp get [:pick [find address=\$tmpGateway]] interface ] ]);
    :global tmpWanIP;
    :foreach ipList in=([/ip address find]) do={
      :local ipAddressInterfaceName ([/ip address get \$ipList interface]);
      :local ipAddressInterfaceDyanamic ([/ip address get \$ipList dynamic]);
      :if ( \$ipAddressInterfaceName = \$getInterfaceName && \$ipAddressInterfaceDyanamic = true) do={
        :local ipAddressNetwork ([/ip address get \$ipList address ]);
        :set tmpWanIP ([:pick \$ipAddressNetwork 0 [:find \$ipAddressNetwork \"/\"]]);
      }
    }
    :set wanIP (\$tmpWanIP);
  }

} on-error={
  :set wanIP \"\";
  #:log info (\"Error finding WAN IP.\");
}

:local upTime [/system resource get uptime];
:local upSeconds [\$rosTsSec \$upTime];

:local collectUpData \"{\\\"collectors\\\":\$collectUpDataVal,\\\"wanIp\\\":\\\"\$wanIP\\\",\\\"uptime\\\":\$upSeconds,\\\"sequenceNumber\\\":\$updateSequenceNumber}\";

:local updateUrl (\"https://\" . \$topDomain . \":\" . \$topListenerPort . \"/update?login=\" . \$login . \"&key=\" . \$topKey);

if ( \$updateScriptSuccessSinceInit = false || \$configScriptSuccessSinceInit = false ) do={
  # show verbose output until the config script and update script succeed
  :put \"sending data to /update\";
  :put \$updateUrl;
  :put (\"\$collectUpData\");
}

:local updateResponse;
:local cmdsArrayLenVal;

:do {
    :set updateResponse ([/tool fetch check-certificate=yes mode=https http-method=post http-header-field=\"cache-control: no-cache, content-type: application/json\" http-data=\"\$collectUpData\" url=\$updateUrl as-value output=user]);
    if ( \$updateScriptSuccessSinceInit = false || \$configScriptSuccessSinceInit = false ) do={
      # show verbose output until the config script and update script succeed
      :put (\"updateResponse\");
      :put (\$updateResponse);
	}

} on-error={
  :log info (\"HTTP Error, no response for /update request to ISPApp, sent \" . [:len \$collectUpData] . \" bytes.\");
  :set connectionFailures (\$connectionFailures + 1);
  :error \"HTTP error with /update request, no response receieved.\";
}
:set updateSequenceNumber (\$updateSequenceNumber + 1);
  :global JSONIn;
  :global JParseOut;
  :global fJParse;
    
  :set JSONIn (\$updateResponse->\"data\");
  :set JParseOut [\$fJParse];
    
  if ( [:len \$JParseOut] != 0 ) do={

    # show the json output in the log
    #:log info \$JParseOut;
    :local jsonError (\$JParseOut->\"error\");
	
	if ( \$jsonError = nil ) do={
	  # there were no errors, set that the update script has succeeded since init
	  :set updateScriptSuccessSinceInit true;
	}

    :set simpleRotatedKey (\$JParseOut->\"simpleRotatedKey\");

    :local fwStatus (\$JParseOut->\"fwStatus\");
    if (\$fwStatus = \"pending\") do={
      :global upgrading;

      if (\$upgrading = true) do={
        :error \"another upgrade is running\";
      }
      :set upgrading true;

      :local upgradeUrl (\"https://\" . \$topDomain . \":\" . \$topServerPort . \"/v1/host_fw?login=\" . \$login . \"&key=\" . \$topKey);

      :do {
        /tool fetch check-certificate=yes url=\"\$upgradeUrl\" output=file dst-path=\"ispapp-upgrade.rsc\";
      } on-error={
        :set upgrading false;
        :error \"HTTP error downloading upgrade file\";
      }
      :set upgrading false;
      /import \"/ispapp-upgrade.rsc\";
    }

    :local rebootval (\$JParseOut->\"reboot\");

    #:put \"rebootval: \$rebootval\";

    if ( \$rebootval = \"1\" ) do={

      :log info \"Reboot\";
      /system reboot;

    } else={

      # check if lastConfigChangeTsMs is different
      /system script run ispappLastConfigChangeTsMs;
      :global lastConfigChangeTsMs;
      :local dbl (\$JParseOut->\"lastConfigChangeTsMs\");

      if (([:len \$dbl] != 0 && [:len \$lastConfigChangeTsMs] != 0) && (\$dbl != \$lastConfigChangeTsMs || \$jsonError != nil)) do={
        #:put \"update response indicates configuration changes\";
        :log info (\"update response indicates configuration changes, running ispappConfig script\");
        /system scheduler disable ispappUpdate;
        /system scheduler enable ispappConfig;
        :error \"there was a json error in the update response\";

      } else={
        if ( \$jsonError != nil ) do={
          :log info (\"update request responded with an error: \" . \$jsonError);
          if ([:find \$jsonError \"invalid login\"] > -1) do={
            #:put \"invalid login, running ispappSetGlobalEnv to make sure login is set correctly\";
            /system script run ispappSetGlobalEnv;
            /system scheduler set interval=300s \"ispappConfig\";
            /system scheduler set interval=300s \"ispappUpdate\";
          }
        }
      }

  # speedtest
  :local executeSpeedtest (\$JParseOut->\"executeSpeedtest\");
  :if ( \$executeSpeedtest = true) do={
    # run this in a thread
    :execute {
      # make the request
      :global speedtestRunning;
      :if ( \$speedtestRunning = true) do={
        :error \"speedtest already running\";
      }
      :set speedtestRunning true;
       :do {
      :local txAvg 0 
      :local rxAvg 0 
      :local txDuration 
      :local rxDuration 
      :local stUrl (\"https://\" . \$topDomain . \":\" . \$topListenerPort . \"/bandwidth?login=\" . \$login . \"&key=\" . \$topKey);
      :local ds [/system clock get date];
      :local currentTime [/system clock get time];
      :set currentTime ([:pick \$currentTime 0 2].[:pick \$currentTime 3 5].[:pick \$currentTime 6 8])
    
      :set ds ([:pick \$ds 7 11].[:pick \$ds 0 3].[:pick \$ds 4 6])
      /tool bandwidth-test protocol=tcp direction=transmit address=\$ipbandswtestserver user=\$btuser password=\$btpwd duration=5s do={
        :set txAvg (\$\"tx-total-average\");
        :set txDuration (\$\"duration\")
        }
    
      /tool bandwidth-test protocol=tcp direction=receive address=\$ipbandswtestserver user=\$btuser password=\$btpwd duration=5s do={
      :set rxAvg (\$\"rx-total-average\");
      :set rxDuration (\$\"duration\")
      }
      :local jsonResult (\"{ \\\"date\\\": \\\"\" . \$ds . \"\\\", \\\"time\\\": \\\"\" . \$currentTime . \"\\\", \\\"txAvg\\\": \" . \$txAvg . \", \\\"rxAvg\\\": \" . \$rxAvg . \", \\\"rxDuration\\\": \\\"\" . \$rxDuration . \"\\\", \\\"txDuration\\\": \\\"\" . \$txDuration . \"\\\" }\")
      :log debug (\$jsonResult);
      :put \$stUrl
      :local result [/tool fetch mode=https url=\$stUrl http-method=post http-data=\$jsonResult http-header=\"Content-Type: application/json\" as-value output=user];
      :if (\$result->\"status\" = \"finished\") do={
        :if (\$result->\"data\" = \"Data received successfully\") do={
            :put (\$result->\"data\")
        }
    }
      } on-error={
        :log info (\"HTTP Error, no response for speedtest request with command error to ISPApp.\");
      }
      :set speedtestRunning false;
    }
  }


  # commands

  :local cmds (\$JParseOut->\"cmds\");

  :foreach cmdKey in=(\$cmds) do={

    :local cmd (\$cmdKey->\"cmd\");
    :local stderr (\$cmdKey->\"stderr\");
    :local stdout (\$cmdKey->\"stdout\");
    :local uuidv4 (\$cmdKey->\"uuidv4\");
    :local wsid (\$cmdKey->\"ws_id\");

    # create the command output filename with the uuidv4 in it
    :local outputFilename (\$uuidv4 . \"ispappCommandOutput.txt\");

    # do not rerun the command if the file already exists
    :if ([:len [/file find name=\$outputFilename]] > 0) do={
      :error \"command already executed, not re-executing\";
    }

    # create a system script with the command contents
    :if ([:len [/system script find name=\"ispappCommand\"]] = 0) do={
      /system script add name=\"ispappCommand\";
    }

    /system script set \"ispappCommand\" source=\"\$cmd\";

    :log info (\"ispapp is executing command: \" . \$cmd);

    # run the script and place the output in a known file
    # this runs in the background if not ran with :put
    # resulting in the contents being empty
    :local scriptJobId [:execute script={/system script run ispappCommand;} file=\$outputFilename];

    :local j ([:len [/system script job find where script=ispappCommand]]);
    :local scriptWaitCount 0;

    # maximum wait time for a job
    # n * 500ms
    :local maxWaitCount 200;

    :while (\$j > 0 && \$scriptWaitCount < \$maxWaitCount) do={
      # wait for script to finish
      :delay 500ms;
      :set scriptWaitCount (\$scriptWaitCount + 1);
      :set j ([:len [/system script job find where script=ispappCommand]]);
      #:log info (\"waiting for \" . \$j . \" at wait count \" . \$scriptWaitCount);
    }

    # get the file size
    :local outputSize 0;
    :local waitForFileCount 0;
    :while (\$outputSize = 0 && \$waitForFileCount < 10) do={
      :delay 500ms;
      :set waitForFileCount (\$waitForFileCount + 1);
      #:log info (\"outputSize: \" . \$outputSize);
      if ([:len [/file find name=\$outputFilename]] > 0) do={
        :set outputSize ([/file get \$outputFilename size]);
      }
    }

    :local timeoutError 0;
    if (\$scriptWaitCount = \$maxWaitCount) do={
      :do {
        # kill hanging job
        :log info (\"killing hanging job \" . \$cmd);
        /system script job remove \$scriptJobId;
        :set timeoutError 1;
      } on-error={
      }
    }

    # base64 encoded
    :global base64EncodeFunct;

    :local cmdJsonData \"\";

    if (\$timeoutError = 1) do={

      # send an error that the command experienced a timeout

      :local output ([\$base64EncodeFunct stringVal=\"command timeout\"]);
      #:log info (\"base64: \" . \$output);

      # make the request body
      :set cmdJsonData \"{\\\"ws_id\\\":\\\"\$wsid\\\",\\\"uuidv4\\\":\\\"\$uuidv4\\\",\\\"stderr\\\":\\\"\$output\\\",\\\"sequenceNumber\\\":\$updateSequenceNumber}\";

      # make the request
      :do {
        :local cmdResponse ([/tool fetch check-certificate=yes mode=https http-method=post http-header-field=\"cache-control: no-cache, content-type: application/json\" http-data=\"\$cmdJsonData\" url=\$updateUrl as-value output=user]);
      } on-error={
        :log info (\"HTTP Error, no response for /update request with command error to ISPApp.\");
      }
      :set updateSequenceNumber (\$updateSequenceNumber + 1);

      #:put \$cmdResponse;

      # delete command output file
      /file remove \$outputFilename;

    } else={

    # successful command
    :log info (\"command output size: \" . \$outputSize);

    # send via https if small enough to fit in a routeros variable
    # send via smtp if not, because smtp can send a file
    if (\$outputSize <= 4096) do={

      # send an http request to /update with the command response

      # file contents are small enough to fit in a routeros variable
      :local output ([/file get \$outputFilename contents]);

      if ([:len \$output] = 0) do={

        # routeros commands like add return nothing when successful
        :set output (\"success\");

      }

      :set output ([\$base64EncodeFunct stringVal=\$output]);
      #:log info (\"base64: \" . \$output);

      # make the request body
      :set cmdJsonData \"{\\\"ws_id\\\":\\\"\$wsid\\\",\\\"uuidv4\\\":\\\"\$uuidv4\\\",\\\"stdout\\\":\\\"\$output\\\",\\\"sequenceNumber\\\":\$updateSequenceNumber}\";

      #:put \$cmdJsonData;
      #:log info (\"ispapp command response json: \" . \$cmdJsonData);

      # make the request
      :do {
        :local cmdResponse ([/tool fetch check-certificate=yes mode=https http-method=post http-header-field=\"cache-control: no-cache, content-type: application/json\" http-data=\"\$cmdJsonData\" url=\$updateUrl as-value output=user]);
      } on-error={
        :log info (\"HTTP Error, no response for /update request with command response to ISPApp.\");
      }
      :set updateSequenceNumber (\$updateSequenceNumber + 1);

      #:put \$cmdResponse;

      # delete command output file
      /file remove \$outputFilename;

    } else={

      # send an email to the instance with the command response on port 465
      # the routeros email tool allows files to be sent, but the fetch tool does not and the
      # variable size in routeros is limited at 4096 bytes

      # make the request body
      :set cmdJsonData \"{\\\"ws_id\\\":\\\"\$wsid\\\", \\\"uuidv4\\\":\\\"\$uuidv4\\\"}\";

      # these are accessed once in the :execute script before the next iteration of ispappUpdate
      :global lastSmtpCommandJsonData \$cmdJsonData;
      :global lastSmtpCommandOutputFilename \$outputFilename;

      # run this in a thread
      :execute {

        :global login;
        :global simpleRotatedKey;
        :global topDomain;
        :global topSmtpPort;
        :global lastSmtpCommandJsonData;
        :global lastSmtpCommandOutputFilename;

        :local threadPersistantFilename \$lastSmtpCommandOutputFilename;

        /tool e-mail send server=(\$topDomain) from=(\$login . \"@\" . \$simpleRotatedKey . \".ispapp.co\") to=(\"command@\" . \$topDomain) port=(\$topSmtpPort) file=\$threadPersistantFilename subject=\"c\" body=(\$lastSmtpCommandJsonData);

        # wait 10 minutes for the upload to finish
        :delay 600s;

        # delete command output file
        /file remove \$threadPersistantFilename;

      };

    }

    }

  }

  # configuration backups
  :do {

      # /system history print does not work yet
      # test if configuration has changed
      #:local lastLocalConfigurationTime ([/system history get ([find]->0) date] . \" \" . [/system history get ([find]->0) time]);
      #:log info \$lastLocalConfigurationTime;

      # get the unix timestamp
      #:local lastLocalConfigurationTs [\$rosTimestringSec \$lastLocalConfigurationTime];
      #:log info \$lastLocalConfigurationTs;

      # get the timestamp of the last local configuration change from the JSON
      # /system history print does not work yet

      :global lastLocalConfigurationBackupSendTs;

      # non documented typeof value of nothing happens when you delete an environment variable, RouterOS 6.49.7
      if ([:typeof \$lastLocalConfigurationBackupSendTs] = \"nil\" || [:typeof \$lastLocalConfigurationBackupSendTs] = \"nothing\") do={
        # set first value
        :set lastLocalConfigurationBackupSendTs 0;
      }

      #:log info (\"lastLocalConfigurationBackupSendTs\", [:typeof \$lastLocalConfigurationBackupSendTs], \$lastLocalConfigurationBackupSendTs);

      :local currentTimestring ([/system clock get date] . \" \" . [/system clock get time]);
      :local currentTs [\$rosTimestringSec \$currentTimestring];

      :local lastBackupDiffSec (\$currentTs - \$lastLocalConfigurationBackupSendTs);
      #:log info (\"lastBackupDiffSec\", \$lastBackupDiffSec);

      if (\$lastBackupDiffSec > 60 * 60 * 12) do={
        # send a new local configuration backup every 12 hours

        :log info (\"sending new local configuration backup\");

        :execute {

          # set last backup time
          :local lastLocalConfigurationBackupSendTimestring ([/system clock get date] . \" \" . [/system clock get time]);
          :global lastLocalConfigurationBackupSendTs [\$rosTimestringSec \$lastLocalConfigurationBackupSendTimestring];

          # send backup

          # run the script and place the output in a known file
          :local scriptJobId [:execute script={/export terse;} file=ispappBackup.txt];

          # wait 10 minutes for the export to finish
          :delay 600s;

          :global login;
          :global simpleRotatedKey;
          :global topDomain;
          :global topSmtpPort;

          /tool e-mail send server=(\$topDomain) from=(\$login . \"@\" . \$simpleRotatedKey . \".ispapp.co\") to=(\"backup@\" . \$topDomain) port=(\$topSmtpPort) file=\"ispappBackup.txt\" subject=\"c\" body=\"{}\";

        };

      }

  } on-error={

    :log info (\"ISPApp, error with configuration backups.\");

  }

        # # enable updateFast if set to true
        # :local updateFast (\$JParseOut->\"updateFast\");
        # :if ( \$updateFast = true) do={
        #   :do {
        #     :local updateSchedulerInterval [/system scheduler get ispappUpdate interval ];
        #     :if (\$updateSchedulerInterval != \"00:00:02\") do={
        #       /system scheduler set interval=10s \"ispappUpdate\";
        #       /system scheduler set interval=10s \"ispappCollectors\";
        #     }
        #   } on-error={
        #   }
        # } else={
        #   :do {

        #       :global lastUpdateOffsetSec;
        #       :set lastUpdateOffsetSec (\$JParseOut->\"lastUpdateOffsetSec\");

        #       :global lastColUpdateOffsetSec;
        #       :set lastColUpdateOffsetSec (\$JParseOut->\"lastColUpdateOffsetSec\");

        #       :global updateIntervalSeconds;
        #       :global outageIntervalSeconds;
        #       :local secUntilNextUpdate (num(\$updateIntervalSeconds-\$lastColUpdateOffsetSec));
        #       :local secUntilNextOutage (num(\$outageIntervalSeconds-\$lastUpdateOffsetSec));
        #       :local setSec \$secUntilNextOutage;

        #       if (\$secUntilNextUpdate <= \$setSec + 5) do={
        #         # the next update request that is an update not an outage update is when the update must be sent to allow the data to be collected (5 seconds max, on planet)
        #         # use updateIntervalSeconds to calculate the setSec
        #         :set setSec \$secUntilNextUpdate;
        #       }

        #       if (\$setSec < 2) do={

        #         # don't change the interval to 0, causing the script to no longer run
        #         # set to 2
        #         :local updateSchedulerInterval [/system scheduler get ispappUpdate interval ];
        #         :if (\$updateSchedulerInterval != \"00:00:02\") do={
        #           /system scheduler set interval=10s \"ispappUpdate\";
        #         }

        #      } else={

        #         # set the update request interval if it is different than what is set
    
        #         :local updateSchedulerInterval [/system scheduler get ispappUpdate interval];
        #         :local tsSec [\$rosTsSec \$updateSchedulerInterval];
        #         :if (\$setSec != \$tsSec) do={
        #           # set the scheduler to the correct interval
        #           /system scheduler set interval=(\$setSec) \"ispappUpdate\";
        #         }

        #     }

        #     :local collSchedulerInterval [/system scheduler get ispappCollectors interval ];
        #     :if (\$collSchedulerInterval != \"00:01:00\") do={
        #         # set the ispappCollectors interval to default
    
        #         /system scheduler set interval=60s \"ispappCollectors\";
        #         /system scheduler set interval=60s \"ispappPingCollector\";
        #     }

        #   } on-error={
        #     :log info (\"error parsing update interval\");
        #   }

        # }

}
}"