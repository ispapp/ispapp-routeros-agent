:global ispappLibraryV3 "ispappLibraryV3 loaded";
# Function to collect all wireless interfaces and format them to be sent to server.
# @param $topDomain - domain of the server
# @param $topKey - key of the server
# @param $topListenerPort - port of the server
# @param $login - login of the server
# @param $password - password of the server
# @param $prepareSSL - if true, SSL preparation will be done
# @return $wlans - array of wireless interfaces
# @return $status - status of the operation
# @return $message - message of the operation
:global Wifewave2InterfacesConfigSync do={
:do {
    :global getAllConfigs;
    :global ispappHTTPClient;
    :global fillGlobalConsts;
    :local getConfig do={
        # get configuration from the server
        :do {
            :global ispappHTTPClient;
            :local res;
            :local i 0;
            :if ([$ispappHTTPClient m="get" a="update"]->"status" = false) do={
                :return { "responce"="firt time config of server error"; "status"=false };
            }
            :while ((any[:find [:tostr $res] "Err.Raise"] || !any$res) && $i < 3) do={
                :set res ([$ispappHTTPClient m="get" a="config"]->"parsed");
                :set i ($i + 1);
            }
            if (any [:find [:tostr $res] "Err.Raise"]) do={
                # check id json received is valid and redy to be used
                :log error "error while getting config (Err.Raise fJSONLoads)";
                :return {"status"=false; "message"="error while getting config (Err.Raise fJSONLoads)"};
            } else={
                :if ($res->"host"->"Authed" != true) do={
                    :log error [:tostr $res];
                    :return {"status"=false; "message"=$res};
                } else={
                    :log info "check id json received is valid and redy to be used with responce: $res";
                    :put [$fillGlobalConsts $res];
                    :return { "responce"=$res; "status"=true };
                }
            }
        } on-error={
            :log error "error while getting config (Err.Raise fJSONLoads)";
            :return {"status"=false; "message"="error while getting config"};
        }
    };
    :local getLocalWlans do={
        # collect all wireless interfaces from the system
        # format them to be sent to server
        :log info "start collect all wireless interfaces from the system ...";
        :local wlans [/interface wifiwave2 print proplist=disabled,security,channel,configuration as-value];
        if ([:len $wlans] > 0) do={
        :local wirelessConfigs;
        foreach i,intr in=$wlans do={
            :local cmdsectemp [:parse "/interface wifiwave2 security print proplist=passphrase,authentication-types,name  as-value where  name=\$1"];
            :local cmdconftemp [:parse "/interface wifiwave2 configuration print proplist=ssid,security  as-value where  name=\$1"];
            :local conftemp [$cmdconftemp ($intr->"configuration")];
            :local secTemp [$cmdsectemp ($conftemp->"security")];
            :local thisWirelessConfig {
                "encKey"=($secTemp->0->"passphrase");
                "encType"=($secTemp->0->"authentication-types");
                "ssid"=($conftemp->0->"ssid")
            };
            :set ($wirelessConfigs->$i) $thisWirelessConfig;
        }
        :log info "collect all wireless interfaces from the system";
        :return { "status"=true; "wirelessConfigs"=$wirelessConfigs };
        } else={
        :log info "collect all wireless interfaces from the system: no wireless interfaces found";
        :return { "status"=false; "message"="no wireless interfaces found" };
        }
    };
    :delay 1s;
    :log info "done setting local functions .... 1s"
    # check if our host is authorized to get configuration
    # and ready to accept interface syncronization
    :local configResponce [$getConfig];
    :local localwirelessConfigs [$getLocalWlans];
    :local output;
    :local wirelessConfigs [:toarray ""];
    :if ($configResponce->"status" = true) do={
        :set wirelessConfigs ($configResponce->"responce"->"host"->"wirelessConfigs");
    }
    :delay 1s;
    :log info "done setting wirelessConfigs .... 1s"
    if ([:len $wirelessConfigs] > 0) do={
        # this is the case when some interface configs received from the host
        # get security profile with same password as the one on first argument $1
        :global SyncSecProfile do={
            # add security profile if not found
            :do {
                :local key ($1->"encKey");
                :local tempName ("ispapp_" . ($1->"ssid"));
                # search for profile with this same password if exist if not just create it.
                :local currentprfpass [:parse "/interface wifiwave2 security print as-value where passphrase=\$1"];
                # todo: separation of sec profiles ....
                :local foundSecProfiles [$currentprfpass $key]; # error 
                :log info "add security profile if not found: $tempName";
                if ([:len $foundSecProfiles] > 0) do={
                    :return ($foundSecProfiles->0->"name");
                } else={
                    :local addSec  [:parse "/interface wifiwave2 security add \\
                        wps=disable \\
                        name=\$tempName \\
                        passphrase=(\$1->\"encKey\") \\
                        authentication-types=wpa2-psk,wpa3-psk"];
                    :put [$addSec $1];
                    :return $tempName;
                }
            } on-error={
                # return the default dec profile in case of error
                # adding or updating to perform interface setup with no problems
                :return [/interface wifiwave2 security get *0 name];
            }
        }
        :global convertToValidFormat;
        ## start comparing local and remote configs
        foreach conf in=$wirelessConfigs do={
            :log info "## start comparing local and remote configs ##";
            :local existedinterf [/interface wifiwave2 configuration find ssid=($conf->"ssid")];
            :local newSecProfile [$SyncSecProfile $conf];
            if ([:len [/interface wifiwave2 channel find]] = 0) do={
                :do {
                    /interface wifiwave2 channel add name=ch-2ghz frequency=2412,2432,2472 width=20mhz
                    /interface wifiwave2 channel add name=ch-5ghz frequency=5180,5260,5500 width=20/40/80mhz
                    :log debug "add name=ch-2ghz frequency=2412,2432,2472 width=20mhz add name=ch-5ghz frequency=5180,5260,5500 width=20/40/80mhz";
                } on-error={
                    :local existchnls [:tostr [/interface wifiwave2 channel print proplist=name,width as-value]];
                    :log error "faild to dual-band channels \n existing channels: $existchnls"
                }
            }
            if ([:len $existedinterf] = 0) do={
                # add new interface
                :local NewInterName ("ispapp_" . [$convertToValidFormat ($conf->"ssid")]);
                :log info "## add new interface -> $NewInterName ##";
                :local addConfig [:parse "/interface/wifiwave2/configuration add \\
                    ssid=(\$1->\"ssid\") \\
                    security=(\$1->\"newSecProfile\") \\
                    country=\"United States\" \\
                    manager=\"local\" \\
                    name=(\$1->\"NewInterName\");"];
                :local addInter [:parse "/interface/wifiwave2 add \\
                    disabled=no \\
                    channel=\$2 \\
                    configuration=(\$1->\"NewInterName\");"];
                :local newinterface ($conf + {"newSecProfile"=$newSecProfile; "NewInterName"=$NewInterName});
                :log debug ("new interface details \n" . [:tostr $newinterface]);
                :put [$addConfig $newinterface];
                :foreach i,k in=[/interface wifiwave2 channel print as-value] do={
                    # solution for muti bands 
                    :put [$addInter $newinterface ($k->"name")];
                }
                :put [/interface wifiwave2 enable $NewInterName];
                :delay 3s; # wait for interface to be created
                :log info "## wait for interface to be created 3s ##";
            } else={
                :local setInter [:parse "/interface/wifiwave2/configuration/set \$2 \\
                    ssid=(\$1->\"ssid\") \\
                    security=(\$1->\"newSecProfile\") \\
                    country=Latvia \\ 
                    name=(\$1->\"NewInterName\");"];
                # set the first interface to the new config
                :local newSecProfile [$SyncSecProfile $conf];
                :local NewInterName ("ispapp_" . [$convertToValidFormat ($conf->"ssid")]);
                :log info "## update new interface -> $NewInterName ##";
                [$setInter ($conf + {"newSecProfile"=$newSecProfile; "NewInterName"=$NewInterName}) ($existedinterf->0)];
                :delay 3s; # wait for interface to be setted
                :log info "## wait for interface to be created 3s ##";
                if ([:len $existedinterf] > 1) do={
                    # remove all interfaces except the first one
                    :foreach k,intfid in=$existedinterf do={
                        if ($k != 0) do={
                            /interface wifiwave2 configuration remove [/interface wifiwave2 configuration get $intfid name];
                            :delay 1s; # wait for interface to be removed
                        }
                    }
                }
            }
        }
        :local message ("syncronization of " . [:len $wirelessConfigs] . " interfaces completed");
        :log info $message;
        :set output {
            "status"=true;
            "message0"=$message;
            "configs"=$wirelessConfigs
        };
    }
    if ([$localwirelessConfigs]->"status" = true) do={
        ## start uploading local configs to host
        # item sended example from local: "{\"if\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"key\":\"$wIfKey\",\"keytypes\":\"$wIfKeyTypeString\"}"
        :log info "## wait for interfaces changes to be applied and can be retrieved from the device 5s ##";
        :delay 5s; # wait for interfaces changes to be applied and can be retrieved from the device
        :local InterfaceslocalConfigs;
        :local getconfiguration  [:parse "/interface wifiwave2 configuration print where name=\$1 as-value"];
        :local getsecurity  [:parse "/interface wifiwave2 security print where name=\$1 as-value"];
        :foreach k,wifiwave in=[/interface wifiwave2 print as-value] do={
            :local currentconfigs [$getconfiguration ($wifiwave->"configuration")]
            :local currentsec [$getsecurity ($wifiwave->"security")]
            :set ($InterfaceslocalConfigs->$k) {
                "if"=($wifiwave->"name");
                "ssid"=($currentconfigs->"ssid");
                "key"=($getsecurity->"passphrase");
                "technology"="wifiwave2";
                "manager"=($getsecurity->"manager");
                "security_profile"=($currentconfigs->"security")
            };
        };
        :local SecProfileslocalConfigs; 
        :foreach k,secprof in=[/interface wifiwave2 security print as-value] do={
            :local authtypes ($secprof->"authentication-types");
            :if ([:len $authtypes] = 0) do={ :set authtypes "[]";}
            :set ($SecProfileslocalConfigs->$k) {
                "name"=($secprof->"name");
                "authentication-types"=$authtypes;
                "technology"="wifiwave2";
                "passphrase"=($secprof->"passphrase");
                "connect-group"=($secprof->"connect-group");
                "owe-transition-interface"=($secprof->"owe-transition-interface")
            };
        };
        # i need a device with wifiwave2 active to finish this part.
        :local sentbody "{}";
        :local message ("uploading " . [:len $InterfaceslocalConfigs] . " interfaces to ispapp server");
        :if ([:len $InterfaceslocalConfigs] = 0) do={
            :set InterfaceslocalConfigs "[]";
        }
        :if ([:len $SecProfileslocalConfigs] = 0) do={
            :set SecProfileslocalConfigs "[]";
        }
        :global getAllConfigs;
        :global ispappHTTPClient;
        :set sentbody ([$getAllConfigs $InterfaceslocalConfigs $SecProfileslocalConfigs]->"json");
        :local returned  [$ispappHTTPClient m=post a=config b=$sentbody];
        :return ($output+{
            "status"=true;
            "body"=$sentbody;
            "responce"=$returned;
            "message1"=$message
        });
    } else={
        :log info "no local wifiwave interfaces found (from WifiwaveInterfacesConfigSync function in ispLibrary.rsc)";
        :return ($output+{
            "status"=true;
            "message1"="no wifiwave interfaces found"
        });
    }
} on-error={
    :return ($output+{
        "status"=false;
        "message1"="no wifiwave support found"
    });
}
};
# Function to collect all Caps manager interfaces and format them to be sent to server.
:global CapsConfigSync do={
    :global getAllConfigs;
    :global fillGlobalConsts;
    :global ispappHTTPClient;
    :local getConfig do={
        # get configuration from the server
        :do {
            :global ispappHTTPClient;
            :local res;
            :local i 0;
            :if ([$ispappHTTPClient m="get" a="update"]->"status" = false) do={
                :return { "responce"="firt time config of server error"; "status"=false };
            }
            :while ((any[:find [:tostr $res] "Err.Raise"] || !any$res) && $i < 3) do={
                :set res ([$ispappHTTPClient m="get" a="config"]->"parsed");
                :set i ($i + 1);
            }
            if (any [:find [:tostr $res] "Err.Raise"]) do={
                # check id json received is valid and redy to be used
                :log error "error while getting config (Err.Raise fJSONLoads)";
                :return {"status"=false; "message"="error while getting config (Err.Raise fJSONLoads)"};
            } else={
                :if ($res->"host"->"Authed" != true) do={
                    :log error [:tostr $res];
                    :return {"status"=false; "message"=$res};
                } else={
                    :log info "check id json received is valid and redy to be used with responce: $res";
                    :put [$fillGlobalConsts $res];
                    :return { "responce"=$res; "status"=true };
                }
            }
        } on-error={
            :log error "error while getting config (Err.Raise fJSONLoads)";
            :return {"status"=false; "message"="error while getting config"};
        }
    };
    :local getLocalWlans do={
        # collect all wireless interfaces from the system
        # format them to be sent to server
        :log info "start collect all wireless interfaces from the system ...";
        :local wlans [/caps-man configuration print proplist=disabled,security,channel,configuration as-value];
        if ([:len $wlans] > 0) do={
        :local wirelessConfigs;
        foreach i,intr in=$wlans do={
            :local cmdsectemp [:parse "/caps-man security print proplist=passphrase,authentication-types,name  as-value where  name=\$1"];
            :local cmdconftemp [:parse "/caps-man configuration print proplist=ssid,security  as-value where  name=\$1"];
            :local conftemp [$cmdconftemp ($intr->"configuration")];
            :local secTemp [$cmdsectemp ($conftemp->"security")];
            :local thisWirelessConfig {
                "encKey"=($secTemp->0->"passphrase");
                "encType"=($secTemp->0->"authentication-types");
                "ssid"=($conftemp->0->"ssid")
            };
            :set ($wirelessConfigs->$i) $thisWirelessConfig;
        }
        :log info "collect all wireless interfaces from the system";
        :return { "status"=true; "wirelessConfigs"=$wirelessConfigs };
        } else={
        :log info "collect all wireless interfaces from the system: no wireless interfaces found";
        :return { "status"=false; "message"="no wireless interfaces found" };
        }
    };
    :delay 1s;
    :log info "done setting local functions .... 1s"
    # check if our host is authorized to get configuration
    # and ready to accept interface syncronization
    :local configResponce [$getConfig];
    :local localwirelessConfigs [$getLocalWlans];
    :local output;
    :local wirelessConfigs [:toarray ""];
    :if ($configResponce->"status" = true) do={
        :set wirelessConfigs ($configResponce->"responce"->"host"->"wirelessConfigs");
    }
    :delay 1s;
    :log info "done setting wirelessConfigs .... 1s"
    if ([:len $wirelessConfigs] > 0) do={
        # this is the case when some interface configs received from the host
        # get security profile with same password as the one on first argument $1
        :global SyncSecProfile do={
            # add security profile if not found
            :do {
                :local key ($1->"encKey");
                :local tempName ("ispapp_" . ($1->"ssid"));
                # search for profile with this same password if exist if not just create it.
                :local currentprfpass [:parse "/caps-man security print as-value where passphrase=\$1"];
                # todo: separation of sec profiles ....
                :local foundSecProfiles [$currentprfpass $key]; # error 
                :log info "add security profile if not found: $tempName";
                if ([:len $foundSecProfiles] > 0) do={
                    :return ($foundSecProfiles->0->"name");
                } else={
                    :local addSec  [:parse "/caps-man security add \\
                        name=\$tempName \\
                        passphrase=(\$1->\"encKey\") \\
                        authentication-types=wpa2-psk,wpa-psk"];
                    :put [$addSec $1];
                    :return $tempName;
                }
            } on-error={
                # return the default dec profile in case of error
                # adding or updating to perform interface setup with no problems
                :return [/caps-man security get *0 name];
            }
        }
        :global convertToValidFormat;
        ## start comparing local and remote configs
        foreach conf in=$wirelessConfigs do={
            :log info "## start comparing local and remote configs ##";
            :local existedinterf [/caps-man/configuration/find ssid=($conf->"ssid")];
            :local newSecProfile [$SyncSecProfile $conf];
            if ([:len [/caps-man channel find]] = 0) do={
                :do {
                    :local set2ghz [:parse "/caps-man channel add name=ch-2ghz frequency=2412,2432,2472 control-channel-width=20mhz band=2ghz-b/g/n"]
                    :local set5ghz [:parse "/caps-man channel add name=ch-5ghz frequency=5180,5260,5500 control-channel-width=40mhz-turbo band=5ghz-a/n/ac"]
                    :put [$set2ghz]
                    :put [$set5ghz]
                    :log debug "add name=ch-2ghz frequency=2412,2432,2472 width=20mhz add name=ch-5ghz frequency=5180,5260,5500 width=20/40/80mhz";
                } on-error={
                    :log error "faild to dual-band channels caps"
                }
            }
            if ([:len $existedinterf] = 0) do={
                # add new interface
                :local NewInterName ("ispapp_" . [$convertToValidFormat ($conf->"ssid")]);
                :log info "## add new interface -> $NewInterName ##";
                :local addconfig [:parse "/caps-man configuration add \\
                    ssid=(\$1->\"ssid\") \\
                    security=(\$1->\"newSecProfile\") \\
                    name=(\$1->\"NewInterName\");"];
                :local addInter [:parse "/caps-man interface add \\
                    disabled=no \\
                    channel=\$2 \\
                    configuration=(\$1->\"NewInterName\");"];
                :foreach i,k in=[/caps-man channel print as-value] do={
                    # solution for muti bands 
                    :put [$addInter $newinterface ($k->"name")];
                }
                # Latvia added as default country for now...
                :local newinterface ($conf + {"newSecProfile"=$newSecProfile; "NewInterName"=$NewInterName});
                :log debug ("new interface details \n" . [:tostr $newinterface]);
                :put [$addconfig $newinterface];
                :put [/interface wifiwave2 enable $NewInterName];
                :delay 3s; # wait for interface to be created
                :log info "## wait for caps interface to be created 3s ##";
            } else={
                :local setInter [:parse "/caps-man configuration set \$2 \\
                    ssid=(\$1->\"ssid\") \\
                    security=(\$1->\"newSecProfile\") \\
                    name=(\$1->\"NewInterName\");"];
                # set the first interface to the new config
                :local newSecProfile [$SyncSecProfile $conf];
                :local NewInterName ("ispapp_" . [$convertToValidFormat ($conf->"ssid")]);
                :log info "## update new interface -> $NewInterName ##";
                [$setInter ($conf + {"newSecProfile"=$newSecProfile; "NewInterName"=$NewInterName}) ($existedinterf->0)];
                :delay 3s; # wait for interface to be setted
                :log info "## wait for interface to be created 3s ##";
                if ([:len $existedinterf] > 1) do={
                    # remove all interfaces except the first one
                    :foreach k,intfid in=$existedinterf do={
                        if ($k != 0) do={
                            :local ifnamebycfg [/caps-man configuration get $intfid name];
                            :local ifsecbycfg [/caps-man configuration get $intfid security];
                            if (any $ifnamebycfg) do={
                                /caps-man interface remove [/caps-man interface find configuration=$ifnamebycfg];
                                /caps-man configuration remove $intfid;
                                /caps-man security remove [/caps-man security find name=$ifsecbycfg];
                            }
                            :delay 1s; # wait for interface to be removed
                        }
                    }
                }
            }
        }
        :local message ("syncronization of " . [:len $wirelessConfigs] . " interfaces completed");
        :log info $message;
        :set output {
            "status"=true;
            "message0"=$message;
            "configs"=$wirelessConfigs
        };
    }
    if ([$localwirelessConfigs]->"status" = true) do={
        ## start uploading local configs to host
        # item sended example from local: "{\"if\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"key\":\"$wIfKey\",\"keytypes\":\"$wIfKeyTypeString\"}"
        :log info "## wait for interfaces changes to be applied and can be retrieved from the device 5s ##";
        :delay 5s; # wait for interfaces changes to be applied and can be retrieved from the device
        :local InterfaceslocalConfigs;
        :local getconfiguration  [:parse "/caps-man/configuration/print where name=\$1 as-value"];
        :local getsecurity  [:parse "/caps-man/security/print where name=\$1 as-value"];
        :foreach k,mancap in=[/caps-man interface print as-value] do={
            :local currentconfigs [$getconfiguration ($mancap->"configuration")]
            :local currentsec [$getsecurity ($currentconfigs->"security")]
            :set ($InterfaceslocalConfigs->$k) {
                "if"=($mancap->"name");
                "ssid"=($currentconfigs->"ssid");
                "key"=($getsecurity->"passphrase");
                "technology"="cap";
                "channel"=[:tostr ($mancap->"channel")];
                "security_profile"=($currentconfigs->"security")
            };
        };
        :local SecProfileslocalConfigs; 
        :foreach k,secprof in=[/caps-man/security print as-value] do={
            :local authtypes ($secprof->"authentication-types");
            :if ([:len $authtypes] = 0) do={ :set authtypes "[]";}
            :set ($SecProfileslocalConfigs->$k) {
                "name"=($secprof->"name");
                "authentication-types"=$authtypes;
                "wpa2-pre-shared-key"=($secprof->"passphrase");
                "technology"="cap";
                "wpa-pre-shared-key"=($secprof->"passphrase");
                "eap-methods"=($secprof->"eap-methods");
                "tls-mode"=($secprof->"tls-mode");
                "eap-radius-accounting"=($secprof->"eap-radius-accounting")
            };
        };
        # i need a device with wifiwave2 active to finish this part.
        :local sentbody "{}";
        :local message ("uploading " . [:len $InterfaceslocalConfigs] . "caps interfaces to ispapp server");
        :if ([:len $InterfaceslocalConfigs] = 0) do={
            :set InterfaceslocalConfigs "[]";
        }
        :if ([:len $SecProfileslocalConfigs] = 0) do={
            :set SecProfileslocalConfigs "[]";
        }
        :global getAllConfigs;
        :global ispappHTTPClient;
        :set sentbody ([$getAllConfigs $InterfaceslocalConfigs $SecProfileslocalConfigs]->"json");
        :local returned  [$ispappHTTPClient m=post a=config b=$sentbody];
        :return ($output+{
            "status"=true;
            "body"=$sentbody;
            "responce"=$returned;
            "message1"=$message
        });
    } else={
        :log info "no local caps interfaces found (from capsInterfacesConfigSync function in ispLibrary.rsc)";
        :return ($output+{
            "status"=true;
            "message1"="no caps interfaces found"
        });
    }
};
# Function to collect disks metrics
# usage: 
#       :put [$diskMetrics];
:global diskMetrics do={
    :local cout ({});
    :foreach i,disk in=[/disk find] do={
      :local diskName [/disk get $disk slot];
      :local diskFree [/disk get $disk free];
      :local diskSize [/disk get $disk size];
      :if ([:len $diskFree] = 0) do={
        :set diskFree 0;
      }
      :if ([:len $diskSize] = 0) do={
        :set diskSize 0;
      }
      :local diskUsed (($diskSize - $diskFree));
      # skip disks with no slot
      :if ([:len $diskName] > 0) do={
        :set ($cout->$i) {
            "mount"=$diskName;
            "used"=$diskUsed;
            "avail"=$diskFree
        };
      }
    }
    :return $cout;
}
# Function to collect partitions metrics
# usage: 
#       :put [$partitionsMetrics];
:global partitionsMetrics do={
    :local cout ({});
    :foreach i,part in=[/partitions find] do={
        :set ($cout->$i) {
            "name"=[/partitions get $part name];
            "fallback-to"=[/partitions get $part fallback-to];
            "version"=[/partitions get $part version]
            "running"=[/partitions get $part running]
            "active"=[/partitions get $part active]
            "size"=[/partitions get $part size]
        };
    }
    :return $cout;
}
:put "\t V3 Library loaded! (;";