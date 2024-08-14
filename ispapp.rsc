# clean old variables before setting new one's
:if ([:len [/system script environment find]] > 0) do={ 
  foreach envVarId in=[/system script environment find] do={
    /system script environment remove $envVarId;
  }
}
:global topKey "#####HOST_KEY#####";
:global topDomain "#####DOMAIN#####";
:global topClientInfo "RouterOS-v3.14.2";
:global topListenerPort "8550";
:global topServerPort "443";
:global topSmtpPort "8465";
:global txAvg 0;
:global rxAvg 0;
:global ipbandswtestserver "#####bandswtest#####";
:global btuser "#####btest#####";
:global btpwd "#####btp#####";
:global librarylastversion "";
:global login "";
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
:local generateUniqueId do={
  :global topDomain;
  :global login;
  :local result [/tool fetch url="https://$topDomain:$topListenerPort/auth/uuid" check-certificate=no as-value output=user];
  :put $result
  :if ($result->"status" = "finished") do={
    :set login ($result->"data");
  } else={
      :log error "Failed to fetch UUID from the specified URL";
      :local time [:pick [/system clock get time] 0 2];
          :local min [:pick [/system clock get time] 3 5];
          :local sec [:pick [/system clock get time] 6 8];
          :local char;
          :set char ( $char . [ :pick $time 1 ] . [ :pick $time 0 ]);
          :local char1;
          :set char1 ( $char1 . [ :pick $min 1 ] . [ :pick $min 0 ]);
          :local char2;
          :set char2 ( $char2 . [ :pick $sec 1 ] . [ :pick $sec 0 ]);
          :local arrayalpha ("2","C","h","Y","f","j","c","q","k","3","Y","T","C","v","n","8","I","r","4","p","V","6","S","V","p","Z","T","6","l","K","b","Y","7","X","c","P","g","m","U","T","g","v","N","j","E","g","f","D","h","W","p","U","z","T","S","h","M","Y","i","E","c","4","Q","Y","h","e","q","7","l","R","h","S","w","r","I","5","h","p","l","1","Y","U","2","J","R","T","Y","b","c","9","d","e","S","6","W","B","Q","S","b","p","3","m","X","g","8","y","j","h","S","Z","F","t","U","j","W","5","a","g","S","S","T","7","f","G","W","T","k","3","T","X","p","m","e","i","L","3","d","G","T","H","Q","k","X","P","Q","k","f","K","T","S","Q","W","S","S","z","z","k","V","X","4","g","t","X","1","h","5","k","T","f","i","Y","1","j","h","l","S","3","b","Y","i","T","j","h","T","7","w","g","D","X","g","T","T","i","S","R","D","d","c","h","d","T","l","N","V","u","Z","T","S","m","Z","d","Z","Z","S","Y","d","k","v","h","7");
          :local new;
          :set new ( $new . [ :pick $arrayalpha ($time+$min+$sec) ] . [ :pick $arrayalpha ($time+$sec) ] . [ :pick $arrayalpha ($min+$sec) ] . [ :pick $arrayalpha $sec ] . [ :pick $arrayalpha $char ] . [ :pick $arrayalpha $char1 ] . [ :pick $arrayalpha $char2 ] . [ :pick $arrayalpha ($char+$char1+$char2) ]);
          :set login $new;
  }
}; :put [$generateUniqueId]
# check if credentials are saved and recover them if there are not set.
:if ([:len [/system script find where name="ispapp_credentials"]] > 0) do={
  /system script run ispapp_credentials
}
:if  (([ :typeof $login ] = "nothing") || ($login = "")) do={
  :do {
    :log info "login: $login";
    [$generateUniqueId]
  } on-error={
    :log error "generateUniqueId faild!";
  }
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
:log info ("Running ispappInit script")
/system script run ispappInit;
:log info ("Completed Mikrotik Script")