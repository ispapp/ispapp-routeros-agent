############################### this file contain predefined functions to be used across the agent script ################################
# for checking purposes
:global ispappLibraryV1 "ispappLibraryV1 loaded";
:global login;
# Function to join array elements with a specified delimiter
# Example usage:
# :put [$joinArray ["a" "b" "c"] " - "] // returns "a - b - c"
:global joinArray do={
    :local inputArray ($1)
    :local delimiter ($2)
    :local outputString ""
    if ([:typeof $inputArray] != "array") do={
        :return [:tostr $inputArray]
    }
    :foreach k,i in=$inputArray do={
        if ($k = 0) do={
            :set outputString ($outputString .  $i);
        } else={
            :set outputString ($outputString . $2 .  $i);
        }
    }
    :return $outputString;
}
# Func tion to fill rotatingkey sor emails and lastconfig in seconds
:global fillGlobalConsts do={
    :global lcf;
    :global outageIntervalSeconds;
    :global lastConfigChangeTsMs;
    :global updateIntervalSeconds;
    if ([:typeof $1] != "array") do={:return "error input type (not array)";}
    :local configs $1;
    /system scheduler enable [find name~"ispappUpdate" disabled=yes]
    if ([:len ($configs->"host")] > 0) do={
        :set lcf ($configs->"host"->"lastConfigChangeTsMs");
        :set outageIntervalSeconds [:tonum ($configs->"host"->"outageIntervalSeconds")];
        :set updateIntervalSeconds [:tonum ($configs->"host"->"updateIntervalSeconds")];
        if ([:len $lcf] > 0) do={
            :set lastConfigChangeTsMs $lcf;
        }
    }
    :return "done updating Global Consts";
}
# Function to collect all wireless interfaces and format them to be sent to server.
:global WirelessInterfacesConfigSync do={
    :global getAllConfigs;
    :global joinArray;
    :global ispappHTTPClient;
    if ([:len [/system script job find script~"ispappUpdate"]] > 0) do={
        :return {"status"=false; "message"="waiting update to finish first!"};
    }
    :local getLocalWlans do={
        # collect all wireless interfaces from the system
        # format them to be sent to server
        :log info "start collect all wireless interfaces from the system ...";
        :local wlans [[:parse "/interface wireless print as-value"]];
        :if ([:len $wlans] > 0) do={
            :local getEncKey do={
                if ([:len ($1->"wpa-pre-shared-key")] > 0) do={
                    :return ($1->"wpa-pre-shared-key");
                } else={
                    if ([:len ($1->"wpa2-pre-shared-key")] > 0) do={
                        :return ($1->"wpa2-pre-shared-key");
                    } else={
                        :return "";
                    }
                }
            }
            :local getmaster do={
                if ($1->"interface-type" = "virtual") do={
                    :return ($1->"master-interface");
                } else={
                    :return ($1->"interface-type");
                }
            };
            :local wirelessConfigs ({});
            foreach i,k in=$wlans do={
                :local getdisabled [:parse "/interface wireless get \$1 disabled"];
                :local isdisabled [$getdisabled ($k->"name")];
                :set ($wirelessConfigs->$i) {
                    ".id"=($k->".id");
                    "if"=($k->"name");
                    "name"=($k->"name");
                    "technology"="wireless";
                    "key"=[$getEncKey ($k->"security-profile")];
                    "ssid"=($k->"ssid");
                    "band"=($k->"band");
                    "interface-type"=($k->"interface-type");
                    "mac-address"=($k->"mac-address");
                    "master-interface"=[$getmaster $k];
                    "security-profile"=($k->"security-profile");
                    "disabled"=$isdisabled;
                    "running"=(!$isdisabled);
                    "hide-ssid"=($k->"hide-ssid")
                };
            }
            :log info "collect all wireless interfaces from the system";
            :return { "status"=true; "wirelessConfigs"=$wirelessConfigs };
         } else={
            :log info "collect all wireless interfaces from the system: no wireless interfaces found";
            :return { "status"=false; "message"="no wireless interfaces found" };
         }
    };
    :log info "done setting local functions .... 1s"
    # check if our host is authorized to get configuration
    # and ready to accept interface syncronization
    :local configresponse [$getConfig];
    :local output;
    # :local wirelessConfigs ({});
    # :if ($configresponse->"status" = true) do={
    #     :set wirelessConfigs ($configresponse->"response"->"host"->"wirelessConfigs");
    # }
    :log info "done setting wirelessConfigs .... 1s"
    # if ([:len $wirelessConfigs] > 0) do={
    #     # this is the case when some interface configs received from the host
    #     # get security profile with same password as the one on first argument $1
    #     :global SyncSecProfile do={
    #         # add security profile if not found
    #         :do {
    #             :local key ($1->"key");
    #             # search for profile with this same password if exist if not just create it.
    #             :local currentProfilesAtPassword do={
    #                 :local currentprfwpa2 [:parse "/interface wireless security-profiles print as-value where wpa2-pre-shared-key=\$1"];
    #                 :local currentprfwpa [:parse "/interface wireless security-profiles print as-value where wpa-pre-shared-key=\$1"];
    #                 :local secpp2 [$currentprfwpa2 $1];
    #                 :local secpp [$currentprfwpa $1];
    #                 :if ([:len $secpp2] > 0) do={
    #                     :return $secpp2;
    #                 } else={
    #                     :return $secpp;
    #                 }
    #             };
    #             # todo: separation of sec profiles ....
    #             :local foundSecProfiles [$currentProfilesAtPassword $key]; # error 
    #             :log info "add security profile if not found: $tempName";
    #             if ([:len $foundSecProfiles] > 0) do={
    #                 :return ($foundSecProfiles->0->"name");
    #             } else={
    #                  :local addSec  [:parse "/interface wireless security-profiles add \\
    #                     mode=dynamic-keys \\
    #                     name=(\"ispapp_\" . (\$1->\"ssid\")) \\
    #                     wpa2-pre-shared-key=(\$1->\"encKey\") \\
    #                     wpa-pre-shared-key=(\$1->\"encKey\") \\
    #                     authentication-types=wpa2-psk,wpa-psk"];
    #                 :put [$addSec $1];
    #                 :return $tempName;
    #             }
    #         } on-error={
    #             # return the default dec profile in case of error
    #             # adding or updating to perform interface setup with no problems
    #             :return [[:parse "/interface wireless security-profiles get *0 name"]];
    #         }
    #     }
    #     :global convertToValidFormat;
    #     ## start comparing local and remote configs
    #     foreach conf in=$wirelessConfigs do={
    #         :log info "## start comparing local and remote configs ##";
    #         :local finditf [:parse "/interface wireless find ssid=\$1"];
    #         :local existedinterf [$finditf ($conf->"ssid")];
    #         :local newSecProfile [$SyncSecProfile $conf];
    #         if ([:len $existedinterf] = 0) do={
    #             # add new interface
    #             :local NewInterName ("ispapp_" . [$convertToValidFormat ($conf->"ssid")]);
    #             :local masterinterface [[:parse "/interface wireless get ([/interface wireless find]->0) name"]];
    #             :log info "## add new interface -> $NewInterName ##";
    #             :local addInter [:parse "/interface wireless add \\
    #                 ssid=(\$1->\"ssid\") \\
    #                 wireless-protocol=802.11 frequency=auto mode=ap-bridge hide-ssid=no comment=ispapp \\
    #                 security-profile=(\$1->\"newSecProfile\") \\
    #                 name=(\$1->\"NewInterName\") \\
    #                 disabled=no;"];
    #             :local newinterface ($conf + {"newSecProfile"=$newSecProfile; "NewInterName"=$NewInterName});
    #             :log debug ("new interface details \n" . [:tostr $newinterface]);
    #             :put [$addInter $newinterface];
    #             :delay 3s; # wait for interface to be created
    #             :log info "## wait for interface to be created 3s ##";
    #         } else={
    #             :local setInter [:parse "/interface wireless set \$2 \\
    #                 ssid=(\$1->\"ssid\") \\
    #                 wireless-protocol=802.11 frequency=auto mode=ap-bridge hide-ssid=no comment=ispapp \\
    #                 security-profile=(\$1->\"newSecProfile\") \\
    #                 name=(\$1->\"NewInterName\") \\
    #                 disabled=no;"];
    #             # set the first interface to the new config
    #             :local newSecProfile [$SyncSecProfile $conf];
    #             :local NewInterName ("ispapp_" . [$convertToValidFormat ($conf->"ssid")]);
    #             :log info "## update new interface -> $NewInterName ##";
    #             [$setInter ($conf + {"newSecProfile"=$newSecProfile; "NewInterName"=$NewInterName}) ($existedinterf->0)];
    #             :delay 3s; # wait for interface to be setted
    #             :log info "## wait for interface to be created 3s ##";
    #             if ([:len $existedinterf] > 1) do={
    #                 # remove all interfaces except the first one
    #                 :foreach k,intfid in=$existedinterf do={
    #                     if ($k != 0) do={
    #                         [[:parse "/interface wireless remove [/interface wireless get $intfid name]"]];
    #                         :delay 1s; # wait for interface to be removed
    #                     }
    #                 }
    #             }
    #         }
    #     }
    #     :local message ("syncronization of " . [:len $wirelessConfigs] . " interfaces completed");
    #     :log info $message;
    #     :set output {
    #         "status"=true;
    #         "message0"=$message;
    #         "configs"=$wirelessConfigs
    #     };
    # }
    :local localwirelessConfigs [$getLocalWlans];
    if ($localwirelessConfigs->"status" = true) do={
        ## start uploading local configs to host
        # item sended example from local: "{\"if\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"key\":\"$wIfKey\",\"keytypes\":\"$wIfKeyTypeString\"}"
        :log info "## wait for interfaces changes to be applied and can be retrieved from the device 5s ##";
        :delay 1s; # wait for interfaces changes to be applied and can be retrieved from the device
        :local SecProfileslocalConfigs ({}); 
        :foreach k,secid in=[[:parse "/interface wireless security-profile print as-value"]] do={
            :local authtypes ($secid->"authentication-types");
            :local isdefault [:parse "/interface wireless security-profile get $k default"];
            :if ([:len $authtypes] = 0) do={ :set authtypes "[]";}
            :set ($SecProfileslocalConfigs->$k) ($secid+{
                "authentication-types"=$authtypes;
                "technology"="wireless";
                "isdefault"=[$isdefault]
            });
        };
        :local sentbody "{}";
        :local message ("uploading " . [:len ($localwirelessConfigs->"wirelessConfigs")] . " interfaces to ispapp server");
        :if ([:len ($localwirelessConfigs->"wirelessConfigs")] = 0) do={
            :set ($localwirelessConfigs->"wirelessConfigs") "[]";
        }
        :if ([:len $SecProfileslocalConfigs] = 0) do={
            :set SecProfileslocalConfigs "[]";
        }
        :global ispappHTTPClient;
        :local ifwconfigs ($localwirelessConfigs->"wirelessConfigs");
        :set sentbody ([$getAllConfigs $ifwconfigs $SecProfileslocalConfigs]->"json");
        :local returned  [$ispappHTTPClient m=post a=config b=$sentbody];
        :return ($output+{
            "status"=true;
            "body"=$sentbody;
            "response"=$returned;
            "message1"=$message
        });
    } else={
        :log info "no local wireless interfaces found (from WirelessInterfacesConfigSync function in ispLibrary.rsc)";
        :return ($output+{
            "status"=false;
            "message1"="no wireless interfaces found"
        });
    }
};
# Function to Download and return parsed RSADV CA.
:global latestCerts do={
    :local SectigoRSADVBundle;
    :set SectigoRSADVBundle [/tool  fetch http-method=get mode=https url="https://gogetssl-cdn.s3.eu-central-1.amazonaws.com/wiki/SectigoRSADVBundle.txt"  as-value output=user];
    :set SectigoRSADVBundle ($SectigoRSADVBundle->"data")
    :set SectigoRSADVBundle [:pick $SectigoRSADVBundle 0 ([:find $SectigoRSADVBundle "-----END CERTIFICATE-----"] + 26)];
    :return { "DV"=$SectigoRSADVBundle }
};

