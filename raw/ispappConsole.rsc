# Check if Console thread busy; if not we run new Console instance;
:if ([:len [/system/script/job/find script="ispappConsole"]] = 0 ) do={
    :global runTerminal;
    :if (any$runTerminal) do={
        # run cmds is exist
        [$runTerminal];
    }
}
