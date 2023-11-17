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
:global librariesurl "https://api.github.com/repos/ispapp/ispapp-routeros-agent/commits?sha=karim&path=ispappLibrary.rsc&per_page=1";
:global librarylastversion 0;
# setup email server
if (any$topDomain) do={
  /tool e-mail set server=($topDomain);
}
if (any$topSmtpPort) do={
  /tool e-mail set port=($topSmtpPort);
}
:local ROSver value=[:tostr [/system resource get value-name=version]];
:local ROSverH value=[:pick $ROSver 0 ([:find $ROSver "." -1]) ];
:global rosMajorVersion value=[:tonum $ROSverH];
:if ($rosMajorVersion = 7) do={
  :execute script="/tool e-mail set tls=yes";
}
:if ($rosMajorVersion = 6) do={
  :execute script="/tool e-mail set start-tls=tls-only";
}

# check if credentials are saved and recover them if there are not set.
:if ([:len [/system script find where name~"ispapp_cred"]]) do={
  :if (!any$login ||  !any$topKey) do={
    /system script run ispapp_credentials
  }
}
:if ([:len [/system script find where name~"ispappFunction"]]) do={
  :if (!any$fJParse) do={
    /system script run ispappFunctions
  }
}
:global librayupdateexist false;
:do {
  :put "Fetch the last version of ispapp Libraries!"
  :global librarylastversion;
  :local currentVersion [$getVersion];
  :if ((any $currentVersion) && ([:len $currentVersion] > 30)) do={
    :if ($currentVersion != $librarylastversion) do={
      :set librarylastversion $currentVersion;
      :put "updating libraries to version $currentVersion!";
      :set librayupdateexist true;
      :put [$savecredentials];
    }
  }
} on-error={
  :log error "error accured while fetching the last release of library!";
}
# start loading libraries from karim branch.
:if (([:len [/system/script/find where name~"ispappLibrary"]] = 0) || $librayupdateexist) do={
  :put "Download and import ispappLibrary.rsc"
  :local getVersion do={
    :global librariesurl;
    :local res ([/tool fetch url="$librariesurl" mode=https output=user as-value]->"data"); :local shaindex [:find $res "\"sha\":\""];
    :local version [:pick $res ($shaindex + 7) ($shaindex + 47)];
    :log debug "found library version: $version"
    :return $version;
  }
  :do {
    /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/karim/ispappLibrary.rsc" dst-path="ispappLibrary.rsc"
    /import ispappLibrary.rsc
    :delay 3s
    # load libraries
    :foreach lib in=[/system/script/find name~"ispappLibrary"] do={ /system/script/run $lib; }
  } on-error={:put "Error fetching ispappLibrary.rsc"; :delay 1s}
} else={
  :foreach id in=[/system/script/find where name~"ispappLibrary"] do={ /system/script/run $id } 
}

#----------------- agent recovery steps here.
:if (any $prepareSSL) do={
  :global prepareSSL;
  :put [$prepareSSL]; # fix ntp and ssl
}
:if (any $TopVariablesDiagnose) do={
  :global TopVariablesDiagnose;
  :put [$TopVariablesDiagnose]; # fix crendentials 
}

#----------------- run configs syncronisations steps is here.
:do {
  :global WirelessInterfacesConfigSync;
  :global Wifewave2InterfacesConfigSync;
  :global CapsConfigSync;
  :if (([/caps-man manager print as-value]->"enabled")) do={
    :put [$CapsConfigSync]
  } else={
    :if ([/interface/wireless/find] > 0) do={
      :put [$WirelessInterfacesConfigSync]
    } else={
      :put [$Wifewave2InterfacesConfigSync]
    }
  }
} on-error={
  :log error "faild to sync device configurations with the host! \n~look in the logs to find more details~"
}
