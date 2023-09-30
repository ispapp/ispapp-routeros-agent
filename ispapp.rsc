:put "Download and import clean.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/master/ispappClean.rsc" dst-path="ispappClean.rsc"
  /import ispappClean.rsc
  :delay 3s
} on-error={:put "Error fetching ispappClean.rsc"; :delay 1s}


:global topKey "#####HOST_KEY#####";
:global topDomain "#####DOMAIN#####";
:global topClientInfo "RouterOS-v3.14.1";
:global topListenerPort "8550";
:global topServerPort "443";
:global topSmtpPort "8465";
:global txAvg 0 ;
:global rxAvg 0 ;
:global ipbandswtestserver "#####bandswtest#####";
:global btuser "#####btest#####";
:global btpwd "#####btp#####";


:put "Download and import ispappDiagnoseConnection.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/master/ispappDiagnoseConnection.rsc" dst-path="ispappDiagnoseConnection.rsc"
  /import ispappDiagnoseConnection.rsc
  :delay 3s
} on-error={:put "Error fetching ispappDiagnoseConnection.rsc"; :delay 1s}

/system script add dont-require-permissions=no name=ispappSetGlobalEnv owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source=":global startEncode 1;\r\
    \n:global isSend 1;\r\
    \n\r\
    \n:global topKey (\"$topKey\");\r\
    \n:global topDomain (\"$topDomain\");\r\
    \n:global topClientInfo (\"$topClientInfo\");\r\
    \n:global topListenerPort (\"$topListenerPort\");\r\
    \n:global topServerPort (\"$topServerPort\");\r\
    \n:global topSmtpPort (\"$topSmtpPort\");\r\
    \n\r\
    \n# setup email server\r\
    \n/tool e-mail set address=(\$topDomain);\r\
    \n/tool e-mail set port=(\$topSmtpPort);\r\
    \n\r\
    \n:local ROSver value=[:tostr [/system resource get value-name=version]];\r\
    \n:local ROSverH value=[:pick \$ROSver 0 ([:find \$ROSver \".\" -1]) ];\r\
    \n:global rosMajorVersion value=[:tonum \$ROSverH];\r\
    \n\r\
    \n:if (\$rosMajorVersion = 7) do={\r\
    \n  #:put \">= 7\";\r\
    \n  :execute script=\"/tool e-mail set tls=yes\";\r\
    \n}\r\
    \n\r\
    \n:if (\$rosMajorVersion = 6) do={\r\
    \n  #:put \"not >= 7\";\r\
    \n  :execute script=\"/tool e-mail set start-tls=tls-only\";\r\
    \n}\r\
    \n\r\
    \n:global currentUrlVal;\r\
    \n\r\
    \n# Get login from MAC address of an interface\r\
    \n:local l \"\";\r\
    \n\r\
    \n:do {\r\
    \n  :set l ([/interface get [find default-name=wlan1] mac-address]);\r\
    \n} on-error={\r\
    \n  :do {\r\
    \n    :set l ([/interface get [find default-name=ether1] mac-address]);\r\
    \n  } on-error={\r\
    \n    :do {\r\
    \n      :set l ([/interface get [find default-name=sfp-sfpplus1] mac-address]);\r\
    \n    } on-error={\r\
    \n      :do {\r\
    \n        :set l ([/interface get [find default-name=lte1] mac-address]);\r\
    \n      } on-error={\r\
    \n        :log info (\"No Interface MAC Address found to use as ISPApp login, default-name=wlan1, ether1, sfp-sfpplus1 or lte1 must exist.\");\r\
    \n      }\r\
    \n    }\r\
    \n  }\r\
    \n}\r\
    \n\r\
    \n:local new \"\";\r\
    \n# Convert to lowercase\r\
    \n:local low (\"a\",\"b\",\"c\",\"d\",\"e\",\"f\",\"g\",\"h\",\"i\",\"j\",\"k\",\"l\",\"m\",\"n\",\"o\",\"p\",\"q\",\"r\",\"s\",\"t\",\"u\",\"v\",\"w\",\"x\",\"y\",\"z\");\r\
    \n:local upp (\"A\",\"B\",\"C\",\"D\",\"E\",\"F\",\"G\",\"H\",\"I\",\"J\",\"K\",\"L\",\"M\",\"N\",\"O\",\"P\",\"Q\",\"R\",\"S\",\"T\",\"U\",\"V\",\"W\",\"X\",\"Y\",\"Z\");\r\
    \n\r\
    \n:for i from=0 to=([:len \$l] - 1) do={\r\
    \n  :local char [:pick \$l \$i];\r\
    \n  :local f [:find \"\$upp\" \"\$char\"];\r\
    \n  :if ( \$f < 0 ) do={\r\
    \n  :set new (\$new . \$char);\r\
    \n  }\r\
    \n  :for a from=0 to=([:len \$upp] - 1) do={\r\
    \n  :local l [:pick \$upp \$a];\r\
    \n  :if ( \$char = \$l) do={\r\
    \n    :local u [:pick \$low \$a];\r\
    \n    :set new (\$new . \$u);\r\
    \n    }\r\
    \n  }\r\
    \n}\r\
    \n\r\
    \n:global login \"00:00:00:00:00:00\";\r\
    \n:if ([:len \$new] > 0) do={\r\
    \n:set login \$new;\r\
    \n}\r\
    \n\r\
    \n#:put (\"ispappSetGlobalEnv executed, login: \$login\");"


