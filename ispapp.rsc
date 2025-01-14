# clean old variables before setting new one's
:if ([:len [/system script environment find]] > 0) do={ 
  foreach envVarId in=[/system script environment find] do={
    /system script environment remove $envVarId;
  }
}
:global topKey "#####HOST_KEY#####";
:global topKey "#####HOST_KEY#####";
:global topClientInfo "RouterOS-v3.14.3";
:global topListenerPort "8550";
:global topServerPort "443";
:global topSmtpPort "8465";
:global txAvg 0;
:global rxAvg 0;
:global ipbandswtestserver "#####bandswtest#####";
:global btuser "#####btest#####";
:global btpwd "#####btp#####";
:global librarylastversion "";
:global login ;
# cleanup old setup if exist (scripts, files, schedulers)
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
    :return {"upper"=$outputupper; "lower"=$outputlower};
}
# Function to clean old agent setup will be used in ispapp only 
:global cleanupagent do={
  :do {
    # remove scripts
    /system script remove [find where name~"ispapp"]
    # remove files
    /file remove [find where name~"ispapp"]
    # remove schedulers
    /system scheduler remove [find where name~"ispapp"]
    # remove environment variables
    :log error "\E2\9D\8C old agent stup cleaned";
    :return "\E2\9D\8C old agent setup cleaned";
  } on-error={
      :return "\E2\9D\8C ispappLibrary not loaded try reset the agent";
      :log error "\E2\9D\8C ispappLibrary not loaded try reset the agent";
  }
}
  :set login [/system routerboard get serial-number]
  :set login ($login . "-" . [/system identity get name])
  :set login  ($login . "-" . [/system routerboard get model])

  :put $login
  

# check if credentials are saved and recover them if there are not set.
:if ([:len [/system script find where name="ispapp_credentials"]] > 0) do={
  /system script run ispapp_credentials
}

# setup steps 
:put [$cleanupagent];

# start installing rsc files from repos.
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/major-refactor/ispappConfig.rsc" dst-path="ispappConfig.rsc"
  /system script add name="ispappConfig" source=[/file get ispappConfig.rsc contents]
  :delay 3s
} on-error={:put "Error fetching ispappConfig.rsc"; :delay 1s}
:put "ispappConfig.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/major-refactor/raw/ispappInit.rsc" dst-path="ispappInit.rsc"
  :delay 3s
  /system script add name="ispappInit" source=[/file get ispappInit.rsc contents]
} on-error={:put "Error fetching ispappInit.rsc"; :delay 1s}
:put "ispappInit.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/major-refactor/raw/ispappUpdate.rsc" dst-path="ispappUpdate.rsc"
  :delay 3s
  /system script add name="ispappUpdate" source=[/file get ispappUpdate.rsc contents]
} on-error={:put "Error fetching ispappUpdate.rsc"; :delay 1s}
:put "ispappUpdate.rsc"
:do {
    /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/major-refactor/ispappLibrary.rsc" dst-path="ispappLibrary.rsc"
    /import ispappLibrary.rsc
    :delay 3s
    # load libraries
} on-error={:put "Error fetching ispappUpdate.rsc"; :delay 1s}
:foreach lib in=[/system script find name~"ispappLibrary"] do={ /system script run $lib; }
:global libLoaded true;
:put "loading all scripts "
:put [$savecredentials];
:put ($refreshToken)
/system script add name=ispappLastConfigChangeTsMs source=":global lastConfigChangeTsMs; :set lastConfigChangeTsMs $lcf;";

:log info ("Starting Mikrotik Script")
/system scheduler add interval=1m name=ispappInit on-event=ispappInit policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-time=startup disabled=no
:log debug ("ispappInit scheduler added")
/system scheduler add interval=10s name=ispappUpdate on-event=ispappUpdate policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-time=startup disabled=yes
:log debug ("ispappUpdate scheduler added")
 /system scheduler add interval=5m name=ispappConfig on-event=ispappConfig policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-time=startup disabled=yes
:log debug ("ispappConfig scheduler added")
/system scheduler add interval=12h name=ispappBackup on-event=":global ConfigBackup; if (any \$ConfigBackup) do={:put [\$ConfigBackup];}" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-time=startup disabled=no
:log debug ("ispappBackup scheduler added")
:log info ("Running ispappInit script")
/system script run ispappInit;
:log info ("Completed Mikrotik Script")