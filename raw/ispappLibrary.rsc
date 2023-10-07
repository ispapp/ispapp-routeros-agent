############################### this file contain predefined functions to be used across the agent script ####################################

# Function to prepare ssl connection to ispappHTTPClient
# 1- check ntp client status if synced with google/apple ntp servers.
#   10- setup ntp client if not synced and keep refreching 3 times max until it's working
#   11- if ntp client is not working, then exit the function with false in ntpStatus key value.
# 2- check if "Sectigo RSA DV CA" and "USERTrust RSA CA" exist and trusted.
#   20- download and install the latest bundle if not exists.
#   21- install the latest bundle if not valid.
#   23- if bundle is not installed, then exit the function with false in caStatus key value.

:global prepareSSL do={
    :local ntpStatus false;
    :local caStatus false;
    # refrechable ssl state (each time u call [$sslIsOk] a new value will be returned)
    :local sslIsOk do={
        :do {
            :return ([/tool fetch url="https://$topDomain:$topListenerPort" mode=https check-certificate=yes output=user as-value]->"status" = "finished");
        } on-error={
            :return false;
        }
    };
    if ([$sslIsOk]) {
        return {
            ntpStatus=true;
            caStatus=true
        };
    } else={
        # Check NTP Client Status
        if ([/system ntp client get enabled]) do={
            if ([/system ntp client get status] = "synchronized") do={
                :set ntpStatus true;
            } else={
                # Configure a new NTP client
                /system ntp client set enabled=yes mode=unicast servers=time.google.com,time.cloudflare.com,time.windows.com,time.nist.gov
                /system ntp server set enabled=yes
                :local retry 0;
                while ([/system ntp client get status] = "waiting" && $retry <= 5) do={
                    :delay 500ms;
                    :set retry ($retry + 1);
                }
                if ([/system ntp client get status] = "synchronized") do={
                    :set ntpStatus true;
                }
            }
        }
    }
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
