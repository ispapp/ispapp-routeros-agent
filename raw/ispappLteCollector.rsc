# if LTE logging is too verbose, disable it in your router's configuration
# /system logging print
# 4     lte       support
# /system logging disable 4

:global Split;

:global lteJsonString;

#------------- Lte Collector-----------------

:local lteArray;
:local lteCount 0;

:foreach lteIfaceId in=[/interface lte find] do={

  :local lteIfName ([/interface lte get $lteIfaceId name]);
  #:put "lte interface name: $lteIfName";

  #:local lteIfDetail [/interface lte print detail as-value where name=$lteIfName];
  #:put ("lteIfDetail: ") . ($lteIfDetail->0);

  # send at-chat to the modem
  :local lteAt0 [:tostr  [/interface lte at-chat $lteIfName input "AT+CSQ" as-value]];
  #:put $lteAt0;

  :local lteAt0Arr [$Split $lteAt0 "\n"];
  #:put ($lteAt0Arr->0);

  :local snrArr [$Split ($lteAt0Arr->0) " "];
  # split the signal and the bit error rate by the comma
  :local sber [$Split ($snrArr->1) ","];
  :local signal [:tonum ($sber->0)];

  # convert the value to rssi
  # 2 equals -109
  # each value above 2 adds -2 and -109
  :local s ($signal - 2);
  :set s ($s * 2);
  :set signal ($s + -109)

  #:put "signal: $signal";

  :local lteAt1 [:tostr  [/interface lte at-chat $lteIfName input "AT+COPS?" as-value]];
  #:put $lteAt1;

  # if ERROR is in this string, then routeros' LTE is broken (happens often)
  :local mnc;
  if ([:find $lteAt1 "ERROR"] > -1) do={
    :log info "$lteIfName not connected";
  } else={
    # get the network name, at least the MNC (Mobile Network Code)
    :local mncArray [$Split $lteAt1 ","];
    # remove the first " because \" cannot be passed to Split due to the routeros scripting language bug
    :set mnc [:pick ($mncArray->2) 1 [:len ($mncArray->2)]];
    # remove the last "
    :set mnc [:pick $mnc 0 ([:len $mnc] - 1)];
    #:put "MNC: $mnc";
  }

  if ($lteCount = 0) do={
    :set lteJsonString ("{\"stations\":[],\"interface\":\"$lteIfName\",\"ssid\":\"$mnc\",\"signal0\":$signal}");
  } else={
    :set lteJsonString ($lteJsonString . "," . ",{\"stations\":[],\"interface\":\"$lteIfName\",\"ssid\":\"$mnc\",\"signal0\":$signal}");
  }

  :set lteCount ($lteCount + 1);

}

#:log info ("ispappLteCollector");

# run this script again
:delay 10s;
:execute {/system script run ispappLteCollector};
:error "ispappLteCollector iteration complete";