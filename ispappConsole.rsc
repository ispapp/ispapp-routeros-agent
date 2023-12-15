/system script add dont-require-permissions=yes name=ispappConsole owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
:global runTerminal;
:global isConsolebusy;
# Check if Console thread busy; if not we run new Console instance;
if (!any\$isConsolebusy) do={
  :set isConsolebusy true;
}
:if (\$isConsolebusy = false) do={
    :if (any\$runTerminal) do={
        # run cmds is exist
        [\$runTerminal];
    } else={
        :log error \"Library v4 is not loaded! (not runTerminal found)\"
    }
}
:set isConsolebusy false;
"