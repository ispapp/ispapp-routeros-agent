:put "Diagnosing ISPApp Connection\n";

# include functions
:global rosTsSec;
:global Split;

:global login;
:global topDomain;
:global topKey;
:global topListenerPort;
:global urlEncodeFunct;

:global collectUpDataVal;
:if ([:len $collectUpDataVal] = 0) do={
  :set collectUpDataVal "{}";
}

# WAN Port IP Address
:global wanIP;
:do {

  :local gatewayStatus ([:tostr [/ip route get [:pick [find dst-address=0.0.0.0/0 active=yes] 0] gateway-status]]);

  #:put "gatewayStatus: $gatewayStatus";

  # split the gateway status into
  # IP/NM, reachable status, via, interface
  :local gwStatusArray [$Split $gatewayStatus " "];
  #:put "$gwStatusArray";

  # get ip address and netmask as IP/Netmask
  :local tempIpv4String [/ip address get [:pick [/ip address find interface=($gwStatusArray->3)] 0] address];
  # split by /
  :local wanIpv4Arr [$Split $tempIpv4String "/"];
  # set the wan ip
  :set wanIP ($wanIpv4Arr->0);

} on-error={
  :set wanIP "";
  #:log info ("Error finding WAN IP.");
}

:local upTime [/system resource get uptime];
:local upSeconds [$rosTsSec $upTime];

# config request without full data

:local configUrl ("https://" . $topDomain . ":" . $topListenerPort . "/update?login=" . $login . "&key=" . $topKey);

:put ("\nMaking HTTP GET config request without body data to: " . $configUrl . "\n");

:local configResponse;

:do {
    :set configResponse ([/tool fetch check-certificate=yes mode=https http-method=get url=$configUrl as-value output=user]);

} on-error={
  :put ("HTTP Error, no response for /config request to ISPApp.");
  :error "HTTP error with /config request, no response received.";
}

:put ("ISPApp Listener responded with:")
:put ($configResponse);

# config request with full data

:local collectUpData "{}";

:local configUrl ("https://" . $topDomain . ":" . $topListenerPort . "/update?login=" . $login . "&key=" . $topKey);

:put ("\nMaking HTTP POST config request with body data to: " . $configUrl . "\n");

:put ("HTTP POST Request Data:");
:put ($collectUpData . "\n");

:local configResponse;

:do {
    :set configResponse ([/tool fetch check-certificate=yes mode=https http-method=post http-header-field="cache-control: no-cache, content-type: application/json" http-data="$collectUpData" url=$configUrl as-value output=user]);

} on-error={
  :put ("HTTP Error, no response for /config request to ISPApp, sent " . [:len $collectUpData] . " bytes.");
  :error "HTTP error with /config request, no response received.";
}

:put ("ISPApp Listener responded with:")
:put ($configResponse);

# update request without full data

:local updateUrl ("https://" . $topDomain . ":" . $topListenerPort . "/update?login=" . $login . "&key=" . $topKey);

:put ("\nMaking HTTP GET update request without body data to: " . $updateUrl . "\n");

:local updateResponse;

:do {
    :set updateResponse ([/tool fetch check-certificate=yes mode=https http-method=get url=$updateUrl as-value output=user]);

} on-error={
  :put ("HTTP Error, no response for /update request to ISPApp.");
  :error "HTTP error with /update request, no response received.";
}

:put ("ISPApp Listener responded with:")
:put ($updateResponse);

# update request with full data

:local collectUpData "{\"collectors\":$collectUpDataVal,\"wanIp\":\"$wanIP\",\"uptime\":$upSeconds}";

:local updateUrl ("https://" . $topDomain . ":" . $topListenerPort . "/update?login=" . $login . "&key=" . $topKey);

:put ("\nMaking HTTP POST update request with body data to: " . $updateUrl . "\n");

:put ("HTTP POST Request Data:");
:put ($collectUpData . "\n");

:local updateResponse;

:do {
    :set updateResponse ([/tool fetch check-certificate=yes mode=https http-method=post http-header-field="cache-control: no-cache, content-type: application/json" http-data="$collectUpData" url=$updateUrl as-value output=user]);

} on-error={
  :put ("HTTP Error, no response for /update request to ISPApp, sent " . [:len $collectUpData] . " bytes.");
  :error "HTTP error with /update request, no response received.";
}

:put ("ISPApp Listener responded with:")
:put ($updateResponse);