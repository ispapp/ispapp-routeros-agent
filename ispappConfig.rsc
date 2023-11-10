# 2023-11-10 18:14:51
/system script
add dont-require-permissions=no name=ispappConfig owner=admin policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="#\
    \_Router Setup Config\r\
    \n# - sending device details to host (interfaces, branding, versions ..)\r\
    \n# - apply any configurations received from the host as setup stage\r\
    \n:global startEncode 1;\r\
    \n:global isSend 1;\r\
    \n:global topKey;\r\
    \n:global topDomain;\r\
    \n:global topClientInfo;\r\
    \n:global topListenerPort;\r\
    \n:global topServerPort;\r\
    \n:global topSmtpPort;\r\
    \n:global WirelessInterfacesConfigSync;\r\
    \n:global TopVariablesDiagnose;\r\
    \n:global prepareSSL;\r\
    \n:global login;\r\
    \n:global librariesurl \"https://api.github.com/repos/ispapp/ispapp-router\
    os-agent/commits\?sha=karim&path=ispappLibrary.rsc&per_page=1\";\r\
    \n:global librarylastversion 0;\r\
    \n# setup email server\r\
    \n/tool e-mail set address=(\$topDomain);\r\
    \n/tool e-mail set port=(\$topSmtpPort);\r\
    \n:local ROSver value=[:tostr [/system resource get value-name=version]];\
    \r\
    \n:local ROSverH value=[:pick \$ROSver 0 ([:find \$ROSver \".\" -1]) ];\r\
    \n:global rosMajorVersion value=[:tonum \$ROSverH];\r\
    \n:if (\$rosMajorVersion = 7) do={\r\
    \n  :execute script=\"/tool e-mail set tls=yes\";\r\
    \n}\r\
    \n:if (\$rosMajorVersion = 6) do={\r\
    \n  :execute script=\"/tool e-mail set start-tls=tls-only\";\r\
    \n}\r\
    \n\r\
    \n# check if credentials are saved and recover them if there are not set.\
    \r\
    \n:if ([:len [/system script find where name~\"ispapp_cred\"]]) do={\r\
    \n  :if ((!any \$login) ||  (!any \$topKey)) do={\r\
    \n    /system script run ispapp_credentials\r\
    \n  }\r\
    \n}\r\
    \n:global librayupdateexist false;\r\
    \n:do {\r\
    \n  :put \"Fetch the last version of ispapp Libraries!\"\r\
    \n  :global librarylastversion;\r\
    \n  :local currentVersion [\$getVersion];\r\
    \n  :if ((any \$currentVersion) && ([:len \$currentVersion] > 30)) do={\r\
    \n    :if (\$currentVersion != \$librarylastversion) do={\r\
    \n      :set librarylastversion \$currentVersion;\r\
    \n      :put \"updating libraries to version \$currentVersion!\";\r\
    \n      :set librayupdateexist true;\r\
    \n      :put [\$savecredentials];\r\
    \n    }\r\
    \n  }\r\
    \n} on-error={\r\
    \n  :log error \"error accured while fetching the last release of library!\
    \";\r\
    \n}\r\
    \n# start loading libraries from karim branch.\r\
    \n:if (([:len [/system/script/find where name~\"ispappLibrary\"]] = 0) || \
    \$librayupdateexist) do={\r\
    \n  :put \"Download and import ispappLibrary.rsc\"\r\
    \n  :local getVersion do={\r\
    \n    :global librariesurl;\r\
    \n    :local res ([/tool fetch url=\"\$librariesurl\" mode=https output=us\
    er as-value]->\"data\"); :local shaindex [:find \$res \"\\\"sha\\\":\\\"\"\
    ]; :local version [:pick \$res (\$shaindex + 7) (\$shaindex + 47)];\r\
    \n    :return \$version;\r\
    \n  }\r\
    \n  :do {\r\
    \n    /tool fetch url=\"https://raw.githubusercontent.com/ispapp/ispapp-ro\
    uteros-agent/karim/ispappLibrary.rsc\" dst-path=\"ispappLibrary.rsc\"\r\
    \n    /import ispappLibrary.rsc\r\
    \n    :delay 3s\r\
    \n    /system/script/run ispappLibraryV1\r\
    \n    /system/script/run ispappLibraryV2\r\
    \n  } on-error={:put \"Error fetching ispappLibrary.rsc\"; :delay 1s}\r\
    \n} else={\r\
    \n  :foreach id in=[/system/script/find where name~\"ispappLibrary\"] do={\
    \_/system/script/run \$id } \r\
    \n}\r\
    \n\r\
    \n#----------------- agent recovery steps here.\r\
    \n:if (any \$prepareSSL) do={\r\
    \n  :global prepareSSL;\r\
    \n  :put [\$prepareSSL]; # fix ntp and ssl\r\
    \n}\r\
    \n:if (any \$TopVariablesDiagnose) do={\r\
    \n  :global TopVariablesDiagnose;\r\
    \n  :put [\$TopVariablesDiagnose]; # fix crendentials \r\
    \n}\r\
    \n\r\
    \n#----------------- run configs syncronisations steps is here.\r\
    \n:if (any \$WirelessInterfacesConfigSync) do={\r\
    \n  :global WirelessInterfacesConfigSync;\r\
    \n  :put [\$WirelessInterfacesConfigSync];\r\
    \n}\r\
    \n"