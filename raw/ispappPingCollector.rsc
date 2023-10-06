#------------- Ping Collector-----------------

:local tempPingJsonString "";
:local pingHosts [:toarray ""];
:global topDomain;
:set ($pingHosts->0) "$topDomain";

:for pc from=0 to=([:len $pingHosts]-1) step=1 do={
  #:put ("pinging host $pc " . $pingHosts->$pc);

  :if ($pc > 0) do={
    :set tempPingJsonString ($tempPingJsonString . ",");
  }

  :local avgRtt 0;
  :local minRtt 0;
  :local maxRtt 0;
  :local toPingDomain ($pingHosts->$pc);
  :local totalpingsreceived 0;
  :local totalpingssend 5;

  :do {
    /tool flood-ping count=$totalpingssend size=64 address=[:resolve $toPingDomain] do={
      :set totalpingsreceived ($"received");
      :set avgRtt ($"avg-rtt");
      :set minRtt ($"min-rtt");
      :set maxRtt ($"max-rtt");
    }
  } on-error={
    #:put ("TOOL FLOOD_PING ERROR=====>>> ");
 }

:local calculateAvgRtt 0;
:local calculateMinRtt 0;
:local calculateMaxRtt 0;
:local percentage 0;
:local packetLoss 0;

:set calculateAvgRtt ([:tostr ($avgRtt)]);
#:put ("avgRtt: ".$calculateAvgRtt);

:set calculateMinRtt ([:tostr ($minRtt)]);
#:put ("minRtt: ".$calculateMinRtt);

:set calculateMaxRtt ([:tostr ($maxRtt)]);
#:put ("maxRtt: ".$calculateMaxRtt);

# sent must be less than 100
# just use uintmax but they aren't normal in this language
:local oneStepPercent (100 / $totalpingssend);

:local percentage 0;
for i from=0 to=($totalpingssend-1) do={
  if ($i < $totalpingsreceived) do={
    :set percentage ($percentage + $oneStepPercent);
  }
}

:set percentage (100 - $percentage);
:set tempPingJsonString ($tempPingJsonString . "{\"host\":\"$toPingDomain\",\"avgRtt\":$calculateAvgRtt,\"loss\":$percentage,\"minRtt\":$calculateMinRtt,\"maxRtt\":$calculateMaxRtt}");

}
:global pingJsonString $tempPingJsonString;
