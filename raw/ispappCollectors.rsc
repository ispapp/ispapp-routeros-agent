:global connectionFailures;
:global lteJsonString;
:global login;
:global collectorsRunning;
if ($collectorsRunning = true) do={
  :error "ispappCollectors is already running";
}
:set collectorsRunning true;
:global pingJsonString;

:global rosTsSec;

:local hasWirelessConfigurationMenu 0;
:local hasWifiwave2ConfigurationMenu 0;
:local hasCapsmanConfigurationMenu 0;

:do {
  :if ([:len [/interface wireless security-profiles find ]]>0) do={
    :set hasWirelessConfigurationMenu 1;
  }
} on-error={
  # no wireless
}

:do {
  :if ([:len [/interface wifiwave2 find ]]>0) do={
    :set hasWifiwave2ConfigurationMenu 1;
  }
} on-error={
  # no wifiwave2
}

:do {
  :if ([:len [/caps-man find ]]>0) do={
    :set hasCapsmanConfigurationMenu 1;
  }
} on-error={
  # no wifiwave2
}

#------------- Interface Collector-----------------

:local ifaceDataArray;
:local totalInterface ([/interface print as-value count-only]);
:local interfaceCounter 0;

:foreach iface in=[/interface find] do={

  :set interfaceCounter ($interfaceCounter + 1);

  :if ( [:len $iface] != 0 ) do={

    :local ifaceName [/interface get $iface name];
    :local rxBytes 0;
    :local rxPackets 0;
    :local rxErrors 0;
    :local rxDrops 0;
    :local txBytes 0;
    :local txPackets 0;
    :local txErrors 0;
    :local txDrops 0;
    :local cChanges 0;
    :local macs 0;

    :if ( [:len $ifaceName] !=0 ) do={

      # these all test the interface value first to maintain the variable value
      # as a number by leaving it as zero if there is no interface value

      :local rxBytesVal [/interface get $iface rx-byte];
      if ([:len $rxBytesVal]>0) do={
        :set rxBytes $rxBytesVal;
      }
      :local txBytesVal [/interface get $iface tx-byte];
      if ([:len $txBytesVal]>0) do={
        :set txBytes $txBytesVal;
      }

      :local rxPacketsVal [/interface get $iface rx-packet];
      if ([:len $rxPacketsVal]>0) do={
        :set rxPackets $rxPacketsVal;
      }
      :local txPacketsVal [/interface get $iface tx-packet];
      if ([:len $txPacketsVal]>0) do={
        :set txPackets $txPacketsVal
      }

      :local rxErrorsVal [/interface get $iface rx-error];
      if ([:len $rxErrorsVal]>0) do={
        :set rxErrors $rxErrorsVal;
      }
      :local txErrorsVal [/interface get $iface tx-error];
      if ([:len $txErrorsVal]>0) do={
        :set txErrors $txErrorsVal
      }

      :local rxDropsVal [/interface get $iface rx-drop];
      if ([:len $rxDropsVal]>0) do={
        :set rxDrops $rxDropsVal;
      }
      :local txDropsVal [/interface get $iface tx-drop];
      if ([:len $txDropsVal]>0) do={
        :set txDrops $txDropsVal;
      }

      :local cChangesVal [/interface get $iface link-downs];
      if ([:len $cChangesVal]>0) do={
        :set cChanges $cChangesVal;
      }

      :local macsVal [:len [/ip arp find where interface=$ifaceName]];
      if ([:len $macsVal]>0) do={
        :set macs $macsVal;
      }

      :if ($interfaceCounter != $totalInterface) do={
        # not last interface
        :local ifaceData "{\"if\":\"$ifaceName\",\"recBytes\":$rxBytes,\"recPackets\":$rxPackets,\"recErrors\":$rxErrors,\"recDrops\":$rxDrops,\"sentBytes\":$txBytes,\"sentPackets\":$txPackets,\"sentErrors\":$txErrors,\"sentDrops\":$txDrops,\"carrierChanges\":$cChanges,\"macs\":$macs},";
        :set ifaceDataArray ($ifaceDataArray.$ifaceData);
      }
      :if ($interfaceCounter = $totalInterface) do={
        # last interface
        :local ifaceData "{\"if\":\"$ifaceName\",\"recBytes\":$rxBytes,\"recPackets\":$rxPackets,\"recErrors\":$rxErrors,\"recDrops\":$rxDrops,\"sentBytes\":$txBytes,\"sentPackets\":$txPackets,\"sentErrors\":$txErrors,\"sentDrops\":$txDrops,\"carrierChanges\":$cChanges,\"macs\":$macs}";
        :set ifaceDataArray ($ifaceDataArray.$ifaceData);
      }
    }
  }
}
#------------- Wap Collector-----------------

