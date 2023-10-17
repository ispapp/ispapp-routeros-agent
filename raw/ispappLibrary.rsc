############################### this file contain predefined functions to be used across the agent script ####################################

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
    # check if SSL preparation is needed
    :local sslPreparation [$prepareSSL];
    :local loginIsOk do={
        # check if login and password are correct
        :do {
            :return ([/tool fetch url="https://$topDomain:$topListenerPort/update?login=$login&key=$topKey" mode=https check-certificate=yes output=user as-value]->"status" = "finished");
        } on-error={
            :return false;
        }
    };
    :local getConfig do={
        :do {
            :local res [$JSONLoads  ([/tool fetch url="https://$topDomain:$topListenerPort/config?login=$login&key=$topKey" mode=https check-certificate=yes output=user as-value]->"data")]
            :return { "responce"=$res; "status"=true };
        } on-error={
            :return {"status"=false; "message"="error while getting config"};
        }
    };
    :local getLocalWlans do={
        # collect all wireless interfaces from the system
        # format them to be sent to server
        :local wlans [/interface/wireless find where disabled=no];
         if ([:len $wlans] > 0) do={
            :local wirelessConfigs {};
            foreach k in=$wlans do={
                :local temp [/interface/wireless print proplist=ssid,security-profile as-value where .id=$k];
                :local secTemp [/interface/wireless/security-profiles print proplist=wpa-pre-shared-key,authentication-types,wpa2-pre-shared-key  as-value where  name=($temp->"security-profile")];
                :local getEncKey do={
                    if([:len ($1->"wpa-pre-shared-key")] > 0) do={
                        :return $1->"wpa-pre-shared-key";
                    } else={
                        if([:len ($1->"wpa2-pre-shared-key")] > 0) do={
                            :return $1->"wpa2-pre-shared-key";
                        } else={
                            :return "";
                        }
                    }
                }
                :local thisWirelessConfig {
                  "encKey"=($secTemp->"");
                  "encType"=[$getEncKey $secTemp];
                  "ssid"=($temp->"ssid")
                };
                :set wirelessConfigs ($wirelessConfigs+$thisWirelessConfig);
            }
            :return { "status"=true; "wirelessConfigs"=$wirelessConfigs };
         } else={
            :return { "status"=false; "message"="no wireless interfaces found" };
         }
    }
    if ([$loginIsOk]) do={
        :local resconfig [$getConfig];
        :delay 500ms;
        :local retrying 0;
        :local configResponce;
        while ((!any ($configResponce->"Authed")) && $retrying <=5) do={
            :set configResponce ([$resconfig]->"responce"->"host")
            :delay 400ms;
            :set retrying ($retrying + 1);
        }
        :local wirelessConfigs ($configResponce->"wirelessConfigs");
        if ([:len $wirelessConfigs] > 0) do={
            # item received example from local: "{\"if\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"key\":\"$wIfKey\",\"keytypes\":\"$wIfKeyTypeString\"}"
            :local localwirelessConfigs [$getLocalWlans];
            :local getSecProfile do={
                # input example from host: clientIsolation=false;dotw=false;dtimPeriod=0;encKey=oxygen_12034;encType=wpa-psk wpa2-psk;sp=false;ssid=sous sol;vlanId=0
                # Get security profile for a wireless configs from server
                # if does't exist create one
                # return security profile name
                # usage: [$getSecProfile $wirelessConfigs] // returns security profile name

                :local secprofile [/interface/wireless/security-profiles/find where wpa-pre-shared-key=($1->"encKey")];
                if([:len $secprofile] > 0) do={
                    :return [/interface/wireless/security-profiles/get ($secprofile->0) name];
                } else={
                     /interface/wireless/security-profiles/add\
                        name=("ispapp_" . ($1->"ssid"))\
                        wpa2-pre-shared-key=($1->"encKey")\
                        enabled=yes\
                        wpa-pre-shared-key=($1->"encKey")\
                        authentication-types=[$formatAuthTypes ($1->"encType")];
                     :return ("ispapp_" . ($1->"ssid"))
                }
            }

            ## start comparing local and remote configs
            foreach conf in=$wirelessConfigs do={
                :local existedinterf [/interface/wireless/find where ssid=($conf->"ssid")];
                if(([:len $existedinterf] = 0)) do={
                    # add new interface
                    /interface/wireless/add\
                        ssid=($conf->"ssid")\
                        security-profile=[$getSecProfile $conf]\
                        name=("ispapp_" . [$convertToValidFormat ($conf->"ssid")])\
                        disabled=no\
                        mode=station\
                } else={
                    if ([:len $existedinterf] > 1) do={
                        # remove all interfaces except the first one
                        :foreach k,intfid in=$existedinterf do={
                            if ($k != 0) do={
                                /interface/wireless/remove [/interface/wireless/get $intfid name];
                            }
                        }
                        # set the first interface to the new config
                        /interface/wireless/set [/interface/wireless/get ($existedinterf->0) name]\
                        ssid=($conf->"ssid")\
                        security-profile=[$getSecProfile $conf]\
                        name=("ispapp_" . [$convertToValidFormat ($conf->"ssid")])\
                        disabled=no\
                        mode=station\
                    } else={
                        # set the first interface to the new config
                        /interface/wireless/set [/interface/wireless/get ($existedinterf->0) name]\
                        ssid=($conf->"ssid")\
                        security-profile=[$getSecProfile $conf]\
                        name=("ispapp_" . [$convertToValidFormat ($conf->"ssid")])\
                        disabled=no\
                        mode=station\
                    }
                }
            }
            :return {
                "status"=true;
                "message"=$wirelessConfigs
            };
        } else={
            :local localwirelessConfigs [$getLocalWlans];
            if ([$localwirelessConfigs]->"status" = true) do={
                ## start uploading local configs to host
                # item sended example from local: "{\"if\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"key\":\"$wIfKey\",\"keytypes\":\"$wIfKeyTypeString\"}"
                :local localConfigs;
                :foreach interfaceid in=[/interface/wireless/find] do={
                    :set localConfigs ($localConfigs+({
                        "if"=([/interface/wireless/get $interfaceid name]);
                        "ssid"=([/interface/wireless/get $interfaceid ssid]);
                        "key"=([/interface/wireless/security-profile get [/interface/wireless/get $interfaceid security-profile] wpa-pre-shared-key]);
                        "keytypes"=([$joinArray [/interface/wireless/security-profiles/get [/interface/wireless/get $interfaceid security-profile] authentication-types] ","])
                    }))
                }
                :return {
                    "status"=true;
                    "message"="no wireless configs found"
                };
            } else={
                :return {
                    "status"=true;
                    "message"="no wireless configs found"
                };
            }
        }
    } else={
        :return {
            "status"=false;
            "message"="login or key is wrong"
        };
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
    # refrechable ssl state (each time u call [$sslIsOk] a new value will be returned)
    :local sslIsOk do={
        :do {
            :return ([/tool fetch url="https://$topDomain:$topListenerPort" mode=https check-certificate=yes output=user as-value]->"status" = "finished");
        } on-error={
            :return false;
        }
    };
    if ([$sslIsOk]) do={
        :return {
            "ntpStatus"=true;
            "caStatus"=true
        };
    } else={
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
        :global latestCerts do={
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
# Handles arrays, numbers, and strings up to 3 levels deep.
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
  if ($IsArray) do={
    :set AjsonString "[";
  } else={
    :set AjsonString "{";
  }
  :local idx 0;
  :foreach Akey,Avalue in=$Aarray do={
    :if ([:typeof $Avalue] = "array") do={
        :local AvalueJson [$toJson $Avalue];
        :set AjsonString "$AjsonString\"$Akey\":$AvalueJson";
    } else={
        if ($IsArray) do={
            :if ([:typeof $Avalue] = "num") do={
                :set AjsonString "$AjsonString$Avalue";
            } else={
                :set AjsonString "$AjsonString\"$Avalue\"";
            }
        } else={
            :if ([:typeof $Avalue] = "num") do={
                :set AjsonString "$AjsonString\"$Akey\":$Avalue";
            } else={
                :set AjsonString "$AjsonString\"$Akey\":\"$Avalue\"";
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

# @Details: Function to convert to lowercase or uppercase 
# @Syntax: $strcaseconv <input string>
# @Example: :put ([$strcaseconv sdsdFS2k-122nicepp#]->"upper") --> result: SDSDFS2K-122NICEPP#
# @Example: :put ([$strcaseconv sdsdFS2k-122nicepp#]->"lower") --> result: sdsdfs2k-122nicepp#
:global strcaseconv do={
    :local outputupper;
    :local outputlower;
    :local lower ("a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z")
    :local upper ("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z")
    :local lent [:len $1];
    :for i from=0 to=($lent - 1) do={ 
        if (any [:find $lower [:pick $1 $i]]) do={
            :set outputupper ($outputupper . [:pick $upper [:find $lower [:pick $1 $i]]]);
        } else={
            :set outputupper ($outputupper . [:pick $1 $i])
        }
        if (any [:find $upper [:pick $1 $i]]) do={
            :set outputlower ($outputlower . [:pick $lower [:find $upper [:pick $1 $i]]]);
        } else={
            :set outputlower ($outputlower . [:pick $1 $i])
        }
    }
    :return {upper=$outputupper; lower=$outputlower};
}

# @Details: Function to Diagnose important global variable for agent connection
# @Syntax: $TopVariablesDiagnose
# @Example: :put [$TopVariablesDiagnose] or just $TopVariablesDiagnose
:global TopVariablesDiagnose do={
    :local refreched do={:return {"topListenerPort"=$topListenerPort; "topDomain"=$topDomain; login=$login}};
    :local res {"topListenerPort"=$topListenerPort; "topDomain"=$topDomain; "login"=$login};
    # Check if topListenerPort is not set and assign a default value if not set
    :if (!any $topListenerPort) do={
      :global topListenerPort 8550;
      :set res [$refreched];
    }
    # Check if topDomain is not set and assign a default value if not set
    :if (!any $topDomain) do={
      :global topDomain "qwer.ispapp.co"
      :set res [$refreched];
    }
    # Check if login is not set and assign a default value as the MikroTik MAC address
    :if (!any $login) do={
      :do {
        :global login ([/interface get [find default-name=wlan1] mac-address]);
        :set res [$refreched];
      } on-error={
        :do {
          :global login ([/interface get [find default-name=ether1] mac-address]);
          :set res [$refreched];
        } on-error={
            :do {
                :global login ([/interface get [find default-name=sfp-sfpplus1] mac-address]);
                :set res [$refreched];
            } on-error={
                :do {
                    :global login ([/interface get [find default-name=lte1] mac-address]);
                    :set res [$refreched];
                } on-error={
                    :log info ("No Interface MAC Address found to use as ISPApp login, default-name=wlan1, ether1, sfp-sfpplus1 or lte1 must exist.");
                    :set res [$refreched];
                }
            }
        }
    }
    :set login ([$strcaseconv $login]->"lower");
  }
  :return $res;
}

# remove all scripts from the system related to ispapp agent
:global removeIspappScripts do={
    :local scriptList [/system script find where name~"ispapp.*"]
    if ([:len [/system script find where name~"ispapp.*"]] > 0) {
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

# remove all schedulers from the system related to ispapp agent
:global removeIspappSchedulers do={
    :local scriptList [/system scheduler find where name~"ispapp.*"]
    if ([:len [/system scheduler find where name~"ispapp.*"]] > 0) {
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

# ------------------- Load JSON from arg --------------------------------
:global JSONLoads
if (!any $JSONLoads) do={ :global JSONLoads do={
    :global JSONIn $1;
    :global fJParse;
    :local ret [$fJParse];
    :set JSONIn;
    :global Jpos;
    :global Jdebug; if (!$Jdebug) do={set Jdebug};
    :return $ret;
}}
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