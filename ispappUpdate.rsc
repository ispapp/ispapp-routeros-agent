/system script add dont-require-permissions=yes name=ispappUpdate owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
# communication script with update endpoint
:global sendUpdate;
:global isUpdatebusy;
# Check if Update thread busy if not we run new Update instance;
if (!any\$isUpdatebusy) do={
  :set isUpdatebusy true;
}
:if (\$isUpdatebusy = false) do={
  :if (any\$sendUpdate) do={
    :do {
      :local updates [\$sendUpdate];
      :if (\$updates->\"status\") do={
        :put \"sendUpdate done :) with output:\\n\\r \$updates\";
      } else={
        :put \"sendUpdate was not successful :(\";
        :log error \"sendUpdate was not successful :(\";
      }
    } on-error={
      :put \"sendUpdate error!\";
      :log error \"sendUpdate error! :(\";
    }
  } else={
    :put \"Library v4 is not loaded! (not sendUpdate found)\";
    :log error \"Library v4 is not loaded! (not sendUpdate found)\";
  }
} else={
    :put \"update thread id busy ....\";
}
:set isUpdatebusy false;"