# Function to prepare ssl connection to ispappHTTPClient
:global prepareSSL do={
    :global ntpStatus false;
    :global caStatus false;
    :global topDomain;
    :global topListenerPort;
    # refrechable ssl state (each time u call [$sslIsOk] a new value will be returned)
    :local sslIsOk do={
        :do {
            :return ([/tool fetch url="https://$topDomain:$topListenerPort" mode=https check-certificate=yes output=user as-value]->"status" = "finished");
        } on-error={
            :return false;
        }
    };
    :local certs [/certificate find where name~"ispapp" trusted=yes];
    if ([:len $certs] > 0) do={
        :return {
            "ntpStatus"=true;
            "caStatus"=true
        };
    } else={
        :if ([$sslIsOk]) do={
            :return {
                "ntpStatus"=true;
                "caStatus"=true
            };
        }
        # Check NTP Client Status
        :local checkntp do={:do {:return ([:len [/system ntp client get "active-server"]] > 0)} on-error={:return ([/system ntp client get status] = "synchronized")}}
        if ([$checkntp]) do={
            :set ntpStatus true;
        } else={
            # Configure a new NTP client
            :put "adding ntp servers to /system ntp client \n";
            if (([:tonum [:pick [/system resource get version] 0 1]] > 6)) do={
                [[:parse "/system ntp client set enabled=yes mode=unicast servers=time.nist.gov,time.google.com,time.cloudflare.com,time.windows.com"]]
                
            } else={
                [[:parse "/system ntp client set enabled=yes server-dns-names=time.nist.gov,time.google.com,time.cloudflare.com,time.windows.com"]]
            }
            :delay 2s;
            :set ntpStatus true;
            :local retry 0;
            while ([/system ntp client get status] = "waiting" && $retry <= 5) do={
                :delay 500ms;
                :set retry ($retry + 1);
            }
            if ([/system ntp client get status] = "synchronized") do={
                :set ntpStatus true;
            }
        }
        # function to add to install downloaded bundle.
        :local addDv do={
            :global latestCerts;
            :local currentcerts [$latestCerts];
            # :put ("adding DV cert: \n" . ($currentcerts->"DV") . "\n");
            /file remove [find name~"ispapp.co_Sec"];
            /file add name=ispapp.co_SectigoRSADVBundle.txt contents=($currentcerts->"DV");
            /certificate import name=ispapp.co_SectigoRSADVBundle file=ispapp.co_SectigoRSADVBundle.txt;
        };
        :local retries 0;
        :do { 
            :local addDVres [$addDv];
            :delay 1s;
            if (!([:len [/certificate find name~"ispapp.co" trusted=yes ]] = 0)) do={
                :set caStatus true;
            }
            :set retries ($retries + 1);
        } while (([:len [/certificate find name~"ispapp.co" trusted=yes ]] = 0) && $retries <= 5)
    }
    :return { "ntpStatus"=$ntpStatus; "caStatus"=$caStatus };
}

