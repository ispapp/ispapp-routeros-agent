#:log info ("ispappAvgCpuCollector");

:global cpuLoad;
:global cpuLoadArray;

if ([:len cpuLoadCount] = 0) do={
  # set empty cpuLoadArray
  :set cpuLoadArray [:toarray ""];
}

if ([:len $cpuLoadArray] >= 15) do={
  # 15 iterations at 4 seconds is 1 minute
  :local cpuLoadTotal 0;
  foreach cpuLoadReading in $cpuLoadArray do={
    :set cpuLoadTotal ($cpuLoadTotal + $cpuLoadReading);
  }

  # set the 1m load
  :set cpuLoad ($cpuLoadTotal / [:len $cpuLoadArray]);
  # empty the array
  :set cpuLoadArray [:toarray ""];
}

:set cpuLoadArray ($cpuLoadArray, [/system resource get cpu-load]);

#:log info ("cpuLoadArray", $cpuLoadArray);

# run this script again
:delay 4s;
:execute {/system script run ispappAvgCpuCollector};
:error "ispappAvgCpuCollector iteration complete";