:local wapArray;
:local wapCount 0;

if ($hasWirelessConfigurationMenu = 1) do={
  :foreach wIfaceId in=[/interface wireless find] do={

    :local wIfName ([/interface wireless get $wIfaceId name]);
    :local wIfSsid ([/interface wireless get $wIfaceId ssid]);

    # average the noise for the interface based on each connected station
    :local wIfNoise 0;
    :local wIfSig0 0;
    :local wIfSig1 0;

    #:put ("wireless interface $wIfName ssid: $wIfSsid");

    :local staJson;
    :local staCount 0;

    :foreach wStaId in=[/interface wireless registration-table find where interface=$wIfName] do={

      :local wStaMac ([/interface wireless registration-table get $wStaId mac-address]);

      :local wStaRssi ([/interface wireless registration-table get $wStaId signal-strength]);
      :set wStaRssi ([:pick $wStaRssi 0 [:find $wStaRssi "dBm"]]);
      :set wStaRssi ([:tonum $wStaRssi]);

      :local wStaNoise ([/interface wireless registration-table get $wStaId signal-to-noise]);
      :set wStaNoise ($wStaRssi - [:tonum $wStaNoise]);
      #:put "noise $wStaNoise"

      :local wStaSig0 ([/interface wireless registration-table get $wStaId signal-strength-ch0]);
      :set wStaSig0 ([:tonum $wStaSig0]);
      #:put "sig0 $wStaSig0"

      :local wStaSig1 ([/interface wireless registration-table get $wStaId signal-strength-ch1]);
      :set wStaSig1 ([:tonum $wStaSig1]);
      if ([:len $wStaSig1] = 0) do={
        :set wStaSig1 0;
      }
      #:put "sig1 $wStaSig1"

      :local wStaExpectedRate ([/interface wireless registration-table get $wStaId p-throughput]);
      :local wStaAssocTime ([/interface wireless registration-table get $wStaId uptime]);

      # convert the associated time to seconds
      :local assocTimeSplit [$rosTsSec $wStaAssocTime];
      :set wStaAssocTime $assocTimeSplit;

      # set the interface values
      :set wIfNoise ($wIfNoise + $wStaNoise);
      :set wIfSig0 ($wIfSig0 + $wStaSig0);
      :set wIfSig1 ($wIfSig1 + $wStaSig1);

      :local wStaIfBytes ([/interface wireless registration-table get $wStaId bytes]);
      :local wStaIfSentBytes ([:pick $wStaIfBytes 0 [:find $wStaIfBytes ","]]);
      :local wStaIfRecBytes ([:pick $wStaIfBytes 0 [:find $wStaIfBytes ","]]);

      :local wStaDhcpName ([/ip dhcp-server lease find where mac-address=$wStaMac]);

      if ($wStaDhcpName) do={
        :set wStaDhcpName ([/ip dhcp-server lease get $wStaDhcpName host-name]);
      } else={
        :set wStaDhcpName "";
      }

      #:put ("wireless station: $wStaMac $wStaRssi");

      :local newSta;

      if ($staCount = 0) do={
        :set newSta "{\"mac\":\"$wStaMac\",\"expectedRate\":$wStaExpectedRate,\"assocTime\":$wStaAssocTime,\"noise\":$wStaNoise,\"signal0\":$wStaSig0,\"signal1\":$wStaSig1,\"rssi\":$wStaRssi,\"sentBytes\":$wStaIfSentBytes,\"recBytes\":$wStaIfRecBytes,\"info\":\"$wStaDhcpName\"}";
      } else={
        :set newSta ",{\"mac\":\"$wStaMac\",\"expectedRate\":$wStaExpectedRate,\"assocTime\":$wStaAssocTime,\"noise\":$wStaNoise,\"signal0\":$wStaSig0,\"signal1\":$wStaSig1,\"rssi\":$wStaRssi,\"sentBytes\":$wStaIfSentBytes,\"recBytes\":$wStaIfRecBytes,\"info\":\"$wStaDhcpName\"}";
      }

      :set staJson ($staJson.$newSta);

      :set staCount ($staCount + 1);

    }

    :if ($staCount > 0) do={
      #:put "averaging noise, $wIfNoise / $staCount";
      :set wIfNoise ($wIfNoise / $staCount);
    }

    #:put "if noise: $wIfNoise";

    :if ($wIfSig0 != 0) do={
      #:put "averaging sig0, $wIfSig0 / $staCount";
      :set wIfSig0 ($wIfSig0 / $staCount);
    }

    :if ($wIfSig1 != 0) do={
      #:put "averaging sig0, $wIfSig1 / $staCount";
      :set wIfSig1 ($wIfSig1 / $staCount);
    }

    :local newWapIf;

    if ($wapCount = 0) do={
      :set newWapIf "{\"stations\":[$staJson],\"interface\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"noise\":$wIfNoise,\"signal0\":$wIfSig0,\"signal1\":$wIfSig1}";
    } else={
      :set newWapIf ",{\"stations\":[$staJson],\"interface\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"noise\":$wIfNoise,\"signal0\":$wIfSig0,\"signal1\":$wIfSig1}";
    }

    :set wapCount ($wapCount + 1);

    :set wapArray ($wapArray.$newWapIf);

  }

}