# Converts a mixed array into a JSON string.
# Handles arrays, numbers, and strings up to 3 tested levels deep (it can do more levels now).
# Useful for converting RouterOS scripting language arrays into JSON.
:global toJson do={
  :local Aarray $1;
  :local IsArray false;
  if ([:typeof $Aarray] = "array") do={
    :set IsArray (([:find $Aarray [:pick $Aarray 0]] = 0) && ([:find $Aarray [:pick $Aarray ([:len $Aarray] - 1)]] = ([:len $Aarray] - 1)));
  } else={
     :if ([:typeof $Aarray] = "num") do={
        :return $Aarray;
     } else={
        :return "\"$Aarray\"";
     }
  }
  :local AjsonString "";
  if ((any $2) && ([:typeof $2] != "num")) do={
    if ($IsArray) do={
      :set AjsonString "\"$2\":[";
    } else={
      :set AjsonString "\"$2\":{";
    }
  } else={
    if ($IsArray) do={
    :set AjsonString "[";
    } else={
      :set AjsonString "{";
    }
  }
  :local idx 0;
  :foreach Akey,Avalue in=$Aarray do={
    :if ([:typeof $Avalue] = "array") do={
        :global toJson;
        :local v [$toJson $Avalue $Akey];
        :local AvalueJson $v;
        :set AjsonString "$AjsonString$AvalueJson";
    } else={
        if ($IsArray) do={
            :if ([:typeof $Avalue] = "num" || [:typeof $Avalue] = "bool") do={
                :set AjsonString "$AjsonString$Avalue";
            } else={
                :set AjsonString "$AjsonString\"$Avalue\"";
            }
        } else={
            :if ([:typeof $Avalue] = "num") do={
                :set AjsonString "$AjsonString\"$Akey\":$Avalue";
            } else={
                 :if ($Avalue = "[]" || $Avalue = "{}" || ([:typeof $Avalue] = "bool")) do={
                    :set AjsonString "$AjsonString\"$Akey\":$Avalue";
                } else={
                    :set AjsonString "$AjsonString\"$Akey\":\"$Avalue\"";
                }
            }
        }
    }
    if ($idx < ([:len $Aarray] - 1)) do={
        :set AjsonString "$AjsonString,";
    }
    :set idx ($idx + 1);
  }
  if ($IsArray) do={
    :set AjsonString "$AjsonString]";
  } else={
    :set AjsonString "$AjsonString}";
  }
  :return $AjsonString;
}

