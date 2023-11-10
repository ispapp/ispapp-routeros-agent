:global topKey "#####HOST_KEY#####";
:global topDomain "#####DOMAIN#####";
:global topClientInfo "RouterOS-v3.14.1";
:global topListenerPort "8550";
:global topServerPort "443";
:global topSmtpPort "8465";
:global txAvg 0;
:global rxAvg 0;
:global ipbandswtestserver "#####bandswtest#####";
:global btuser "#####btest#####";
:global btpwd "#####btp#####";

# cleanup old setup if exist (scripts, files, schedulers)
/system/script/remove [/system/script/find where name~"ispapp"]
/file/remove [/file/find where name~"ispapp"]
/system/scheduler/remove [/system/scheduler/find where name~"ispapp"]
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
# Get login from MAC address of an interface
:global login "00:00:00:00:00:00";
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
};
:if ([:len $l] > 0) do={
  :set login ([$strcaseconv $l]->"lower");
}
# look at LibV2 for more infos
:global savecredentials do={
  :global topKey;
  :global topDomain;
  :global topClientInfo;
  :global topListenerPort;
  :global topServerPort;
  :global topSmtpPort;
  :global txAvg;
  :global rxAvg;
  :global ipbandswtestserver;
  :global btuser;
  :global btpwd;
  :global login;
  :global librarylastversion;
  /system/script/remove ispapp_credentials
  :local cridentials "\n:global topKey $topKey;\r\
    \n:global topDomain $topDomain;\r\
    \n:global topClientInfo $topClientInfo;\r\
    \n:global topListenerPort $topListenerPort;\r\
    \n:global topServerPort $topServerPort;\r\
    \n:global topSmtpPort $topSmtpPort;\r\
    \n:global txAvg 0;\r\
    \n:global rxAvg 0;\r\
    \n:global ipbandswtestserver $ipbandswtestserver;\r\
    \n:global btuser $btuser;\r\
    \n:global login $login;\r\
    \n:global librarylastversion $librarylastversion;\r\
    \n:global btpwd $btpwd;"
  /system/script/add name=ispapp_credentials source=$cridentials
  :log info "ispapp_credentials updated!";
  :return "ispapp_credentials updated!";
}
:put [$savecredentials];
# start installing rsc files from repos.
:put "ispappConfig.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/karim/ispappConfig.rsc" dst-path="ispappConfig.rsc"
  /import ispappConfig.rsc
  :delay 3s
} on-error={:put "Error fetching ispappConfig.rsc"; :delay 1s}

:put "Download and import ispappDiagnoseConnection.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/karim/ispappDiagnoseConnection.rsc" dst-path="ispappDiagnoseConnection.rsc"
  /import ispappDiagnoseConnection.rsc
  :delay 3s
} on-error={:put "Error fetching ispappDiagnoseConnection.rsc"; :delay 1s}

:put "Download and import ispappInit.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/karim/ispappInit.rsc" dst-path="ispappInit.rsc"
  /import ispappInit.rsc
  :delay 3s
} on-error={:put "Error fetching ispappInit.rsc"; :delay 1s}

:put "Download and import ispappFunctions.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/karim/ispappFunctions.rsc" dst-path="ispappFunctions.rsc"
  /import ispappFunctions.rsc
  :delay 3s
} on-error={:put "Error fetching ispappFunctions.rsc"; :delay 1s}

:put "Download and import ispappPingCollector.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/karim/ispappPingCollector.rsc" dst-path="ispappPingCollector.rsc"
  /import ispappPingCollector.rsc
  :delay 3s
} on-error={:put "Error fetching ispappPingCollector.rsc"; :delay 1s}

:put "Download and import ispappLteCollector.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/karim/ispappLteCollector.rsc" dst-path="ispappLteCollector.rsc"
  /import ispappLteCollector.rsc
  :delay 3s
} on-error={:put "Error fetching ispappLteCollector.rsc"; :delay 1s}

:put "Download and import ispappCollectors.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/karim/ispappCollectors.rsc" dst-path="ispappCollectors.rsc"
  /import ispappCollectors.rsc
  :delay 3s
} on-error={:put "Error fetching ispappCollectors.rsc"; :delay 1s}

:put "ispappRemoveConfiguration.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/master/ispappRemoveConfiguration.rsc" dst-path="ispappRemoveConfiguration.rsc"
  /import ispappRemoveConfiguration.rsc
  :delay 3s
} on-error={:put "Error fetching ispappRemoveConfiguration.rsc"; :delay 1s}

:put "ispappUpdate.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/karim/ispappUpdate.rsc" dst-path="ispappUpdate.rsc"
  /import ispappUpdate.rsc
  :delay 3s
} on-error={:put "Error fetching ispappUpdate.rsc"; :delay 1s}

:put "ispappAvgCpuCollector.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/karim/ispappAvgCpuCollector.rsc" dst-path="ispappAvgCpuCollector.rsc"
  /import ispappAvgCpuCollector.rsc
  :delay 3s
} on-error={:put "Error fetching ispappAvgCpuCollector.rsc"; :delay 1s}

/system script add name=ispappLastConfigChangeTsMs;
/system script set "ispappLastConfigChangeTsMs" source=":global lastConfigChangeTsMs; :set lastConfigChangeTsMs $lcf;";

:log info ("Starting Mikrotik Script")

/system scheduler
add name=ispappInit on-event=ispappInit policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-time=startup
:log debug ("ispappInit scheduler added")

add interval=60s name=ispappPingCollector on-event=ispappPingCollector policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-time=startup
:log debug ("ispappPingCollector scheduler added")

add interval=60s name=ispappCollectors on-event=ispappCollectors policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-time=startup
:log debug ("ispappCollectors scheduler added")

add interval=15s name=ispappUpdate on-event=ispappUpdate policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-time=startup
:log debug ("ispappUpdate scheduler added")

add interval=300s name=ispappConfig on-event=ispappConfig policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-time=startup
:log debug ("ispappConfig scheduler added")

:log info ("Running ispappInit script")
/system script run ispappInit;

:log info ("Completed Mikrotik Script")