:put "Download and import ispappInit.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/master/ispappInit.rsc" dst-path="ispappInit.rsc"
  /import ispappInit.rsc
  :delay 3s
} on-error={:put "Error fetching ispappInit.rsc"; :delay 1s}

:put "Download and import ispappFunctions.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/master/ispappFunctions.rsc" dst-path="ispappFunctions.rsc"
  /import ispappFunctions.rsc
  :delay 3s
} on-error={:put "Error fetching ispappFunctions.rsc"; :delay 1s}

:put "Download and import ispappPingCollector.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/master/ispappPingCollector.rsc" dst-path="ispappPingCollector.rsc"
  /import ispappPingCollector.rsc
  :delay 3s
} on-error={:put "Error fetching ispappPingCollector.rsc"; :delay 1s}

:put "Download and import ispappLteCollector.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/master/ispappLteCollector.rsc" dst-path="ispappLteCollector.rsc"
  /import ispappLteCollector.rsc
  :delay 3s
} on-error={:put "Error fetching ispappLteCollector.rsc"; :delay 1s}

:put "Download and import ispappCollectors.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/master/ispappCollectors.rsc" dst-path="ispappCollectors.rsc"
  /import ispappCollectors.rsc
  :delay 3s
} on-error={:put "Error fetching ispappCollectors.rsc"; :delay 1s}

:put "ispappConfig.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/master/ispappConfig.rsc" dst-path="ispappConfig.rsc"
  /import ispappConfig.rsc
  :delay 3s
} on-error={:put "Error fetching ispappConfig.rsc"; :delay 1s}

:put "ispappRemoveConfiguration.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/master/ispappRemoveConfiguration.rsc" dst-path="ispappRemoveConfiguration.rsc"
  /import ispappRemoveConfiguration.rsc
  :delay 3s
} on-error={:put "Error fetching ispappRemoveConfiguration.rsc"; :delay 1s}

:put "ispappUpdate.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/master/ispappUpdate.rsc" dst-path="ispappUpdate.rsc"
  /import ispappUpdate.rsc
  :delay 3s
} on-error={:put "Error fetching ispappUpdate.rsc"; :delay 1s}

:put "ispappAvgCpuCollector.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/master/ispappAvgCpuCollector.rsc" dst-path="ispappAvgCpuCollector.rsc"
  /import ispappAvgCpuCollector.rsc
  :delay 3s
} on-error={:put "Error fetching ispappAvgCpuCollector.rsc"; :delay 1s}

:put "ispappRemoveFiles.rsc"
:do {
  /tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/master/ispappRemoveFiles.rsc" dst-path="ispappRemoveFiles.rsc"
  /import ispappRemoveFiles.rsc
  :delay 3s
} on-error={:put "Error fetching ispappRemoveFiles.rsc"; :delay 1s}

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

