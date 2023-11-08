# Router Setup Config
# - sending device details to host (interfaces, branding, versions ..)
# - apply any configurations received from the host as setup stage
:global startEncode 1;
:global isSend 1;
:global topKey;
:global topDomain;
:global topClientInfo;
:global topListenerPort;
:global topServerPort;
:global topSmtpPort;
:global WirelessInterfacesConfigSync;
:global TopVariablesDiagnose;
:global prepareSSL;
:global login;

# setup email server
/tool e-mail set address=($topDomain);
/tool e-mail set port=($topSmtpPort);
:local ROSver value=[:tostr [/system resource get value-name=version]];
:local ROSverH value=[:pick $ROSver 0 ([:find $ROSver "." -1]) ];
:global rosMajorVersion value=[:tonum $ROSverH];
:if ($rosMajorVersion = 7) do={
  :execute script="/tool e-mail set tls=yes";
}
:if ($rosMajorVersion = 6) do={
  :execute script="/tool e-mail set start-tls=tls-only";
}
:global currentUrlVal;

# Get login from MAC address of an interface
:local l "";
:do {
  :set l ([/interface get [find default-name=wlan1] mac-address]);
} on-error={
  :do {
    :set l ([/interface get [find default-name=ether1] mac-address]);
  } on-error={
    :do {
      :set l ([/interface get [find default-name=sfp-sfpplus1] mac-address]);
    } on-error={
      :do {
        :set l ([/interface get [find default-name=lte1] mac-address]);
      } on-error={
        :log info ("No Interface MAC Address found to use as ISPApp login, default-name=wlan1, ether1, sfp-sfpplus1 or lte1 must exist.");
      }
    }
  }
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

# save important variables to be used after for recovery in case it's overrided of lost.
:do {
  :if ([:len [/file find name=ispapp_cridentials]] > 0) do={
    /file remove [/file find name=ispapp_cridentials]
  }
  :local cridentials "\r\
    \n:global topKey $topKey;\r\
    \n:global topDomain $topDomain;\r\
    \n:global topClientInfo $topClientInfo;\r\
    \n:global topListenerPort $topListenerPort;\r\
    \n:global topServerPort $topServerPort;\r\
    \n:global topSmtpPort $topSmtpPort;\r\
    \n:global ipbandswtestserver $ipbandswtestserver;\r\
    \n:global btuser $btuser;\r\
    \n:global btpwd $btpwd;";
  /file add name=ispapp_cridentials contents=$cridentials
} on-error={
  :log error "faild to save cridentials!";
}

:global login "00:00:00:00:00:00";
:if ([:len $l] > 0) do={
:set login ([$strcaseconv $l]->"lower");
}

:local sameScriptRunningCount [:len [/system script job find script=ispappConfig]];
if ($sameScriptRunningCount > 1) do={
  :error ("ispappConfig script already running " . $sameScriptRunningCount . " times");
}
:if ([:len [/system/script/find where name~"ispappLibrary"]] = 0) do={
  :put "Download and import ispappLibrary.rsc"
  :do {
    /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/karim/ispappLibrary.rsc" dst-path="ispappLibrary.rsc"
    /import ispappLibrary.rsc
    :delay 3s
    /system/script/run ispappLibraryV1
    /system/script/run ispappLibraryV2
  } on-error={:put "Error fetching ispappLibrary.rsc"; :delay 1s}
} else={
  :foreach id in=[/system/script/find where name~"ispappLibrary"] do={ /system/script/run $id } 
}
:if (any $login) do={
  :put [$prepareSSL];
  :put [$TopVariablesDiagnose];
}
# run configs syncronisations.
:if (any $WirelessInterfacesConfigSync) do={
  :put [$WirelessInterfacesConfigSync];
}
