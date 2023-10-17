# Router Setup Config  Testing file 0
:local sameScriptRunningCount [:len [/system script job find script=ispappConfig]];

if ($sameScriptRunningCount > 1) do={
  :error ("ispappConfig script already running " . $sameScriptRunningCount . " times");
}

:global login;
if ($login = "00:00:00:00:00:00" || $login = "") do={
  :system script run ispappSetGlobalEnv;
  :error "ispappConfig not running with login 00:00:00:00:00:00 or blank, attempting login gain again.";
} else={

  :log info ("ispappConfig script start");

  :global topDomain;
  :global topKey;
  :global topClientInfo;
  :global topListenerPort;
  :global rosTimestringSec;
  :global urlEncodeFunct;
  :local lcf;
  :local buildTime [/system resource get build-time];
  :local osbuilddate [$rosTimestringSec $buildTime];
  :set osbuilddate [:tostr $osbuilddate];
  :local osversion [/system package get 0 version];
  :local os [/system package get 0 name];
  :local hardwaremake [/system resource get platform];
  :local hardwaremodel [/system resource get board-name];
  :local cpu [/system resource get cpu];
  :local hostname [/system identity get name];
  :local hasWirelessConfigurationMenu 0;
  :local hasWifiwave2ConfigurationMenu 0;
  :global configScriptSuccessSinceInit;
  :global updateScriptSuccessSinceInit;

  :do {
    :if ([:len [/interface wireless security-profiles find ]]>0) do={
      :set hasWirelessConfigurationMenu 1;
    }
  } on-error={
    # no wireless
  }

  :do {
    :if ([:len [/interface wifiwave2 find ]]>0) do={
      :set hasWifiwave2ConfigurationMenu 1;
    }
  } on-error={
    # no wifiwave2
  }

  # ----- interfaces -------

  :local ifaceDataArray;
  :local totalInterface ([/interface print as-value count-only]);
  :local interfaceCounter 0;

  foreach iface in=[/interface find] do={

    :set interfaceCounter ($interfaceCounter + 1);

    if ( [:len $iface] != 0 ) do={

      :local ifaceName [/interface get $iface name];
      :local ifaceMac [/interface get $iface mac-address];

      :local ifaceDefaultName "";

      :do {
        :set ifaceDefaultName [/interface get $iface default-name];
      } on-error={
        # no default name, many interface types are this way
      }

      #:put ($ifaceName, $ifaceMac);

      if ( [:len $ifaceName] !=0 ) do={
        if ($interfaceCounter != $totalInterface) do={
          # not last interface
          :local ifaceData "{\"if\":\"$ifaceName\",\"mac\":\"$ifaceMac\",\"defaultIf\":\"$ifaceDefaultName\"},";
          :set ifaceDataArray ($ifaceDataArray.$ifaceData);
        }
        if ($interfaceCounter = $totalInterface) do={
          # last interface
          :local ifaceData "{\"if\":\"$ifaceName\",\"mac\":\"$ifaceMac\",\"defaultIf\":\"$ifaceDefaultName\"}";
          :set ifaceDataArray ($ifaceDataArray.$ifaceData);
        }

      }
    }
  }

  # ----- wireless configs used for unknown hosts -----

  :local wapArray;
  :local wapCount 0;

  if ($hasWirelessConfigurationMenu = 1) do={

    :put "has wireless configuration menu";

    :foreach wIfaceId in=[/interface wireless find] do={

      :local wIfName ([/interface wireless get $wIfaceId name]);
      :local wIfSsid ([/interface wireless get $wIfaceId ssid]);
      :local wIfSecurityProfile ([/interface wireless get $wIfaceId security-profile]);

      :local wIfKey "";
      :local wIfKeyTypeString "";

      :do {
        :set wIfKey ([/interface wireless security-profiles get [/interface wireless security-profiles find name=$wIfSecurityProfile] wpa2-pre-shared-key]);
        :local wIfKeyType ([/interface wireless security-profiles get [/interface wireless security-profiles find name=$wIfSecurityProfile] authentication-types]);

        # convert the array $wIfKeyType to the space delimited string $wIfKeyTypeString
        :foreach kt in=$wIfKeyType do={
          :set wIfKeyTypeString ($wIfKeyTypeString . $kt . " ");
        }

      } on-error={
        # no settings in security profile or profile does not exist
      }

      # remove the last space if it exists
      if ([:len $wIfKeyTypeString] > 0) do={
        :set wIfKeyTypeString [:pick $wIfKeyTypeString 0 ([:len $wIfKeyTypeString] -1)];
      }

      # if the wpa2 key is empty, get the wpa key
      if ([:len $wIfKey] = 0) do={
        :do {
          :set wIfKey ([/interface wireless security-profiles get [/interface wireless security-profiles find name=$wIfSecurityProfile] wpa-pre-shared-key]);
        } on-error={
          # no security profile found
        }
      }

      :local newWapIf;

      if ($wapCount = 0) do={
        # first wifi interface
        :set newWapIf "{\"if\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"key\":\"$wIfKey\",\"keytypes\":\"$wIfKeyTypeString\"}";
      } else={
        # not first wifi interface
        :set newWapIf ",{\"if\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"key\":\"$wIfKey\",\"keytypes\":\"$wIfKeyTypeString\"}";
      }

      :set wapCount ($wapCount + 1);

      :set wapArray ($wapArray.$newWapIf);
      
    }
  }

  if ($hasWifiwave2ConfigurationMenu = 1) do={

    :put "has wifiwave2 configuration menu"

    :foreach wIfaceId in=[/interface wifiwave2 find] do={

      :local wIfName ([/interface wifiwave2 get $wIfaceId name]);
      :local wIfSsid ([/interface wifiwave2 get $wIfaceId configuration.ssid]);

      :local wIfKey "";
      :local wIfKeyTypeString "";

      :do {
        :set wIfKey ([/interface wifiwave2 get $wIfaceId security.passphrase]);
        :local wIfKeyType ([/interface wifiwave2 get $wIfaceId security.authentication-types]);

        # convert the array $wIfKeyType to the space delimited string $wIfKeyTypeString
        :foreach kt in=$wIfKeyType do={
          :set wIfKeyTypeString ($wIfKeyTypeString . $kt . " ");
        }

      } on-error={
      }

      # remove the last space if it exists
      if ([:len $wIfKeyTypeString] > 0) do={
        :set wIfKeyTypeString [:pick $wIfKeyTypeString 0 ([:len $wIfKeyTypeString] -1)];
      }

      #:put ("wifiwave2 interface $wIfName, ssid: $wIfSsid, key: $wIfKey");

      :local newWapIf;

      if ($wapCount = 0) do={
        # first wifi interface
        :set newWapIf "{\"if\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"key\":\"$wIfKey\",\"keytypes\":\"$wIfKeyTypeString\"}";
      } else={
        # not first wifi interface
        :set newWapIf ",{\"if\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"key\":\"$wIfKey\",\"keytypes\":\"$wIfKeyTypeString\"}";
      }

      :set wapCount ($wapCount + 1);

      :set wapArray ($wapArray.$newWapIf);

    }

  }

  # ----- json config string -----

  :local hwUrlValCollectData ("{\"clientInfo\":\"$topClientInfo\", \"osVersion\":\"$osversion\", \"hardwareMake\":\"$hardwaremake\",\"hardwareModel\":\"$hardwaremodel\",\"hardwareCpuInfo\":\"$cpu\",\"os\":\"$os\",\"osBuildDate\":$osbuilddate,\"fw\":\"$topClientInfo\",\"hostname\":\"$hostname\",\"interfaces\":[$ifaceDataArray],\"wirelessConfigured\":[$wapArray],\"webshellSupport\":true,\"bandwidthTestSupport\":true,\"firmwareUpgradeSupport\":true,\"wirelessSupport\":true}");

  if ( $updateScriptSuccessSinceInit = false || $configScriptSuccessSinceInit = false ) do={
    # show verbose output until the config script and update script succeed
    :put ("config request url", "https://" . $topDomain . ":" . $topListenerPort . "/config?login=" . $login . "&key=" . $topKey);
    :put ("config request json", $hwUrlValCollectData);
  }

  :local configSendData;
  :do { 
    :set configSendData [/tool fetch check-certificate=yes mode=https http-method=post http-header-field="cache-control: no-cache, content-type: application/json" http-data="$hwUrlValCollectData" url=("https://" . $topDomain . ":" . $topListenerPort . "/config?login=" . $login . "&key=" . $topKey) as-value output=user]
      if ( $updateScriptSuccessSinceInit = false || $configScriptSuccessSinceInit = false ) do={
        # show verbose output until the config script and update script succeed
        :put "\nconfigSendData (config request response before parsing):\n";
        :put $configSendData;
	  }
  } on-error={
    :log info ("HTTP Error, no response for /config request to ISPApp, sent " . [:len $hwUrlValCollectData] . " bytes");
  }

  :delay 1;

  :local setConfig 0;
  :local host;

  # make sure there was a non empty response
  # and that Err was not the first three characters, indicating an inability to parse
  if ([:len $configSendData] != 0 && [:find $configSendData "Err.Raise 8732"] != 0) do={

    :local jstr;

    :set jstr [$configSendData];
    global JSONIn
    global JParseOut;
    global fJParse;

    # Parse data
    :set JSONIn ($jstr->"data");
    :set JParseOut [$fJParse];

    :set host ($JParseOut->"host");
    :local jsonError ($JParseOut->"error");

    if ( [:len $host] != 0 ) do={
	
	  :set configScriptSuccessSinceInit true;

      # set outageIntervalSeconds and updateIntervalSeconds
      :global outageIntervalSeconds (num($host->"outageIntervalSeconds"));
      :global updateIntervalSeconds (num($host->"updateIntervalSeconds"));

      # check if lastConfigChangeTsMs in the response
      # is larger than the last configuration application

      :set lcf ($host->"lastConfigChangeTsMs");
      #:put "response's lastConfigChangeTsMs: $lcf";
      if ( [:len [/system script find name=ispappLastConfigChangeTsMs]] > 0 ) do={
        /system script run ispappLastConfigChangeTsMs;
      } else={
        /system script add name=ispappLastConfigChangeTsMs;
      }
      :global lastConfigChangeTsMs;
      #:put "current lastConfigChangeTsMs: $lastConfigChangeTsMs";

      if ($lcf != $lastConfigChangeTsMs) do={
        #:put "new configuration must be applied";

        :set setConfig 1;

        :log info ("ISPApp has responded with a configuration change");

      }

      # set the value in the ispappLastConfigChangeTsMs script to that sent by the server
      /system script set "ispappLastConfigChangeTsMs" source=":global lastConfigChangeTsMs; :set lastConfigChangeTsMs $lcf;";

      # the config response is authenticated, disable the scheduler
      # and enable the ispappUpdate script

      /system scheduler disable ispappConfig;
      /system scheduler enable ispappUpdate;

    } else={

      # there was an error in the response
      :log info ("config request responded with an error: " . $jsonError);

      if ([:find $jsonError "invalid login"] > -1) do={
        #:put "invalid login, running ispappSetGlobalEnv to make sure login is set correctly";
        /system script run ispappSetGlobalEnv;
        /system scheduler set interval=300s "ispappConfig";
        /system scheduler set interval=300s "ispappUpdate";
      }

    }

  } else={

    # there was a parsing error, the scheduler will continue repeating config requests and $setConfig will not equal 1
    #:put "JSON parsing error with config request, config scheduler will continue retrying";

  }

  if ($setConfig = 1) do={

    :put "Configuring from ISPApp.";

    :local configuredSsids ($host->"wirelessConfigs");

    :local hostkey ($host->"key");
    #:put "hostkey: $hostkey";
    :do {
      # if the password is blank, set it to the hostkey
      /password new-password="$hostkey" confirm-new-password="$hostkey" old-password="";
      # if the password was able to be modified, then disable ip services that are not required
      /ip service disable ftp;
      /ip service disable api;
      /ip service disable telnet;
      /ip service disable www;
      /ip service disable www-ssl;
    } on-error={
      :put "existing password remains, ISPApp host key not set as password";
    }

    :local hostname ($host->"name");
    #:put "hostname: $hostname";

    #:put ("Host Name ==>>>" . $hostname);
    if ([:len $hostname] != 0) do={
      #:put ("System identity changed.");
      :do { /system identity set name=$hostname }
    }
    if ([:len $hostname] = 0) do={
      #:put ("System identity not added!!!");
    }

    :local mode;
    :local channelwidth;
    :local wifibeaconint;

    :set mode ($host->"wirelessMode");
    :set channelwidth ($host->"wirelessChannel");
    #:set wifibeaconint ($host->"wirelessBeaconInt");

    :global wanIP;
    #:put "wanIP: $wanIP";

    #:put "wireless mode: $mode with WAN interface: $wanport";

    # remove the existing ispapp configuration
    /system script run ispappRemoveConfiguration;

    :put ("configured ssids", [:len $configuredSsids]);

    if ([:len $configuredSsids] > 0) do={
      # this device has wireless interfaces and configurations have been sent from the server
      :put "ISPApp configuring wireless";

      :local ssidIndex;
      :local ssidCount 0;
      :foreach ssidIndex in $configuredSsids do={
        # this is each configured ssid, there can be many
        
        :local vlanmode "use-tag";

        :local authenticationtypes ($ssidIndex->"encType");
        :local encryptionKey ($ssidIndex->"encKey");
        :local ssid ($ssidIndex->"ssid");
        #:local vlanid ($ssidIndex->"vlanId");
        :local vlanid 0;
        :local defaultforward ($ssidIndex->"clientIsolation");
        :local preamblemode ($ssidIndex->"sp");
        :local dotw ($ssidIndex->"dotw");

        if ($authenticationtypes = "psk") do={
          :set authenticationtypes "wpa-psk";
        }
        if ($authenticationtypes = "psk2") do={
          :set authenticationtypes "wpa2-psk";
        }
        if ($authenticationtypes = "sae") do={
          :set authenticationtypes "wpa2-psk";
        }
        if ($authenticationtypes = "sae-mixed") do={
          :set authenticationtypes "wpa2-psk";
        }
        if ($authenticationtypes = "owe") do={
          :set authenticationtypes "wpa2-psk";
        }

        if ($vlanid = 0) do={
          :set vlanid  1;
          :set vlanmode "no-tag"
        }

        # change json values of configuration parameters to what routeros expects
        if ($mode = "sta") do={
          :set mode "station";
        }
        if ($defaultforward = "true") do={
          :set defaultforward "yes";
        }
        if ($defaultforward = "false") do={
          :set defaultforward "no";
        }
        if ($channelwidth != "auto") do={
          :set channelwidth "20mhz";
        }
        if ($preamblemode = "true") do={
          :set preamblemode "long";
        }
        if ($preamblemode = "false") do={
          :set preamblemode "short";
        }

        #:put "\nconfiguring wireless network $ssid";
        #:put ("index ==>" . $ssidIndex);
        #:put ("authtype==>" . $authenticationtypes);
        #:put ("enckey==>" . $encryptionKey);
        #:put ("ssid==>" . $ssid);
        #:put ("vlanid==>" . $vlanid);
        #:put ("chwidth==>" . $channelwidth);
        #:put ("forwardmode==>" . $defaultforward);
        #:put ("preamblemode==>" . $preamblemode);

        if ($hasWirelessConfigurationMenu = 1) do={
          :foreach wIfaceId in=[/interface wireless find] do={

            :local wIfName ([/interface wireless get $wIfaceId name]);
            :local wIfType ([/interface wireless get $wIfaceId interface-type]);

            if ($wIfType != "virtual") do={
              # this is a physical interface
              :put "configuring wireless interface: $wIfName, ssid: $ssid, authenticationtypes: $authenticationtypes";
              :local scriptText "";

              if ($authenticationtypes != "none") do={
                :do {
                  :set scriptText "/interface wireless security-profiles add name=\"ispapp-$ssid-$wIfName\" mode=dynamic-keys authentication-types=\"$authenticationtypes\" wpa2-pre-shared-key=\"$encryptionKey\";";
                } on-error={
                }
              }

              if ($ssidCount = 0) do={

                # set each physical wireless interface with the first ssid
                # and the comment "ispapp" to know that ispapp configured it
                if ($authenticationtypes = "none") do={
                  :set scriptText ($scriptText . " /interface wireless set $wIfName ssid=\"$ssid\" wireless-protocol=802.11 frequency=auto mode=ap-bridge hide-ssid=no comment=ispapp; /interface wireless enable $wIfName;");
                } else={
                  :set scriptText ($scriptText . " /interface wireless set $wIfName ssid=\"$ssid\" security-profile=\"ispapp-$ssid-$wIfName\" wireless-protocol=802.11 frequency=auto mode=ap-bridge hide-ssid=no comment=ispapp; /interface wireless enable $wIfName;");
                }

              } else={
                # create a virtual interface for any ssids after the first
                if ($authenticationtypes = "none") do={
                  :set scriptText ($scriptText . " /interface wireless add master-interface=\"$wIfName\" ssid=\"$ssid\" name=\"ispapp-$ssid-$wIfName\" wireless-protocol=802.11 frequency=auto mode=ap-bridge; /interface wireless enable \"ispapp-$ssid-$wIfName\";");
                } else={
                  :set scriptText ($scriptText . " /interface wireless add master-interface=\"$wIfName\" ssid=\"$ssid\" name=\"ispapp-$ssid-$wIfName\" security-profile=\"ispapp-$ssid-$wIfName\" wireless-protocol=802.11 frequency=auto mode=ap-bridge; /interface wireless enable \"ispapp-$ssid-$wIfName\";");
                }
              }
              :execute script="$scriptText";
            }

          }
        }

        if ($hasWifiwave2ConfigurationMenu = 1) do={
          :foreach wIfaceId in=[/interface wifiwave2 find] do={

            :local wIfName ([/interface wifiwave2 get $wIfaceId name]);
            :local wIfMasterIf ([/interface wifiwave2 get $wIfaceId master-interface]);

            if ([:len $wIfMasterIf] = 0) do={
              # this is a physical interface

              :put "configuring wifiwave2 interface: $wIfName, ssid: $ssid, authenticationtypes: $authenticationtypes";

              if ($ssidCount = 0) do={

                # set each physical wireless interface with the first ssid
                # and the comment "ispapp" to know that ispapp configured it
                if ($authenticationtypes = "none") do={
                  :execute script="/interface wifiwave2 set $wIfName configuration.ssid=\"$ssid\" configuration.mode=ap configuration.hide-ssid=no comment=ispapp; /interface wifiwave2 enable $wIfName;";
                } else={
                  :execute script="/interface wifiwave2 set $wIfName configuration.ssid=\"$ssid\" security.passphrase=\"$encryptionKey\" security.authentication-types=\"$authenticationtypes\" configuration.mode=ap configuration.hide-ssid=no comment=ispapp; /interface wifiwave2 enable $wIfName;";
                }

              } else={
                # create a virtual interface for any ssids after the first
                if ($authenticationtypes = "none") do={
                  :execute script="/interface wifiwave2 add master-interface=\"$wIfName\" configuration.ssid=\"$ssid\" configuration.mode=ap configuration.hide-ssid=no comment=ispapp; /interface wifiwave2 enable \"ispapp-$ssid-$wIfName\";";
                } else={
                  :execute script="/interface wifiwave2 add master-interface=\"$wIfName\" configuration.ssid=\"$ssid\" security.passphrase=\"$encryptionKey\" security.authentication-types=\"$authenticationtypes\" configuration.mode=ap configuration.hide-ssid=no comment=ispapp; /interface wifiwave2 enable \"ispapp-$ssid-$wIfName\";";
                }
              }
            }

          }
        }

        :set ssidCount ($ssidCount + 1);

      }
    }

  }

}