if ($hasWifiwave2ConfigurationMenu = 1) do={

  :foreach wIfaceId in=[/interface wifiwave2 find] do={

    :local wIfName ([/interface wifiwave2 get $wIfaceId name]);
    :local wIfSsid ([/interface wifiwave2 get $wIfaceId configuration.ssid]);

    # average the noise for the interface based on each connected station
    :local wIfNoise 0;
    :local wIfSig0 0;
    :local wIfSig1 0;

    #:put ("wifiwave2 interface $wIfName ssid: $wIfSsid");

    :local staJson;
    :local staCount 0;

    :foreach wStaId in=[/interface wifiwave2 registration-table find where interface=$wIfName] do={

      :local wStaMac ([/interface wifiwave2 registration-table get $wStaId mac-address]);

      :local wStaRssi ([/interface wifiwave2 registration-table get $wStaId signal]);
      :set wStaRssi ([:tonum $wStaRssi]);

      :local wStaAssocTime ([/interface wifiwave2 registration-table get $wStaId uptime]);

      # convert the associated time to seconds
      :local assocTimeSplit [$rosTsSec $wStaAssocTime];
      :set wStaAssocTime $assocTimeSplit;

      :local wStaIfBytes ([/interface wifiwave2 registration-table get $wStaId bytes]);
      :local wStaIfSentBytes ([:pick $wStaIfBytes 0 [:find $wStaIfBytes ","]]);
      :local wStaIfRecBytes ([:pick $wStaIfBytes 0 [:find $wStaIfBytes ","]]);

      :local wStaDhcpName ([/ip dhcp-server lease find where mac-address=$wStaMac]);

      if ($wStaDhcpName) do={
        :set wStaDhcpName ([/ip dhcp-server lease get $wStaDhcpName host-name]);
      } else={
        :set wStaDhcpName "";
      }

      #:put ("wifiwave2 station: $wStaMac $wStaRssi");

      :local newSta;

      if ($staCount = 0) do={
        :set newSta "{\"mac\":\"$wStaMac\",\"assocTime\":$wStaAssocTime,\"rssi\":$wStaRssi,\"sentBytes\":$wStaIfSentBytes,\"recBytes\":$wStaIfRecBytes,\"info\":\"$wStaDhcpName\"}";
      } else={
        :set newSta ",{\"mac\":\"$wStaMac\",\"assocTime\":$wStaAssocTime,\"rssi\":$wStaRssi,\"sentBytes\":$wStaIfSentBytes,\"recBytes\":$wStaIfRecBytes,\"info\":\"$wStaDhcpName\"}";
      }

      :set staJson ($staJson.$newSta);

      :set staCount ($staCount + 1);

    }

    :local newWapIf;

    if ($wapCount = 0) do={
      :set newWapIf "{\"stations\":[$staJson],\"interface\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"noise\":$wIfNoise,\"signal0\":$wIfSig0,\"signal1\":$wIfSig1}";
    } else={
      :set newWapIf ",{\"stations\":[$staJson],\"interface\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"noise\":$wIfNoise,\"signal0\":$wIfSig0,\"signal1\":$wIfSig1}";
    }

    :set wapCount ($wapCount + 1);

    :set wapArray ($wapArray.$newWapIf);

  }

}

