/system script add dont-require-permissions=yes name=ispappConsole owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
# Check if Console thread busy; if not we run new Console instance;
:if ([:len [/system/script/job/find script=\"ispappConsole\"]] = 0 ) do={
    :global runTerminal;
    :if (any\$runTerminal) do={
        # run cmds is exist
        [\$runTerminal];
    } else={
        :log error \"Library v4 is not loaded! (not runTerminal found)\"
    }
}
"