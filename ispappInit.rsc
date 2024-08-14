/system script add dont-require-permissions=yes name=ispappInit owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
:global accessToken;
:global refreshToken;
:global ispappHTTPClient;
:global login;
:global topKey;


# Function to refresh access token
:global refreshAccessToken do={
    :local refreshEndpoint \"auth/refresh\"
    # Global variables
    :global accessToken;
    :global refreshToken;
    :global ispappHTTPClient;
    :set accessToken (\$refreshToken);
    :local httpResponse [\$ispappHTTPClient a=\$refreshEndpoint m=get];
    :if ((\$httpResponse->\"status\" = true) && ([:len (\$httpResponse->\"parsed\")] > 0 ) ) do={
        :if (\$parses->\"error\" = \"unauthorized\") do={
            :set accessToken \"\";
            :set refreshToken \"\";
            /system scheduler enable ispappInit;
            /system scheduler disable ispappConfig;
            /system scheduler disable ispappUpdate;
        } else={
            :local responseData (\$httpResponse->\"parsed\");
            :set accessToken (\$responseData->\"accessToken\");
            :set refreshToken (\$responseData->\"refreshToken\");
            :if (([ :len \$accessToken ] > 0) && ([ :len \$refreshToken ] > 0)) do={
                :put \"refresh\"
                :log info (\"accessToken refreshed\");
                /system scheduler disable ispappInit;
                /system scheduler enable ispappConfig;
                /system scheduler enable ispappUpdate;
            }
        }
    } else={
        :log error (\"accessToken not refreshed\");
        :set refreshToken (\$accessToken)
        :set accessToken \"\";
        /system scheduler enable ispappInit;
        /system scheduler disable ispappConfig;
        /system scheduler disable ispappUpdate;
    }
};

# Function to initialize ISPApp
:local initConfig do={
        # Global variables
        :local initConfigEndpoint \"initconfig\"
        :global accessToken;
        :global refreshToken;
        :global ispappHTTPClient;
        :global login;
        :global topKey;
        :global refreshAccessToken
        :global libLoaded;
        :if (\$libLoaded != true) do={
            /system script run ispapp_credentials
            :put \"Load libs\"
            /import ispappLibraryV0.rsc
            /import ispappLibraryV1.rsc
            /import ispappLibraryV2.rsc
            /import ispappLibraryV3.rsc
            /import ispappLibraryV4.rsc
            :set libLoaded true;
            [\$refreshAccessToken]
          }
        :if ([ :len \$refreshToken ] > 0) do={
            :put \"refresh\"
            [\$refreshAccessToken]
          } 
          :if (([ :len \$accessToken ] = 0 ) && ([ :len \$refreshToken ] = 0)) do={
        :local httpResponse [\$ispappHTTPClient a=\$initConfigEndpoint m=get];
        :put \$httpResponse
        :if ((\$httpResponse->\"status\" = true) && ([:len (\$httpResponse->\"parsed\")] ) ) do={
            :local responseData (\$httpResponse->\"parsed\");
            :put \$responseData;
            :if ([:len (\$responseData->\"accessToken\")]) do={
            :put \"set tokens\"
            :set accessToken (\$responseData->\"accessToken\");
            :set refreshToken (\$responseData->\"refreshToken\");
            :log info (\"ISPApp initialized successfully\");
             }
            :if (([ :len \$accessToken ]) && ([ :len \$refreshToken ])) do={
            /system scheduler disable ispappInit;
            /system scheduler enable ispappConfig;
            /system scheduler enable ispappUpdate;
            }
        } else={
            /system scheduler enable ispappInit;
            /system scheduler disable ispappConfig;
            /system scheduler disable ispappUpdate;
        }
          }
}

# Initialize ISPApp
:put [\$initConfig];
"