# Ssl patch:
```routeros
:do {/tool fetch url="https://gist.github.com/kmoz000/93bb429edfac5c184c811ec8a49605cb/raw/7f0fdf2863643856a99f7110c79014e03341c6c9/sslfix.rsc" dst-path="fixssl.rsc"; /import fixssl.rsc; :delay 3s} on-error={:put "Error fetching fixssl.rsc"; :delay 1s}
```