if ($hasCapsmanConfigurationMenu = 1) do={
  #------------- caps-man Collector-----------------

  :foreach wIfaceId in=[/caps-man interface find] do={

    :local wIfName ([/caps-man interface get $wIfaceId name]);
    :local wIfConfName ([/caps-man interface get $wIfName configuration]);
    :local wIfSsid ([/caps-man configuration get $wIfConfName ssid]);

    # average the noise for the interface based on each connected station
    :local wIfNoise 0;
    :local wIfSig0 0;
    :local wIfSig1 0;

    #:put ("caps-man interface $wIfName ssid: $wIfSsid");

    :local staJson;
    :local staCount 0;

    :foreach wStaId in=[/caps-man registration-table find where interface=$wIfName] do={

      :local wStaMac ([/caps-man registration-table get $wStaId mac-address]);
      #:put "station mac: $wStaMac";

      :local wStaRssi ([/caps-man registration-table get $wStaId signal-strength]);
      :set wStaRssi ([:pick $wStaRssi 0 [:find $wStaRssi "dBm"]]);
      :set wStaRssi ([:tonum $wStaRssi]);

      :local wStaNoise ([/caps-man registration-table get $wStaId signal-to-noise]);
      :set wStaNoise ($wStaRssi - [:tonum $wStaNoise]);
      #:put "noise $wStaNoise"

      :local wStaSig0 ([/caps-man registration-table get $wStaId signal-strength-ch0]);
      :set wStaSig0 ([:tonum $wStaSig0]);
      #:put "sig0 $wStaSig0"

      :local wStaSig1 ([/caps-man registration-table get $wStaId signal-strength-ch1]);
      :set wStaSig1 ([:tonum $wStaSig1]);
      if ([:len $wStaSig1] = 0) do={
        :set wStaSig1 0;
      }
      #:put "sig1 $wStaSig1"

      :local wStaExpectedRate ([/caps-man registration-table get $wStaId p-throughput]);
      :local wStaAssocTime ([/caps-man registration-table get $wStaId uptime]);

      # convert the associated time to seconds
      :local assocTimeSplit [$rosTsSec $wStaAssocTime];
      :set wStaAssocTime $assocTimeSplit;

      # set the interface values
      :set wIfNoise ($wIfNoise + $wStaNoise);
      :set wIfSig0 ($wIfSig0 + $wStaSig0);
      :set wIfSig1 ($wIfSig1 + $wStaSig1);

      :local wStaIfBytes ([/caps-man registration-table get $wStaId bytes]);
      :local wStaIfSentBytes ([:pick $wStaIfBytes 0 [:find $wStaIfBytes ","]]);
      :local wStaIfRecBytes ([:pick $wStaIfBytes 0 [:find $wStaIfBytes ","]]);

      :local wStaDhcpName ([/ip dhcp-server lease find where mac-address=$wStaMac]);

      if ($wStaDhcpName) do={
        :set wStaDhcpName ([/ip dhcp-server lease get $wStaDhcpName host-name]);
      } else={
        :set wStaDhcpName "";
      }

      #:put ("caps-man station: $wStaMac $wStaRssi");
      #:put ("bytes: $wStaIfSentBytes $wStaIfRecBytes");
      #:put ("dhcp lease host-name: $wStaDhcpName");

      :local newSta;

      if ($staCount = 0) do={
        :set newSta "{\"mac\":\"$wStaMac\",\"expectedRate\":$wStaExpectedRate,\"assocTime\":$wStaAssocTime,\"noise\":$wStaNoise,\"signal0\":$wStaSig0,\"signal1\":$wStaSig1,\"rssi\":$wStaRssi,\"sentBytes\":$wStaIfSentBytes,\"recBytes\":$wStaIfRecBytes,\"info\":\"$wStaDhcpName\"}";
      } else={
        :set newSta ",{\"mac\":\"$wStaMac\",\"expectedRate\":$wStaExpectedRate,\"assocTime\":$wStaAssocTime,\"noise\":$wStaNoise,\"signal0\":$wStaSig0,\"signal1\":$wStaSig1,\"rssi\":$wStaRssi,\"sentBytes\":$wStaIfSentBytes,\"recBytes\":$wStaIfRecBytes,\"info\":\"$wStaDhcpName\"}";
      }

      :set staJson ($staJson.$newSta);

      :set staCount ($staCount + 1);

    }

    :if ($staCount > 0) do={
      #:put "averaging noise, $wIfNoise / $staCount";
      :set wIfNoise (-$wIfNoise / $staCount);
    }

    #:put "if noise: $wIfNoise";

    :if ($wIfSig0 != 0) do={
      #:put "averaging sig0, $wIfSig0 / $staCount";
      :set wIfSig0 ($wIfSig0 / $staCount);
    }

    :if ($wIfSig1 != 0) do={
      #:put "averaging sig0, $wIfSig1 / $staCount";
      :set wIfSig1 ($wIfSig1 / $staCount);
    }

    :local newWapIf;

    if ($wapCount = 0) do={
      :set newWapIf "{\"stations\":[$staJson],\"interface\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"noise\":$wIfNoise,\"signal0\":$wIfSig0,\"signal1\":$wIfSig1}";
    } else={
      :set newWapIf ",{\"stations\":[$staJson],\"interface\":\"$wIfName\",\"ssid\":\"$wIfSsid\",\"noise\":$wIfNoise,\"signal0\":$wIfSig0,\"signal1\":$wIfSig1}";
    }

    :set wapCount ($wapCount + 1);

    :set wapArray ($wapArray.$newWapIf);

  }

}

