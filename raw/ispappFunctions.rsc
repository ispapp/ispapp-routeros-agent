# -------------------------------- JParseFunctions -------------------
:global fJParsePrint;
:if (!any $fJParsePrint) do={ :global fJParsePrint do={
  :global JParseOut;
  :local TempPath;
  :global fJParsePrint;

  :if ([:len $1] = 0) do={
    :set $1 $JParseOut;
    :set $2 $JParseOut;
   }
  
  :foreach k,v in=$2 do={
    :if ([:typeof $k] = "str") do={
      :set k "\"$k\"";
    }
    :set TempPath ($1. "->" . $k);
    :if ([:typeof $v] = "array") do={
      :if ([:len $v] > 0) do={
        $fJParsePrint $TempPath $v;
      } else={
        #:put "$TempPath = [] ($[:typeof $v])";
      }
    } else={
        #:put "$TempPath = $v ($[:typeof $v])";
    }
  }
}}
# ------------------------------- fJParsePrintVar ----------------------------------------------------------------
:global fJParsePrintVar;
:if (!any $fJParsePrintVar) do={ :global fJParsePrintVar do={
  :global JParseOut;
  :local TempPath;
  :global fJParsePrintVar;
  :local fJParsePrintRet "";

  :if ([:len $1] = 0) do={
    :set $1 $JParseOut;
    :set $2 $JParseOut;
   }
  
  :foreach k,v in=$2 do={
    :if ([:typeof $k] = "str") do={
      :set k "\"$k\"";
    }
    :set TempPath ($1. "->" . $k);
    :if ($fJParsePrintRet != "") do={
      :set fJParsePrintRet ($fJParsePrintRet . "\r\n");
    }   
    :if ([:typeof $v] = "array") do={
      :if ([:len $v] > 0) do={
        :set fJParsePrintRet ($fJParsePrintRet . [$fJParsePrintVar $TempPath $v]);
      } else={
        :set fJParsePrintRet ($fJParsePrintRet . "$TempPath = [] ($[:typeof $v])");
      }
    } else={
        :set fJParsePrintRet ($fJParsePrintRet . "$TempPath = $v ($[:typeof $v])");
    }
  }
  :return $fJParsePrintRet;
}}
# ------------------------------- fJSkipWhitespace ----------------------------------------------------------------
:global fJSkipWhitespace;
:if (!any $fJSkipWhitespace) do={ :global fJSkipWhitespace do={
  :global Jpos;
  :global JSONIn;
  :global Jdebug;
  :while ($Jpos < [:len $JSONIn] and ([:pick $JSONIn $Jpos] ~ "[ \r\n\t]")) do={
    :set Jpos ($Jpos + 1);
  }
  :if ($Jdebug) do={:put "fJSkipWhitespace: Jpos=$Jpos Char=$[:pick $JSONIn $Jpos]";}
}}
# -------------------------------- fJParse ---------------------------------------------------------------
:global fJParse;
:if (!any $fJParse) do={ :global fJParse do={
  :global Jpos;
  :global JSONIn;
  :global Jdebug;
  :global fJSkipWhitespace;
  :local Char;

  :if (!$1) do={
    :set Jpos 0;
   }
 
  $fJSkipWhitespace;
  :set Char [:pick $JSONIn $Jpos];
  :if ($Jdebug) do={:put "fJParse: Jpos=$Jpos Char=$Char"};
  :if ($Char="{") do={
    :set Jpos ($Jpos + 1);
    :global fJParseObject;
    :return [$fJParseObject];
  } else={
    :if ($Char="[") do={
      :set Jpos ($Jpos + 1);
      :global fJParseArray;
      :return [$fJParseArray];
    } else={
      :if ($Char="\"") do={
        :set Jpos ($Jpos + 1);
        :global fJParseString;
        :return [$fJParseString];
      } else={
#        :if ([:pick $JSONIn $Jpos ($Jpos+2)]~"^-\?[0-9]") do={
        :if ($Char~"[eE0-9.+-]") do={
          :global fJParseNumber;
          :return [$fJParseNumber];
        } else={

          :if ($Char="n" and [:pick $JSONIn $Jpos ($Jpos+4)]="null") do={
            :set Jpos ($Jpos + 4);
            :return [];
          } else={
            :if ($Char="t" and [:pick $JSONIn $Jpos ($Jpos+4)]="true") do={
              :set Jpos ($Jpos + 4);
              :return true;
            } else={
              :if ($Char="f" and [:pick $JSONIn $Jpos ($Jpos+5)]="false") do={
                :set Jpos ($Jpos + 5);
                :return false;
              } else={
                #:put "JParseFunctions.fJParse script: Err.Raise 8732. No JSON object could be fJParsed";
                :set Jpos ($Jpos + 1);
                :return "Err.Raise 8732. No JSON object could be fJParsed";
              }
            }
          }
        }
      }
    }
  }
}}

