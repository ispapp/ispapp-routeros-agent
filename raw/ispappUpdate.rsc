# communication script with update endpoint
# Check if Update thread busy if not we run new Update instance;
:local jobcount [:len [/system script job find script=ispappUpdate]];
:if ($jobcount <= 1) do={
  :global sendUpdate;
  :global submitCmds;
  :global execActions;
  :global executeCmds;
  :if (any$sendUpdate) do={
    :do {
      :local updates [$sendUpdate];
      :if ($updates->"status") do={
        :local response ($updates->"output"->"parsed");
        if ([:len $response] > 0) do={
          if ([:len ($response->"cmds")]) do={
            :put [$submitCmds ($response->"cmds")];
            :delay ([:len ($response->"cmds")] . "s");
            :put [$executeCmds];
          }
          if (($response->"executeSpeedtest") = true) do={
            :put [$execActions a="executeSpeedtest"]
          }
          if (($response->"fwStatus") = "pending") do={
            :put [$execActions a="upgrade"]
          }
          if (($response->"updateFast") = true) do={
            /system scheduler set ispappUpdate interval=3s disabled=no
            /system scheduler set ispappConfig interval=1m disabled=no
          } else={
            /system scheduler set ispappUpdate interval=30s disabled=no
            /system scheduler set ispappConfig interval=5m disabled=no
          }
          if (($response->"reboot") = "1") do={
            :put [$execActions a="reboot"]
          }
        }
      } else={
        :put "sendUpdate was not successful :(";
        :log error "sendUpdate was not successful :(";
      }
    } on-error={
      :put "sendUpdate error!";
      :log error "sendUpdate error! :(";
    }
  } else={
    :put "Library v4 is not loaded! (not sendUpdate found)";
    :log error "Library v4 is not loaded! (not sendUpdate found)";
  }
} else={
    :put "update thread id busy ....";
}