# function to create an HTTPS client for ispapp.co
:global ispappHTTPClient do={
    :local method $m; # method
    :local action $a; # action
    :local body $b; # body
    # get current time and format it
    :local time [/system clock print as-value];
    :local formattedTime (($time->"date") . " | " . ($time->"time"))
    :local actions ("update", "config");
    # check if method argument is provided
    if (!any $m) do={
        :return {
            status=false;
            ok=false;
            response=false;
            error="No method provided";
        };
    }
    # check if action was provided
    if (!any $action) do={
      :set action "update";
      :log warning "default action added!\tispappHTTPClient.rsc\t[$formattedTime] !\nusage: (ispappHTTPClient a=<update|config> b=<json>  m=<get|post|put|delete>)";
    }
    # check if key was provided if not run ispappSet
    if (!any $topKey) do={
        :global topKey ispappSet;
    }
    # Check if topListenerPort is not set and assign a default value if not set
    :if ([:typeof $topListenerPort] = "nothing") do={
      :global topListenerPort 8550
    }
    # Check if topDomain is not set and assign a default value if not set
    :if ([:typeof $topDomain] = "nothing") do={
        :global topDomain "qwer.ispapp.co"
    }
    :local $requestUrl "https://$topDomain:$topListenerPort/$action?login=$login&key=$topKey";
    # Check certificates
    :local validCerts false;
    :if ( [:len [/certificate find]] > 0 && [/system clock get time-zone-name] != "none" ) do={
      :set validCerts true; 
    } else={
        # Try setting NTP 
        /system clock set time-zone-name=UTC;
        /system ntp client set enabled=yes primary-ntp=time.apple.com secondary-ntp=time.google.com;
        :if ([:len [/system package find where !disabled and name=ntp]] > 0) do={
            :set ntpstatus [/system ntp client get status]
        } else={
            :if ([:typeof [/system ntp client get last-update-from]] = "nil") do={
                :set ntpstatus "using-local-clock"
            } else={
                :set ntpstatus "synchronized"
            }
        }
        :delay 5s;
        :if ( [:len [/certificate find]] > 0 && [/system clock get time-zone-name] != "none" ) do={
            :set validCerts true;
        } else={
            # Reinstall certificates
            :do { 
              # install certs
            }
        }
    }

    :if ( $validCerts = false ) do={
    
      :return "Certificates invalid";
    }
    # Make request
    :local out {};
    :if ($m = "get") do={
      :set out [/tool fetch https://example.com as-value]; 
    } else={
      :set out [/tool fetch https://example.com http-method=$m http-data=$b as-value];
    }

    :return $out;
}