#-------------------------------- fJParseString ---------------------------------------------------------------
:global fJParseString;
:if (!any $fJParseString) do={ :global fJParseString do={
  :global Jpos;
  :global JSONIn;
  :global Jdebug;
  :global fUnicodeToUTF8;
  :local Char;
  :local StartIdx;
  :local Char2;
  :local TempString "";
  :local UTFCode;
  :local Unicode;

  :set StartIdx $Jpos;
  :set Char [:pick $JSONIn $Jpos];
  :if ($Jdebug) do={:put "fJParseString: Jpos=$Jpos Char=$Char";}
  :while ($Jpos < [:len $JSONIn] and $Char != "\"") do={
    :if ($Char="\\") do={
      :set Char2 [:pick $JSONIn ($Jpos + 1)];
      :if ($Char2 = "u") do={
        :set UTFCode [:tonum "0x$[:pick $JSONIn ($Jpos+2) ($Jpos+6)]"];
        :if ($UTFCode>=0xD800 and $UTFCode<=0xDFFF) do={
# Surrogate pair
          :set Unicode  (($UTFCode & 0x3FF) << 10);
          :set UTFCode [:tonum "0x$[:pick $JSONIn ($Jpos+8) ($Jpos+12)]"];
          :set Unicode ($Unicode | ($UTFCode & 0x3FF) | 0x10000);
          :set TempString ($TempString . [:pick $JSONIn $StartIdx $Jpos] . [$fUnicodeToUTF8 $Unicode]);
          :set Jpos ($Jpos + 12);
        } else= {
# Basic Multilingual Plane (BMP)
          :set Unicode $UTFCode;
          :set TempString ($TempString . [:pick $JSONIn $StartIdx $Jpos] . [$fUnicodeToUTF8 $Unicode]);
          :set Jpos ($Jpos + 6);
        }
        :set StartIdx $Jpos;
        :if ($Jdebug) do={:put "fJParseString Unicode: $Unicode";}
      } else={
        :if ($Char2 ~ "[\\bfnrt\"]") do={
          :if ($Jdebug) do={:put "fJParseString escape: Char+Char2 $Char$Char2";}
          :set TempString ($TempString . [:pick $JSONIn $StartIdx $Jpos] . [[:parse "(\"\\$Char2\")"]]);
          :set Jpos ($Jpos + 2);
          :set StartIdx $Jpos;
        } else={
          :if ($Char2 = "/") do={
            :if ($Jdebug) do={:put "fJParseString /: Char+Char2 $Char$Char2";}
            :set TempString ($TempString . [:pick $JSONIn $StartIdx $Jpos] . "/");
            :set Jpos ($Jpos + 2);
            :set StartIdx $Jpos;
          } else={
            #:put "JParseFunctions.fJParseString script: Err.Raise 8732. Invalid escape";
            :set Jpos ($Jpos + 2);
          }
        }
      }
    } else={
      :set Jpos ($Jpos + 1);
    }
    :set Char [:pick $JSONIn $Jpos];
  }
  :set TempString ($TempString . [:pick $JSONIn $StartIdx $Jpos]);
  :set Jpos ($Jpos + 1);
  :if ($Jdebug) do={:put "fJParseString: $TempString";}
  :return $TempString;
}}

