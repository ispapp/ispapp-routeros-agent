:global startEncode 1;
:global isSend 1;

:global topKey ($topKey);
:global topDomain ($topDomain);
:global topClientInfo ($topClientInfo);
:global topListenerPort ($topListenerPort);
:global topServerPort ($topServerPort);
:global topSmtpPort ($topSmtpPort);

# setup email server
/tool e-mail set address=($topDomain);
/tool e-mail set port=($topSmtpPort);

:local ROSver value=[:tostr [/system resource get value-name=version]];
:local ROSverH value=[:pick $ROSver 0 ([:find $ROSver "." -1]) ];
:global rosMajorVersion value=[:tonum $ROSverH];

:if ($rosMajorVersion = 7) do={
  #:put ">= 7";
  :execute script="/tool e-mail set tls=yes";
}

:if ($rosMajorVersion = 6) do={
  #:put "not >= 7";
  :execute script="/tool e-mail set start-tls=tls-only";
}

:global currentUrlVal;

# Get login from MAC address of an interface
:local l "";

:do {
  :set l ([/interface get [find default-name=wlan1] mac-address]);
} on-error={
  :do {
    :set l ([/interface get [find default-name=ether1] mac-address]);
  } on-error={
    :do {
      :set l ([/interface get [find default-name=sfp-sfpplus1] mac-address]);
    } on-error={
      :do {
        :set l ([/interface get [find default-name=lte1] mac-address]);
      } on-error={
        :log info ("No Interface MAC Address found to use as ISPApp login, default-name=wlan1, ether1, sfp-sfpplus1 or lte1 must exist.");
      }
    }
  }
}

:local new "";
# Convert to lowercase
:local low ("a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z");
:local upp ("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z");

:for i from=0 to=([:len $l] - 1) do={
  :local char [:pick $l $i];
  :local f [:find "$upp" "$char"];
  :if ( $f < 0 ) do={
  :set new ($new . $char);
  }
  :for a from=0 to=([:len $upp] - 1) do={
  :local l [:pick $upp $a];
  :if ( $char = $l) do={
    :local u [:pick $low $a];
    :set new ($new . $u);
    }
  }
}

:global login "00:00:00:00:00:00";
:if ([:len $new] > 0) do={
:set login $new;
}

#:put ("ispappSetGlobalEnv executed, login: $login");