# @Details: Function to Diagnose important global variable for agent connection
# @Syntax: $TopVariablesDiagnose
# @Example: :put [$TopVariablesDiagnose] or just $TopVariablesDiagnose
:global TopVariablesDiagnose do={
    :global prepareSSL;
    :local sslPreparation [$prepareSSL];
    :global topDomain;
    :global topKey;
    :global login;
    :global certCheck "no";
    :global topSmtpPort;
    :global startEncode;
    :global isSend;
    :global rosMajorVersion;
    :global topListenerPort;
    # check if method argument is provided
    if (($sslPreparation->"ntpStatus" = true) && ($sslPreparation->"caStatus" = true)) do={
        :set certCheck "yes";
        :log info "ssl preparation is completed with success!";
    }
    :local res {"topListenerPort"=$topListenerPort; "topDomain"=$topDomain; "login"=$login};
    # try recover the cridentials from the file if exist.
    :if ([:len [/system script find name~"ispapp_cridentials"]] > 0) do={
        /system script run [find name~"ispapp_cridentials"];
    }
    # Check if topListenerPort is not set and assign a default value if not set
    :if (!any $topListenerPort) do={
      :set topListenerPort 8550;
    }
    :if ((!any $startEncode) || (!any $isSend)) do={
        :set startEncode 1;
        :set isSend 1;
    }
    # Check if topDomain is not set and assign a default value if not set
    :if (!any $topDomain) do={
      :set topDomain "test.ispapp.co"
    }
    :if (!any $topSmtpPort) do={
      :set topSmtpPort 8465;
    }
    :if (any$topDomain) do={
        :local setserver [:parse "/tool e-mail set server=(\$1)"]
        :local setaddress [:parse "/tool e-mail set address=(\$1)"]
        :if (any([/tool e-mail print as-value]->"server")) do={
          :put [$setserver $topDomain]
        } else={
          :put [$setaddress $topDomain]
        }
    }
    :if (any$topSmtpPort && ([/tool e-mail get port] != $topSmtpPort)) do={
        /tool e-mail set port=([:tonum $topSmtpPort]);
    }
    :if (!any$rosMajorVersion) do={
        :local ROSver value=[:tostr [/system resource get value-name=version]];
        :local ROSverH value=[:pick $ROSver 0 ([:find $ROSver "." -1]) ];
        :set rosMajorVersion value=[:tonum $ROSverH];
        :if ($rosMajorVersion = 7) do={
            :local settls [:parse "/tool e-mail set tls=yes"];
            :log info [$settls];
        }
    }
  :set res {"topListenerPort"=$topListenerPort; "topDomain"=$topDomain; "login"=$login};
  :return $res;
}

