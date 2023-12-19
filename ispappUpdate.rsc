/system script add dont-require-permissions=yes name=ispappUpdate owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
# communication script with update endpoint
# Check if Update thread busy if not we run new Update instance;
:if ([:len [/system/script/job/find script=ispappUpdate]] = 1) do={
  :global sendUpdate;
  :if (any\$sendUpdate) do={
    :do {
      :local updates [\$sendUpdate];
      :if (\$updates->\"status\") do={
        :local responce (\$responce->\"output\"->\"parsed\");
        if ([:len \$responce] > 0) do={
          if ([:len (\$responce->\"cmds\")]) do={
            :put \"execute Cmds .....\\n\"
            :put [\$submitCmds (\$responce->\"cmds\")]; # send to ispappConsole
            :put [\$executeCmds];
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