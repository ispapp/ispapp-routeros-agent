############################### this file contain predefined functions to be used across the agent script ####################################

# Converts a mixed array into a JSON string.
# 
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

# @Details: Function to convert to lowercase or uppercase 
# @Syntax: $TopVariablesDiagnose
# @Example: :put [$TopVariablesDiagnose] or just $TopVariablesDiagnose
:global TopVariablesDiagnose do={
  :local refreched do={:return {"topListenerPort"=$topListenerPort; "topDomain"=$topDomain; "login"=$login}};
  :local res {"topListenerPort"=$topListenerPort; "topDomain"=$topDomain; "login"=$login};
  # Check if topListenerPort is not set and assign a default value if not set
  :if (!any $topListenerPort) do={
    :set topListenerPort 8550;
    :set res [$refreched];
  }
  # Check if topDomain is not set and assign a default value if not set
  :if (!any $topDomain) do={
    :set topDomain "qwer.ispapp.co"
    :set res [$refreched];
  }
  # Check if login is not set and assign a default value as the MikroTik MAC address
  :if (!any $login) do={
    :do {
      :set login ([/interface get [find default-name=wlan1] mac-address]);
      :set res [$refreched];
    } on-error={
      :do {
        :set login ([/interface get [find default-name=ether1] mac-address]);
        :set res [$refreched];
      } on-error={
        :do {
          :set login ([/interface get [find default-name=sfp-sfpplus1] mac-address]);
          :set res [$refreched];
        } on-error={
          :do {
            :set login ([/interface get [find default-name=lte1] mac-address]);
            :set res [$refreched];
          } on-error={
            :log info ("No Interface MAC Address found to use as ISPApp login, default-name=wlan1, ether1, sfp-sfpplus1 or lte1 must exist.");
            :set res [$refreched];
          }
        }
      }
    }
  }
  :return $res;
}