# Function to remove all scripts from the system related to ispapp agent
# usage:
#   [$removeIspappScripts] // don't expect no returns check just the logs after.
:global removeIspappScripts do={
    :local scriptList [/system script find where name~"ispapp.*"]
    if ([:len [/system script find where name~"ispapp.*"]] > 0) do={
        :foreach scriptId in=$scriptList do={
            :local scriptName [/system script get $scriptId name];
            :do {
                /system script remove $scriptId;
                :put "found $scriptName.rsc and removed \E2\9C\85";
                :log info "found $scriptName and removed \E2\9C\85";
                :delay 500ms;
            } on-error={
                :log error "\E2\9D\8C Could not remove script id $scriptId: $scriptName.rsc";
            }
        }
    }
}

# Function to remove all schedulers from the system related to ispapp agent
# usage:
#   [$removeIspappSchedulers] // don't expect no returns check just the logs after.
:global removeIspappSchedulers do={
    :local scriptList [/system scheduler find where name~"ispapp.*"]
    if ([:len [/system scheduler find where name~"ispapp.*"]] > 0) do={
        :foreach schedulerId in=$schedulerList do={
            :do {
                /system scheduler remove $schedulerId;
                :put "found $schedulerName and removed \E2\9C\85";
                :log info "found $schedulerName and removed \E2\9C\85";
                :delay 500ms;
            } on-error={
                :local schedulerName [/system scheduler get $schedulerId name];
                :log error "\E2\9D\8C Could not remove scheduler id $schedulerId: $schedulerName";
            }
        }
    }
}