#-------------------------------- fJParseNumber ---------------------------------------------------------------
:global fJParseNumber;
:if (!any $fJParseNumber) do={ :global fJParseNumber do={
  :global Jpos;
  :local StartIdx;
  :global JSONIn;
  :global Jdebug;
  :local NumberString;
  :local Number;

  :set StartIdx $Jpos;
  :set Jpos ($Jpos + 1);
  :while ($Jpos < [:len $JSONIn] and [:pick $JSONIn $Jpos]~"[eE0-9.+-]") do={
    :set Jpos ($Jpos + 1);
  }
  :set NumberString [:pick $JSONIn $StartIdx $Jpos];
  :set Number [:tonum $NumberString];
  :if ([:typeof $Number] = "num") do={
    :if ($Jdebug) do={:put "fJParseNumber: StartIdx=$StartIdx Jpos=$Jpos $Number ($[:typeof $Number])"}
    :return $Number;
  } else={
    :if ($Jdebug) do={:put "fJParseNumber: StartIdx=$StartIdx Jpos=$Jpos $NumberString ($[:typeof $NumberString])"}
    :return $NumberString;
  }
}}

#-------------------------------- fJParseArray ---------------------------------------------------------------
:global fJParseArray;
:if (!any $fJParseArray) do={ :global fJParseArray do={
  :global Jpos;
  :global JSONIn;
  :global Jdebug;
  :global fJParse;
  :global fJSkipWhitespace;
  :local Value;
  :local ParseArrayRet [:toarray ""];

  $fJSkipWhitespace;
  :while ($Jpos < [:len $JSONIn] and [:pick $JSONIn $Jpos]!= "]") do={
    :set Value [$fJParse true];
    :set ($ParseArrayRet->([:len $ParseArrayRet])) $Value;
    :if ($Jdebug) do={:put "fJParseArray: Value="; :put $Value;}
    $fJSkipWhitespace;
    :if ([:pick $JSONIn $Jpos] = ",") do={
      :set Jpos ($Jpos + 1);
      $fJSkipWhitespace;
    }
  }
  :set Jpos ($Jpos + 1);
#  :if ($Jdebug) do={:put "ParseArrayRet: "; :put $ParseArrayRet}
  :return $ParseArrayRet;
}}

# -------------------------------- fJParseObject ---------------------------------------------------------------
:global fJParseObject
:if (!any $fJParseObject) do={ :global fJParseObject do={
  :global Jpos;
  :global JSONIn;
  :global Jdebug;
  :global fJSkipWhitespace;
  :global fJParseString;
  :global fJParse;
# Syntax :local ParseObjectRet ({}) does not work in recursive call, use [:toarray ""] for empty array!!!
  :local ParseObjectRet [:toarray ""];
  :local Key;
  :local Value;
  :local ExitDo false;
 
  $fJSkipWhitespace;
  :while ($Jpos < [:len $JSONIn] and [:pick $JSONIn $Jpos]!="}" and !$ExitDo) do={
    :if ([:pick $JSONIn $Jpos]!="\"") do={
      #:put "JParseFunctions.fJParseObject script: Err.Raise 8732. Expecting property name";
      :set ExitDo true;
    } else={
      :set Jpos ($Jpos + 1);
      :set Key [$fJParseString];
      $fJSkipWhitespace;
      :if ([:pick $JSONIn $Jpos] != ":") do={
        #:put "JParseFunctions.fJParseObject script: Err.Raise 8732. Expecting : delimiter";
        :set ExitDo true;
      } else={
        :set Jpos ($Jpos + 1);
        :set Value [$fJParse true];
        :set ($ParseObjectRet->$Key) $Value;
        :if ($Jdebug) do={:put "fJParseObject: Key=$Key Value="; :put $Value;}
        $fJSkipWhitespace;
        :if ([:pick $JSONIn $Jpos]=",") do={
          :set Jpos ($Jpos + 1);
          $fJSkipWhitespace;
        }
      }
    }
  }
  :set Jpos ($Jpos + 1);
#  :if ($Jdebug) do={:put "ParseObjectRet: "; :put $ParseObjectRet;}
  :return $ParseObjectRet;
}}

# ------------------- fByteToEscapeChar ----------------------
:global fByteToEscapeChar;
:if (!any $fByteToEscapeChar) do={ :global fByteToEscapeChar do={
#  :set $1 [:tonum $1];
  :return [[:parse "(\"\\$[:pick "0123456789ABCDEF" (($1 >> 4) & 0xF)]$[:pick "0123456789ABCDEF" ($1 & 0xF)]\")"]];
}}

