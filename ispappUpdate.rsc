/system script add dont-require-permissions=yes name=ispappUpdate owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
# communication script with update endpoint
# Check if Update thread busy if not we run new Update instance;
:local jobcount [:len [/system/script/job/find script=ispappUpdate]];
:if (\$jobcount <= 1) do={
  :global sendUpdate;
  :global submitCmds;
  :global execActions;
  :if (any\$sendUpdate) do={
    :do {
      :local updates [\$sendUpdate];
      :if (\$updates->\"status\") do={
        :local responce (\$updates->\"output\"->\"parsed\");
        if ([:len \$responce] > 0) do={
          if ([:len (\$responce->\"cmds\")]) do={
            :put \"Cmds processing .....\\n\";
            :put [\$submitCmds (\$responce->\"cmds\")];
            :put [\$executeCmds];
          }
          if ((\$responce->\"executeSpeedtest\") = \"true\") do={
            :put [\$execActions a=\"executeSpeedtest\"]
          }
          if ((\$responce->\"fwStatus\") = \"pending\") do={
            :put [\$execActions a=\"upgrade\"]
          }
          if ((\$responce->\"updateFast\") = \"true\") do={
            /system/scheduler/set ispappUpdate interval=3s disabled=no
          } else={
            /system/scheduler/set ispappUpdate interval=30s disabled=no
          }
           if ((\$responce->\"reboot\") = \"1\") do={
            :put [\$execActions a=\"reboot\"]
          }
        }
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
}"