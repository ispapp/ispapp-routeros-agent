/system script add dont-require-permissions=yes name=ispappInit owner=admin policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="#\
    \_keep track of the number of update retries\r\
    \n:global updateSequenceNumber 0;\r\
    \n:global connectionFailures 0;\r\
    \n\r\
    \n# track status since init for these booleans\r\
    \n:global configScriptSuccessSinceInit false;\r\
    \n:global updateScriptSuccessSinceInit false;\r\
    \n:do {\r\
    \n     /system script run ispappConfig;\r\
    \n  #:put (\"ran ispappConfig\");\r\
    \n} on-error={\r\
    \n  :log info (\"ispappConfig script error.\");\r\
    \n}\r\
    \n:do {\r\
    \n  /system script run ispappFunctions;\r\
    \n} on-error={\r\
    \n  :log info (\"ispappFunctions script error.\");\r\
    \n}\r\
    \n:do {\r\
    \n  # this runs without a scheduler, because LTE modems use serial communi\
    cations and often pending activity blocks data collection\r\
    \n  /system script run ispappLteCollector;\r\
    \n} on-error={\r\
    \n  :log info (\"ispappLteCollector script error.\");\r\
    \n}\r\
    \n:do {\r\
    \n  # this runs without a scheduler, because the routeros scheduler wastes\
    \_too many cpu cycles\r\
    \n  /system script run ispappAvgCpuCollector;\r\
    \n} on-error={\r\
    \n  :log info (\"ispappAvgCpuCollector script error.\");\r\
    \n}\r\
    \n\r\
    \n/system scheduler enable ispappCollectors;\r\
    \n/system scheduler enable ispappInit;"