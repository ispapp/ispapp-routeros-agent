# Function to collect pinging stats from device to $topdomain;
:global getPingingMetrics do={
    :global topDomain;
    :local avgRtt 0;
    :local minRtt 0;
    :local maxRtt 0;
    :local totalpingsreceived 0;
    :local totalpingssend 5;
    :do {
        :local res [/tool flood-ping count=5 size=64 address=[:resolve $topDomain] as-value];
        :set totalpingsreceived ($res->"received");
        :set avgRtt ($res->"avg-rtt");
        :set minRtt ($res->"min-rtt");
        :set maxRtt ($res->"max-rtt");
    } on-error={
      :put ("TOOL FLOOD_PING ERROR");
    }
    :local oneStepPercent (100 / $totalpingssend);
    :local percentage 0;
    for i from=0 to=($totalpingssend-1) do={
      if ($i < $totalpingsreceived) do={
        :set percentage ($percentage + $oneStepPercent);
      }
    }
    :set percentage (100 - $percentage);
    :return ({
        "host"="$topDomain";
        "avgRtt"=([:tostr $avgRtt]);
        "loss"=$percentage;
        "minRtt"=([:tostr $minRtt]);
        "maxRtt"=([:tostr $maxRtt])
    });
}
# Function to join all collectect metrics
:global getCollections do={
    :local cout ({});
    :global getSystemMetrics;
    :global wapCollector;
    :global collectInterfacesMetrics;
    :global getCpuLoads;
    :local wapArray [$wapCollector];
    :local dhcpLeaseCount 0;
    :local systemArray [$getSystemMetrics];
    :local ifaceDataArray [$collectInterfacesMetrics];
    :local pings [$getPingingMetrics];
    :do {
        # count the number of dhcp leases
        :set dhcpLeaseCount [:len [/ip dhcp-server lease find]];
        # add IPv6 leases
        :set dhcpLeaseCount ($dhcpLeaseCount + [:len [/ipv6 address find]]);
    } on-error={
        :set dhcpLeaseCount $dhcpLeaseCount;
    }
    :set cout {
        "ping"=[$pings];
        "wap"=[$wapArray];
        "interface"=[$ifaceDataArray];
        "system"=$systemArray;
        "gauge"=({"name"="Total DHCP Leases"; "point"=$dhcpLeaseCount})
        };
    :set cout [$toJson $cout]
    :return $cout;
};
:put "\t V4 Library loaded! (;";