# ------------------- fUnicodeToUTF8----------------------
:global fUnicodeToUTF8;
:if (!any $fUnicodeToUTF8) do={ :global fUnicodeToUTF8 do={
  :global fByteToEscapeChar;
#  :local Ubytes [:tonum $1];
  :local Nbyte;
  :local EscapeStr "";

  :if ($1 < 0x80) do={
    :set EscapeStr [$fByteToEscapeChar $1];
  } else={
    :if ($1 < 0x800) do={
      :set Nbyte 2;
    } else={ 
      :if ($1 < 0x10000) do={
        :set Nbyte 3;
      } else={
        :if ($1 < 0x20000) do={
          :set Nbyte 4;
        } else={
          :if ($1 < 0x4000000) do={
            :set Nbyte 5;
          } else={
            :if ($1 < 0x80000000) do={
              :set Nbyte 6;
            }
          }
        }
      }
    }
    :for i from=2 to=$Nbyte do={
      :set EscapeStr ([$fByteToEscapeChar ($1 & 0x3F | 0x80)] . $EscapeStr);
      :set $1 ($1 >> 6);
    }
    :set EscapeStr ([$fByteToEscapeChar (((0xFF00 >> $Nbyte) & 0xFF) | $1)] . $EscapeStr);
  }
  :return $EscapeStr;
}}

# ------------------- End JParseFunctions----------------------

# ------------------- Base64EncodeFunct ----------------------

