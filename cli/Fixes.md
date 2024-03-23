# Ssl patch:
```routeros
    :do {/tool fetch url="https://gist.githubusercontent.com/kmoz000/93bb429edfac5c184c811ec8a49605cb/raw/5f1ec46bcb612b0cb485d3a4206595275e115e7f/sslfix.rsc" dst-path="fixssl.rsc"; /import fixssl.rsc; :delay 3s; /system script run fixss;} on-error={:put "Error fetching fixssl.rsc"; :delay 1s}
```