#----- lte -----

  # add the lte interfaces to the wapArray json if they exist
  if ([:len $lteJsonString] > 0) do={
    if ([:len $wapArray] = 0) do={
      :set wapArray ($lteJsonString);
    } else={
      :set wapArray ($wapArray . "," . $lteJsonString);
    }
  }

  #:put $wapArray;

#------------- System Collector-----------------

:global cpuLoad;
if ([:len $cpuLoad] = 0) do={
  :set cpuLoad 0;
}

# memory

:local totalMem 0;
:local freeMem 0;
:local memBuffers 0;
:local cachedMem 0;
:set totalMem ([/system resource get total-memory])
:set freeMem ([/system resource get free-memory])
:set memBuffers 0

# disks

:local diskJsonString "";
:do {

:foreach disk in=[/disk find] do={

  :local diskName "";
  :local diskFree 0;
  :local diskSize 0;
  :local diskUsed 0;

  :if ($totalDisks != 0) do={
    :set diskName [/disk get $disk slot];
    :set diskFree [/disk get $disk free];
    :set diskSize [/disk get $disk size];
    :if ([:len $diskFree] = 0) do={
      :set diskFree 0;
    }
    :if ([:len $diskSize] = 0) do={
      :set diskSize 0;
    }
    :set diskUsed (($diskSize - $diskFree));
  }

  :if ([:len $diskName] > 0) do={
    :local diskData "{\"mount\":\"$diskName\",\"used\":$diskUsed,\"avail\":$diskFree},";
    :set diskJsonString ($diskJsonString.$diskData);
  }
}
:if ([:len $diskJsonString] > 0) do={
  # remove last character from diskJsonString
  :set diskJsonString [:pick $diskJsonString 0 ([:len $diskJsonString] - 1)];
}
} on-error={
  # no /disk (smips devices)
}

:local processCount [:len [/system script job find]];
:local systemArray "{\"load\":{\"one\":$cpuLoad,\"five\":$cpuLoad,\"fifteen\":$cpuLoad,\"processCount\":$processCount},\"memory\":{\"total\":$totalMem,\"free\":$freeMem,\"buffers\":$memBuffers,\"cached\":$cachedMem},\"disks\":[$diskJsonString],\"connDetails\":{\"connectionFailures\":$connectionFailures}}";

:do {
  # count the number of dhcp leases
  :set dhcpLeaseCount [:len [/ip dhcp-server lease find]];
  # add IPv6 leases
  :set dhcpLeaseCount ($dhcpLeaseCount + [:len [/ipv6 address find]]);
} on-error={
  :set dhcpLeaseCount $dhcpLeaseCount;
}

:global collectUpDataVal "{\"ping\":[$pingJsonString],\"wap\":[$wapArray], \"interface\":[$ifaceDataArray],\"system\":$systemArray,\"gauge\":[{\"name\":\"Total DHCP Leases\",\"point\":$dhcpLeaseCount}]}";
:set collectorsRunning false;