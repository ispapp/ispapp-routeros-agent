:global connectionFailures;
:global getCollections;
:global collectorsRunning;
:global collectUpDataVal;
if ($collectorsRunning = true) do={
  :error "ispappCollectors is already running";
}
:set collectorsRunning true;
# cpu metric is the only thing that need continous refresh to fill cpu loads array
# other than that the function get fresh data at execution.
:set collectUpDataVal [$getCollections];
:set collectorsRunning false;