# 2023-11-07 16:10:26
/system script
add dont-require-permissions=no name=ispappConfig owner=admin policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="#\
    \_Router Setup Config\r\
    \n# - sending device details to host (interfaces, branding, versions ..)\r\
    \n# - apply any configurations received from the host as setup stage\r\
    \n:global startEncode 1;\r\
    \n:global isSend 1;\r\
    \n:global topKey \$topKey;\r\
    \n:global topDomain \$topDomain;\r\
    \n:global topClientInfo \$topClientInfo;\r\
    \n:global topListenerPort \$topListenerPort;\r\
    \n:global topServerPort \$topServerPort;\r\
    \n:global topSmtpPort \$topSmtpPort;\r\
    \n\r\
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
    \n:global currentUrlVal;\r\
    \n\r\
    \n# Get login from MAC address of an interface\r\
    \n:local l \"\";\r\
    \n:do {\r\
    \n  :set l ([/interface get [find default-name=wlan1] mac-address]);\r\
    \n} on-error={\r\
    \n  :do {\r\
    \n    :set l ([/interface get [find default-name=ether1] mac-address]);\r\
    \n  } on-error={\r\
    \n    :do {\r\
    \n      :set l ([/interface get [find default-name=sfp-sfpplus1] mac-addre\
    ss]);\r\
    \n    } on-error={\r\
    \n      :do {\r\
    \n        :set l ([/interface get [find default-name=lte1] mac-address]);\
    \r\
    \n      } on-error={\r\
    \n        :log info (\"No Interface MAC Address found to use as ISPApp log\
    in, default-name=wlan1, ether1, sfp-sfpplus1 or lte1 must exist.\");\r\
    \n      }\r\
    \n    }\r\
    \n  }\r\
    \n}\r\
    \n# @Details: Function to convert to lowercase or uppercase \r\
    \n# @Syntax: \$strcaseconv <input string>\r\
    \n# @Example: :put ([\$strcaseconv sdsdFS2k-122nicepp#]->\"upper\") --> re\
    sult: SDSDFS2K-122NICEPP#\r\
    \n# @Example: :put ([\$strcaseconv sdsdFS2k-122nicepp#]->\"lower\") --> re\
    sult: sdsdfs2k-122nicepp#\r\
    \n:global strcaseconv do={\r\
    \n    :local outputupper;\r\
    \n    :local outputlower;\r\
    \n    :local lower (\"a\",\"b\",\"c\",\"d\",\"e\",\"f\",\"g\",\"h\",\"i\",\
    \"j\",\"k\",\"l\",\"m\",\"n\",\"o\",\"p\",\"q\",\"r\",\"s\",\"t\",\"u\",\"\
    v\",\"w\",\"x\",\"y\",\"z\")\r\
    \n    :local upper (\"A\",\"B\",\"C\",\"D\",\"E\",\"F\",\"G\",\"H\",\"I\",\
    \"J\",\"K\",\"L\",\"M\",\"N\",\"O\",\"P\",\"Q\",\"R\",\"S\",\"T\",\"U\",\"\
    V\",\"W\",\"X\",\"Y\",\"Z\")\r\
    \n    :local lent [:len \$1];\r\
    \n    :for i from=0 to=(\$lent - 1) do={ \r\
    \n        if (any [:find \$lower [:pick \$1 \$i]]) do={\r\
    \n            :set outputupper (\$outputupper . [:pick \$upper [:find \$lo\
    wer [:pick \$1 \$i]]]);\r\
    \n        } else={\r\
    \n            :set outputupper (\$outputupper . [:pick \$1 \$i])\r\
    \n        }\r\
    \n        if (any [:find \$upper [:pick \$1 \$i]]) do={\r\
    \n            :set outputlower (\$outputlower . [:pick \$lower [:find \$up\
    per [:pick \$1 \$i]]]);\r\
    \n        } else={\r\
    \n            :set outputlower (\$outputlower . [:pick \$1 \$i])\r\
    \n        }\r\
    \n    }\r\
    \n    :return {upper=\$outputupper; lower=\$outputlower};\r\
    \n}\r\
    \n:global login \"00:00:00:00:00:00\";\r\
    \n:if ([:len \$l] > 0) do={\r\
    \n:set login ([\$strcaseconv \$l]->\"lower\");\r\
    \n}\r\
    \n\r\
    \n:local sameScriptRunningCount [:len [/system script job find script=ispa\
    ppConfig]];\r\
    \nif (\$sameScriptRunningCount > 1) do={\r\
    \n  :error (\"ispappConfig script already running \" . \$sameScriptRunning\
    Count . \" times\");\r\
    \n}\r\
    \n:if ([:len [/system/script/find where name~\"ispappLibrary\"]] = 0) do={\
    \r\
    \n  :put \"Download and import ispappLibrary.rsc\"\r\
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
    \n:if (any \$login) do={\r\
    \n  :put [\$prepareSSL];\r\
    \n  :put [\$TopVariablesDiagnose];\r\
    \n}\r\
    \n# run configs syncronisations.\r\
    \n:if (any \$WirelessInterfacesConfigSync) do={\r\
    \n  :put [\$WirelessInterfacesConfigSync];\r\
    \n}\r\
    \n"