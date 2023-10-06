
do={
    # remove scripts
    if (!any $removeIspappScripts){
        $removeIspappScripts;
    }
    # remove schedulers
    if (!any $removeIspappSchedulers){
        $removeIspappSchedulers;
    }
} on-error{
    :put "\E2\9D\8C ispappLibrary not loaded try reset the agent";
    :log error "\E2\9D\8C ispappLibrary not loaded try reset the agent";
}
# remove environment variables
foreach envVarId in=[/system script environment find] do={
  /system script environment remove $envVarId;
}
# maintain only one running instance of these scripts
foreach j in=[/system script job find] do={
  :local scriptName [/system script job get $j script];
  if ($scriptName = "ispappLteCollector") do={
    /system script job remove $j;
  }
  if ($scriptName = "ispappAvgCpuCollector") do={
    /system script job remove $j;
  }
}