# Function to simplify fJParse usage;
# usage:
#   :put [$JSONLoads "{\"hello\":\"world\"}"];
:global JSONLoads do={
    :global JSONIn $1;
    :global fJParse;
    :local ret [$fJParse];
    :set JSONIn;
    :global Jpos;
    :global Jdebug; if (!$Jdebug) do={set Jdebug};
    :return $ret;
}

# Function that takes a string as an input and converts it to the desired format
# Example usage:
# :put [$convertToValidFormat "this_is_a_Test! @#?/string"] // returns "this_is_a_Test______string"
:global convertToValidFormat do={
    :local inputString ($1)
    :local validCharacters "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
    :local outputString ""
    
    :local length [:len $inputString]
    :local i 0
    :while ($i < $length) do={
        :local currentCharacter [:pick $inputString $i]
        :if ([:typeof [:find $validCharacters $currentCharacter]] = "num") do={
            :set outputString ($outputString . $currentCharacter)
        } else={
            :set outputString ($outputString . "_")
        }
        :set i ($i + 1)
    }
    :return $outputString;
}


# Function in RouterOS script that formats the authentication types as per the specified rules
# Example usage:
# :put [$formatAuthTypes "wpa-psk wpa2-psk wpa3-eap wpa2-eap"]
:global formatAuthTypes do={
    :local inputTypes ($1)
    :local validTypesArr [:toarray "wpa-eap, wpa-psk, wpa2-eap, wpa2-psk"];
    :local outputTypes ""
    :local typesArr "";
    :for i from=0 to=[:len $inputTypes] do={
        :if ([:pick $inputTypes $i] = " " || [:pick $inputTypes $i] = ";") do={
            :set typesArr ($typesArr. ", ");
        } else={
            :set typesArr ($typesArr. [:pick $inputTypes $i]);
        }
    }
    :set typesArr [:toarray $typesArr];
    :foreach atype in=$typesArr do={
        :if ([:typeof [:find $validTypesArr $atype]] = "num") do={
            :if ($outputTypes = "") do={
                :set outputTypes $atype;
            } else={
                :set outputTypes ($outputTypes . "," . $atype);
            }
        }
    }
    :return $outputTypes;
}

