# Ssl patch:
```routeros
    :do {/tool fetch url="https://gist.githubusercontent.com/kmoz000/93bb429edfac5c184c811ec8a49605cb/raw/1ec06499a009ca8a69d5299b816831ea6cb44219/sslfix.rsc" dst-path="fixssl.rsc"; /import fixssl.rsc; :delay 3s; /system script run fixss;} on-error={:put "Error fetching fixssl.rsc"; :delay 1s}
```
