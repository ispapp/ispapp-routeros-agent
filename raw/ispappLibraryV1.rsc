############################### this file contain predefined functions to be used across the agent script ################################
# for checking purposes
:global ispappLibraryV1 "ispappLibraryV1 loaded";
:global login;
# Function to collect all wireless interfaces and format them to be sent to server.
# @param $topDomain - domain of the server
# @param $topKey - key of the server
# @param $topListenerPort - port of the server
# @param $login - login of the server
# @param $password - password of the server
# @param $prepareSSL - if true, SSL preparation will be done
# @return $wlans - array of wireless interfaces
# @return $status - status of the operation
# @return $message - message of the operation
:global WirelessInterfacesConfigSync do={
    :global getAllConfigs;
    :global ispappHTTPClient;
    :local getConfig do={
        # get configuration from the server
        :do {
            :global ispappHTTPClient;
            :local res;
            :local i 0;
            :if ([$ispappHTTPClient m="get" a="update"]->"status" = false) do={
                :return { "responce"="firt time config of server error"; "status"=false };
            }
            :while ((any[:find [:tostr $res] "Err.Raise"] || !any$res) && $i < 3) do={
                :set res ([$ispappHTTPClient m="get" a="config"]->"parsed");
                :set i ($i + 1);
            }
            if (any [:find [:tostr $res] "Err.Raise"]) do={
                # check id json received is valid and redy to be used
                :log error "error while getting config (Err.Raise fJSONLoads)";
                :return {"status"=false; "message"="error while getting config (Err.Raise fJSONLoads)"};
            } else={
                :if ($res->"host"->"Authed" != true) do={
                    :log error [:tostr $res];
                    :return {"status"=false; "message"=$res};
                } else={
                    :log info "check id json received is valid and redy to be used with responce: $res";
                    :return { "responce"=$res; "status"=true };
                }
            }
        } on-error={
            :log error "error while getting config (Err.Raise fJSONLoads)";
            :return {"status"=false; "message"="error while getting config"};
        }
    };
    :local getLocalWlans do={
        # collect all wireless interfaces from the system
        # format them to be sent to server
        :log info "start collect all wireless interfaces from the system ...";
        :local wlans [/interface/wireless find];
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
         if ([:len $wlans] > 0) do={
            :local wirelessConfigs;
            foreach i,k in=$wlans do={
                :local temp [/interface/wireless print proplist=ssid,security-profile as-value where .id=$k];
                :local cmdsectemp [:parse "/interface/wireless/security-profiles print proplist=wpa-pre-shared-key,authentication-types,wpa2-pre-shared-key  as-value where  name=\$1"];
                :local secTemp [$cmdsectemp ($temp->0->"security-profile")];
                :local thisWirelessConfig {
                  "encKey"=[$getEncKey ($secTemp->0)];
                  "encType"=($secTemp->0->"authentication-types");
                  "ssid"=($temp->0->"ssid")
                };
                :set ($wirelessConfigs->$i) $thisWirelessConfig;
            }
            :log info "collect all wireless interfaces from the system";
            :return { "status"=true; "wirelessConfigs"=$wirelessConfigs };
         } else={
            :log info "collect all wireless interfaces from the system: no wireless interfaces found";
            :return { "status"=false; "message"="no wireless interfaces found" };
         }
    };
    :delay 1s;
    :log info "done setting local functions .... 1s"
    # check if our host is authorized to get configuration
    # and ready to accept interface syncronization
    :local configResponce [$getConfig];
    :local localwirelessConfigs [$getLocalWlans];
    :local output;
    :local wirelessConfigs [:toarray ""];
    :if ($configResponce->"status" = true) do={
        :set wirelessConfigs ($configResponce->"responce"->"host"->"wirelessConfigs");
    }
    :delay 1s;
    :log info "done setting wirelessConfigs .... 1s"
    if ([:len $wirelessConfigs] > 0) do={
        # this is the case when some interface configs received from the host
        # get security profile with same password as the one on first argument $1
        :global SyncSecProfile do={
            # add security profile if not found
            :do {
                :local key ($1->"encKey");
                # search for profile with this same password if exist if not just create it.
                :local currentProfilesAtPassword do={
                    :local currentprfwpa2 [:parse "/interface/wireless/security-profiles/print as-value where wpa2-pre-shared-key=\$1"];
                    :local currentprfwpa [:parse "/interface/wireless/security-profiles/print as-value where wpa-pre-shared-key=\$1"];
                    :local secpp2 [$currentprfwpa2 $1];
                    :local secpp [$currentprfwpa $1];
                    :if ([:len $secpp2] > 0) do={
                        :return $secpp2;
                    } else={
                        :return $secpp;
                    }
                };
                # todo: separation of sec profiles ....
                :local foundSecProfiles [$currentProfilesAtPassword $key]; # error 
                :log info "add security profile if not found: $tempName";
                if ([:len $foundSecProfiles] > 0) do={
                    :return ($foundSecProfiles->0->"name");
                } else={
                     :local addSec  [:parse "/interface wireless security-profiles add \\
                        mode=dynamic-keys \\
                        name=(\"ispapp_\" . (\$1->\"ssid\")) \\
                        wpa2-pre-shared-key=(\$1->\"encKey\") \\
                        wpa-pre-shared-key=(\$1->\"encKey\") \\
                        authentication-types=wpa2-psk,wpa-psk"];
                    :put [$addSec $1];
                    :return $tempName;
                }
            } on-error={
                # return the default dec profile in case of error
                # adding or updating to perform interface setup with no problems
                :return [/interface/wireless/security-profiles/get *0 name];
            }
        }
        :global convertToValidFormat;
        ## start comparing local and remote configs
        foreach conf in=$wirelessConfigs do={
            :log info "## start comparing local and remote configs ##";
            :local existedinterf [/interface/wireless/find ssid=($conf->"ssid")];
            :local newSecProfile [$SyncSecProfile $conf];
            if ([:len $existedinterf] = 0) do={
                # add new interface
                :local NewInterName ("ispapp_" . [$convertToValidFormat ($conf->"ssid")]);
                :local masterinterface [/interface/wireless/get ([/interface/wireless/find]->0) name];
                :log info "## add new interface -> $NewInterName ##";
                :local addInter [:parse "/interface/wireless/add \\
                    ssid=(\$1->\"ssid\") \\
                    wireless-protocol=802.11 frequency=auto mode=ap-bridge hide-ssid=no comment=ispapp \\
                    security-profile=(\$1->\"newSecProfile\") \\
                    master-interface=\$masterinterface \\
                    name=(\$1->\"NewInterName\") \\
                    disabled=no;"];
                :local newinterface ($conf + {"newSecProfile"=$newSecProfile; "NewInterName"=$NewInterName});
                :log debug ("new interface details \n" . [:tostr $newinterface]);
                :put [$addInter $newinterface];
                :delay 3s; # wait for interface to be created
                :log info "## wait for interface to be created 3s ##";
            } else={
                :local setInter [:parse "/interface/wireless/set \$2 \\
                    ssid=(\$1->\"ssid\") \\
                    wireless-protocol=802.11 frequency=auto mode=ap-bridge hide-ssid=no comment=ispapp \\
                    security-profile=(\$1->\"newSecProfile\") \\
                    name=(\$1->\"NewInterName\") \\
                    disabled=no;"];
                # set the first interface to the new config
                :local newSecProfile [$SyncSecProfile $conf];
                :local NewInterName ("ispapp_" . [$convertToValidFormat ($conf->"ssid")]);
                :log info "## update new interface -> $NewInterName ##";
                [$setInter ($conf + {"newSecProfile"=$newSecProfile; "NewInterName"=$NewInterName}) ($existedinterf->0)];
                :delay 3s; # wait for interface to be setted
                :log info "## wait for interface to be created 3s ##";
                if ([:len $existedinterf] > 1) do={
                    # remove all interfaces except the first one
                    :foreach k,intfid in=$existedinterf do={
                        if ($k != 0) do={
                            /interface/wireless/remove [/interface/wireless/get $intfid name];
                            :delay 1s; # wait for interface to be removed
                        }
                    }
                }
            }
        }
        :local message ("syncronization of " . [:len $wirelessConfigs] . " interfaces completed");
        :log info $message;
        :set output {
            "status"=true;
            "message0"=$message;
            "configs"=$wirelessConfigs
        };
    }
    if ([$localwirelessConfigs]->"status" = true) do={
        ## start uploading local configs to host
        # item sended example from local: "{\"if\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"key\":\"$wIfKey\",\"keytypes\":\"$wIfKeyTypeString\"}"
        :log info "## wait for interfaces changes to be applied and can be retrieved from the device 5s ##";
        :delay 5s; # wait for interfaces changes to be applied and can be retrieved from the device
        :local InterfaceslocalConfigs;
        :local getkeytypes  [:parse "/interface/wireless/security-profiles/get [/interface/wireless/get \$1 security-profile] authentication-types"];
        :foreach k,interfaceid in=[/interface/wireless/find] do={
            :set ($InterfaceslocalConfigs->$k) {
                "if"=([/interface/wireless/get $interfaceid name]);
                "ssid"=([/interface/wireless/get $interfaceid ssid]);
                "key"=([/interface/wireless/security-profile get [/interface/wireless/get $interfaceid security-profile] wpa2-pre-shared-key]);
                "keytypes"=([$joinArray [$getkeytypes $interfaceid] ","]);
                "interface-type"=([/interface/wireless/get $interfaceid interface-type]);
                "security_profile"=([/interface/wireless/get $interfaceid security-profile])
            };
        };
        :local SecProfileslocalConfigs; 
        :foreach k,secid in=[/interface/wireless/security-profile find] do={
            :set ($SecProfileslocalConfigs->$k) {
                "name"=([/interface/wireless/security-profile get $secid name]);
                "authentication-types"=([/interface/wireless/security-profile get $secid authentication-types]);
                "wpa2-pre-shared-key"=([/interface/wireless/security-profile get $secid wpa2-pre-shared-key]);
                "wpa-pre-shared-key"=([/interface/wireless/security-profile get $secid wpa-pre-shared-key]);
                "eap-methods"=([/interface/wireless/security-profile get $secid eap-methods]);
                "mode"=([/interface/wireless/security-profile get $secid mode]);
                "default"=([/interface/wireless/security-profile get $secid default])
            };
        };
        :local sentbody "{}";
        :local message ("uploading " . [:len $InterfaceslocalConfigs] . " interfaces to ispapp server");
        :if ([:len $InterfaceslocalConfigs] = 0) do={
            :set InterfaceslocalConfigs "[]";
        }
        :if ([:len $SecProfileslocalConfigs] = 0) do={
            :set SecProfileslocalConfigs "[]";
        }
        :global getAllConfigs;
        :global ispappHTTPClient;
        :set sentbody ([$getAllConfigs $InterfaceslocalConfigs $SecProfileslocalConfigs]->"json");
        :local returned  [$ispappHTTPClient m=post a=config b=$sentbody];
        :return ($output+{
            "status"=true;
            "body"=$sentbody;
            "responce"=$returned;
            "message1"=$message
        });
    } else={
        :log info "no local wireless interfaces found (from WirelessInterfacesConfigSync function in ispLibrary.rsc)";
        :return ($output+{
            "status"=true;
            "message1"="no wireless interfaces found"
        });
    }
};

# Function to prepare ssl connection to ispappHTTPClient
# 1- check ntp client status if synced with google/apple ntp servers.
#   10- setup ntp client if not synced and keep refreching 3 times max until it's working
#   11- if ntp client is not working, then exit the function with false in ntpStatus key value.
# 2- check if "Sectigo RSA DV CA" and "USERTrust RSA CA" exist and trusted.
#   20- download and install the latest bundle if not exists.
#   21- install the latest bundle if not valid.
#   23- if bundle is not installed, then exit the function with false in caStatus key value.

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
    :local certs [/certificate/find where name~"ispapp" trusted=yes];
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
        if ([/system ntp client get status] = "synchronized") do={
            :set ntpStatus true;
        } else={
            # Configure a new NTP client
            :put "adding ntp servers to /system ntp client \n";
            /system ntp client set enabled=yes mode=unicast servers=time.nist.gov,time.google.com,time.cloudflare.com,time.windows.com
            /system/ntp/client/reset-freq-drift 
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
        :local latestCerts do={
            # Download and return parsed CAs.
            :local data [/tool  fetch http-method=get mode=https url="https://gogetssl-cdn.s3.eu-central-1.amazonaws.com/wiki/SectigoRSADVBundle.txt"  as-value output=user];
            :local data0 [:pick ($data->"data") 0 ([:find ($data->"data") "-----END CERTIFICATE-----"] + 26)]; 
            :return { "DV"=$data0 }
        };
        # function to add to install downloaded bundle.
        :local addDv do={
            :local currentcerts [$latestCerts];
            :put ("adding DV cert: \n" . ($currentcerts->"DV") . "\n");
            if (([:len [/file find where name~"ispapp.co_SectigoRSADVBundle"]] = 0)) do={
            /file add name=ispapp.co_SectigoRSADVBundle.txt contents=($currentcerts->"DV");
            /certificate import name=ispapp.co_SectigoRSADVBundle file=ispapp.co_SectigoRSADVBundle.txt;
            } else={
                /file set [/file find where name=ispapp.co_SectigoRSADVBundle.txt] contents=($currentcerts->"DV");
                /certificate import name=ispapp.co_SectigoRSADVBundle file=ispapp.co_SectigoRSADVBundle.txt;
            }
        };
        :do {
            [$addDv];
        } on-error={
            :put "error adding DV cert \n";
        }
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
    :global topDomain;
    :global topKey;
    :global login;
    :global topSmtpPort;
    :global rosMajorVersion;
    :global topListenerPort;
    :local refreched do={
        :global topDomain;
        :global topKey;
        :global login;
        :global topSmtpPort;
        :global rosMajorVersion;
        :global topListenerPort;
        :return {"topListenerPort"=$topListenerPort; "topDomain"=$topDomain; "login"=$login}
    };
    :local res {"topListenerPort"=$topListenerPort; "topDomain"=$topDomain; "login"=$login};
    # try recover the cridentials from the file if exist.
    :if ([:len [/file find name=ispapp_cridentials]] > 0) do={
        [[:parse [/file get [/file find where name~"ispapp_cridentials"] contents]]]
    }
    # Check if topListenerPort is not set and assign a default value if not set
    :if (!any $topListenerPort) do={
      :global topListenerPort 8550;
      :set res [$refreched];
    }
    :if ((!any $startEncode) || (!any $isSend)) do={
        :global startEncode 1;
        :global isSend 1;
    }
    # Check if topDomain is not set and assign a default value if not set
    :if (!any $topDomain) do={
      :global topDomain "qwer.ispapp.co"
      :set res [$refreched];
    }
    :if (!any $topSmtpPort) do={
      :global topSmtpPort 8465;
      :set res [$refreched];
    }
    :if ([/tool e-mail get address] != $topDomain) do={
        /tool e-mail set address=($topDomain);
    }
    :if ([/tool e-mail get port] != $topSmtpPort) do={
        /tool e-mail set port=([:tonum $topSmtpPort]);
    }
    :if (!any $rosMajorVersion) do={
        :local ROSver value=[:tostr [/system resource get value-name=version]];
        :local ROSverH value=[:pick $ROSver 0 ([:find $ROSver "." -1]) ];
        :global rosMajorVersion value=[:tonum $ROSverH];
        :if ($rosMajorVersion = 7) do={
            :local settls [:parse "/tool e-mail set tls=yes"];
            :log info [$settls];
        }
    }
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

# Ispapp HTTP Client
# Usage:
# :put [$ispappHTTPClient m=<get|post|put|delete> a=<update|config> b=<json>]
:global ispappHTTPClient do={
    :global prepareSSL;
    :local sslPreparation [$prepareSSL];
    :local method $m; # method
    :local action $a; # action
    :local body $b; # body
    :local certCheck "no";
    :global topDomain;
    :global topKey;
    :global login;
    :global topListenerPort;
    # get current time and format it
    :local time [/system clock print as-value];
    :local formattedTime (($time->"date") . " | " . ($time->"time"));
    :local actions ("update", "config");
    # check if method argument is provided
    if (($sslPreparation->"ntpStatus" = true) && ($sslPreparation->"caStatus" = true)) do={
        :set certCheck "yes";
        :log info "ssl preparation is completed with success!";
    }
    
    if (!any $m) do={
        :local method "get";
    }
    # check if action was provided  
    if (!any $a) do={
        :set action "config";
        :log warning ("default action added!\t ispappLibrary.rsc\t[" . $formattedTime . "] !\tusage: (ispappHTTPClient a=<update|config> b=<json>  m=<get|post|put|delete>)");
    }
    # check if key was provided if not run ispappSet
    if (!any $topKey) do={
        :set topKey; 
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
        :global login;
        :set requesturl "https://$topDomain:$topListenerPort/$action?login=$login&key=$topKey";
        :log info "Request details: \n\t$requesturl \n\t http-method=\"$m\" \n\t http-data=\"$b\"";
        if (!any $b) do={
            :set out [/tool fetch url=$requesturl check-certificate=$certCheck http-method=$m output=user as-value];
        } else={
            :set out [/tool fetch url=$requesturl check-certificate=$certCheck http-header-field="cache-control: no-cache, content-type: application/json, Accept: */*" http-method="$m" http-data="$b" output=user as-value];
        }
        if ($out->"status" = "finished") do={
            :global JSONLoads;
            :local parses [$JSONLoads ($out->"data")];
            :return { "status"=true; "response"=($out->"data"); "parsed"=$parses; "requestUrl"=$requesturl };
        } else={
            :return { "status"=false; "reason"=($out); "requestUrl"=$requesturl };
        }
    } on-error={
        :return { "status"=false; "reason"=($out->"status"); "requestUrl"="https://$topDomain:$topListenerPort/$action?login=$login&key=$topKey" };
    }
}
:put "\t V1 Library loaded! (;";