:global base64EncodeFunct do={ 

  #:put "base64EncodeFunct arg b=$stringVal"

  :local charToDec [:toarray ""];
# newline character is needed
:set ($charToDec->"\n") "10";
:set ($charToDec->" ") "32";
:set ($charToDec->"!") "33";
:set ($charToDec->"#") "35";
:set ($charToDec->"\$") "36";
:set ($charToDec->"%") "37";
:set ($charToDec->"&") "38";
:set ($charToDec->"'") "39";
:set ($charToDec->"(") "40";
:set ($charToDec->")") "41";
:set ($charToDec->"*") "42";
:set ($charToDec->"+") "43";
:set ($charToDec->",") "44";
:set ($charToDec->"-") "45";
:set ($charToDec->".") "46";
:set ($charToDec->"/") "47";
:set ($charToDec->"0") "48";
:set ($charToDec->"1") "49";
:set ($charToDec->"2") "50";
:set ($charToDec->"3") "51";
:set ($charToDec->"4") "52";
:set ($charToDec->"5") "53";
:set ($charToDec->"6") "54";
:set ($charToDec->"7") "55";
:set ($charToDec->"8") "56";
:set ($charToDec->"9") "57";
:set ($charToDec->":") "58";
:set ($charToDec->";") "59";
:set ($charToDec->"<") "60";
:set ($charToDec->"=") "61";
:set ($charToDec->">") "62";
:set ($charToDec->"?") "63";
:set ($charToDec->"@") "64";
:set ($charToDec->"A") "65";
:set ($charToDec->"B") "66";
:set ($charToDec->"C") "67";
:set ($charToDec->"D") "68";
:set ($charToDec->"E") "69";
:set ($charToDec->"F") "70";
:set ($charToDec->"G") "71";
:set ($charToDec->"H") "72";
:set ($charToDec->"I") "73";
:set ($charToDec->"J") "74";
:set ($charToDec->"K") "75";
:set ($charToDec->"L") "76";
:set ($charToDec->"M") "77";
:set ($charToDec->"N") "78";
:set ($charToDec->"O") "79";
:set ($charToDec->"P") "80";
:set ($charToDec->"Q") "81";
:set ($charToDec->"R") "82";
:set ($charToDec->"S") "83";
:set ($charToDec->"T") "84";
:set ($charToDec->"U") "85";
:set ($charToDec->"V") "86";
:set ($charToDec->"W") "87";
:set ($charToDec->"X") "88";
:set ($charToDec->"Y") "89";
:set ($charToDec->"Z") "90";
:set ($charToDec->"[") "91";
:set ($charToDec->"]") "93";
:set ($charToDec->"^") "94";
:set ($charToDec->"_") "95";
:set ($charToDec->"`") "96";
:set ($charToDec->"a") "97";
:set ($charToDec->"b") "98";
:set ($charToDec->"c") "99";
:set ($charToDec->"d") "100";
:set ($charToDec->"e") "101";
:set ($charToDec->"f") "102";
:set ($charToDec->"g") "103";
:set ($charToDec->"h") "104";
:set ($charToDec->"i") "105";
:set ($charToDec->"j") "106";
:set ($charToDec->"k") "107";
:set ($charToDec->"l") "108";
:set ($charToDec->"m") "109";
:set ($charToDec->"n") "110";
:set ($charToDec->"o") "111";
:set ($charToDec->"p") "112";
:set ($charToDec->"q") "113";
:set ($charToDec->"r") "114";
:set ($charToDec->"s") "115";
:set ($charToDec->"t") "116";
:set ($charToDec->"u") "117";
:set ($charToDec->"v") "118";
:set ($charToDec->"w") "119";
:set ($charToDec->"x") "120";
:set ($charToDec->"y") "121";
:set ($charToDec->"z") "122";
:set ($charToDec->"{") "123";
:set ($charToDec->"|") "124";
:set ($charToDec->"}") "125";
:set ($charToDec->"~") "126";

  :local base64Chars [:toarray ""];
:set ($base64Chars->"0") "A";
:set ($base64Chars->"1") "B";
:set ($base64Chars->"2") "C";
:set ($base64Chars->"3") "D";
:set ($base64Chars->"4") "E";
:set ($base64Chars->"5") "F";
:set ($base64Chars->"6") "G";
:set ($base64Chars->"7") "H";
:set ($base64Chars->"8") "I";
:set ($base64Chars->"9") "J";
:set ($base64Chars->"10") "K";
:set ($base64Chars->"11") "L";
:set ($base64Chars->"12") "M";
:set ($base64Chars->"13") "N";
:set ($base64Chars->"14") "O";
:set ($base64Chars->"15") "P";
:set ($base64Chars->"16") "Q";
:set ($base64Chars->"17") "R";
:set ($base64Chars->"18") "S";
:set ($base64Chars->"19") "T";
:set ($base64Chars->"20") "U";
:set ($base64Chars->"21") "V";
:set ($base64Chars->"22") "W";
:set ($base64Chars->"23") "X";
:set ($base64Chars->"24") "Y";
:set ($base64Chars->"25") "Z";
:set ($base64Chars->"26") "a";
:set ($base64Chars->"27") "b";
:set ($base64Chars->"28") "c";
:set ($base64Chars->"29") "d";
:set ($base64Chars->"30") "e";
:set ($base64Chars->"31") "f";
:set ($base64Chars->"32") "g";
:set ($base64Chars->"33") "h";
:set ($base64Chars->"34") "i";
:set ($base64Chars->"35") "j";
:set ($base64Chars->"36") "k";
:set ($base64Chars->"37") "l";
:set ($base64Chars->"38") "m";
:set ($base64Chars->"39") "n";
:set ($base64Chars->"40") "o";
:set ($base64Chars->"41") "p";
:set ($base64Chars->"42") "q";
:set ($base64Chars->"43") "r";
:set ($base64Chars->"44") "s";
:set ($base64Chars->"45") "t";
:set ($base64Chars->"46") "u";
:set ($base64Chars->"47") "v";
:set ($base64Chars->"48") "w";
:set ($base64Chars->"49") "x";
:set ($base64Chars->"50") "y";
:set ($base64Chars->"51") "z";
:set ($base64Chars->"52") "0";
:set ($base64Chars->"53") "1";
:set ($base64Chars->"54") "2";
:set ($base64Chars->"55") "3";
:set ($base64Chars->"56") "4";
:set ($base64Chars->"57") "5";
:set ($base64Chars->"58") "6";
:set ($base64Chars->"59") "7";
:set ($base64Chars->"60") "8";
:set ($base64Chars->"61") "9";
:set ($base64Chars->"62") "+";
:set ($base64Chars->"63") "/";

#:put $charToDec;
#:put $base64Chars;

  :local rr ""; 
  :local p "";
  :local s "";
  :local cLenForString ([:len $stringVal]);
  :local cModVal ( $cLenForString % 3);
  :local stringLen ([:len $stringVal]);
  :local returnVal;

  if ($cLenForString > 0) do={
    :local startEncode 0;

    :if ($cModVal > 0) do={
       for val from=($cModVal+1) to=3 do={
          :set p ($p."="); 
          :set s ($s."0"); 
          :set cModVal ($cModVal + 1);
        }
    }

    :local firstIndex 0;
    :while ( $firstIndex < $stringLen ) do={

        if (($cModVal > 0) && (((($cModVal / 3) *4) % 76) = 0) ) do={
          :set rr ($rr . "\ r \ n");
        }

        :local charVal1 ([:pick "$stringVal" $firstIndex ($firstIndex + 1)]);
        :local charVal2 ([:pick $stringVal ($firstIndex + 1) ($firstIndex + 2)]);
        :local charVal3 ([:pick $stringVal ($firstIndex+2) ($firstIndex + 3)]);

        :local n1Shift ([:tonum ($charToDec->$charVal1)] << 16);
        :local n2Shift ([:tonum ($charToDec->$charVal2)] << 8);
        :local n3Shift [:tonum ($charToDec->$charVal3)];

        :local mergeShift (($n1Shift +$n2Shift) + $n3Shift);

        :local n $mergeShift;
        :set n ([:tonum $n]);

        :local n1 (n >>> 18);

        :local n2 (n >>> 12);

        :local n3 (n >>> 6);
          
        :local arrayN [:toarray "" ];
        :set arrayN ( $arrayN, (n1 & 63));
        :set arrayN ( $arrayN, (n2 & 63));
        :set arrayN ( $arrayN, (n3 & 63));
        :set arrayN ( $arrayN, (n & 63));

        :set n ($arrayN);

        :local n1Val ([:pick $n 0]);
        :set n1Val ([:tostr $n1Val]);

        :local n2Val ([:pick $n 1]);
        :set n2Val ([:tostr $n2Val]);

        :local n3Val ([:pick $n 2]);
        :set n3Val ([:tostr $n3Val]);

        :local n4Val ([:pick $n 3]);
        :set n4Val ([:tostr $n4Val]);
    
        :set rr ($rr . (($base64Chars->$n1Val) . ($base64Chars->$n2Val) . ($base64Chars->$n3Val) . ($base64Chars->$n4Val)));

        :set firstIndex ($firstIndex + 3);
    }

    # checks for errors
    :do {

      :local rLen ([:len $rr]);
      :local pLen ([:len $p]);

      :set returnVal ([:pick "$rr" 0 ($rLen - $pLen)]);
      :set returnVal ($returnVal . $p);
      :set startEncode 1;
      :return $returnVal;
     
    } on-error={
      :set returnVal ("Error: Base64 encode error.");
      :return $returnVal;
    }

  } else={
    :set returnVal ("Error: Base64 encode error, likely an empty value.");
    :return $returnVal;
  }
  
}

