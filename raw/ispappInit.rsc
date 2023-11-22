# keep track of the number of update retries
:global updateSequenceNumber 0;
:global connectionFailures 0;

# track status since init for these booleans
:global configScriptSuccessSinceInit false;
:global updateScriptSuccessSinceInit false;
:do {
     /system script run ispappConfig;
} on-error={
  :log info ("ispappConfig script error.");
}
:do {
  # this runs without a scheduler, because LTE modems use serial communications and often pending activity blocks data collection
  /system script run ispappCollectors;
} on-error={
  :log info ("ispappLteCollector script error.");
}

/system scheduler enable ispappCollectors;
/system scheduler enable ispappInit;