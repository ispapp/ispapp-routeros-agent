/system script add dont-require-permissions=yes name=ispappInit owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
# keep track of the number of update retries
:global updateSequenceNumber 0;
:global connectionFailures 0;

# track status since init for these booleans
:global configScriptSuccessSinceInit false;
:global updateScriptSuccessSinceInit false;
:do {
     /system script run ispappConfig;
} on-error={
  :log info (\"ispappConfig script error.\");
}
:do {
     /system script run ispappConsole;
} on-error={
  :log info (\"ispappConfig script error.\");
}
:do {
  # this runs without a scheduler, because LTE modems use serial communications and often pending activity blocks data collection
  /system script run ispappCollectors;
} on-error={
  :log info (\"ispappLteCollector script error.\");
}
/system scheduler enable ispappInit;"