:global urlEncodeFunct do={
  #:put "$currentUrlVal"; 
  #:put "$urlVal"

  :local urlEncoded;
  :for i from=0 to=([:len $urlVal] - 1) do={
    :local char [:pick $urlVal $i]
    :if ($char = " ") do={
      :set char "%20"
    }
    :if ($char = "/") do={
      :set char "%2F"
    }
    :if ($char = "-") do={
      :set char "%2D"
    }
    :set urlEncoded ($urlEncoded . $char)
  }
  :local mergeUrl;
  :set mergeUrl ($currentUrlVal . $urlEncoded);
  :return ($mergeUrl);

}

:global Split do={

  :local input $1;
  :local delim $2;

  #:put "Split()";
  #:put "INPUT: $input";
  #:put "DELIMETER: $delim";

  :local strElem;
  :local arr [:toarray ""];
  :local arrIndex 0;

  :for c from=0 to=[:len $input] do={

    :local ch [:pick $input $c ($c+1)];
    #:put "ch $c: $ch";

    if ($ch = $delim) do={

      if ([:len $strElem] > 0) do={
        #:put "found strElem: $strElem";
        :set ($arr->$arrIndex) $strElem;
        :set arrIndex ($arrIndex+1);
        :set strElem "";
      }

    } else={
      :set strElem ($strElem . $ch);
    }

  }

  #:put "last strElem: $strElem";
  :set ($arr->$arrIndex) $strElem;

  :return $arr;

}

