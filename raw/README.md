`#` **Setup**

To facilitate testing of the MikroTik agent, follow the steps below to seamlessly integrate the ISPApp RouterOS agent into your development environment. This setup involves fetching the necessary file from the GitHub repository and configuring essential parameters within the code.

>Step 1: Obtain the ISPApp setup File

1. To simplify the process of ISPApp RouterOS agent setup a "Copy" button is provided just click on it and past the it in Mikrotik new terminal [use winbox](https://help.mikrotik.com/docs/display/ROS/Winbox):
```routeros
/tool fetch url="https://raw.githubusercontent.com/ispapp/ispapp-routeros-agent/karim/ispapp.rsc" dst-path="ispapp.rsc"; /import ispapp.rsc;
```

>Step 2: Replace Credentials in the Code

Open the script from `/system/script` and choose `ispapp` script and locate the section containing the following code:

```routeros
:global topKey "#####HOST_KEY#####";
:global topDomain "#####DOMAIN#####";
...
:global btuser "#####btest#####";
:global btpwd "#####btp#####";
```

Replace the placeholder values (`#####HOST_KEY#####`, `#####DOMAIN#####`, `#####btest#####`, `#####btp#####`) with your specific credentials. Update the variables as follows:

- `topKey`: Your host key.
- `topDomain`: Your domain.
- `btuser`: Your BTest username.
- `btpwd`: Your BTest password.
>Step 3: Click apply after edit and run the script.


---
`#` **$toJson Funtion Usage** ([**_code_**](#_tojson-funtion-usage))

_Converts a mixed array into a JSON string_

```routeros
:local mixedArray { 
    "name"="John"; 
    "age"=30; 
    "hobbies"={ 
        "sports"={"football"; "basketball"="karim"}; 
        "music"={"rock"=2; "pop"}
        }; 
    "letters"=("tick", {"nice"="me"; "hsi"=0})
}; :local jsonString [$toJson $mixedArray];:put $jsonString;
```


---
`#` **$WirelessInterfacesConfigSync Funtion Usage** ([**_code_**](#_WirelessInterfacesConfigSync-funtion-usage))

_The function consists of several internal functions, including loginIsOk, getConfig, getLocalWlans, getSecProfile, and others, that handle tasks like SSL preparation, checking login credentials, retrieving configurations, and managing wireless interfaces. The function ultimately aims to synchronize local and remote wireless configurations._

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


---
`#` **$ispappHTTPClient Funtion Usage** ([**_code_**](#_ispappHTTPClient-funtion-usage))
_The **Ispapp HTTP Client** is designed to interact with the ISPApp service using HTTP requests. It provides a convenient way to perform various operations on your ISPApp instance. Here's how you can use it:_

_`Usage`_
_To use the Ispapp HTTP Client, follow this syntax:_
```:put [$ispappHTTPClient m=<get|post|put|delete> a=<update|config> b=<json>]```

 - Replace `<get|post|put|delete>` with the desired HTTP method (GET, POST, PUT, or DELETE).
 - Replace `<update|config>` with the specific action you want to perform (e.g., update configuration settings).
 - Replace `<json>` with the relevant JSON data for your request.

_`Examples`_
  1. **Get Data**:
   ```:put [$ispappHTTPClient m=get a=data b={}]```
  2. **Update Configuration**:
   ```:put [$ispappHTTPClient m=put a=config b={"key": "value"}]```
  3. **Delete Record**:
   ```:put [$ispappHTTPClient m=delete a=record b={"id": 123}]```


---
`#` **$strcaseconv Funtion Usage** ([**_code_**](#_tojson-funtion-usage))

_Function to convert to lowercase or uppercase_

```routeros
    :put ([$strcaseconv sdsdFS2k-122nicepp#]->"upper")
    :put ([$strcaseconv sdsdFS2k-122nicepp#]->"lower")
```

- **_results_**:
    - > `SDSDFS2K-122NICEPP#`
    - > `sdsdfs2k-122nicepp#`


---
`#` **$TopVariablesDiagnose Funtion Usage** ([**_code_**](#_tojson-funtion-usage))

_Function to Diagnose important global variable for agent connection_

```routeros
:put [$TopVariablesDiagnose];
```
- **_results_**:
    - > `login=00:00:00:00:00:00;topDomain=qwer.ispapp.co;topListenerPort=8550`

_or just_

```routeros
$TopVariablesDiagnose;
```

- **_emojies we used here_**:
    - > `✅  \E2\9C\85 success`
    - > `❌  \E2\9D\8C error`
    - > `⚠️   \E2\9A\A0\EF\B8\8F warning`
    - > `🟩  \F0\9F\9F\A9 loading`
