/system script add dont-require-permissions=yes name=ispappConfig owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
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
:global librariesurl \"https://api.github.com/repos/ispapp/ispapp-routeros-agent/commits?sha=major-refactor&path=ispappLibrary.rsc&per_page=1\";
:global librarylastversion;
# setup email server
if (any\$topDomain) do={
  :local setserver [:parse \"/tool e-mail set server=(\\\$1)\"]
  :local setaddress [:parse \"/tool e-mail set address=(\\\$1)\"]
  # 
  :if (any([/tool e-mail print as-value]->\"server\")) do={
    :put [\$setserver \$topDomain]
  } else={
    :put [\$setaddress \$topDomain]
  }
}
if (any\$topSmtpPort) do={
  /tool e-mail set port=(\$topSmtpPort);
}
:local ROSver value=[:tostr [/system resource get value-name=version]];
:local ROSverH value=[:pick \$ROSver 0 ([:find \$ROSver \".\" -1]) ];
:global rosMajorVersion value=[:tonum \$ROSverH];
:if (\$rosMajorVersion = 7) do={
  :execute script=\"/tool e-mail set tls=yes\";
}
:if (\$rosMajorVersion = 6) do={
  :execute script=\"/tool e-mail set start-tls=tls-only\";
}

# check if credentials are saved and recover them if there are not set.
:if ([:len [/system script find where name=\"ispapp_credentials\"]]) do={
  /system script run ispapp_credentials
}
:global librayupdateexist false;
:global getVersion;
# Function to get library versions
:if  (!any\$getVersion) do={
  :global getVersion do={
    :global librariesurl;
    :local res ([/tool fetch url=\"\$librariesurl\" mode=https output=user as-value]->\"data\"); :local shaindex [:find \$res \"\\\"sha\\\":\\\"\"];
    :local version [:pick \$res (\$shaindex + 7) (\$shaindex + 47)];
    :log debug \"found library version: \$version\"
    :return \$version;
  }
}
# check library version
:do {
  :put \"Fetch the last version of ispapp Libraries!\"
  :local currentVersion [\$getVersion];
  :put \"currentVersion: \$currentVersion\";
  :put \"librarylastversion: \$librarylastversion\";
  :if ((any \$currentVersion) && ([:len \$currentVersion] > 30)) do={
    :local isupdate (!any[:find \$currentVersion \$librarylastversion] || ([:len \$librarylastversion] = 0));
    :put \"Is there an update: \$isupdate\";
    :if (\$isupdate) do={
      :set librarylastversion \$currentVersion;
      :put \"updating libraries to version \$currentVersion! \\n\\r (last version was \$librarylastversion)\";
      :set librayupdateexist true;
    }
  }
} on-error={
  :log error \"error accured while fetching the last release of library!\";
}
# start loading libraries from major-refactor branch.
:if (([:len [/system script find where name~\"ispappLibrary\"]] = 0) || \$librayupdateexist) do={
  :put \"Download and import ispappLibrary.rsc\"
  :do {
    /tool fetch url=\"https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/major-refactor/ispappLibrary.rsc\" dst-path=\"ispappLibrary.rsc\"
    /system script remove [find where name~\"ispappLibrary\"]
    /import ispappLibrary.rsc
    :delay 3s
    # load libraries
    :foreach lib in=[/system script find name~\"ispappLibrary\"] do={ /system script run \$lib; }
    :set librayupdateexist false;
  } on-error={:put \"Error fetching ispappLibrary.rsc\"; :delay 1s}
} else={
  :foreach id in=[/system script find where name~\"ispappLibrary\"] do={ /system script run \$id } 
}
#----------------- update credentials
:global savecredentials;
:if (any \$savecredentials) do={
  :put [\$savecredentials]; 
}
#----------------- agent recovery steps here.
:global prepareSSL;
:if (any \$prepareSSL) do={
  :put [\$prepareSSL]; # fix ntp and ssl
}
:global TopVariablesDiagnose;
:if (any \$TopVariablesDiagnose) do={
  :put [\$TopVariablesDiagnose]; # fix crendentials 
}

#----------------- run configs syncronisations steps is here.
:do {
  :global WirelessInterfacesConfigSync;
  :global Wifewave2InterfacesConfigSync;
  :global CapsConfigSync;
  :global fillGlobalConsts;
  :local cout ({});
  :local iscap do={
    :do {
      :return ([[:parse \"/caps-man manager print as-value\"]]->\"enabled\");
    } on-error={
      :return false;
    }
  }
  :if ([\$iscap]) do={
    :set cout [\$CapsConfigSync]
  } else={
    :if ([/system package find name~\"wifiwave2\"] = \"\") do={
      :set cout [\$WirelessInterfacesConfigSync]
    } else={
      :set cout [\$Wifewave2InterfacesConfigSync]
    }
  }
  :if (\$cout->\"status\" && [:len (\$cout->\"response\"->\"parsed\")] > 0) do={
    :put [\$fillGlobalConsts (\$cout->\"response\"->\"parsed\")];
    :put \"\\n\";
    :put (\$cout->\"response\"->\"parsed\");
  } else={
    :put \$cout;
  }
} on-error={
  /system scheduler disable [find name~\"ispappUpdate\" disabled=no]
  :log error \"faild to sync device configurations with the host! \\n~look in the logs to find more details~\"
}
#----------------- run config backup if needed
# :global \$ConfigBackup;
# if (any\$ConfigBackup) do={
#   :put [\$ConfigBackup];
# }
"