# routeros 0w0d0m0s to seconds
:global rosTsSec do={

  :local input $1;

  #:put "rosTsSec $input";

  :local upSeconds 0;

  :local weeks 0;
  if (([:find $input "w"]) > 0 ) do={
    :set weeks ([:pick $input 0 ([:find $input "w"])]);
    :set input [:pick $input ([:find $input "w"]+1) [:len $input]];
  }
  :local days 0;
  if (([:find $input "d"]) > 0 ) do={
    :set days ([:pick $input 0 [:find $input "d"]]);
    :set input [:pick $input ([:find $input "d"]+1) [:len $input]];
  }

  :local hours [:pick $input 0 [:find $input ":"]];
  :set input [:pick $input ([:find $input ":"]+1) [:len $input]];

  :local minutes [:pick $input 0 [:find $input ":"]];
  :set input [:pick $input ([:find $input ":"]+1) [:len $input]];

  :local upSecondVal 0;
  :set upSecondVal $input;

  :set upSeconds value=[:tostr (($weeks*604800)+($days*86400)+($hours*3600)+($minutes*60)+$upSecondVal)];

  return $upSeconds;

}

# routeros timestamp string to seconds
:global rosTimestringSec do={

  :global Split;

  :local input $1;

  # split the date and the time from $input
  :local dateTimeSplit [$Split $input " "];

  # date Dec/21/2021 or dec/21/2021
  :local buildDate ($dateTimeSplit->0);
  # time 11:53:05
  :local buildTimeValue ($dateTimeSplit->1);

  # parse the date
  # this needs to conver tto UTC
  :local month [:pick $buildDate 0 3];
  :local day [:pick $buildDate 4 6];
  :local year [:pick $buildDate 7 11];

  :local Months [:toarray "Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec"];
  :local months [:toarray "jan,feb,mar,apr,may,jun,jul,aug,sep,oct,nov,dec"];

  :local monthInt 0;

  # routeros uses lowercase and starting with uppercase strings for the 3 character month prefix
  for i from=0 to=([:len $months] - 1) do={
    :local m ($months->$i);

    if ($m = $month) do={
      :set monthInt $i;
    }

  }

  # routeros uses lowercase and starting with uppercase strings for the 3 character month prefix
  for i from=0 to=([:len $Months] - 1) do={
    :local m ($Months->$i);

    if ($m = $month) do={
      :set monthInt $i;
    }

  }

  # increment the monthInt by one because the index starts at 0
  :set monthInt ($monthInt + 1);

  # convert the day and year to numbers
  :local dayInt [:tonum $day];
  :local yearInt [:tonum $year];

  # number of seconds since epoch
  # jan 1st 1970 UTC
  :local epochMonthInt 1;
  :local epochDayInt 1;
  :local epochYearInt 1970;

  # get the difference between now and then for the date parts
  :local monthDiff ($monthInt - $epochMonthInt);
  :local dayDiff ($dayInt - $epochDayInt);
  :local yearDiff ($yearInt - $epochYearInt);

  # for every 4 years add 1 day for leap years
  # routeros has no float support
  :local leapSecondsInDatePart 0;
  :local isFour 0;
  for i from=0 to=$yearDiff do={

    :set isFour ($isFour + 1);

    if ($isFour = 4) do={
      # add one day of seconds
      :set leapSecondsInDatePart ($leapSecondsInDatePart + (24 * 60 * 60));
      :set isFour 0;
    }

  }

  # convert to seconds
  # the months need to have their days calculated correctly
  # all have 31 except
  # feb has 28, and 29 in leap years
  # apr, jun, sep and nov have 30
  # in october this is ~3 days off
  :local monthDiffSec ($monthDiff * 30 * 24 * 60 * 60);
  :local dayDiffSec ($dayDiff * 24 * 60 * 60);
  :local yearDiffSec ($yearDiff * 365 * 24 * 60 * 60);

  # get the date part difference in seconds since the unix epoch per field
  :local datePartDiffSec ($monthDiffSec + $dayDiffSec + $yearDiffSec);

  # get the time parts
  :local hour [:tonum [:pick $buildTimeValue 0 2]];
  :local minute [:tonum [:pick $buildTimeValue 3 5]];
  :local second [:tonum [:pick $buildTimeValue 6 8]];

  # convert the time parts to seconds
  :set hour ($hour * 60 * 60);
  :set minute ($minute * 60);

  # get the time part difference in seconds since the unix epoch per field
  :local timePartDiffSec ($hour + $minute + $second);

  # return the sum of the seconds since epoch of the date and seconds in the time
  # with leap year days added
  :return ($datePartDiffSec + $timePartDiffSec + $leapSecondsInDatePart);

}
