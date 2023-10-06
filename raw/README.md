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
:local mixedArray1 (42, 77, {"kimo":"nice"}); :local jsonString [$arrayToJsonDeep3 $mixedArray];:put ("JSON String: " . $jsonString);
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
    - **ispappHTTPClient**
        - > check certificates and ntp server and fix them if certs not valid or ntp client not in sync.
        - > handle all sort of requests to backend.
        - > convert responces to value-list format. ready to be used in Router Os SCRIPT.