**$toJson Funtion Usage** ([**_code_**](#_tojson-funtion-usage))
__Converts a mixed array into a JSON string__

```routeros
:local mixedArray0 { 
    "name"="John"; 
    "age"=30; 
    "hobbies"={ 
        "sports"={"football"; "basketball"="karim"}; 
        "music"={"rock"=2; "pop"}
        }; 
    "numbers"=(42, 77, "letter")
};
:local mixedArray1 (42, 77, {"kimo":"nice"}); :local jsonString [$toJson $mixedArray];:put ("JSON String: " . $jsonString);
```

**$WirelessInterfacesConfigSync Funtion Usage** ([**_code_**](#_WirelessInterfacesConfigSync-funtion-usage))
__The function consists of several internal functions, including loginIsOk, getConfig, getLocalWlans, getSecProfile, and others, that handle tasks like SSL preparation, checking login credentials, retrieving configurations, and managing wireless interfaces. The function ultimately aims to synchronize local and remote wireless configurations.__

```routeros
# Function to collect all wireless interfaces and format them to be sent to the server.
# @param $topDomain - domain of the server
# @param $topKey - key of the server
# @param $topListenerPort - port of the server
# @param $login - login of the server
# @param $password - password of the server
# @param $prepareSSL - if true, SSL preparation will be done
# @return $wlans - array of wireless interfaces
# @return $status - status of the operation
# @return $message - message of the operation
:global WirelessInterfacesConfigSync do={
    # (..function content..)
};
```

**$WirelessInterfacesConfigSync Funtion Usage** ([**_code_**](#_WirelessInterfacesConfigSync-funtion-usage))
__The function consists of several internal functions, including loginIsOk, getConfig, getLocalWlans, getSecProfile, and others, that handle tasks like SSL preparation, checking login credentials, retrieving configurations, and managing wireless interfaces. The function ultimately aims to synchronize local and remote wireless configurations.__

```routeros
# Function to collect all wireless interfaces and format them to be sent to the server.
# @param $topDomain - domain of the server
# @param $topKey - key of the server
# @param $topListenerPort - port of the server
# @param $login - login of the server
# @param $password - password of the server
# @param $prepareSSL - if true, SSL preparation will be done
# @return $wlans - array of wireless interfaces
# @return $status - status of the operation
# @return $message - message of the operation
:global WirelessInterfacesConfigSync do={
    # (..function content..)
};
```

**$strcaseconv Funtion Usage** ([**_code_**](#_tojson-funtion-usage))
__Function to convert to lowercase or uppercase__

```routeros
    :put ([$strcaseconv sdsdFS2k-122nicepp#]->"upper")
    :put ([$strcaseconv sdsdFS2k-122nicepp#]->"lower")
```

- **_results_**:
    - > `SDSDFS2K-122NICEPP#`
    - > `sdsdfs2k-122nicepp#`

**$TopVariablesDiagnose Funtion Usage** ([**_code_**](#_tojson-funtion-usage))
__Function to Diagnose important global variable for agent connection__

```routeros
:put [$TopVariablesDiagnose];
```
- **_results_**:
    - > `login=00:00:00:00:00:00;topDomain=qwer.ispapp.co;topListenerPort=8550`

__or just__

```routeros
$TopVariablesDiagnose;
```

- **_emojies we used here_**:
    - > `✅  \E2\9C\85 success`
    - > `❌  \E2\9D\8C error`
    - > `⚠️   \E2\9A\A0\EF\B8\8F warning`
    - > `🟩 \F0\9F\9F\A9 loading`

- **_todo_**:
    - **do more tests on the interfaces syhnc function**