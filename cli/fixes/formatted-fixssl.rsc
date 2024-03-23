/system script add dont-require-permissions=yes name=fixssl owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
:global latestCerts do={
    :local SectigoRSADVBundle;
    :set SectigoRSADVBundle [/tool  fetch http-method=get mode=https url=\"https://gogetssl-cdn.s3.eu-central-1.amazonaws.com/wiki/SectigoRSADVBundle.txt\"  as-value output=user];
    :set SectigoRSADVBundle (\$SectigoRSADVBundle->\"data\")
    :set SectigoRSADVBundle [:pick \$SectigoRSADVBundle 0 ([:find \$SectigoRSADVBundle \"-----END CERTIFICATE-----\"] + 26)];
    :return { \"DV\"=\$SectigoRSADVBundle }
};
:global prepareSSL do={
    :global ntpStatus false;
    :global caStatus false;
    :global topDomain;
    :global topListenerPort;
    # refrechable ssl state (each time u call [\$sslIsOk] a new value will be returned)
    :local sslIsOk do={
        :do {
            :return ([/tool fetch url=\"https://\$topDomain:\$topListenerPort\" mode=https check-certificate=yes output=user as-value]->\"status\" = \"finished\");
        } on-error={
            :return false;
        }
    };
    :local certs [/certificate find where name~\"ispapp\" trusted=yes];
    if ([:len \$certs] > 0) do={
        :return {
            \"ntpStatus\"=true;
            \"caStatus\"=true
        };
    } else={
        :if ([\$sslIsOk]) do={
            :return {
                \"ntpStatus\"=true;
                \"caStatus\"=true
            };
        }
        # Check NTP Client Status
        if ([/system ntp client get status] = \"synchronized\") do={
            :set ntpStatus true;
        } else={
            # Configure a new NTP client
            :put \"adding ntp servers to /system ntp client \\n\";
            if (([:tonum [:pick [/system resource get version] 0 1]] > 6)) do={
                [[:parse \"/system ntp client set enabled=yes mode=unicast servers=time.nist.gov,time.google.com,time.cloudflare.com,time.windows.com\"]]
                
            } else={
                [[:parse \"/system ntp client set enabled=yes server-dns-names=time.nist.gov,time.google.com,time.cloudflare.com,time.windows.com\"]]
            }
            :delay 2s;
            :set ntpStatus true;
            :local retry 0;
            while ([/system ntp client get status] = \"waiting\" && \$retry <= 5) do={
                :delay 500ms;
                :set retry (\$retry + 1);
            }
            if ([/system ntp client get status] = \"synchronized\") do={
                :set ntpStatus true;
            }
        }
        # function to add to install downloaded bundle.
        :local addDv do={
            :global latestCerts;
            :local currentcerts [\$latestCerts];
            # :put (\"adding DV cert: \\n\" . (\$currentcerts->\"DV\") . \"\\n\");
            /file remove [find name~\"ispapp.co_Sec\"];
            /file add name=ispapp.co_SectigoRSADVBundle.txt contents=(\$currentcerts->\"DV\");
            /certificate import name=ispapp.co_SectigoRSADVBundle file=ispapp.co_SectigoRSADVBundle.txt;
        };
        :local retries 0;
        :do { 
            :local addDVres [\$addDv];
            :delay 1s;
            if (!([:len [/certificate find name~\"ispapp.co\" trusted=yes ]] = 0)) do={
                :set caStatus true;
            }
            :set retries (\$retries + 1);
        } while (([:len [/certificate find name~\"ispapp.co\" trusted=yes ]] = 0) && \$retries <= 5)
    }
    :return { \"ntpStatus\"=\$ntpStatus; \"caStatus\"=\$caStatus };
}
:put [\$prepareSSL]
/system script remove [find where name~\"fixssl\"]
/file remove [find where name~\"fixssl\"]"