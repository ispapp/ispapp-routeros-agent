/system script add dont-require-permissions=yes name=ispappConfig owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
# Router Setup Config
# - sending device details to host (interfaces, branding, versions ..)
# - apply any configurations received from the host as setup stage
:global startEncode 1;
:global isSend 1;
:global topKey;
:global topDomain;
:global topSmtpPort;
:global WirelessInterfacesConfigSync;
:global TopVariablesDiagnose;
:global prepareSSL;
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
# }"