# remove existing ispapp configuration
:local hasWirelessConfigurationMenu 0;
:local hasWifiwave2ConfigurationMenu 0;

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

if ($hasWirelessConfigurationMenu = 1) do={

  # remove existing ispapp security profiles
  :foreach wSpId in=[/interface wireless security-profiles find] do={

   :local wSpName ([/interface wireless security-profiles get $wSpId name]);
   :local isIspappSp ([:find $wSpName "ispapp-"]);

   if ($isIspappSp = 0) do={
     # remove existing ispapp security profile
     /interface wireless security-profiles remove $wSpName;
   }

  }

  # remove existing ispapp vaps and bridge ports
  :foreach wIfaceId in=[/interface wireless find] do={

   :local wIfName ([/interface wireless get $wIfaceId name]);
   :local wIfSsid ([/interface wireless get $wIfaceId ssid]);
   :local isIspappIf ([:find $wIfName "ispapp-"]);
   :local wIfType ([/interface wireless get $wIfaceId interface-type]);
   :local wComment ([/interface wireless get $wIfaceId comment]);

   if ($wIfType != "virtual" && $wComment = "ispapp") do={
     :do {
       # set the comment to "" on the physical interface to know it was not configured by ispapp
       /interface wireless set comment="" $wIfaceId;
     } on-error={
     }
   }

   if ($isIspappIf = 0) do={
     #:put "deleting virtual ispapp interface: $wIfName";
     /interface wireless remove $wIfName;
   }

  }

}

if ($hasWifiwave2ConfigurationMenu = 1) do={
  :foreach wIfaceId in=[/interface wifiwave2 find] do={

    :local wIfName ([/interface wifiwave2 get $wIfaceId name]);
    :local wIfMasterIf ([/interface wifiwave2 get $wIfaceId master-interface]);
    :local wIfComment ([/interface wifiwave2 get $wIfaceId comment]);

    if ([:len $wIfMasterIf] = 0) do={
      # this is a physical interface
      :do {
       # set the comment to "" on the physical interface to know it was not configured by ispapp
       /interface wifiwave2 set comment="" $wIfaceId;
     } on-error={
     }
      
    } else={
      # this is not a physical interface
      if ($wIfComment = "ispapp") do={
        # remove this virtual ispapp wifiwave2 interface
        /interface wifiwave2 remove $wIfaceId;
      }
    }

  }
  }