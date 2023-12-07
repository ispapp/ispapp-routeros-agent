/system script add dont-require-permissions=yes name=ispappCollectors owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
:global connectionFailures;
:global getCollections;
:global collectorsRunning;
:global collectUpDataVal;
if (\$collectorsRunning = true) do={
  :error \"ispappCollectors is already running\";
}
:set collectorsRunning true;
# cpu metric is the only thing that need continous refresh to fill cpu loads array
# other than that the function get fresh data at execution.
:set collectUpDataVal [\$getCollections];
# temporary lines ->
:set collectUpDataVal [\$toJson \$collectUpDataVal];
:set collectUpDataVal [:pick  1 ([:len \$collectUpDataVal] - 1)];
# temporary lines <-
:set collectorsRunning false;"