/system script add dont-require-permissions=yes name=ispappUpdate owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
# communication script with update endpoint
:global sendUpdate;
# Check if Console thread busy; if not we run new Console instance;
:if ([:len [/system/script/job/find script=\"ispappUpdate\"]] = 0 ) do={
  :if(any\$sendUpdate) do={
    :local updates [\$sendUpdate];
    :put \$updates;
  } else={
    :log error \"Library v4 is not loaded! (not sendUpdate found)\"
  }
}"