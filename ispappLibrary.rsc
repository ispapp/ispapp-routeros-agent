# 2023-11-02 23:37:37
/system script
add dont-require-permissions=no name=ispappLibraryV1 owner=admin policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="#\
    ############################## this file contain predefined functions to b\
    e used across the agent script ################################\r\
    \n\r\
    \n# Function to collect all wireless interfaces and format them to be sent\
    \_to server.\r\
    \n# @param \$topDomain - domain of the server\r\
    \n# @param \$topKey - key of the server\r\
    \n# @param \$topListenerPort - port of the server\r\
    \n# @param \$login - login of the server\r\
    \n# @param \$password - password of the server\r\
    \n# @param \$prepareSSL - if true, SSL preparation will be done\r\
    \n# @return \$wlans - array of wireless interfaces\r\
    \n# @return \$status - status of the operation\r\
    \n# @return \$message - message of the operation\r\
    \n:global WirelessInterfacesConfigSync do={\r\
    \n    :local getConfig do={\r\
    \n        # get configuration from the server\r\
    \n        :do {\r\
    \n            :local res { \"host\"={ \"Authed\"=\"false\" } };\r\
    \n            :local i 0;\r\
    \n             :while (((\$res->\"host\"->\"Authed\") != true && (!any[:fi\
    nd [:tostr \$res] \"Err.Raise\"])) || \$i > 5 ) do={\r\
    \n                :set res ([\$ispappHTTPClient m=\"get\" a=\"config\"]->\
    \"parsed\");\r\
    \n                :set i (\$i + 1);\r\
    \n            }\r\
    \n            if (any [:find [:tostr \$res] \"Err.Raise\"]) do={\r\
    \n                # check id json received is valid and redy to be used\r\
    \n                :log error \"error while getting config (Err.Raise fJSON\
    Loads)\";\r\
    \n                :return {\"status\"=false; \"message\"=\"error while get\
    ting config (Err.Raise fJSONLoads)\"};\r\
    \n            } else={\r\
    \n                :log info \"check id json received is valid and redy to \
    be used with responce: \$res\";\r\
    \n                :return { \"responce\"=\$res; \"status\"=true };\r\
    \n            }\r\
    \n        } on-error={\r\
    \n            :log error \"error while getting config (Err.Raise fJSONLoad\
    s)\";\r\
    \n            :return {\"status\"=false; \"message\"=\"error while getting\
    \_config\"};\r\
    \n        }\r\
    \n    };\r\
    \n    :local getLocalWlans do={\r\
    \n        # collect all wireless interfaces from the system\r\
    \n        # format them to be sent to server\r\
    \n        :log info \"start collect all wireless interfaces from the syste\
    m ...\";\r\
    \n        :local wlans [/interface/wireless find];\r\
    \n        :local getEncKey do={\r\
    \n            if ([:len (\$1->\"wpa-pre-shared-key\")] > 0) do={\r\
    \n                :return (\$1->\"wpa-pre-shared-key\");\r\
    \n            } else={\r\
    \n                if ([:len (\$1->\"wpa2-pre-shared-key\")] > 0) do={\r\
    \n                    :return (\$1->\"wpa2-pre-shared-key\");\r\
    \n                } else={\r\
    \n                    :return \"\";\r\
    \n                }\r\
    \n            }\r\
    \n        }\r\
    \n         if ([:len \$wlans] > 0) do={\r\
    \n            :local wirelessConfigs;\r\
    \n            foreach i,k in=\$wlans do={\r\
    \n                :local temp [/interface/wireless print proplist=ssid,sec\
    urity-profile as-value where .id=\$k];\r\
    \n                :local cmdsectemp [:parse \"/interface/wireless/security\
    -profiles print proplist=wpa-pre-shared-key,authentication-types,wpa2-pre-\
    shared-key  as-value where  name=\\\$1\"];\r\
    \n                :local secTemp [\$cmdsectemp (\$temp->0->\"security-prof\
    ile\")];\r\
    \n                :local thisWirelessConfig {\r\
    \n                  \"encKey\"=[\$getEncKey (\$secTemp->0)];\r\
    \n                  \"encType\"=(\$secTemp->0->\"authentication-types\");\
    \r\
    \n                  \"ssid\"=(\$temp->0->\"ssid\")\r\
    \n                };\r\
    \n                :set (\$wirelessConfigs->\$i) \$thisWirelessConfig;\r\
    \n            }\r\
    \n            :log info \"collect all wireless interfaces from the system\
    \";\r\
    \n            :return { \"status\"=true; \"wirelessConfigs\"=\$wirelessCon\
    figs };\r\
    \n         } else={\r\
    \n            :log info \"collect all wireless interfaces from the system:\
    \_no wireless interfaces found\";\r\
    \n            :return { \"status\"=false; \"message\"=\"no wireless interf\
    aces found\" };\r\
    \n         }\r\
    \n    };\r\
    \n    \r\
    \n    if ([\$loginIsOk]) do={\r\
    \n        # check if our host is authorized to get configuration\r\
    \n        # and ready to accept interface syncronization\r\
    \n        :local configResponce [\$getConfig];\r\
    \n        :local retrying 0;\r\
    \n        :local wirelessConfigs (\$configResponce->\"responce\"->\"host\"\
    ->\"wirelessConfigs\");\r\
    \n        :local localwirelessConfigs [\$getLocalWlans];\r\
    \n        :local output;\r\
    \n        if ([:len \$wirelessConfigs] > 0) do={\r\
    \n            # this is the case when some interface configs received from\
    \_the host\r\
    \n            # get security profile with same password as the one on firs\
    t argument \$1\r\
    \n            \r\
    \n            :local SyncSecProfile do={\r\
    \n                # add security profile if not found\r\
    \n                :do {\r\
    \n                    :local tempName (\"ispapp_\" . (\$1->\"ssid\"));\r\
    \n                    :local currentProfilesAtPassword [:parse \"/interfac\
    e/wireless/security-profiles/print as-value where wpa-pre-shared-key=\\\$1\
    \"];\r\
    \n                    :local foundSecProfiles [\$currentProfilesAtPassword\
    \_\$tempName];\r\
    \n                    :log info \"add security profile if not found: \$tem\
    pName\";\r\
    \n                    :local updateSec  [:parse \"/interface wireless secu\
    rity-profiles set \\\$3 \\\\\r\
    \n                        wpa-pre-shared-key=\\\$1 \\\\\r\
    \n                        wpa2-pre-shared-key=\\\$1 \\\\\r\
    \n                        authentication-types=\\\$2\"];\r\
    \n                    if ([:len \$foundSecProfiles] > 0) do={\r\
    \n                        :local thisencTypeFormated [\$formatAuthTypes (\
    \$1->\"encType\")];\r\
    \n                        :local thisfoundSecProfiles (\$foundSecProfiles-\
    >0->\".id\");\r\
    \n                        [\$updateSec (\$1->\"encKey\") \$thisencTypeForm\
    ated \$thisfoundSecProfiles];\r\
    \n                        :return (\$foundSecProfiles->0->\"name\");\r\
    \n                    } else={\r\
    \n                         :local addSec  [:parse \"/interface wireless se\
    curity-profiles add \\\\\r\
    \n                            mode=dynamic-keys \\\\\r\
    \n                            name=(\\\"ispapp_\\\" . (\\\$1->\\\"ssid\\\"\
    )) \\\\\r\
    \n                            wpa2-pre-shared-key=(\\\$1->\\\"encKey\\\") \
    \\\\\r\
    \n                            wpa-pre-shared-key=(\\\$1->\\\"encKey\\\") \
    \\\\\r\
    \n                            authentication-types=(\\\$1->\\\"encTypeForm\
    ated\\\")\"];\r\
    \n                        [\$addSec (\$1 + {\"encTypeFormated\"=[\$formatA\
    uthTypes (\$1->\"encType\")]})];\r\
    \n                        :return \$tempName;\r\
    \n                    }\r\
    \n                } on-error={\r\
    \n                    # return the default dec profile in case of error\r\
    \n                    # adding or updating to perform interface setup with\
    \_no problems\r\
    \n                    :return [/interface/wireless/security-profiles/get *\
    0 name];\r\
    \n                }\r\
    \n            }\r\
    \n\r\
    \n            ## start comparing local and remote configs\r\
    \n            foreach conf in=\$wirelessConfigs do={\r\
    \n                :log info \"## start comparing local and remote configs \
    ##\";\r\
    \n                :local existedinterf [/interface/wireless/find ssid=(\$c\
    onf->\"ssid\")];\r\
    \n                if ([:len \$existedinterf] = 0) do={\r\
    \n                    # add new interface\r\
    \n                    :local newSecProfile [\$SyncSecProfile \$conf];\r\
    \n                    :local NewInterName (\"ispapp_\" . [\$convertToValid\
    Format (\$conf->\"ssid\")]);\r\
    \n                    :local masterinterface [/interface/wireless/get ([/i\
    nterface/wireless/find]->0) name];\r\
    \n                    :log info \"## add new interface -> \$NewInterName #\
    #\";\r\
    \n                    :local addInter [:parse \"/interface/wireless/add \\\
    \\\r\
    \n                        ssid=(\\\$1->\\\"ssid\\\") \\\\\r\
    \n                        wireless-protocol=802.11 frequency=auto mode=ap-\
    bridge hide-ssid=no comment=ispapp \\\\\r\
    \n                        security-profile=(\\\$1->\\\"newSecProfile\\\") \
    \\\\\r\
    \n                        master-interface=\\\$masterinterface \\\\\r\
    \n                        name=(\\\$1->\\\"NewInterName\\\") \\\\\r\
    \n                        disabled=no;\"];\r\
    \n                    [\$addInter (\$conf + {\"newSecProfile\"=\$newSecPro\
    file; \"NewInterName\"=\$NewInterName})];\r\
    \n                    :delay 3s; # wait for interface to be created\r\
    \n                    :log info \"## wait for interface to be created 3s #\
    #\";\r\
    \n                } else={\r\
    \n                    :local setInter [:parse \"/interface/wireless/set \\\
    \$2 \\\\\r\
    \n                        ssid=(\\\$1->\\\"ssid\\\") \\\\\r\
    \n                        wireless-protocol=802.11 frequency=auto mode=ap-\
    bridge hide-ssid=no comment=ispapp \\\\\r\
    \n                        security-profile=(\\\$1->\\\"newSecProfile\\\") \
    \\\\\r\
    \n                        name=(\\\$1->\\\"NewInterName\\\") \\\\\r\
    \n                        disabled=no;\"];\r\
    \n                    # set the first interface to the new config\r\
    \n                    :local newSecProfile [\$SyncSecProfile \$conf];\r\
    \n                    :local NewInterName (\"ispapp_\" . [\$convertToValid\
    Format (\$conf->\"ssid\")]);\r\
    \n                    :log info \"## update new interface -> \$NewInterNam\
    e ##\";\r\
    \n                    [\$setInter (\$conf + {\"newSecProfile\"=\$newSecPro\
    file; \"NewInterName\"=\$NewInterName}) (\$existedinterf->0)];\r\
    \n                    :delay 3s; # wait for interface to be setted\r\
    \n                    :log info \"## wait for interface to be created 3s #\
    #\";\r\
    \n                    if ([:len \$existedinterf] > 1) do={\r\
    \n                        # remove all interfaces except the first one\r\
    \n                        :foreach k,intfid in=\$existedinterf do={\r\
    \n                            if (\$k != 0) do={\r\
    \n                                /interface/wireless/remove [/interface/w\
    ireless/get \$intfid name];\r\
    \n                                :delay 1s; # wait for interface to be re\
    moved\r\
    \n                            }\r\
    \n                        }\r\
    \n                    }\r\
    \n                }\r\
    \n            }\r\
    \n            :local message (\"syncronization of \" . [:len \$wirelessCon\
    figs] . \" interfaces completed\");\r\
    \n            :log info \$message;\r\
    \n            :set output {\r\
    \n                \"status\"=true;\r\
    \n                \"message0\"=\$message;\r\
    \n                \"configs\"=\$wirelessConfigs\r\
    \n            };\r\
    \n        }\r\
    \n        if ([\$localwirelessConfigs]->\"status\" = true) do={\r\
    \n            ## start uploading local configs to host\r\
    \n            # item sended example from local: \"{\\\"if\\\":\\\"\$wIfNam\
    e\\\",\\\"ssid\\\":\\\"\$wIfSsid\\\",\\\"key\\\":\\\"\$wIfKey\\\",\\\"keyt\
    ypes\\\":\\\"\$wIfKeyTypeString\\\"}\"\r\
    \n            :delay 5s; # wait for interfaces changes to be applied and c\
    an be retrieved from the device\r\
    \n            :log info \"## wait for interfaces changes to be applied and\
    \_can be retrieved from the device 5s ##\";\r\
    \n            :local InterfaceslocalConfigs;\r\
    \n            :local getkeytypes  [:parse \"/interface/wireless/security-p\
    rofiles/get [/interface/wireless/get \\\$1 security-profile] authenticatio\
    n-types\"];\r\
    \n            :foreach k,interfaceid in=[/interface/wireless/find] do={\r\
    \n                :set (\$InterfaceslocalConfigs->\$k) {\r\
    \n                    \"if\"=([/interface/wireless/get \$interfaceid name]\
    );\r\
    \n                    \"ssid\"=([/interface/wireless/get \$interfaceid ssi\
    d]);\r\
    \n                    \"key\"=([/interface/wireless/security-profile get [\
    /interface/wireless/get \$interfaceid security-profile] wpa-pre-shared-key\
    ]);\r\
    \n                    \"keytypes\"=([\$joinArray [\$getkeytypes \$interfac\
    eid] \",\"])\r\
    \n                };\r\
    \n            };\r\
    \n            :local sentbody \"{}\";\r\
    \n            :local message (\"uploading \" . [:len \$InterfaceslocalConf\
    igs] . \" interfaces to ispapp server\");\r\
    \n            :set sentbody ([\$getAllConfigs \$InterfaceslocalConfigs]->\
    \"json\");\r\
    \n            :local returned  [\$ispappHTTPClient m=post a=config b=\$sen\
    tbody];\r\
    \n            :return (\$output+{\r\
    \n                \"status\"=true;\r\
    \n                \"body\"=\$sentbody;\r\
    \n                \"responce\"=\$returned;\r\
    \n                \"message1\"=\$message\r\
    \n            });\r\
    \n        } else={\r\
    \n            :log info \"no local wireless interfaces found (from Wireles\
    sInterfacesConfigSync function in ispLibrary.rsc)\";\r\
    \n            :return (\$output+{\r\
    \n                \"status\"=true;\r\
    \n                \"message1\"=\"no wireless interfaces found\"\r\
    \n            });\r\
    \n        }\r\
    \n    } else={\r\
    \n        :log error \"login or key is wrong or ispapp server is down or i\
    spapp server is not reachable check WirelessInterfacesConfigSync function \
    in ispLibrary.rsc\";\r\
    \n        :return {\r\
    \n            \"status\"=false;\r\
    \n            \"message\"=\"login or key is wrong\"\r\
    \n        };\r\
    \n    }\r\
    \n};\r\
    \n\r\
    \n# Function to prepare ssl connection to ispappHTTPClient\r\
    \n# 1- check ntp client status if synced with google/apple ntp servers.\r\
    \n#   10- setup ntp client if not synced and keep refreching 3 times max u\
    ntil it's working\r\
    \n#   11- if ntp client is not working, then exit the function with false \
    in ntpStatus key value.\r\
    \n# 2- check if \"Sectigo RSA DV CA\" and \"USERTrust RSA CA\" exist and t\
    rusted.\r\
    \n#   20- download and install the latest bundle if not exists.\r\
    \n#   21- install the latest bundle if not valid.\r\
    \n#   23- if bundle is not installed, then exit the function with false in\
    \_caStatus key value.\r\
    \n\r\
    \n:global prepareSSL do={\r\
    \n    :global ntpStatus false;\r\
    \n    :global caStatus false;\r\
    \n    # refrechable ssl state (each time u call [\$sslIsOk] a new value wi\
    ll be returned)\r\
    \n    :local sslIsOk do={\r\
    \n        :do {\r\
    \n            :return ([/tool fetch url=\"https://\$topDomain:\$topListene\
    rPort\" mode=https check-certificate=yes output=user as-value]->\"status\"\
    \_= \"finished\");\r\
    \n        } on-error={\r\
    \n            :return false;\r\
    \n        }\r\
    \n    };\r\
    \n    if ([\$sslIsOk]) do={\r\
    \n        :return {\r\
    \n            \"ntpStatus\"=true;\r\
    \n            \"caStatus\"=true\r\
    \n        };\r\
    \n    } else={\r\
    \n        # Check NTP Client Status\r\
    \n        if ([/system ntp client get status] = \"synchronized\") do={\r\
    \n            :set ntpStatus true;\r\
    \n        } else={\r\
    \n            # Configure a new NTP client\r\
    \n            :put \"adding ntp servers to /system ntp client \\n\";\r\
    \n            /system ntp client set enabled=yes mode=unicast servers=time\
    .nist.gov,time.google.com,time.cloudflare.com,time.windows.com\r\
    \n            /system/ntp/client/reset-freq-drift \r\
    \n            :delay 2s;\r\
    \n            :set ntpStatus true;\r\
    \n            :local retry 0;\r\
    \n            while ([/system ntp client get status] = \"waiting\" && \$re\
    try <= 5) do={\r\
    \n                :delay 500ms;\r\
    \n                :set retry (\$retry + 1);\r\
    \n            }\r\
    \n            if ([/system ntp client get status] = \"synchronized\") do={\
    \r\
    \n                :set ntpStatus true;\r\
    \n            }\r\
    \n        }\r\
    \n        :local latestCerts do={\r\
    \n            # Download and return parsed CAs.\r\
    \n            :local data [/tool  fetch http-method=get mode=https url=\"h\
    ttps://gogetssl-cdn.s3.eu-central-1.amazonaws.com/wiki/SectigoRSADVBundle.\
    txt\"  as-value output=user];\r\
    \n            :local data0 [:pick (\$data->\"data\") 0 ([:find (\$data->\"\
    data\") \"-----END CERTIFICATE-----\"] + 26)]; \r\
    \n            :return { \"DV\"=\$data0 }\r\
    \n        };\r\
    \n        # function to add to install downloaded bundle.\r\
    \n        :local addDv do={\r\
    \n            :local currentcerts [\$latestCerts];\r\
    \n            :put (\"adding DV cert: \\n\" . (\$currentcerts->\"DV\") . \
    \"\\n\");\r\
    \n            if (([:len [/file find where name~\"ispapp.co_SectigoRSADVBu\
    ndle\"]] = 0)) do={\r\
    \n            /file add name=ispapp.co_SectigoRSADVBundle.txt contents=(\$\
    currentcerts->\"DV\");\r\
    \n            /certificate import name=ispapp.co_SectigoRSADVBundle file=i\
    spapp.co_SectigoRSADVBundle.txt;\r\
    \n            } else={\r\
    \n                /file set [/file find where name=ispapp.co_SectigoRSADVB\
    undle.txt] contents=(\$currentcerts->\"DV\");\r\
    \n                /certificate import name=ispapp.co_SectigoRSADVBundle fi\
    le=ispapp.co_SectigoRSADVBundle.txt;\r\
    \n            }\r\
    \n        };\r\
    \n        :do {\r\
    \n            [\$addDv];\r\
    \n        } on-error={\r\
    \n            :put \"error adding DV cert \\n\";\r\
    \n        }\r\
    \n        :local retries 0;\r\
    \n        :do { \r\
    \n            :local addDVres [\$addDv];\r\
    \n            :delay 1s;\r\
    \n            if (!([:len [/certificate find name~\"ispapp.co\" trusted=ye\
    s ]] = 0)) do={\r\
    \n                :set caStatus true;\r\
    \n            }\r\
    \n            :set retries (\$retries + 1);\r\
    \n        } while (([:len [/certificate find name~\"ispapp.co\" trusted=ye\
    s ]] = 0) && \$retries <= 5)\r\
    \n    }\r\
    \n    :return { \"ntpStatus\"=\$ntpStatus; \"caStatus\"=\$caStatus };\r\
    \n}\r\
    \n\r\
    \n# Converts a mixed array into a JSON string.\r\
    \n# Handles arrays, numbers, and strings up to 3 tested levels deep (it ca\
    n do more levels now).\r\
    \n# Useful for converting RouterOS scripting language arrays into JSON.\r\
    \n:global toJson do={\r\
    \n  :local Aarray \$1;\r\
    \n  :local IsArray false;\r\
    \n  if ([:typeof \$Aarray] = \"array\") do={\r\
    \n    :set IsArray (([:find \$Aarray [:pick \$Aarray 0]] = 0) && ([:find \
    \$Aarray [:pick \$Aarray ([:len \$Aarray] - 1)]] = ([:len \$Aarray] - 1)))\
    ;\r\
    \n  } else={\r\
    \n     :if ([:typeof \$Aarray] = \"num\") do={\r\
    \n        :return \$Aarray;\r\
    \n     } else={\r\
    \n        :return \"\\\"\$Aarray\\\"\";\r\
    \n     }\r\
    \n  }\r\
    \n  :local AjsonString \"\";\r\
    \n  if ((any \$2) && ([:typeof \$2] != \"num\")) do={\r\
    \n    if (\$IsArray) do={\r\
    \n      :set AjsonString \"\\\"\$2\\\":[\";\r\
    \n    } else={\r\
    \n      :set AjsonString \"\\\"\$2\\\":{\";\r\
    \n    }\r\
    \n  } else={\r\
    \n    if (\$IsArray) do={\r\
    \n    :set AjsonString \"[\";\r\
    \n    } else={\r\
    \n      :set AjsonString \"{\";\r\
    \n    }\r\
    \n  }\r\
    \n  :local idx 0;\r\
    \n  :foreach Akey,Avalue in=\$Aarray do={\r\
    \n    :if ([:typeof \$Avalue] = \"array\") do={\r\
    \n        :local v [\$toJson \$Avalue \$Akey];\r\
    \n        :local AvalueJson \$v;\r\
    \n        :set AjsonString \"\$AjsonString\$AvalueJson\";\r\
    \n    } else={\r\
    \n        if (\$IsArray) do={\r\
    \n            :if ([:typeof \$Avalue] = \"num\" || [:typeof \$Avalue] = \"\
    bool\") do={\r\
    \n                :set AjsonString \"\$AjsonString\$Avalue\";\r\
    \n            } else={\r\
    \n                :set AjsonString \"\$AjsonString\\\"\$Avalue\\\"\";\r\
    \n            }\r\
    \n        } else={\r\
    \n            :if ([:typeof \$Avalue] = \"num\") do={\r\
    \n                :set AjsonString \"\$AjsonString\\\"\$Akey\\\":\$Avalue\
    \";\r\
    \n            } else={\r\
    \n                 :if (\$Avalue = \"[]\" || \$Avalue = \"{}\" || ([:typeo\
    f \$Avalue] = \"bool\")) do={\r\
    \n                    :set AjsonString \"\$AjsonString\\\"\$Akey\\\":\$Ava\
    lue\";\r\
    \n                } else={\r\
    \n                    :set AjsonString \"\$AjsonString\\\"\$Akey\\\":\\\"\
    \$Avalue\\\"\";\r\
    \n                }\r\
    \n            }\r\
    \n        }\r\
    \n    }\r\
    \n    if (\$idx < ([:len \$Aarray] - 1)) do={\r\
    \n        :set AjsonString \"\$AjsonString,\";\r\
    \n    }\r\
    \n    :set idx (\$idx + 1);\r\
    \n  }\r\
    \n  if (\$IsArray) do={\r\
    \n    :set AjsonString \"\$AjsonString]\";\r\
    \n  } else={\r\
    \n    :set AjsonString \"\$AjsonString}\";\r\
    \n  }\r\
    \n  :return \$AjsonString;\r\
    \n}\r\
    \n\r\
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
    \n\r\
    \n# @Details: Function to Diagnose important global variable for agent con\
    nection\r\
    \n# @Syntax: \$TopVariablesDiagnose\r\
    \n# @Example: :put [\$TopVariablesDiagnose] or just \$TopVariablesDiagnose\
    \r\
    \n:global TopVariablesDiagnose do={\r\
    \n    :local refreched do={:return {\"topListenerPort\"=\$topListenerPort;\
    \_\"topDomain\"=\$topDomain; login=\$login}};\r\
    \n    :local res {\"topListenerPort\"=\$topListenerPort; \"topDomain\"=\$t\
    opDomain; \"login\"=\$login};\r\
    \n    # Check if topListenerPort is not set and assign a default value if \
    not set\r\
    \n    :if (!any \$topListenerPort) do={\r\
    \n      :global topListenerPort 8550;\r\
    \n      :set res [\$refreched];\r\
    \n    }\r\
    \n    # Check if topDomain is not set and assign a default value if not se\
    t\r\
    \n    :if (!any \$topDomain) do={\r\
    \n      :global topDomain \"qwer.ispapp.co\"\r\
    \n      :set res [\$refreched];\r\
    \n    }\r\
    \n    # Check if login is not set and assign a default value as the MikroT\
    ik MAC address\r\
    \n    :if (!any \$login) do={\r\
    \n      :do {\r\
    \n        :global login ([/interface get [find default-name=wlan1] mac-add\
    ress]);\r\
    \n        :set res [\$refreched];\r\
    \n      } on-error={\r\
    \n        :do {\r\
    \n          :global login ([/interface get [find default-name=ether1] mac-\
    address]);\r\
    \n          :set res [\$refreched];\r\
    \n        } on-error={\r\
    \n            :do {\r\
    \n                :global login ([/interface get [find default-name=sfp-sf\
    pplus1] mac-address]);\r\
    \n                :set res [\$refreched];\r\
    \n            } on-error={\r\
    \n                :do {\r\
    \n                    :global login ([/interface get [find default-name=lt\
    e1] mac-address]);\r\
    \n                    :set res [\$refreched];\r\
    \n                } on-error={\r\
    \n                    :log info (\"No Interface MAC Address found to use a\
    s ISPApp login, default-name=wlan1, ether1, sfp-sfpplus1 or lte1 must exis\
    t.\");\r\
    \n                    :set res [\$refreched];\r\
    \n                }\r\
    \n            }\r\
    \n        }\r\
    \n    }\r\
    \n    :set login ([\$strcaseconv \$login]->\"lower\");\r\
    \n  }\r\
    \n  :return \$res;\r\
    \n}\r\
    \n\r\
    \n# Function to remove all scripts from the system related to ispapp agent\
    \r\
    \n# usage:\r\
    \n#   [\$removeIspappScripts] // don't expect no returns check just the lo\
    gs after.\r\
    \n:global removeIspappScripts do={\r\
    \n    :local scriptList [/system script find where name~\"ispapp.*\"]\r\
    \n    if ([:len [/system script find where name~\"ispapp.*\"]] > 0) {\r\
    \n        :foreach scriptId in=\$scriptList do={\r\
    \n            :local scriptName [/system script get \$scriptId name];\r\
    \n            :do {\r\
    \n                /system script remove \$scriptId;\r\
    \n                :put \"found \$scriptName.rsc and removed \\E2\\9C\\85\"\
    ;\r\
    \n                :log info \"found \$scriptName and removed \\E2\\9C\\85\
    \";\r\
    \n                :delay 500ms;\r\
    \n            } on-error={\r\
    \n                :log error \"\\E2\\9D\\8C Could not remove script id \$s\
    criptId: \$scriptName.rsc\";\r\
    \n            }\r\
    \n        }\r\
    \n    }\r\
    \n}\r\
    \n\r\
    \n# Function to remove all schedulers from the system related to ispapp ag\
    ent\r\
    \n# usage:\r\
    \n#   [\$removeIspappSchedulers] // don't expect no returns check just the\
    \_logs after.\r\
    \n:global removeIspappSchedulers do={\r\
    \n    :local scriptList [/system scheduler find where name~\"ispapp.*\"]\r\
    \n    if ([:len [/system scheduler find where name~\"ispapp.*\"]] > 0) {\r\
    \n        :foreach schedulerId in=\$schedulerList do={\r\
    \n            :do {\r\
    \n                /system scheduler remove \$schedulerId;\r\
    \n                :put \"found \$schedulerName and removed \\E2\\9C\\85\";\
    \r\
    \n                :log info \"found \$schedulerName and removed \\E2\\9C\\\
    85\";\r\
    \n                :delay 500ms;\r\
    \n            } on-error={\r\
    \n                :local schedulerName [/system scheduler get \$schedulerI\
    d name];\r\
    \n                :log error \"\\E2\\9D\\8C Could not remove scheduler id \
    \$schedulerId: \$schedulerName\";\r\
    \n            }\r\
    \n        }\r\
    \n    }\r\
    \n}\r\
    \n\r\
    \n# Function to simplify fJParse usage;\r\
    \n# usage:\r\
    \n#   :put [\$JSONLoads \"{\\\"hello\\\":\\\"world\\\"}\"];\r\
    \n:global JSONLoads do={\r\
    \n    :global JSONIn \$1;\r\
    \n    :global fJParse;\r\
    \n    :local ret [\$fJParse];\r\
    \n    :set JSONIn;\r\
    \n    :global Jpos;\r\
    \n    :global Jdebug; if (!\$Jdebug) do={set Jdebug};\r\
    \n    :return \$ret;\r\
    \n}\r\
    \n\r\
    \n# Function that takes a string as an input and converts it to the desire\
    d format\r\
    \n# Example usage:\r\
    \n# :put [\$convertToValidFormat \"this_is_a_Test! @#\?/string\"] // retur\
    ns \"this_is_a_Test______string\"\r\
    \n:global convertToValidFormat do={\r\
    \n    :local inputString (\$1)\r\
    \n    :local validCharacters \"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ\
    RSTUVWXYZ0123456789_\"\r\
    \n    :local outputString \"\"\r\
    \n    \r\
    \n    :local length [:len \$inputString]\r\
    \n    :local i 0\r\
    \n    :while (\$i < \$length) do={\r\
    \n        :local currentCharacter [:pick \$inputString \$i]\r\
    \n        :if ([:typeof [:find \$validCharacters \$currentCharacter]] = \"\
    num\") do={\r\
    \n            :set outputString (\$outputString . \$currentCharacter)\r\
    \n        } else={\r\
    \n            :set outputString (\$outputString . \"_\")\r\
    \n        }\r\
    \n        :set i (\$i + 1)\r\
    \n    }\r\
    \n    :return \$outputString;\r\
    \n}\r\
    \n\r\
    \n\r\
    \n# Function in RouterOS script that formats the authentication types as p\
    er the specified rules\r\
    \n# Example usage:\r\
    \n# :put [\$formatAuthTypes \"wpa-psk wpa2-psk wpa3-eap wpa2-eap\"]\r\
    \n:global formatAuthTypes do={\r\
    \n    :local inputTypes (\$1)\r\
    \n    :local validTypesArr [:toarray \"wpa-eap, wpa-psk, wpa2-eap, wpa2-ps\
    k\"];\r\
    \n    :local outputTypes \"\"\r\
    \n    :local typesArr \"\";\r\
    \n    :for i from=0 to=[:len \$inputTypes] do={\r\
    \n        :if ([:pick \$inputTypes \$i] = \" \" || [:pick \$inputTypes \$i\
    ] = \";\") do={\r\
    \n            :set typesArr (\$typesArr. \", \");\r\
    \n        } else={\r\
    \n            :set typesArr (\$typesArr. [:pick \$inputTypes \$i]);\r\
    \n        }\r\
    \n    }\r\
    \n    :set typesArr [:toarray \$typesArr];\r\
    \n    :foreach atype in=\$typesArr do={\r\
    \n        :if ([:typeof [:find \$validTypesArr \$atype]] = \"num\") do={\r\
    \n            :if (\$outputTypes = \"\") do={\r\
    \n                :set outputTypes \$atype;\r\
    \n            } else={\r\
    \n                :set outputTypes (\$outputTypes . \",\" . \$atype);\r\
    \n            }\r\
    \n        }\r\
    \n    }\r\
    \n    :return \$outputTypes;\r\
    \n}\r\
    \n\r\
    \n# Function to join array elements with a specified delimiter\r\
    \n# Example usage:\r\
    \n# :put [\$joinArray [\"a\" \"b\" \"c\"] \" - \"] // returns \"a - b - c\
    \"\r\
    \n\r\
    \n:global joinArray do={\r\
    \n    :local inputArray (\$1)\r\
    \n    :local delimiter (\$2)\r\
    \n    :local outputString \"\"\r\
    \n    if ([:typeof \$inputArray] != \"array\") do={\r\
    \n        :return [:tostr \$inputArray]\r\
    \n    }\r\
    \n    :foreach k,i in=\$inputArray do={\r\
    \n        if (\$k = 0) do={\r\
    \n            :set outputString (\$outputString .  \$i);\r\
    \n        } else={\r\
    \n            :set outputString (\$outputString . \$2 .  \$i);\r\
    \n        }\r\
    \n    }\r\
    \n    :return \$outputString;\r\
    \n}\r\
    \n\r\
    \n# Ispapp HTTP Client\r\
    \n# Usage:\r\
    \n# :put [\$ispappHTTPClient m=<get|post|put|delete> a=<update|config> b=<\
    json>]\r\
    \n:global ispappHTTPClient do={\r\
    \n    :local sslPreparation [\$prepareSSL];\r\
    \n    :local method \$m; # method\r\
    \n    :local action \$a; # action\r\
    \n    :local body \$b; # body\r\
    \n    :local certCheck \"no\";\r\
    \n    # get current time and format it\r\
    \n    :local time [/system clock print as-value];\r\
    \n    :local formattedTime ((\$time->\"date\") . \" | \" . (\$time->\"time\
    \"));\r\
    \n    :local actions (\"update\", \"config\");\r\
    \n    # check if method argument is provided\r\
    \n    if ((\$sslPreparation->\"ntpStatus\" = true) && (\$sslPreparation->\
    \"caStatus\" = true)) do={\r\
    \n        :set certCheck \"yes\";\r\
    \n        :log info \"ssl preparation is completed with success!\";\r\
    \n    }\r\
    \n    if (!any \$m) do={\r\
    \n        :local method \"get\";\r\
    \n    }\r\
    \n    # check if action was provided\r\
    \n    if (!any \$a) do={\r\
    \n        :set action \"config\";\r\
    \n        :log warning (\"default action added!\\t ispappLibrary.rsc\\t[\"\
    \_. \$formattedTime . \"] !\\tusage: (ispappHTTPClient a=<update|config> b\
    =<json>  m=<get|post|put|delete>)\");\r\
    \n    }\r\
    \n    # check if key was provided if not run ispappSet\r\
    \n    if (!any \$topKey) do={\r\
    \n        :global topKey; \r\
    \n    }\r\
    \n    # Check if topListenerPort is not set and assign a default value if \
    not set\r\
    \n    :if (!any \$topListenerPort) do={\r\
    \n        :global topListenerPort 8550;\r\
    \n    }\r\
    \n    # Check if topDomain is not set and assign a default value if not se\
    t\r\
    \n    :if (!any \$topDomain) do={\r\
    \n        :global topDomain \"qwer.ispapp.co\";\r\
    \n    }\r\
    \n    :local requestUrl (\"https://\" . \$topDomain . \":\" . \$topListene\
    rPort . \"/\" . \$action . \"\?login=\" . \$login . \"&key=\" . \$topKey);\
    \r\
    \n    # Check certificates\r\
    \n    # Make request\r\
    \n    :local out;\r\
    \n    if (!any \$b) do={\r\
    \n        :set out [/tool fetch url=\$requestUrl check-certificate=\$certC\
    heck http-method=\$m output=user as-value];\r\
    \n    } else={\r\
    \n        :set out [/tool fetch url=\$requestUrl check-certificate=\$certC\
    heck http-header-field=\"cache-control: no-cache, content-type: applicatio\
    n/json, Accept: */*\" http-method=\"\$m\" http-data=\"\$b\" output=user as\
    -value];\r\
    \n    }\r\
    \n    if (\$out->\"status\" = \"finished\") do={\r\
    \n        :local parses [\$JSONLoads (\$out->\"data\")];\r\
    \n        :return { \"status\"=true; \"response\"=(\$out->\"data\"); \"par\
    sed\"=\$parses; \"requestUrl\"=\$requestUrl };\r\
    \n    } else={\r\
    \n        :return { \"status\"=false; \"reason\"=(\$out->\"status\"); \"re\
    questUrl\"=\$requestUrl };\r\
    \n    }\r\
    \n}\r\
    \n\r\
    \n# Function to check if credentials are ok\r\
    \n# get last login state and save it for avoiding server loading \r\
    \n# syntax:\r\
    \n#       :put [\$loginIsOk] \\\\ result: true/false\r\
    \n:global loginIsOk do={\r\
    \n    # check if login and password are correct\r\
    \n    if (!any \$loginIsOkLastCheck) do={\r\
    \n        :global loginIsOkLastCheck ([\$getTimestamp]->\"current\");\r\
    \n    } else={\r\
    \n        :local difft ([\$getTimestamp s \$loginIsOkLastCheck]->\"diff\")\
    \_;\r\
    \n        if (\$difft < -30) do={\r\
    \n            :return \$loginIsOkLastCheckvalue;\r\
    \n        } \r\
    \n    }\r\
    \n    if (!any \$loginIsOkLastCheckvalue) do={\r\
    \n        :global loginIsOkLastCheckvalue true;\r\
    \n    }\r\
    \n    :do {\r\
    \n        :set loginIsOkLastCheck ([\$getTimestamp]->\"current\");\r\
    \n        :local res [/tool fetch url=\"https://\$topDomain:\$topListenerP\
    ort/update\?login=\$login&key=\$topKey\" mode=https check-certificate=yes \
    output=user as-value];\r\
    \n        :set loginIsOkLastCheckvalue (\$res->\"status\" = \"finished\");\
    \r\
    \n        :log info \"check if login and password are correct completed wi\
    th responce: \$loginIsOkLastCheckvalue\";\r\
    \n        :return \$loginIsOkLastCheckvalue;\r\
    \n    } on-error={\r\
    \n        :log info \"check if login and password are correct completed wi\
    th responce: error\";\r\
    \n        :set loginIsOkLastCheckvalue false;\r\
    \n        :return \$loginIsOkLastCheckvalue;\r\
    \n    }\r\
    \n};\r\
    \n"
add dont-require-permissions=no name=ispappLibraryV2 owner=admin policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="\
    \r\
    \n# Function to get timestamp in seconds, minutes, hours, or days\r\
    \n# save it in a global variable to get diff between it and the current ti\
    mestamp.\r\
    \n# synctax:\r\
    \n#       :put [\$getTimestamp <s|m|d|h> <your saved timestamp variable to\
    \_get diff>]\r\
    \n:global getTimestamp do={\r\
    \n    :local format \$1;\r\
    \n    :local out;\r\
    \n    :local time2parse [:timestamp]\r\
    \n    :local w [:find \$time2parse \"w\"]\r\
    \n    :local d [:find \$time2parse \"d\"]\r\
    \n    :local c [:find \$time2parse \":\"]\r\
    \n    :local p [:find \$time2parse \".\"]\r\
    \n    :local weeks [:pick \$time2parse 0 [\$w]]\r\
    \n    :set \$weeks [:tonum (\$weeks * 604800)]\r\
    \n    :local days [:pick \$time2parse (\$w + 1) \$d]\r\
    \n    :set days [:tonum (\$days * 86400)]\r\
    \n    :local hours [:pick \$time2parse (\$d + 1) \$c]\r\
    \n    :set hours [:tonum (\$hours * 3600)]\r\
    \n    :local minutes [:pick \$time2parse (\$c + 1) [:find \$time2parse (\$\
    c + 3)]]\r\
    \n    :set minutes [:tonum (\$minutes * 60)]\r\
    \n    :local seconds [:pick \$time2parse (\$c + 4) \$p]\r\
    \n    :local rawtime (\$weeks+\$days+\$hours+\$minutes+\$seconds)\r\
    \n    :local current (\$weeks+\$days+\$hours+\$minutes+\$seconds)\r\
    \n    if (!any \$lastTimestamp) do={\r\
    \n        :global lastTimestamp \$rawtime;\r\
    \n    }\r\
    \n    if ([:typeof \$2] = \"num\") do={\r\
    \n        :set lastTimestamp \$2;\r\
    \n    }\r\
    \n    :if (\$format = \"s\") do={\r\
    \n      :local diff (\$rawtime - \$lastTimestamp);\r\
    \n      :set out { \"current\"=\$current; \"diff\"=\$diff;}\r\
    \n      :global lastTimestamp \$rawtime;\r\
    \n      :return \$out;\r\
    \n    } else={\r\
    \n      :if (\$format = \"m\") do={\r\
    \n           :local diff ((\$rawtime - \$lastTimestamp)/60);\r\
    \n           :set out { \"current\"=\$current; \"diff\"=\$diff }\r\
    \n           :global lastTimestamp \$rawtime;\r\
    \n           :return \$out;\r\
    \n      } else={\r\
    \n        :if (\$format = \"h\") do={\r\
    \n           :local diff ((\$rawtime - \$lastTimestamp)/3600);\r\
    \n           :set out { \"current\"=\$current; \"diff\"=\$diff }\r\
    \n           :global lastTimestamp \$rawtime;\r\
    \n           :return \$out;\r\
    \n        } else={\r\
    \n          :if (\$format = \"d\") do={\r\
    \n               :local diff ((\$rawtime - \$lastTimestamp)/86400);\r\
    \n               :set out { \"current\"=\$current; \"diff\"=\$diff }\r\
    \n               :global lastTimestamp \$rawtime;\r\
    \n               :return \$out;\r\
    \n          } else={\r\
    \n              :local diff (\$rawtime - \$lastTimestamp);\r\
    \n              :set out { \"current\"=\$current; \"diff\"=\$diff }\r\
    \n              :global lastTimestamp \$rawtime;\r\
    \n              :return \$out;\r\
    \n          }\r\
    \n        }\r\
    \n      }\r\
    \n    }\r\
    \n}\r\
    \n# Function to collect all information needed yo be sent to config endpoi\
    nt\r\
    \n# usage: \r\
    \n#   :put [\$getAllConfigs <interfacesinfos array>] \r\
    \n# result will be in this format:\r\
    \n#      (\"{\"clientInfo\":\"\$topClientInfo\", \"osVersion\":\"\$osversi\
    on\", \"hardwareMake\":\"\$hardwaremake\",\r\
    \n#     \"hardwareModel\":\"\$hardwaremodel\",\"hardwareCpuInfo\":\"\$cpu\
    \",\"os\":\"\$os\",\"osBuildDate\":\$osbuilddate\r\
    \n#     ,\"fw\":\"\$topClientInfo\",\"hostname\":\"\$hostname\",\"interfac\
    es\":[\$ifaceDataArray],\"wirelessConfigured\":[\$wapArray],\r\
    \n#     \"webshellSupport\":true,\"bandwidthTestSupport\":true,\"firmwareU\
    pgradeSupport\":true,\"wirelessSupport\":true}\");\r\
    \n\r\
    \n:global getAllConfigs do={\r\
    \n    :do {\r\
    \n        :local buildTime [/system resource get build-time];\r\
    \n        :local osbuilddate [\$rosTimestringSec \$buildTime];\r\
    \n        :local interfaces;\r\
    \n        foreach k,v in=[/interface/find] do={\r\
    \n            :local Name [/interface get \$v name];\r\
    \n            :local Mac [/interface get \$v mac-address];\r\
    \n            :local DefaultName [:parse \"/interface get \\\$1 default-na\
    me\"];\r\
    \n            :set (\$interfaces->\$k) {\r\
    \n                \"if\"=\$Name;\r\
    \n                \"mac\"=\$Mac;\r\
    \n                \"defaultIf\"=[\$DefaultName \$v]\r\
    \n            };\r\
    \n        }\r\
    \n        :set osbuilddate [:tostr \$osbuilddate];\r\
    \n        :local data {\r\
    \n            \"clientInfo\"=\$topClientInfo;\r\
    \n            \"osVersion\"=[/system resource get version];\r\
    \n            \"hardwareMake\"=[/system resource get platform];\r\
    \n            \"hardwareModel\"=[/system resource get board-name];\r\
    \n            \"hardwareCpuInfo\"=[/system resource get cpu];\r\
    \n            \"osBuildDate\"=[\$rosTimestringSec [/system resource get bu\
    ild-time]];\r\
    \n            \"fw\"=\$topClientInfo;\r\
    \n            \"interfaces\"=\$interfaces;\r\
    \n            \"hostname\"=[/system identity get name];\r\
    \n            \"os\"=[/system package get 0 name];\r\
    \n            \"wirelessConfigured\"=\$1;\r\
    \n            \"webshellSupport\"=true;\r\
    \n            \"firmwareUpgradeSupport\"=true;\r\
    \n            \"wirelessSupport\"=true;\r\
    \n            \"bandwidthTestSupport\"=true\r\
    \n        };\r\
    \n        :local json [\$toJson \$data];\r\
    \n        :log info \"Configs body json created with success (getAllConfig\
    sFigs function -> true).\";\r\
    \n        :return {\"status\"=true; \"json\"=\$json};\r\
    \n    } on-error={\r\
    \n        :log error \"faild to build config json object!\";\r\
    \n        :return {\"status\"=false; \"reason\"=\"faild to build config js\
    on object!\"};\r\
    \n    }\r\
    \n}\r\
    \n"
/system script run ispappLibraryV2
/system script run ispappLibraryV1