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
/system scheduler enable ispappInit;