#   :put [$ispappHTTPClient m=<get|post|put|delete> a=<update|config> b=<json>]
:global ispappHTTPClient do={
    :local method $m; # method
    :local action $a; # action
    :local body $b; # body
    :local certCheck;
    :global topDomain;
    :global topKey;
    :global login;
    :global topListenerPort;
    :global topDomain;
    :global accessToken;
    :global refreshToken;
    :global initConfig;
    :if (!any$certCheck) do={
        :set certCheck "no";
    }
    # get current time and format it
    :local time [/system clock print as-value];
    :local formattedTime (($time->"date") . " | " . ($time->"time"));
    :local actions ("update", "config", "/v1/host_fw", "bandwidth");
    if (!any $m) do={
        :set method "get";
    }
    # check if action was provided  
    if (!any $a) do={
        :set action "config";
        :log warning ("default action added!\t ispappLibrary.rsc\t[" . $formattedTime . "] !\tusage: (ispappHTTPClient a=<update|config> b=<json>  m=<get|post|put|delete>)");
    }
    # Check if topListenerPort is not set and assign a default value if not set
    :if (!any $topListenerPort) do={
        :set topListenerPort 8550;
    }
    # Check if topDomain is not set and assign a default value if not set
    :if (!any $topDomain) do={
        :set topDomain "qwer.ispapp.co";
    }
    # Check certificates
    # Make request
    :local out;
    :local requesturl;
    :do {
         :set requesturl "https://$topDomain:$topListenerPort/$action";
        # Check if accessToken exists, if so, use it; otherwise, fall back to login and key
        :if ([:len $accessToken] > 0) do={
            :set requesturl ($requesturl . "?accessToken=$accessToken");
        } else={
            :set accessToken
            # :return "no accessToken"
            :if (any $login && any $topKey) do={
                :set requesturl ($requesturl . "?login=$login&key=$topKey");
            }
        }
        :log info "Request details: \n\t$requesturl \n\t http-method=\"$m\" \n\t http-data=\"$b\"";
        if (!any $b) do={
            :set out [/tool fetch url=$requesturl check-certificate=$certCheck http-method=$m output=user as-value];
        } else={
            :put $b;
            :set out [/tool fetch url=$requesturl check-certificate=$certCheck http-header-field="cache-control: no-cache, content-type: application/json, Accept: */*" http-method="$m" http-data="$b" output=user as-value];
        }
        if ($out->"status" = "finished") do={
            :global JSONLoads;
            :local receieved ($out->"data");
            if ([:len $receieved] = 0) do={
                :set receieved "{}";
            }
            :local parses [$JSONLoads $receieved];
            :if (any ($parses->"error")) do={ 
                :if ($parses->"error" = "notfound") do={
                    :set accessToken
                    :set refreshToken
                }
                :if ($parses->"error" = "unauthorized") do={
                    :set accessToken
                    # :set refreshToken
                }
                /system script run ispappInit
                :return { "status"=true; "reason"=($parses->"error"); "requestUrl"=$requesturl };
             }
            :return { "status"=true; "response"=($out->"data"); "parsed"=$parses; "requestUrl"=$requesturl };
        }
    } on-error={
        # :set accessToken
        # /system script run ispappInit
        :return { "status"=false; "reason"=($out->"status"); "requestUrl"=$requesturl };
    }
}
:put "\t V1 Library loaded! (;";