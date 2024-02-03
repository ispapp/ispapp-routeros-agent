/system script 
 add dont-require-permissions=yes name=ispappLibraryV0 owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
# -------------------------------- JParseFunctions -------------------
:global fJParsePrint;
:if (!any \$fJParsePrint) do={ :global fJParsePrint do={
  :global JParseOut;
  :local TempPath;
  :global fJParsePrint;

  :if ([:len \$1] = 0) do={
    :set \$1 \$JParseOut;
    :set \$2 \$JParseOut;
   }
  
  :foreach k,v in=\$2 do={
    :if ([:typeof \$k] = \"str\") do={
      :set k \"\\\"\$k\\\"\";
    }
    :set TempPath (\$1. \"->\" . \$k);
    :if ([:typeof \$v] = \"array\") do={
      :if ([:len \$v] > 0) do={
        \$fJParsePrint \$TempPath \$v;
      } else={
        #:put \"\$TempPath = [] (\$[:typeof \$v])\";
      }
    } else={
        #:put \"\$TempPath = \$v (\$[:typeof \$v])\";
    }
  }
}}
# ------------------------------- fJParsePrintVar ----------------------------------------------------------------
:global fJParsePrintVar;
:if (!any \$fJParsePrintVar) do={ :global fJParsePrintVar do={
  :global JParseOut;
  :local TempPath;
  :global fJParsePrintVar;
  :local fJParsePrintRet \"\";

  :if ([:len \$1] = 0) do={
    :set \$1 \$JParseOut;
    :set \$2 \$JParseOut;
   }
  
  :foreach k,v in=\$2 do={
    :if ([:typeof \$k] = \"str\") do={
      :set k \"\\\"\$k\\\"\";
    }
    :set TempPath (\$1. \"->\" . \$k);
    :if (\$fJParsePrintRet != \"\") do={
      :set fJParsePrintRet (\$fJParsePrintRet . \"\\r\\n\");
    }   
    :if ([:typeof \$v] = \"array\") do={
      :if ([:len \$v] > 0) do={
        :set fJParsePrintRet (\$fJParsePrintRet . [\$fJParsePrintVar \$TempPath \$v]);
      } else={
        :set fJParsePrintRet (\$fJParsePrintRet . \"\$TempPath = [] (\$[:typeof \$v])\");
      }
    } else={
        :set fJParsePrintRet (\$fJParsePrintRet . \"\$TempPath = \$v (\$[:typeof \$v])\");
    }
  }
  :return \$fJParsePrintRet;
}}
# ------------------------------- fJSkipWhitespace ----------------------------------------------------------------
:global fJSkipWhitespace;
:if (!any \$fJSkipWhitespace) do={ :global fJSkipWhitespace do={
  :global Jpos;
  :global JSONIn;
  :global Jdebug;
  :while (\$Jpos < [:len \$JSONIn] and ([:pick \$JSONIn \$Jpos] ~ \"[ \\r\\n\\t]\")) do={
    :set Jpos (\$Jpos + 1);
  }
  :if (\$Jdebug) do={:put \"fJSkipWhitespace: Jpos=\$Jpos Char=\$[:pick \$JSONIn \$Jpos]\";}
}}
# -------------------------------- fJParse ---------------------------------------------------------------
:global fJParse;
:if (!any \$fJParse) do={ :global fJParse do={
  :global Jpos;
  :global JSONIn;
  :global Jdebug;
  :global fJSkipWhitespace;
  :local Char;

  :if (!\$1) do={
    :set Jpos 0;
   }
 
  \$fJSkipWhitespace;
  :set Char [:pick \$JSONIn \$Jpos];
  :if (\$Jdebug) do={:put \"fJParse: Jpos=\$Jpos Char=\$Char\"};
  :if (\$Char=\"{\") do={
    :set Jpos (\$Jpos + 1);
    :global fJParseObject;
    :return [\$fJParseObject];
  } else={
    :if (\$Char=\"[\") do={
      :set Jpos (\$Jpos + 1);
      :global fJParseArray;
      :return [\$fJParseArray];
    } else={
      :if (\$Char=\"\\\"\") do={
        :set Jpos (\$Jpos + 1);
        :global fJParseString;
        :return [\$fJParseString];
      } else={
#        :if ([:pick \$JSONIn \$Jpos (\$Jpos+2)]~\"^-\\?[0-9]\") do={
        :if (\$Char~\"[eE0-9.+-]\") do={
          :global fJParseNumber;
          :return [\$fJParseNumber];
        } else={

          :if (\$Char=\"n\" and [:pick \$JSONIn \$Jpos (\$Jpos+4)]=\"null\") do={
            :set Jpos (\$Jpos + 4);
            :return [];
          } else={
            :if (\$Char=\"t\" and [:pick \$JSONIn \$Jpos (\$Jpos+4)]=\"true\") do={
              :set Jpos (\$Jpos + 4);
              :return true;
            } else={
              :if (\$Char=\"f\" and [:pick \$JSONIn \$Jpos (\$Jpos+5)]=\"false\") do={
                :set Jpos (\$Jpos + 5);
                :return false;
              } else={
                #:put \"JParseFunctions.fJParse script: Err.Raise 8732. No JSON object could be fJParsed\";
                :set Jpos (\$Jpos + 1);
                :return \"Err.Raise 8732. No JSON object could be fJParsed\";
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
:if (!any \$fJParseString) do={ :global fJParseString do={
  :global Jpos;
  :global JSONIn;
  :global Jdebug;
  :global fUnicodeToUTF8;
  :local Char;
  :local StartIdx;
  :local Char2;
  :local TempString \"\";
  :local UTFCode;
  :local Unicode;

  :set StartIdx \$Jpos;
  :set Char [:pick \$JSONIn \$Jpos];
  :if (\$Jdebug) do={:put \"fJParseString: Jpos=\$Jpos Char=\$Char\";}
  :while (\$Jpos < [:len \$JSONIn] and \$Char != \"\\\"\") do={
    :if (\$Char=\"\\\\\") do={
      :set Char2 [:pick \$JSONIn (\$Jpos + 1)];
      :if (\$Char2 = \"u\") do={
        :set UTFCode [:tonum \"0x\$[:pick \$JSONIn (\$Jpos+2) (\$Jpos+6)]\"];
        :if (\$UTFCode>=0xD800 and \$UTFCode<=0xDFFF) do={
# Surrogate pair
          :set Unicode  ((\$UTFCode & 0x3FF) << 10);
          :set UTFCode [:tonum \"0x\$[:pick \$JSONIn (\$Jpos+8) (\$Jpos+12)]\"];
          :set Unicode (\$Unicode | (\$UTFCode & 0x3FF) | 0x10000);
          :set TempString (\$TempString . [:pick \$JSONIn \$StartIdx \$Jpos] . [\$fUnicodeToUTF8 \$Unicode]);
          :set Jpos (\$Jpos + 12);
        } else= {
# Basic Multilingual Plane (BMP)
          :set Unicode \$UTFCode;
          :set TempString (\$TempString . [:pick \$JSONIn \$StartIdx \$Jpos] . [\$fUnicodeToUTF8 \$Unicode]);
          :set Jpos (\$Jpos + 6);
        }
        :set StartIdx \$Jpos;
        :if (\$Jdebug) do={:put \"fJParseString Unicode: \$Unicode\";}
      } else={
        :if (\$Char2 ~ \"[\\\\bfnrt\\\"]\") do={
          :if (\$Jdebug) do={:put \"fJParseString escape: Char+Char2 \$Char\$Char2\";}
          :set TempString (\$TempString . [:pick \$JSONIn \$StartIdx \$Jpos] . [[:parse \"(\\\"\\\\\$Char2\\\")\"]]);
          :set Jpos (\$Jpos + 2);
          :set StartIdx \$Jpos;
        } else={
          :if (\$Char2 = \"/\") do={
            :if (\$Jdebug) do={:put \"fJParseString /: Char+Char2 \$Char\$Char2\";}
            :set TempString (\$TempString . [:pick \$JSONIn \$StartIdx \$Jpos] . \"/\");
            :set Jpos (\$Jpos + 2);
            :set StartIdx \$Jpos;
          } else={
            #:put \"JParseFunctions.fJParseString script: Err.Raise 8732. Invalid escape\";
            :set Jpos (\$Jpos + 2);
          }
        }
      }
    } else={
      :set Jpos (\$Jpos + 1);
    }
    :set Char [:pick \$JSONIn \$Jpos];
  }
  :set TempString (\$TempString . [:pick \$JSONIn \$StartIdx \$Jpos]);
  :set Jpos (\$Jpos + 1);
  :if (\$Jdebug) do={:put \"fJParseString: \$TempString\";}
  :return \$TempString;
}}

#-------------------------------- fJParseNumber ---------------------------------------------------------------
:global fJParseNumber;
:if (!any \$fJParseNumber) do={ :global fJParseNumber do={
  :global Jpos;
  :local StartIdx;
  :global JSONIn;
  :global Jdebug;
  :local NumberString;
  :local Number;

  :set StartIdx \$Jpos;
  :set Jpos (\$Jpos + 1);
  :while (\$Jpos < [:len \$JSONIn] and [:pick \$JSONIn \$Jpos]~\"[eE0-9.+-]\") do={
    :set Jpos (\$Jpos + 1);
  }
  :set NumberString [:pick \$JSONIn \$StartIdx \$Jpos];
  :set Number [:tonum \$NumberString];
  :if ([:typeof \$Number] = \"num\") do={
    :if (\$Jdebug) do={:put \"fJParseNumber: StartIdx=\$StartIdx Jpos=\$Jpos \$Number (\$[:typeof \$Number])\"}
    :return \$Number;
  } else={
    :if (\$Jdebug) do={:put \"fJParseNumber: StartIdx=\$StartIdx Jpos=\$Jpos \$NumberString (\$[:typeof \$NumberString])\"}
    :return \$NumberString;
  }
}}

#-------------------------------- fJParseArray ---------------------------------------------------------------
:global fJParseArray;
:if (!any \$fJParseArray) do={ :global fJParseArray do={
  :global Jpos;
  :global JSONIn;
  :global Jdebug;
  :global fJParse;
  :global fJSkipWhitespace;
  :local Value;
  :local ParseArrayRet [:toarray \"\"];

  \$fJSkipWhitespace;
  :while (\$Jpos < [:len \$JSONIn] and [:pick \$JSONIn \$Jpos]!= \"]\") do={
    :set Value [\$fJParse true];
    :set (\$ParseArrayRet->([:len \$ParseArrayRet])) \$Value;
    :if (\$Jdebug) do={:put \"fJParseArray: Value=\"; :put \$Value;}
    \$fJSkipWhitespace;
    :if ([:pick \$JSONIn \$Jpos] = \",\") do={
      :set Jpos (\$Jpos + 1);
      \$fJSkipWhitespace;
    }
  }
  :set Jpos (\$Jpos + 1);
#  :if (\$Jdebug) do={:put \"ParseArrayRet: \"; :put \$ParseArrayRet}
  :return \$ParseArrayRet;
}}

# -------------------------------- fJParseObject ---------------------------------------------------------------
:global fJParseObject
:if (!any \$fJParseObject) do={ :global fJParseObject do={
  :global Jpos;
  :global JSONIn;
  :global Jdebug;
  :global fJSkipWhitespace;
  :global fJParseString;
  :global fJParse;
# Syntax :local ParseObjectRet ({}) does not work in recursive call, use [:toarray \"\"] for empty array!!!
  :local ParseObjectRet [:toarray \"\"];
  :local Key;
  :local Value;
  :local ExitDo false;
 
  \$fJSkipWhitespace;
  :while (\$Jpos < [:len \$JSONIn] and [:pick \$JSONIn \$Jpos]!=\"}\" and !\$ExitDo) do={
    :if ([:pick \$JSONIn \$Jpos]!=\"\\\"\") do={
      #:put \"JParseFunctions.fJParseObject script: Err.Raise 8732. Expecting property name\";
      :set ExitDo true;
    } else={
      :set Jpos (\$Jpos + 1);
      :set Key [\$fJParseString];
      \$fJSkipWhitespace;
      :if ([:pick \$JSONIn \$Jpos] != \":\") do={
        #:put \"JParseFunctions.fJParseObject script: Err.Raise 8732. Expecting : delimiter\";
        :set ExitDo true;
      } else={
        :set Jpos (\$Jpos + 1);
        :set Value [\$fJParse true];
        :set (\$ParseObjectRet->\$Key) \$Value;
        :if (\$Jdebug) do={:put \"fJParseObject: Key=\$Key Value=\"; :put \$Value;}
        \$fJSkipWhitespace;
        :if ([:pick \$JSONIn \$Jpos]=\",\") do={
          :set Jpos (\$Jpos + 1);
          \$fJSkipWhitespace;
        }
      }
    }
  }
  :set Jpos (\$Jpos + 1);
#  :if (\$Jdebug) do={:put \"ParseObjectRet: \"; :put \$ParseObjectRet;}
  :return \$ParseObjectRet;
}}

# ------------------- fByteToEscapeChar ----------------------
:global fByteToEscapeChar;
:if (!any \$fByteToEscapeChar) do={ :global fByteToEscapeChar do={
#  :set \$1 [:tonum \$1];
  :return [[:parse \"(\\\"\\\\\$[:pick \"0123456789ABCDEF\" ((\$1 >> 4) & 0xF)]\$[:pick \"0123456789ABCDEF\" (\$1 & 0xF)]\\\")\"]];
}}

# ------------------- fUnicodeToUTF8----------------------
:global fUnicodeToUTF8;
:if (!any \$fUnicodeToUTF8) do={ :global fUnicodeToUTF8 do={
  :global fByteToEscapeChar;
#  :local Ubytes [:tonum \$1];
  :local Nbyte;
  :local EscapeStr \"\";

  :if (\$1 < 0x80) do={
    :set EscapeStr [\$fByteToEscapeChar \$1];
  } else={
    :if (\$1 < 0x800) do={
      :set Nbyte 2;
    } else={ 
      :if (\$1 < 0x10000) do={
        :set Nbyte 3;
      } else={
        :if (\$1 < 0x20000) do={
          :set Nbyte 4;
        } else={
          :if (\$1 < 0x4000000) do={
            :set Nbyte 5;
          } else={
            :if (\$1 < 0x80000000) do={
              :set Nbyte 6;
            }
          }
        }
      }
    }
    :for i from=2 to=\$Nbyte do={
      :set EscapeStr ([\$fByteToEscapeChar (\$1 & 0x3F | 0x80)] . \$EscapeStr);
      :set \$1 (\$1 >> 6);
    }
    :set EscapeStr ([\$fByteToEscapeChar (((0xFF00 >> \$Nbyte) & 0xFF) | \$1)] . \$EscapeStr);
  }
  :return \$EscapeStr;
}}

# ------------------- End JParseFunctions----------------------

# ------------------- Base64EncodeFunct ----------------------

:global base64EncodeFunct do={ 

  #:put \"base64EncodeFunct arg b=\$stringVal\"

  :local charToDec [:toarray \"\"];
# newline character is needed
:set (\$charToDec->\"\\n\") \"10\";
:set (\$charToDec->\" \") \"32\";
:set (\$charToDec->\"!\") \"33\";
:set (\$charToDec->\"#\") \"35\";
:set (\$charToDec->\"\\\$\") \"36\";
:set (\$charToDec->\"%\") \"37\";
:set (\$charToDec->\"&\") \"38\";
:set (\$charToDec->\"'\") \"39\";
:set (\$charToDec->\"(\") \"40\";
:set (\$charToDec->\")\") \"41\";
:set (\$charToDec->\"*\") \"42\";
:set (\$charToDec->\"+\") \"43\";
:set (\$charToDec->\",\") \"44\";
:set (\$charToDec->\"-\") \"45\";
:set (\$charToDec->\".\") \"46\";
:set (\$charToDec->\"/\") \"47\";
:set (\$charToDec->\"0\") \"48\";
:set (\$charToDec->\"1\") \"49\";
:set (\$charToDec->\"2\") \"50\";
:set (\$charToDec->\"3\") \"51\";
:set (\$charToDec->\"4\") \"52\";
:set (\$charToDec->\"5\") \"53\";
:set (\$charToDec->\"6\") \"54\";
:set (\$charToDec->\"7\") \"55\";
:set (\$charToDec->\"8\") \"56\";
:set (\$charToDec->\"9\") \"57\";
:set (\$charToDec->\":\") \"58\";
:set (\$charToDec->\";\") \"59\";
:set (\$charToDec->\"<\") \"60\";
:set (\$charToDec->\"=\") \"61\";
:set (\$charToDec->\">\") \"62\";
:set (\$charToDec->\"?\") \"63\";
:set (\$charToDec->\"@\") \"64\";
:set (\$charToDec->\"A\") \"65\";
:set (\$charToDec->\"B\") \"66\";
:set (\$charToDec->\"C\") \"67\";
:set (\$charToDec->\"D\") \"68\";
:set (\$charToDec->\"E\") \"69\";
:set (\$charToDec->\"F\") \"70\";
:set (\$charToDec->\"G\") \"71\";
:set (\$charToDec->\"H\") \"72\";
:set (\$charToDec->\"I\") \"73\";
:set (\$charToDec->\"J\") \"74\";
:set (\$charToDec->\"K\") \"75\";
:set (\$charToDec->\"L\") \"76\";
:set (\$charToDec->\"M\") \"77\";
:set (\$charToDec->\"N\") \"78\";
:set (\$charToDec->\"O\") \"79\";
:set (\$charToDec->\"P\") \"80\";
:set (\$charToDec->\"Q\") \"81\";
:set (\$charToDec->\"R\") \"82\";
:set (\$charToDec->\"S\") \"83\";
:set (\$charToDec->\"T\") \"84\";
:set (\$charToDec->\"U\") \"85\";
:set (\$charToDec->\"V\") \"86\";
:set (\$charToDec->\"W\") \"87\";
:set (\$charToDec->\"X\") \"88\";
:set (\$charToDec->\"Y\") \"89\";
:set (\$charToDec->\"Z\") \"90\";
:set (\$charToDec->\"[\") \"91\";
:set (\$charToDec->\"]\") \"93\";
:set (\$charToDec->\"^\") \"94\";
:set (\$charToDec->\"_\") \"95\";
:set (\$charToDec->\"`\") \"96\";
:set (\$charToDec->\"a\") \"97\";
:set (\$charToDec->\"b\") \"98\";
:set (\$charToDec->\"c\") \"99\";
:set (\$charToDec->\"d\") \"100\";
:set (\$charToDec->\"e\") \"101\";
:set (\$charToDec->\"f\") \"102\";
:set (\$charToDec->\"g\") \"103\";
:set (\$charToDec->\"h\") \"104\";
:set (\$charToDec->\"i\") \"105\";
:set (\$charToDec->\"j\") \"106\";
:set (\$charToDec->\"k\") \"107\";
:set (\$charToDec->\"l\") \"108\";
:set (\$charToDec->\"m\") \"109\";
:set (\$charToDec->\"n\") \"110\";
:set (\$charToDec->\"o\") \"111\";
:set (\$charToDec->\"p\") \"112\";
:set (\$charToDec->\"q\") \"113\";
:set (\$charToDec->\"r\") \"114\";
:set (\$charToDec->\"s\") \"115\";
:set (\$charToDec->\"t\") \"116\";
:set (\$charToDec->\"u\") \"117\";
:set (\$charToDec->\"v\") \"118\";
:set (\$charToDec->\"w\") \"119\";
:set (\$charToDec->\"x\") \"120\";
:set (\$charToDec->\"y\") \"121\";
:set (\$charToDec->\"z\") \"122\";
:set (\$charToDec->\"{\") \"123\";
:set (\$charToDec->\"|\") \"124\";
:set (\$charToDec->\"}\") \"125\";
:set (\$charToDec->\"~\") \"126\";

  :local base64Chars [:toarray \"\"];
:set (\$base64Chars->\"0\") \"A\";
:set (\$base64Chars->\"1\") \"B\";
:set (\$base64Chars->\"2\") \"C\";
:set (\$base64Chars->\"3\") \"D\";
:set (\$base64Chars->\"4\") \"E\";
:set (\$base64Chars->\"5\") \"F\";
:set (\$base64Chars->\"6\") \"G\";
:set (\$base64Chars->\"7\") \"H\";
:set (\$base64Chars->\"8\") \"I\";
:set (\$base64Chars->\"9\") \"J\";
:set (\$base64Chars->\"10\") \"K\";
:set (\$base64Chars->\"11\") \"L\";
:set (\$base64Chars->\"12\") \"M\";
:set (\$base64Chars->\"13\") \"N\";
:set (\$base64Chars->\"14\") \"O\";
:set (\$base64Chars->\"15\") \"P\";
:set (\$base64Chars->\"16\") \"Q\";
:set (\$base64Chars->\"17\") \"R\";
:set (\$base64Chars->\"18\") \"S\";
:set (\$base64Chars->\"19\") \"T\";
:set (\$base64Chars->\"20\") \"U\";
:set (\$base64Chars->\"21\") \"V\";
:set (\$base64Chars->\"22\") \"W\";
:set (\$base64Chars->\"23\") \"X\";
:set (\$base64Chars->\"24\") \"Y\";
:set (\$base64Chars->\"25\") \"Z\";
:set (\$base64Chars->\"26\") \"a\";
:set (\$base64Chars->\"27\") \"b\";
:set (\$base64Chars->\"28\") \"c\";
:set (\$base64Chars->\"29\") \"d\";
:set (\$base64Chars->\"30\") \"e\";
:set (\$base64Chars->\"31\") \"f\";
:set (\$base64Chars->\"32\") \"g\";
:set (\$base64Chars->\"33\") \"h\";
:set (\$base64Chars->\"34\") \"i\";
:set (\$base64Chars->\"35\") \"j\";
:set (\$base64Chars->\"36\") \"k\";
:set (\$base64Chars->\"37\") \"l\";
:set (\$base64Chars->\"38\") \"m\";
:set (\$base64Chars->\"39\") \"n\";
:set (\$base64Chars->\"40\") \"o\";
:set (\$base64Chars->\"41\") \"p\";
:set (\$base64Chars->\"42\") \"q\";
:set (\$base64Chars->\"43\") \"r\";
:set (\$base64Chars->\"44\") \"s\";
:set (\$base64Chars->\"45\") \"t\";
:set (\$base64Chars->\"46\") \"u\";
:set (\$base64Chars->\"47\") \"v\";
:set (\$base64Chars->\"48\") \"w\";
:set (\$base64Chars->\"49\") \"x\";
:set (\$base64Chars->\"50\") \"y\";
:set (\$base64Chars->\"51\") \"z\";
:set (\$base64Chars->\"52\") \"0\";
:set (\$base64Chars->\"53\") \"1\";
:set (\$base64Chars->\"54\") \"2\";
:set (\$base64Chars->\"55\") \"3\";
:set (\$base64Chars->\"56\") \"4\";
:set (\$base64Chars->\"57\") \"5\";
:set (\$base64Chars->\"58\") \"6\";
:set (\$base64Chars->\"59\") \"7\";
:set (\$base64Chars->\"60\") \"8\";
:set (\$base64Chars->\"61\") \"9\";
:set (\$base64Chars->\"62\") \"+\";
:set (\$base64Chars->\"63\") \"/\";

#:put \$charToDec;
#:put \$base64Chars;

  :local rr \"\"; 
  :local p \"\";
  :local s \"\";
  :local cLenForString ([:len \$stringVal]);
  :local cModVal ( \$cLenForString % 3);
  :local stringLen ([:len \$stringVal]);
  :local returnVal;

  if (\$cLenForString > 0) do={
    :local startEncode 0;

    :if (\$cModVal > 0) do={
       for val from=(\$cModVal+1) to=3 do={
          :set p (\$p.\"=\"); 
          :set s (\$s.\"0\"); 
          :set cModVal (\$cModVal + 1);
        }
    }

    :local firstIndex 0;
    :while ( \$firstIndex < \$stringLen ) do={

        if ((\$cModVal > 0) && ((((\$cModVal / 3) *4) % 76) = 0) ) do={
          :set rr (\$rr . \"\\ r \\ n\");
        }

        :local charVal1 ([:pick \"\$stringVal\" \$firstIndex (\$firstIndex + 1)]);
        :local charVal2 ([:pick \$stringVal (\$firstIndex + 1) (\$firstIndex + 2)]);
        :local charVal3 ([:pick \$stringVal (\$firstIndex+2) (\$firstIndex + 3)]);

        :local n1Shift ([:tonum (\$charToDec->\$charVal1)] << 16);
        :local n2Shift ([:tonum (\$charToDec->\$charVal2)] << 8);
        :local n3Shift [:tonum (\$charToDec->\$charVal3)];

        :local mergeShift ((\$n1Shift +\$n2Shift) + \$n3Shift);

        :local n \$mergeShift;
        :set n ([:tonum \$n]);

        :local n1 (n >>> 18);

        :local n2 (n >>> 12);

        :local n3 (n >>> 6);
          
        :local arrayN [:toarray \"\" ];
        :set arrayN ( \$arrayN, (n1 & 63));
        :set arrayN ( \$arrayN, (n2 & 63));
        :set arrayN ( \$arrayN, (n3 & 63));
        :set arrayN ( \$arrayN, (n & 63));

        :set n (\$arrayN);

        :local n1Val ([:pick \$n 0]);
        :set n1Val ([:tostr \$n1Val]);

        :local n2Val ([:pick \$n 1]);
        :set n2Val ([:tostr \$n2Val]);

        :local n3Val ([:pick \$n 2]);
        :set n3Val ([:tostr \$n3Val]);

        :local n4Val ([:pick \$n 3]);
        :set n4Val ([:tostr \$n4Val]);
    
        :set rr (\$rr . ((\$base64Chars->\$n1Val) . (\$base64Chars->\$n2Val) . (\$base64Chars->\$n3Val) . (\$base64Chars->\$n4Val)));

        :set firstIndex (\$firstIndex + 3);
    }

    # checks for errors
    :do {

      :local rLen ([:len \$rr]);
      :local pLen ([:len \$p]);

      :set returnVal ([:pick \"\$rr\" 0 (\$rLen - \$pLen)]);
      :set returnVal (\$returnVal . \$p);
      :set startEncode 1;
      :return \$returnVal;
     
    } on-error={
      :set returnVal (\"Error: Base64 encode error.\");
      :return \$returnVal;
    }

  } else={
    :set returnVal (\"Error: Base64 encode error, likely an empty value.\");
    :return \$returnVal;
  }
  
}

:global urlEncodeFunct do={
  #:put \"\$currentUrlVal\"; 
  #:put \"\$urlVal\"

  :local urlEncoded;
  :for i from=0 to=([:len \$urlVal] - 1) do={
    :local char [:pick \$urlVal \$i]
    :if (\$char = \" \") do={
      :set char \"%20\"
    }
    :if (\$char = \"/\") do={
      :set char \"%2F\"
    }
    :if (\$char = \"-\") do={
      :set char \"%2D\"
    }
    :set urlEncoded (\$urlEncoded . \$char)
  }
  :local mergeUrl;
  :set mergeUrl (\$currentUrlVal . \$urlEncoded);
  :return (\$mergeUrl);

}
# function to split string by delimiter 
# usage: :put [\$Split \"Split\" \"i\"]; #result in: Spl;t
:global Split do={
  :local input \$1;
  :local delim \$2;
  :local strElem;
  :local arr [:toarray \"\"];
  :local arrIndex 0;

  :for c from=0 to=[:len \$input] do={
    :local ch [:pick \$input \$c (\$c+1)];
    if (\$ch = \$delim) do={
      if ([:len \$strElem] > 0) do={
        :set (\$arr->\$arrIndex) \$strElem;
        :set arrIndex (\$arrIndex+1);
        :set strElem \"\";
      }
    } else={
      :set strElem (\$strElem . \$ch);
    }
  }
  :set (\$arr->\$arrIndex) \$strElem;
  :return \$arr;
}

# routeros 0w0d0m0s to seconds
:global rosTsSec do={

  :local input \$1;
  :local upSeconds 0;
  :local weeks 0;
  if (([:find \$input \"w\"]) > 0 ) do={
    :set weeks ([:pick \$input 0 ([:find \$input \"w\"])]);
    :set input [:pick \$input ([:find \$input \"w\"]+1) [:len \$input]];
  }
  :local days 0;
  if (([:find \$input \"d\"]) > 0 ) do={
    :set days ([:pick \$input 0 [:find \$input \"d\"]]);
    :set input [:pick \$input ([:find \$input \"d\"]+1) [:len \$input]];
  }
  :local hours [:pick \$input 0 [:find \$input \":\"]];
  :set input [:pick \$input ([:find \$input \":\"]+1) [:len \$input]];
  :local minutes [:pick \$input 0 [:find \$input \":\"]];
  :set input [:pick \$input ([:find \$input \":\"]+1) [:len \$input]];
  :local upSecondVal 0;
  :set upSecondVal \$input;
  :set upSeconds value=[:tostr ((\$weeks*604800)+(\$days*86400)+(\$hours*3600)+(\$minutes*60)+\$upSecondVal)];
  return \$upSeconds;

}

# routeros timestamp string to seconds
:global rosTimestringSec do={

  :global Split;

  :local input \$1;

  # split the date and the time from \$input
  :local dateTimeSplit [\$Split \$input \" \"];

  # date Dec/21/2021 or dec/21/2021
  :local buildDate (\$dateTimeSplit->0);
  # time 11:53:05
  :local buildTimeValue (\$dateTimeSplit->1);

  # parse the date
  # this needs to conver tto UTC
  :local month [:pick \$buildDate 0 3];
  :local day [:pick \$buildDate 4 6];
  :local year [:pick \$buildDate 7 11];

  :local Months [:toarray \"Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec\"];
  :local months [:toarray \"jan,feb,mar,apr,may,jun,jul,aug,sep,oct,nov,dec\"];

  :local monthInt 0;

  # routeros uses lowercase and starting with uppercase strings for the 3 character month prefix
  for i from=0 to=([:len \$months] - 1) do={
    :local m (\$months->\$i);

    if (\$m = \$month) do={
      :set monthInt \$i;
    }

  }

  # routeros uses lowercase and starting with uppercase strings for the 3 character month prefix
  for i from=0 to=([:len \$Months] - 1) do={
    :local m (\$Months->\$i);

    if (\$m = \$month) do={
      :set monthInt \$i;
    }

  }

  # increment the monthInt by one because the index starts at 0
  :set monthInt (\$monthInt + 1);

  # convert the day and year to numbers
  :local dayInt [:tonum \$day];
  :local yearInt [:tonum \$year];

  # number of seconds since epoch
  # jan 1st 1970 UTC
  :local epochMonthInt 1;
  :local epochDayInt 1;
  :local epochYearInt 1970;

  # get the difference between now and then for the date parts
  :local monthDiff (\$monthInt - \$epochMonthInt);
  :local dayDiff (\$dayInt - \$epochDayInt);
  :local yearDiff (\$yearInt - \$epochYearInt);

  # for every 4 years add 1 day for leap years
  # routeros has no float support
  :local leapSecondsInDatePart 0;
  :local isFour 0;
  for i from=0 to=\$yearDiff do={

    :set isFour (\$isFour + 1);

    if (\$isFour = 4) do={
      # add one day of seconds
      :set leapSecondsInDatePart (\$leapSecondsInDatePart + (24 * 60 * 60));
      :set isFour 0;
    }

  }

  # convert to seconds
  # the months need to have their days calculated correctly
  # all have 31 except
  # feb has 28, and 29 in leap years
  # apr, jun, sep and nov have 30
  # in october this is ~3 days off
  :local monthDiffSec (\$monthDiff * 30 * 24 * 60 * 60);
  :local dayDiffSec (\$dayDiff * 24 * 60 * 60);
  :local yearDiffSec (\$yearDiff * 365 * 24 * 60 * 60);

  # get the date part difference in seconds since the unix epoch per field
  :local datePartDiffSec (\$monthDiffSec + \$dayDiffSec + \$yearDiffSec);

  # get the time parts
  :local hour [:tonum [:pick \$buildTimeValue 0 2]];
  :local minute [:tonum [:pick \$buildTimeValue 3 5]];
  :local second [:tonum [:pick \$buildTimeValue 6 8]];

  # convert the time parts to seconds
  :set hour (\$hour * 60 * 60);
  :set minute (\$minute * 60);

  # get the time part difference in seconds since the unix epoch per field
  :local timePartDiffSec (\$hour + \$minute + \$second);

  # return the sum of the seconds since epoch of the date and seconds in the time
  # with leap year days added
  :return (\$datePartDiffSec + \$timePartDiffSec + \$leapSecondsInDatePart);

}
:put \"\\t V0 Library loaded! (;\";"

 add dont-require-permissions=yes name=ispappLibraryV1 owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
############################### this file contain predefined functions to be used across the agent script ################################
# for checking purposes
:global ispappLibraryV1 \"ispappLibraryV1 loaded\";
:global login;
# Function to join array elements with a specified delimiter
# Example usage:
# :put [\$joinArray [\"a\" \"b\" \"c\"] \" - \"] // returns \"a - b - c\"
:global joinArray do={
    :local inputArray (\$1)
    :local delimiter (\$2)
    :local outputString \"\"
    if ([:typeof \$inputArray] != \"array\") do={
        :return [:tostr \$inputArray]
    }
    :foreach k,i in=\$inputArray do={
        if (\$k = 0) do={
            :set outputString (\$outputString .  \$i);
        } else={
            :set outputString (\$outputString . \$2 .  \$i);
        }
    }
    :return \$outputString;
}
# Func tion to fill rotatingkey sor emails and lastconfig in seconds
:global fillGlobalConsts do={
    :global lcf;
    :global outageIntervalSeconds;
    :global simpleRotatedKey;
    :global lastConfigChangeTsMs;
    :global updateIntervalSeconds;
    if ([:typeof \$1] != \"array\") do={:return \"error input type (not array)\";}
    :local configs \$1;
    /system scheduler enable [find name~\"ispappUpdate\" disabled=yes]
    if ([:len (\$configs->\"host\")] > 0) do={
        :set lcf (\$configs->\"host\"->\"lastConfigChangeTsMs\");
        :set outageIntervalSeconds [:tonum (\$configs->\"host\"->\"outageIntervalSeconds\")];
        :set updateIntervalSeconds [:tonum (\$configs->\"host\"->\"updateIntervalSeconds\")];
        :set simpleRotatedKey (\$configs->\"host\"->\"simpleRotatedKey\");
        if ([:len \$lcf] > 0) do={
            :set lastConfigChangeTsMs \$lcf;
        }
    }
    :return \"done updating Global Consts\";
}
# Function to collect all wireless interfaces and format them to be sent to server.
:global WirelessInterfacesConfigSync do={
    :global getAllConfigs;
    :global joinArray;
    :global ispappHTTPClient;
    if ([:len [/system script job find script~\"ispappUpdate\"]] > 0) do={
        :return {\"status\"=false; \"message\"=\"waiting update to finish first!\"};
    }
    :local getConfig do={
        # get configuration from the server
        :do {
            :global ispappHTTPClient;
            :global fillGlobalConsts;
            :local res;
            :local i 0;
            # :if ([\$ispappHTTPClient m=\"get\" a=\"update\"]->\"status\" = false) do={
            #     :return { \"response\"=\"first time config of server error\"; \"status\"=false };
            # }
            :while (([:len [:find [:tostr \$res] \"Err.Raise\"]] != 0 || [:len \$res] = 0) && \$i < 3) do={
                :set res ([\$ispappHTTPClient m=\"get\" a=\"config\"]->\"parsed\");
                :delay 1s;
                :set i (\$i + 1);
            }
            if ([:len [:find [:tostr \$res] \"Err.Raise\"]] != 0) do={
                # check id json received is valid and redy to be used
                :log error \"error while getting config (Err.Raise fJSONLoads)\";
                :return {\"status\"=false; \"message\"=\"error while getting config (Err.Raise fJSONLoads)\"};
            } else={
                :if (\$res->\"host\"->\"Authed\" != true) do={
                    :log error [:tostr \$res];
                    :return {\"status\"=false; \"message\"=\$res};
                } else={
                    :log info \"check id json received is valid and ready to be used with response: \$res\";
                    :put [\$fillGlobalConsts \$res];
                    :return { \"response\"=\$res; \"status\"=true };
                }
            }
        } on-error={
            :log error \"error while getting config (Err.Raise fJSONLoads)\";
            :return {\"status\"=false; \"message\"=\"error while getting config\"};
        }
    };
    :local getLocalWlans do={
        # collect all wireless interfaces from the system
        # format them to be sent to server
        :log info \"start collect all wireless interfaces from the system ...\";
        :local wlans [[:parse \"/interface wireless print as-value\"]];
        :if ([:len \$wlans] > 0) do={
            :local getEncKey do={
                if ([:len (\$1->\"wpa-pre-shared-key\")] > 0) do={
                    :return (\$1->\"wpa-pre-shared-key\");
                } else={
                    if ([:len (\$1->\"wpa2-pre-shared-key\")] > 0) do={
                        :return (\$1->\"wpa2-pre-shared-key\");
                    } else={
                        :return \"\";
                    }
                }
            }
            :local getmaster do={
                if (\$1->\"interface-type\" = \"virtual\") do={
                    :return (\$1->\"master-interface\");
                } else={
                    :return (\$1->\"interface-type\");
                }
            };
            :local wirelessConfigs ({});
            foreach i,k in=\$wlans do={
                :local getdisabled [:parse \"/interface wireless get \\\$1 disabled\"];
                :local isdisabled [\$getdisabled (\$k->\"name\")];
                :set (\$wirelessConfigs->\$i) {
                    \".id\"=(\$k->\".id\");
                    \"if\"=(\$k->\"name\");
                    \"technology\"=\"wireless\";
                    \"key\"=[\$getEncKey (\$k->\"security-profile\")];
                    \"ssid\"=(\$k->\"ssid\");
                    \"band\"=(\$k->\"band\");
                    \"interface-type\"=(\$k->\"interface-type\");
                    \"mac-address\"=(\$k->\"mac-address\");
                    \"master-interface\"=[\$getmaster \$k];
                    \"security-profile\"=(\$k->\"security-profile\");
                    \"disabled\"=\$isdisabled;
                    \"running\"=(!\$isdisabled);
                    \"hide-ssid\"=(\$k->\"hide-ssid\")
                };
            }
            :log info \"collect all wireless interfaces from the system\";
            :return { \"status\"=true; \"wirelessConfigs\"=\$wirelessConfigs };
         } else={
            :log info \"collect all wireless interfaces from the system: no wireless interfaces found\";
            :return { \"status\"=false; \"message\"=\"no wireless interfaces found\" };
         }
    };
    :log info \"done setting local functions .... 1s\"
    # check if our host is authorized to get configuration
    # and ready to accept interface syncronization
    :local configresponse [\$getConfig];
    :local output;
    :local wirelessConfigs ({});
    :if (\$configresponse->\"status\" = true) do={
        :set wirelessConfigs (\$configresponse->\"response\"->\"host\"->\"wirelessConfigs\");
    }
    :log info \"done setting wirelessConfigs .... 1s\"
    if ([:len \$wirelessConfigs] > 0) do={
        # this is the case when some interface configs received from the host
        # get security profile with same password as the one on first argument \$1
        :global SyncSecProfile do={
            # add security profile if not found
            :do {
                :local key (\$1->\"key\");
                # search for profile with this same password if exist if not just create it.
                :local currentProfilesAtPassword do={
                    :local currentprfwpa2 [:parse \"/interface wireless security-profiles print as-value where wpa2-pre-shared-key=\\\$1\"];
                    :local currentprfwpa [:parse \"/interface wireless security-profiles print as-value where wpa-pre-shared-key=\\\$1\"];
                    :local secpp2 [\$currentprfwpa2 \$1];
                    :local secpp [\$currentprfwpa \$1];
                    :if ([:len \$secpp2] > 0) do={
                        :return \$secpp2;
                    } else={
                        :return \$secpp;
                    }
                };
                # todo: separation of sec profiles ....
                :local foundSecProfiles [\$currentProfilesAtPassword \$key]; # error 
                :log info \"add security profile if not found: \$tempName\";
                if ([:len \$foundSecProfiles] > 0) do={
                    :return (\$foundSecProfiles->0->\"name\");
                } else={
                     :local addSec  [:parse \"/interface wireless security-profiles add \\\\
                        mode=dynamic-keys \\\\
                        name=(\\\"ispapp_\\\" . (\\\$1->\\\"ssid\\\")) \\\\
                        wpa2-pre-shared-key=(\\\$1->\\\"encKey\\\") \\\\
                        wpa-pre-shared-key=(\\\$1->\\\"encKey\\\") \\\\
                        authentication-types=wpa2-psk,wpa-psk\"];
                    :put [\$addSec \$1];
                    :return \$tempName;
                }
            } on-error={
                # return the default dec profile in case of error
                # adding or updating to perform interface setup with no problems
                :return [[:parse \"/interface wireless security-profiles get *0 name\"]];
            }
        }
        :global convertToValidFormat;
        ## start comparing local and remote configs
        foreach conf in=\$wirelessConfigs do={
            :log info \"## start comparing local and remote configs ##\";
            :local finditf [:parse \"/interface wireless find ssid=\\\$1\"];
            :local existedinterf [\$finditf (\$conf->\"ssid\")];
            :local newSecProfile [\$SyncSecProfile \$conf];
            if ([:len \$existedinterf] = 0) do={
                # add new interface
                :local NewInterName (\"ispapp_\" . [\$convertToValidFormat (\$conf->\"ssid\")]);
                :local masterinterface [[:parse \"/interface wireless get ([/interface wireless find]->0) name\"]];
                :log info \"## add new interface -> \$NewInterName ##\";
                :local addInter [:parse \"/interface wireless add \\\\
                    ssid=(\\\$1->\\\"ssid\\\") \\\\
                    wireless-protocol=802.11 frequency=auto mode=ap-bridge hide-ssid=no comment=ispapp \\\\
                    security-profile=(\\\$1->\\\"newSecProfile\\\") \\\\
                    name=(\\\$1->\\\"NewInterName\\\") \\\\
                    disabled=no;\"];
                :local newinterface (\$conf + {\"newSecProfile\"=\$newSecProfile; \"NewInterName\"=\$NewInterName});
                :log debug (\"new interface details \\n\" . [:tostr \$newinterface]);
                :put [\$addInter \$newinterface];
                :delay 3s; # wait for interface to be created
                :log info \"## wait for interface to be created 3s ##\";
            } else={
                :local setInter [:parse \"/interface wireless set \\\$2 \\\\
                    ssid=(\\\$1->\\\"ssid\\\") \\\\
                    wireless-protocol=802.11 frequency=auto mode=ap-bridge hide-ssid=no comment=ispapp \\\\
                    security-profile=(\\\$1->\\\"newSecProfile\\\") \\\\
                    name=(\\\$1->\\\"NewInterName\\\") \\\\
                    disabled=no;\"];
                # set the first interface to the new config
                :local newSecProfile [\$SyncSecProfile \$conf];
                :local NewInterName (\"ispapp_\" . [\$convertToValidFormat (\$conf->\"ssid\")]);
                :log info \"## update new interface -> \$NewInterName ##\";
                [\$setInter (\$conf + {\"newSecProfile\"=\$newSecProfile; \"NewInterName\"=\$NewInterName}) (\$existedinterf->0)];
                :delay 3s; # wait for interface to be setted
                :log info \"## wait for interface to be created 3s ##\";
                if ([:len \$existedinterf] > 1) do={
                    # remove all interfaces except the first one
                    :foreach k,intfid in=\$existedinterf do={
                        if (\$k != 0) do={
                            [[:parse \"/interface wireless remove [/interface wireless get \$intfid name]\"]];
                            :delay 1s; # wait for interface to be removed
                        }
                    }
                }
            }
        }
        :local message (\"syncronization of \" . [:len \$wirelessConfigs] . \" interfaces completed\");
        :log info \$message;
        :set output {
            \"status\"=true;
            \"message0\"=\$message;
            \"configs\"=\$wirelessConfigs
        };
    }
    :local localwirelessConfigs [\$getLocalWlans];
    if (\$localwirelessConfigs->\"status\" = true) do={
        ## start uploading local configs to host
        # item sended example from local: \"{\\\"if\\\":\\\"\$wIfName\\\",\\\"ssid\\\":\\\"\$wIfSsid\\\",\\\"key\\\":\\\"\$wIfKey\\\",\\\"keytypes\\\":\\\"\$wIfKeyTypeString\\\"}\"
        :log info \"## wait for interfaces changes to be applied and can be retrieved from the device 5s ##\";
        :delay 1s; # wait for interfaces changes to be applied and can be retrieved from the device
        :local SecProfileslocalConfigs ({}); 
        :foreach k,secid in=[[:parse \"/interface wireless security-profile print as-value\"]] do={
            :local authtypes (\$secid->\"authentication-types\");
            :local isdefault [:parse \"/interface wireless security-profile get \$k default\"];
            :if ([:len \$authtypes] = 0) do={ :set authtypes \"[]\";}
            :set (\$SecProfileslocalConfigs->\$k) (\$secid+{
                \"authentication-types\"=\$authtypes;
                \"technology\"=\"wireless\";
                \"isdefault\"=[\$isdefault]
            });
        };
        :local sentbody \"{}\";
        :local message (\"uploading \" . [:len (\$localwirelessConfigs->\"wirelessConfigs\")] . \" interfaces to ispapp server\");
        :if ([:len (\$localwirelessConfigs->\"wirelessConfigs\")] = 0) do={
            :set (\$localwirelessConfigs->\"wirelessConfigs\") \"[]\";
        }
        :if ([:len \$SecProfileslocalConfigs] = 0) do={
            :set SecProfileslocalConfigs \"[]\";
        }
        :global ispappHTTPClient;
        :local ifwconfigs (\$localwirelessConfigs->\"wirelessConfigs\");
        :set sentbody ([\$getAllConfigs \$ifwconfigs \$SecProfileslocalConfigs]->\"json\");
        :local returned  [\$ispappHTTPClient m=post a=config b=\$sentbody];
        :return (\$output+{
            \"status\"=true;
            \"body\"=\$sentbody;
            \"response\"=\$returned;
            \"message1\"=\$message
        });
    } else={
        :log info \"no local wireless interfaces found (from WirelessInterfacesConfigSync function in ispLibrary.rsc)\";
        :return (\$output+{
            \"status\"=true;
            \"message1\"=\"no wireless interfaces found\"
        });
    }
};
# Function to Download and return parsed RSADV CA.
:global latestCerts do={
    :local SectigoRSADVBundle;
    :set SectigoRSADVBundle [/tool  fetch http-method=get mode=https url=\"https://gogetssl-cdn.s3.eu-central-1.amazonaws.com/wiki/SectigoRSADVBundle.txt\"  as-value output=user];
    :set SectigoRSADVBundle (\$SectigoRSADVBundle->\"data\")
    :set SectigoRSADVBundle [:pick \$SectigoRSADVBundle 0 ([:find \$SectigoRSADVBundle \"-----END CERTIFICATE-----\"] + 26)];
    :return { \"DV\"=\$SectigoRSADVBundle }
};

# Function to prepare ssl connection to ispappHTTPClient
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

# Converts a mixed array into a JSON string.
# Handles arrays, numbers, and strings up to 3 tested levels deep (it can do more levels now).
# Useful for converting RouterOS scripting language arrays into JSON.
:global toJson do={
  :local Aarray \$1;
  :local IsArray false;
  if ([:typeof \$Aarray] = \"array\") do={
    :set IsArray (([:find \$Aarray [:pick \$Aarray 0]] = 0) && ([:find \$Aarray [:pick \$Aarray ([:len \$Aarray] - 1)]] = ([:len \$Aarray] - 1)));
  } else={
     :if ([:typeof \$Aarray] = \"num\") do={
        :return \$Aarray;
     } else={
        :return \"\\\"\$Aarray\\\"\";
     }
  }
  :local AjsonString \"\";
  if ((any \$2) && ([:typeof \$2] != \"num\")) do={
    if (\$IsArray) do={
      :set AjsonString \"\\\"\$2\\\":[\";
    } else={
      :set AjsonString \"\\\"\$2\\\":{\";
    }
  } else={
    if (\$IsArray) do={
    :set AjsonString \"[\";
    } else={
      :set AjsonString \"{\";
    }
  }
  :local idx 0;
  :foreach Akey,Avalue in=\$Aarray do={
    :if ([:typeof \$Avalue] = \"array\") do={
        :global toJson;
        :local v [\$toJson \$Avalue \$Akey];
        :local AvalueJson \$v;
        :set AjsonString \"\$AjsonString\$AvalueJson\";
    } else={
        if (\$IsArray) do={
            :if ([:typeof \$Avalue] = \"num\" || [:typeof \$Avalue] = \"bool\") do={
                :set AjsonString \"\$AjsonString\$Avalue\";
            } else={
                :set AjsonString \"\$AjsonString\\\"\$Avalue\\\"\";
            }
        } else={
            :if ([:typeof \$Avalue] = \"num\") do={
                :set AjsonString \"\$AjsonString\\\"\$Akey\\\":\$Avalue\";
            } else={
                 :if (\$Avalue = \"[]\" || \$Avalue = \"{}\" || ([:typeof \$Avalue] = \"bool\")) do={
                    :set AjsonString \"\$AjsonString\\\"\$Akey\\\":\$Avalue\";
                } else={
                    :set AjsonString \"\$AjsonString\\\"\$Akey\\\":\\\"\$Avalue\\\"\";
                }
            }
        }
    }
    if (\$idx < ([:len \$Aarray] - 1)) do={
        :set AjsonString \"\$AjsonString,\";
    }
    :set idx (\$idx + 1);
  }
  if (\$IsArray) do={
    :set AjsonString \"\$AjsonString]\";
  } else={
    :set AjsonString \"\$AjsonString}\";
  }
  :return \$AjsonString;
}

# @Details: Function to Diagnose important global variable for agent connection
# @Syntax: \$TopVariablesDiagnose
# @Example: :put [\$TopVariablesDiagnose] or just \$TopVariablesDiagnose
:global TopVariablesDiagnose do={
    :global prepareSSL;
    :local sslPreparation [\$prepareSSL];
    :global topDomain;
    :global topKey;
    :global login;
    :global certCheck \"no\";
    :global topSmtpPort;
    :global startEncode;
    :global isSend;
    :global rosMajorVersion;
    :global topListenerPort;
    # check if method argument is provided
    if ((\$sslPreparation->\"ntpStatus\" = true) && (\$sslPreparation->\"caStatus\" = true)) do={
        :set certCheck \"yes\";
        :log info \"ssl preparation is completed with success!\";
    }
    :local res {\"topListenerPort\"=\$topListenerPort; \"topDomain\"=\$topDomain; \"login\"=\$login};
    # try recover the cridentials from the file if exist.
    :if ([:len [/system script find name~\"ispapp_cridentials\"]] > 0) do={
        /system script run [find name~\"ispapp_cridentials\"];
    }
    # Check if topListenerPort is not set and assign a default value if not set
    :if (!any \$topListenerPort) do={
      :set topListenerPort 8550;
    }
    :if ((!any \$startEncode) || (!any \$isSend)) do={
        :set startEncode 1;
        :set isSend 1;
    }
    # Check if topDomain is not set and assign a default value if not set
    :if (!any \$topDomain) do={
      :set topDomain \"qwer.ispapp.co\"
    }
    :if (!any \$topSmtpPort) do={
      :set topSmtpPort 8465;
    }
    :if (any\$topDomain) do={
        :local setserver [:parse \"/tool e-mail set server=(\\\$1)\"]
        :local setaddress [:parse \"/tool e-mail set address=(\\\$1)\"]
        :if (any([/tool e-mail print as-value]->\"server\")) do={
          :put [\$setserver \$topDomain]
        } else={
          :put [\$setaddress \$topDomain]
        }
    }
    :if (any\$topSmtpPort && ([/tool e-mail get port] != \$topSmtpPort)) do={
        /tool e-mail set port=([:tonum \$topSmtpPort]);
    }
    :if (!any\$rosMajorVersion) do={
        :local ROSver value=[:tostr [/system resource get value-name=version]];
        :local ROSverH value=[:pick \$ROSver 0 ([:find \$ROSver \".\" -1]) ];
        :set rosMajorVersion value=[:tonum \$ROSverH];
        :if (\$rosMajorVersion = 7) do={
            :local settls [:parse \"/tool e-mail set tls=yes\"];
            :log info [\$settls];
        }
    }
  :set res {\"topListenerPort\"=\$topListenerPort; \"topDomain\"=\$topDomain; \"login\"=\$login};
  :return \$res;
}

# Function to remove all scripts from the system related to ispapp agent
# usage:
#   [\$removeIspappScripts] // don't expect no returns check just the logs after.
:global removeIspappScripts do={
    :local scriptList [/system script find where name~\"ispapp.*\"]
    if ([:len [/system script find where name~\"ispapp.*\"]] > 0) do={
        :foreach scriptId in=\$scriptList do={
            :local scriptName [/system script get \$scriptId name];
            :do {
                /system script remove \$scriptId;
                :put \"found \$scriptName.rsc and removed \\E2\\9C\\85\";
                :log info \"found \$scriptName and removed \\E2\\9C\\85\";
                :delay 500ms;
            } on-error={
                :log error \"\\E2\\9D\\8C Could not remove script id \$scriptId: \$scriptName.rsc\";
            }
        }
    }
}

# Function to remove all schedulers from the system related to ispapp agent
# usage:
#   [\$removeIspappSchedulers] // don't expect no returns check just the logs after.
:global removeIspappSchedulers do={
    :local scriptList [/system scheduler find where name~\"ispapp.*\"]
    if ([:len [/system scheduler find where name~\"ispapp.*\"]] > 0) do={
        :foreach schedulerId in=\$schedulerList do={
            :do {
                /system scheduler remove \$schedulerId;
                :put \"found \$schedulerName and removed \\E2\\9C\\85\";
                :log info \"found \$schedulerName and removed \\E2\\9C\\85\";
                :delay 500ms;
            } on-error={
                :local schedulerName [/system scheduler get \$schedulerId name];
                :log error \"\\E2\\9D\\8C Could not remove scheduler id \$schedulerId: \$schedulerName\";
            }
        }
    }
}

# Function to simplify fJParse usage;
# usage:
#   :put [\$JSONLoads \"{\\\"hello\\\":\\\"world\\\"}\"];
:global JSONLoads do={
    :global JSONIn \$1;
    :global fJParse;
    :local ret [\$fJParse];
    :set JSONIn;
    :global Jpos;
    :global Jdebug; if (!\$Jdebug) do={set Jdebug};
    :return \$ret;
}

# Function that takes a string as an input and converts it to the desired format
# Example usage:
# :put [\$convertToValidFormat \"this_is_a_Test! @#?/string\"] // returns \"this_is_a_Test______string\"
:global convertToValidFormat do={
    :local inputString (\$1)
    :local validCharacters \"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_\"
    :local outputString \"\"
    
    :local length [:len \$inputString]
    :local i 0
    :while (\$i < \$length) do={
        :local currentCharacter [:pick \$inputString \$i]
        :if ([:typeof [:find \$validCharacters \$currentCharacter]] = \"num\") do={
            :set outputString (\$outputString . \$currentCharacter)
        } else={
            :set outputString (\$outputString . \"_\")
        }
        :set i (\$i + 1)
    }
    :return \$outputString;
}


# Function in RouterOS script that formats the authentication types as per the specified rules
# Example usage:
# :put [\$formatAuthTypes \"wpa-psk wpa2-psk wpa3-eap wpa2-eap\"]
:global formatAuthTypes do={
    :local inputTypes (\$1)
    :local validTypesArr [:toarray \"wpa-eap, wpa-psk, wpa2-eap, wpa2-psk\"];
    :local outputTypes \"\"
    :local typesArr \"\";
    :for i from=0 to=[:len \$inputTypes] do={
        :if ([:pick \$inputTypes \$i] = \" \" || [:pick \$inputTypes \$i] = \";\") do={
            :set typesArr (\$typesArr. \", \");
        } else={
            :set typesArr (\$typesArr. [:pick \$inputTypes \$i]);
        }
    }
    :set typesArr [:toarray \$typesArr];
    :foreach atype in=\$typesArr do={
        :if ([:typeof [:find \$validTypesArr \$atype]] = \"num\") do={
            :if (\$outputTypes = \"\") do={
                :set outputTypes \$atype;
            } else={
                :set outputTypes (\$outputTypes . \",\" . \$atype);
            }
        }
    }
    :return \$outputTypes;
}

# Ispapp HTTP Client
# Usage:
#   :put [\$ispappHTTPClient m=<get|post|put|delete> a=<update|config> b=<json>]
:global ispappHTTPClient do={
    :local method \$m; # method
    :local action \$a; # action
    :local body \$b; # body
    :local certCheck;
    :global topDomain;
    :global topKey;
    :global login;
    :global topListenerPort;
    :if (!any\$certCheck) do={
        :set certCheck \"no\";
    }
    # get current time and format it
    :local time [/system clock print as-value];
    :local formattedTime ((\$time->\"date\") . \" | \" . (\$time->\"time\"));
    :local actions (\"update\", \"config\", \"/v1/host_fw\", \"bandwidth\");
    if (!any \$m) do={
        :set method \"get\";
    }
    # check if action was provided  
    if (!any \$a) do={
        :set action \"config\";
        :log warning (\"default action added!\\t ispappLibrary.rsc\\t[\" . \$formattedTime . \"] !\\tusage: (ispappHTTPClient a=<update|config> b=<json>  m=<get|post|put|delete>)\");
    }
    # check if key was provided if not run ispappSet
    if (!any \$topKey) do={
        :set topKey; 
    }
    # Check if topListenerPort is not set and assign a default value if not set
    :if (!any \$topListenerPort) do={
        :set topListenerPort 8550;
    }
    # Check if topDomain is not set and assign a default value if not set
    :if (!any \$topDomain) do={
        :set topDomain \"qwer.ispapp.co\";
    }
    # Check certificates
    # Make request
    :local out;
    :local requesturl;
    :do {
        :global login;
        :set requesturl \"https://\$topDomain:\$topListenerPort/\$action?login=\$login&key=\$topKey\";
        :log info \"Request details: \\n\\t\$requesturl \\n\\t http-method=\\\"\$m\\\" \\n\\t http-data=\\\"\$b\\\"\";
        if (!any \$b) do={
            :set out [/tool fetch url=\$requesturl check-certificate=\$certCheck http-method=\$m output=user as-value];
        } else={
            :set out [/tool fetch url=\$requesturl check-certificate=\$certCheck http-header-field=\"cache-control: no-cache, content-type: application/json, Accept: */*\" http-method=\"\$m\" http-data=\"\$b\" output=user as-value];
        }
        if (\$out->\"status\" = \"finished\") do={
            :global JSONLoads;
            :local receieved (\$out->\"data\");
            if ([:len \$receieved] = 0) do={
                :set receieved \"{}\";
            }
            :local parses [\$JSONLoads \$receieved];
            :return { \"status\"=true; \"response\"=(\$out->\"data\"); \"parsed\"=\$parses; \"requestUrl\"=\$requesturl };
        } else={
            :return { \"status\"=false; \"reason\"=(\$out); \"requestUrl\"=\$requesturl };
        }
    } on-error={
        :return { \"status\"=false; \"reason\"=(\$out->\"status\"); \"requestUrl\"=\"https://\$topDomain:\$topListenerPort/\$action?login=\$login&key=\$topKey\" };
    }
}
:put \"\\t V1 Library loaded! (;\";"

 add dont-require-permissions=yes name=ispappLibraryV2 owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="

# for checking purposes
:global ispappLibraryV2 \"ispappLibraryV2 loaded\";
# Function to get timestamp in seconds, minutes, hours, or days
# save it in a global variable to get diff between it and the current timestamp.
# synctax:
#       :put [\$getTimestamp <s|m|d|h> <your saved timestamp variable to get diff>]
:global getTimestamp do={
    :local format \$1;
    :local out;
    :local time2parse [:timestamp]
    :local w [:find \$time2parse \"w\"]
    :local d [:find \$time2parse \"d\"]
    :local c [:find \$time2parse \":\"]
    :local p [:find \$time2parse \".\"]
    :local weeks [:pick \$time2parse 0 [\$w]]
    :set \$weeks [:tonum (\$weeks * 604800)]
    :local days [:pick \$time2parse (\$w + 1) \$d]
    :set days [:tonum (\$days * 86400)]
    :local hours [:pick \$time2parse (\$d + 1) \$c]
    :set hours [:tonum (\$hours * 3600)]
    :local minutes [:pick \$time2parse (\$c + 1) [:find \$time2parse (\$c + 3)]]
    :set minutes [:tonum (\$minutes * 60)]
    :local seconds [:pick \$time2parse (\$c + 4) \$p]
    :local rawtime (\$weeks+\$days+\$hours+\$minutes+\$seconds)
    :local current (\$weeks+\$days+\$hours+\$minutes+\$seconds)
    :global lastTimestamp \$lastTimestamp;
    if ([:typeof \$2] = \"num\") do={
        :set lastTimestamp \$2;
    }
    :if (\$format = \"s\") do={
      :local diff (\$rawtime - \$lastTimestamp);
      :set out { \"current\"=\$current; \"diff\"=\$diff;}
      :global lastTimestamp \$rawtime;
      :return \$out;
    } else={
      :if (\$format = \"m\") do={
           :local diff ((\$rawtime - \$lastTimestamp)/60);
           :set out { \"current\"=\$current; \"diff\"=\$diff }
           :global lastTimestamp \$rawtime;
           :return \$out;
      } else={
        :if (\$format = \"h\") do={
           :local diff ((\$rawtime - \$lastTimestamp)/3600);
           :set out { \"current\"=\$current; \"diff\"=\$diff }
           :global lastTimestamp \$rawtime;
           :return \$out;
        } else={
          :if (\$format = \"d\") do={
               :local diff ((\$rawtime - \$lastTimestamp)/86400);
               :set out { \"current\"=\$current; \"diff\"=\$diff }
               :global lastTimestamp \$rawtime;
               :return \$out;
          } else={
              :local diff (\$rawtime - \$lastTimestamp);
              :set out { \"current\"=\$current; \"diff\"=\$diff }
              :global lastTimestamp \$rawtime;
              :return \$out;
          }
        }
      }
    }
}
# Function to get router board infos if exist;
:global getRouterboard do={
  :do {
    :local boardinfos [/system routerboard print as-value];
    :return {
      \"mn\"=(\$boardinfos->\"model\");
      \"sn\"=(\$boardinfos->\"serial-number\")
    };
  } on-error={
    :return {
      \"mn\"=\"CHR\";
      \"sn\"=\"CHR\"
    };
  }
}
# Function to collect all information needed yo be sent to config endpoint
# usage: 
#   :put [\$getAllConfigs <interfacesinfos array>] 
:global getAllConfigs do={
    :do {
        :global getRouterboard;
        :global rosTimestringSec;
        :global toJson;
        :global lastConfigChangeTsMs;
        :global getPublicIp;
        :global topClientInfo;
        :local data;
        :local resources [/system resource get];
        :local osbuilddate [\$rosTimestringSec (\$resources->\"build-time\")];
        :local interfaces ({});
        foreach k,v in=[/interface find] do={
            :local Name [/interface get \$v name];
            :local Mac [/interface get \$v mac-address];
            :local DefaultName [:parse \"/interface get \\\$1 default-name\"];
            :set (\$interfaces->\$k) {
                \"if\"=\$Name;
                \"mac\"=\$Mac;
                \"defaultIf\"=[\$DefaultName \$v]
            };
        }
        :local hdwModelN \"\";
        :local hdwSerialN \"\";
        if ([:len \$lastConfigChangeTsMs] = 0) do={
          :set lastConfigChangeTsMs \$osbuilddate;
        }
        :set data {
            \"clientInfo\"=\$topClientInfo;
            \"osVersion\"=(\$resources->\"version\");
            \"os\"=[/system package get 0 name];
            \"hardwareMake\"=(\$resources->\"platform\");
            \"hardwareModel\"=(\$resources->\"board-name\");
            \"hardwareModelNumber\"=([\$getRouterboard]->\"mn\");
            \"hardwareSerialNumber\"=([\$getRouterboard]->\"sn\");
            \"hardwareCpuInfo\"=(\$resources->\"cpu\");
            \"osBuildDate\"=\$osbuilddate;
            \"hostname\"=[:tostr [/system identity get name]];
            \"wirelessConfigured\"=\$1;
            \"webshellSupport\"=true;
            \"uptime\"=\$osbuilddate;
            \"firmwareUpgradeSupport\"=true;
            \"wirelessSupport\"=true;
            \"sequenceNumber\"=([:tonum [/system script get ispappConfig run-count]] + 1);
            \"interfaces\"=\$interfaces;
            \"security-profiles\"=\$2;
            \"lastConfigRequest\"=[:tonum \$lastConfigChangeTsMs];
            \"bandwidthTestSupport\"=true;
            \"outsideIp\"=[\$getPublicIp];
            \"usingWebSocket\"=false;
            \"fw\"=\$topClientInfo
        };
        :local json [\$toJson \$data];
        :log info \"Configs body json created with success (getAllConfigsFigs function -> true).\";
        :return {\"status\"=true; \"json\"=\$json};
    } on-error={
        :log error \"faild to build config json object!\";
        :return {\"status\"=false; \"reason\"=\"faild to build config json object!\"};
    }
}

# a function to persist variables in a script called ispapp_credentials
:global savecredentials do={
  :global topKey;
  :global topDomain;
  :global topClientInfo;
  :global topListenerPort;
  :global topServerPort;
  :global topSmtpPort;
  :global txAvg;
  :global rxAvg;
  :global ipbandswtestserver;
  :global btuser;
  :global btpwd;
  :global login;
  :global librarylastversion;
  /system script remove [find name~\"ispapp_credentials\"]
  :local cridentials \"\\n:global topKey \$topKey;\\r\\
    \\n:global topDomain \$topDomain;\\r\\
    \\n:global topClientInfo \$topClientInfo;\\r\\
    \\n:global topListenerPort \$topListenerPort;\\r\\
    \\n:global topServerPort \$topServerPort;\\r\\
    \\n:global topSmtpPort \$topSmtpPort;\\r\\
    \\n:global txAvg 0;\\r\\
    \\n:global rxAvg 0;\\r\\
    \\n:global ipbandswtestserver \$ipbandswtestserver;\\r\\
    \\n:global btuser \$btuser;\\r\\
    \\n:global login \$login;\\r\\
    \\n:global librarylastversion \$librarylastversion;\\r\\
    \\n:global btpwd \$btpwd;\"
  /system script add name=ispapp_credentials source=\$cridentials
  :log info \"ispapp_credentials updated!\";
  :return \"ispapp_credentials updated!\";
}
# collect cpu load and calculates avrg of 5 and 15
:global getCpuLoads do={
  :do {
    :global cpularray;
    :local Array5 [:pick \$cpularray 0 5];
    :local Array15 [:pick \$cpularray 0 15];
    :local someArray5 0;
    :local someArray15 0;
    :foreach k in=\$Array15 do={ :set someArray15 (\$k+\$someArray15); }
    :foreach k in=\$Array5 do={ :set someArray5 (\$k+\$someArray5); }
    :set cpularray (\$cpularray, [:tonum [/system resource get cpu-load]]);
    :set cpularray [:pick \$cpularray ([:len \$cpularray] - 15) [:len \$cpularray]];
    :return {
      \"cpuLoadOne\"=[/system resource get cpu-load];
      \"cpuLoadFive\"=(\$someArray5 / [:len \$Array5]);
      \"cpuLoadFifteen\"=(\$someArray15 / [:len \$Array15])
    }
    :log debug \"ispappAvgCpuCollector complete\";
  } on-error={
    :return {
      \"cpuLoadOne\"=[/system resource get cpu-load];
      \"cpuLoadFive\"=[/system resource get cpu-load];
      \"cpuLoadFifteen\"=[/system resource get cpu-load]
    }
    :log error \"ispappAvgCpuCollector did not complete with success!\";
  }
}
# Function to collect metric from each interface and format them as array
# usage:
#    :put [\$collectInterfacesMetrics]
:global collectInterfacesMetrics do={
  :local cout ({});
  :foreach i,iface in=[/interface find] do={
    :local ifaceprops [/interface get \$iface];
    :local maccount [:len [/ip arp find where interface=\$ifaceName]];
    :set (\$cout->\$i) {
    \"if\"=(\$ifaceprops->\"name\");
    \"recBytes\"=(\$ifaceprops->\"rx-byte\");
    \"recPackets\"=(\$ifaceprops->\"rx-packet\");
    \"recErrors\"=(\$ifaceprops->\"rx-error\");
    \"recDrops\"=(\$ifaceprops->\"rx-drop\");
    \"sentBytes\"=(\$ifaceprops->\"tx-byte\");
    \"sentPackets\"=(\$ifaceprops->\"tx-packet\");
    \"sentErrors\"=(\$ifaceprops->\"tx-error\");
    \"sentDrops\"=(\$ifaceprops->\"tx-drop\");
    \"carrierChanges\"=(\$ifaceprops->\"link-downs\");
    \"macs\"=\$maccount
    };
  }
  :return \$cout;
}
# Function to collect wireless interface stations metrics 
# look for wapCollector function for more usage details;
:global getWirelessStas do={
  :local staout ({});
  :local wIfNoise 0;
  :local wStaNoise 0;
  :local wStaRssi 0;
  :local wStaSig0 0;
  :local wStaSig1 0;
  :local wIfSig1 0;
  :local wIfSig0 0;
  :global rosTsSec;
  :foreach i,wStaId in=[/interface wireless registration-table find where interface=\$1] do={
        :local ifregprops [/interface wireless registration-table get \$wStaId];
        :local wStaMac (\$ifregprops->\"mac-address\");
        :local wStaRssi (\$ifregprops->\"signal-strength\");
        :set wStaRssi ([:pick \$wStaRssi 0 [:find \$wStaRssi \"dBm\"]]);
        :set wStaRssi ([:tonum \$wStaRssi]);
        :set wStaNoise (\$wStaRssi - [:tonum (\$ifregprops->\"signal-to-noise\")]);
        :set wStaSig0 ([:tonum (\$ifregprops->\"signal-strength-ch0\")]);
        :set wStaSig1 ([:tonum (\$ifregprops->\"signal-strength-ch1\")]);
        if ([:len \$wStaSig1] = 0) do={
          :set wStaSig1 0;
        }
        :local wStaExpectedRate ([/interface wireless registration-table get \$wStaId p-throughput]);
        :local wStaAssocTime ([/interface wireless registration-table get \$wStaId uptime]);
        # convert the associated time to seconds
        :local assocTimeSplit [\$rosTsSec \$wStaAssocTime];
        :set wStaAssocTime \$assocTimeSplit;
        # set the interface values
        :set wIfNoise (\$wIfNoise + \$wStaNoise);
        :set wIfSig0 (\$wIfSig0 + \$wStaSig0);
        :set wIfSig1 (\$wIfSig1 + \$wStaSig1);
        :local wStaIfBytes ([/interface wireless registration-table get \$wStaId bytes]);
        :local wStaIfSentBytes ([:pick \$wStaIfBytes 0 [:find \$wStaIfBytes \",\"]]);
        :local wStaIfRecBytes ([:pick \$wStaIfBytes 0 [:find \$wStaIfBytes \",\"]]);
        :local wStaDhcpName ([/ip dhcp-server lease find where mac-address=\$wStaMac]);
        if (\$wStaDhcpName) do={
          :set wStaDhcpName ([/ip dhcp-server lease get \$wStaDhcpName host-name]);
        } else={
          :set wStaDhcpName \"\";
        }
        :local newSta;
        :set (\$staout->\$i) {
          \"mac\"=\$wStaMac;
          \"expectedRate\"=([:tonum \$wStaExpectedRate]);
          \"assocTime\"=([:tonum \$wStaAssocTime]);
          \"noise\"=([:tonum \$wStaNoise]);
          \"signal0\"=([:tonum \$wStaSig0]);
          \"signal1\"=([:tonum \$wStaSig1]);
          \"rssi\"=([:tonum \$wStaRssi]);
          \"sentBytes\"=([:tonum \$wStaIfSentBytes]);
          \"recBytes\"=([:tonum \$wStaIfRecBytes]);
          \"info\"=\$wStaDhcpName
        };
      }
    :local count [:len \$staout];
    if (\$count = 0) do={
      :set count 1;
    }
    :set wIfNoise (-\$wIfNoise / \$count)
    :set wIfSig0 (-\$wIfSig0 / \$count)
    :set wIfSig1 (-\$wIfSig1 / \$count)
    :if (!any \$wIfNoise) do={:set wIfNoise 0;}
    :if (!any \$wIfSig0) do={:set wIfSig0 0;}
    :if (!any \$wIfSig0) do={:set wIfSig0 0;}
    :return {
      \"stations\"=\$staout;
      \"noise\"=\$wIfNoise;
      \"signal0\"=\$wIfSig0;
      \"signal1\"=\$wIfSig1
    };
}
# Function to collect cap-man managed interface stations metrics 
# look for wapCollector function for more usage details;
:global getCapsStas do={
  :local staout ({});
  :local wIfNoise 0;
  :local wStaNoise 0;
  :local wStaRssi 0;
  :local wStaSig0 0;
  :local wStaSig1 0;
  :local wIfSig1 0;
  :local wIfSig0 0;
  :global rosTsSec;
  :foreach i,wStaId in=[/caps-man registration-table find where  interface=\$1] do={
      :local ifregprops [/caps-man registration-table get \$wStaId];
      :local wStaMac (\$ifregprops->\"mac-address\");
      :local wStaRssi (\$ifregprops->\"signal-strength\");
      :set wStaRssi ([:pick \$wStaRssi 0 [:find \$wStaRssi \"dBm\"]]);
      :set wStaRssi ([:tonum \$wStaRssi]);
      :local wStaNoise (\$ifregprops->\"signal-to-noise\");
      :set wStaNoise (\$wStaRssi - [:tonum \$wStaNoise]);
      :local wStaSig0 (\$ifregprops->\"signal-strength-ch0\");
      :set wStaSig0 ([:tonum \$wStaSig0]);
      :local wStaSig1 (\$ifregprops->\"signal-strength-ch1\");
      :set wStaSig1 ([:tonum \$wStaSig1]);
      if ([:len \$wStaSig1] = 0) do={
        :set wStaSig1 0;
      }
      :local wStaExpectedRate (\$ifregprops->\"p-throughput\");
      :local wStaAssocTime (\$ifregprops->\"uptime\");
      # convert the associated time to seconds
      :local assocTimeSplit [\$rosTsSec \$wStaAssocTime];
      :set wStaAssocTime \$assocTimeSplit;
      # set the interface values
      :set wIfNoise (\$wIfNoise + \$wStaNoise);
      :set wIfSig0 (\$wIfSig0 + \$wStaSig0);
      :set wIfSig1 (\$wIfSig1 + \$wStaSig1);
      :local wStaIfBytes (\$ifregprops->\"bytes\");
      :local wStaIfSentBytes ([:pick \$wStaIfBytes 0 [:find \$wStaIfBytes \",\"]]);
      :local wStaIfRecBytes ([:pick \$wStaIfBytes 0 [:find \$wStaIfBytes \",\"]]);
      :local wStaDhcpName ([/ip dhcp-server lease find where mac-address=\$wStaMac]);
      if (\$wStaDhcpName) do={
        :set wStaDhcpName ([/ip dhcp-server lease get \$wStaDhcpName host-name]);
      } else={
        :set wStaDhcpName \"\";
      }
      :local newSta;
      :set (\$staout->\$i) {
        \"mac\"=\$wStaMac;
        \"expectedRate\"=\$wStaExpectedRate;
        \"assocTime\"=([:tonum \$wStaAssocTime]);
        \"noise\"=\$wStaNoise;
        \"signal0\"=\$wStaSig0;
        \"signal1\"=\$wStaSig1;
        \"rssi\"=\$wStaRssi;
        \"sentBytes\"=([:tonum \$wStaIfSentBytes]);
        \"recBytes\"=([:tonum \$wStaIfRecBytes]);
        \"info\"=\$wStaDhcpName
      };
  }
  :local count [:len \$staout];
  if (\$count = 0) do={
    :set count 1;
  }
  :set wIfNoise (-\$wIfNoise / \$count)
  :set wIfSig0 (-\$wIfSig0 / \$count)
  :set wIfSig1 (-\$wIfSig1 / \$count)
  :if (!any \$wIfNoise) do={:set wIfNoise 0;}
  :if (!any \$wIfSig0) do={:set wIfSig0 0;}
  :if (!any \$wIfSig0) do={:set wIfSig0 0;}
  :return {
    \"stations\"=\$staout;
    \"noise\"=\$wIfNoise;
    \"signal0\"=\$wIfSig0;
    \"signal1\"=\$wIfSig1
  };
}
# Function to collect Wifiwave2 interface stations metrics 
# look for wapCollector function for more usage details;
:global getWifiwave2Stas do={
  :local staout ({});
  :local wIfNoise 0;
  :local wStaNoise 0;
  :local wStaRssi 0;
  :local wStaSig0 0;
  :local wStaSig1 0;
  :local wIfSig1 0;
  :local wIfSig0 0;
  :global rosTsSec;
  :foreach i,wStaId in=[/interface wifiwave2 registration-table find where interface=\$1] do={
    :local ifregprops [/interface wifiwave2 registration-table get \$wStaId];
    :local wStaMac (\$ifregprops->\"mac-address\");
    :local wStaRssi (\$ifregprops->\"signal\");
    :set wStaRssi ([:tonum \$wStaRssi]);
    :local wStaAssocTime (\$ifregprops->\"uptime\");
    :local assocTimeSplit [\$rosTsSec \$wStaAssocTime];
    :set wStaAssocTime \$assocTimeSplit;
    :local wStaIfBytes (\$ifregprops->\"bytes\");
    :local wStaIfSentBytes ([:pick \$wStaIfBytes 0 [:find \$wStaIfBytes \",\"]]);
    :local wStaIfRecBytes ([:pick \$wStaIfBytes 0 [:find \$wStaIfBytes \",\"]]);
    :local wStaDhcpName ([/ip dhcp-server lease find where mac-address=\$wStaMac]);
    # todo (getting channels signals)
    if (\$wStaDhcpName) do={
      :set wStaDhcpName ([/ip dhcp-server lease get \$wStaDhcpName host-name]);
    } else={
      :set wStaDhcpName \"\";
    }
    :local newSta;
    :set (\$staout->\$i) {
      \"mac\"=\$wStaMac;
      \"assocTime\"=([:tonum \$wStaAssocTime]);
      \"rssi\"=\$wStaRssi;
      \"sentBytes\"=([:tonum \$wStaIfSentBytes]);
      \"recBytes\"=([:tonum \$wStaIfRecBytes]);
      \"info\"=\$wStaDhcpName
    };
  }
  :return {
    \"stations\"=\$staout;
    \"noise\"=\$wIfNoise;
    \"signal0\"=\$wIfSig0;
    \"signal1\"=\$wIfSig1
  };
}
# Function to collect LTE interfaces if exist any
:global getLtestats do={
  :local cout ({});
  :global Split;
  # NB: i wish i had lte sim slot to try those things !!
  :foreach i,lteIfaceId in=[/interface lte find] do={
    :local mnc;
    :local isconnected true;
    :local lteIfName ([/interface lte get \$lteIfaceId name]);
    # The at+csq command returns received signal strength indication (RSSI)
    :local lteAt0 [:tostr  [/interface lte at-chat \$lteIfName input \"AT+CSQ\" as-value]];
    :local lteAt0Arr [\$Split [:tostr \$lteAt0] [:tostr \"\\n\"]]; 
    :local snrArr [\$Split (\$lteAt0Arr->0) \" \"];
    # split the signal and the bit error rate by the comma
    :local sber [\$Split (\$snrArr->1) \",\"];
    :local signal [:tonum (\$sber->0)];
    # convert the value to rssi
    # 2 equals -109
    # each value above 2 adds -2 and -109
    :local s (\$signal - 2);
    :set s (\$s * 2);
    :set signal (\$s + -109)
    # The at+cops? command is used to check the current network connection.
    :local lteAt1 [:tostr  [/interface lte at-chat \$lteIfName input \"AT+COPS?\" as-value]];
    if ([:find \$lteAt1 \"ERROR\"] > -1) do={
      :log info \"\$lteIfName not connected\";
      :set isconnected false;
    } else={
      # get the network name, at least the MNC (Mobile Network Code)
      :local mncArray [\$Split \$lteAt1 \",\"];
      # remove the first \" because \\\" cannot be passed to Split due to the routeros scripting language bug
      :set mnc [:pick (\$mncArray->2) 1 [:len (\$mncArray->2)]];
      # remove the last \"
      :set mnc [:pick \$mnc 0 ([:len \$mnc] - 1)];
    }
    :set (\$cout->\$i) {
      \"isconnected\"=\$isconnected;
      \"stations\"=\"[]\";
      \"interface\"=\"\$lteIfName\";
      \"ssid\"=\"\$mnc\";
      \"signal0\"=\$signal
    };
  }
  :return \$cout;
}
# Function to wap interfaces metrics (work on progress ...)
# usage:
#   :put [\$wapCollector]
:global wapCollector do={
  :global getCapsStas;
  :global getWirelessStas;
  :global getWifiwave2Stas;
  :local cout ({});
  :local iscap do={
    :do {
      :return ([[:parse \"/caps-man manager print as-value\"]]->\"enabled\");
    } on-error={
      :return false;
    }
  }
  :if ([\$iscap]) do={
    :foreach i,wIfaceId in=[[:parse \"/caps-man interface find\"]] do={
      :local ifDetails [[:parse \"/caps-man interface get \$wIfaceId\"]];
      :local ifName (\$ifDetails->\"name\");
      :local ifMaster (\$ifDetails->\"master-interface\");
      :local staout;
      :set staout [\$getCapsStas \$ifName];
      :local stations ({});
      :if ([:len (\$staout->\"stations\")] > 0) do={
        :set stations (\$staout->\"stations\");
      } else={
          :set stations \"[]\";
      }
      :set (\$cout->\$i) {
        \"stations\"=\$stations;
        \"interface\"=\$ifName;
        \"master-interface\"=\$ifMaster;
        \"ssid\"=(\$ifDetails->\"configuration.ssid\");
        \"noise\"=(\$staout->\"noise\");
        \"signal0\"=(\$staout->\"signal0\");
        \"signal1\"=(\$staout->\"signal1\")
        };
    }
  } else={
    :if ([/system package find name~\"wifiwave2\"] = \"\") do={
      :foreach i,wIfaceId in=[[:parse \"/interface wireless find\"]] do={
        :local ifDetails [[:parse \"/interface wireless get \$wIfaceId\"]];
        :local ifName (\$ifDetails->\"name\"); 
        :local ifMaster (\$ifDetails->\"interface-type\"); 
        if (\$ifMaster = \"virtual\") do={
          :set ifMaster (\$ifDetails->\"master-interface\"); 
        }
        :local staout ({});
        :set staout [\$getWirelessStas \$ifName]
        :local stations ({});
        :if ([:len (\$staout->\"stations\")] > 0) do={
          :set stations (\$staout->\"stations\");
        } else={
          :set stations \"[]\";
        }
        :set (\$cout->\$i) {
          \"stations\"=\$stations;
          \"interface\"=\$ifName;
          \"master-interface\"=\$ifMaster;
          \"ssid\"=(\$ifDetails->\"ssid\");
          \"noise\"=(\$staout->\"noise\");
          \"signal0\"=(\$staout->\"signal0\");
          \"signal1\"=(\$staout->\"signal1\")
          };
      }
    } else={
      :foreach i,wIfaceId in=[[:parse \"/interface wifiwave2 find\"]] do={
        :local staout ({});
        :local ifDetails [[:parse \"/interface wifiwave2 get \$wIfaceId\"]];
        :local ifName (\$ifDetails->\"name\"); 
        :local ifMaster (\$ifDetails->\"master-interface\"); 
        :set staout [\$getWifiwave2Stas \$ifName]
        :local stations ({});
        :if ([:len (\$staout->\"stations\")] > 0) do={
          :set stations (\$staout->\"stations\");
        } else={
          :set stations \"[]\";
        }
        :set (\$cout->\$i) {
        \"stations\"=\$stations;
        \"interface\"=\$ifName;
        \"master-interface\"=\$ifMaster;
        \"ssid\"=(\$ifDetails->\"configuration.ssid\");
        \"noise\"=(\$staout->\"noise\");
        \"signal0\"=(\$staout->\"signal0\");
        \"signal1\"=(\$staout->\"signal1\")
        };
      }
    }
  }
  :local lteIfs [\$getLtestats];
  :if ([:len \$lteIfs] > 0) do={
    :foreach i,ifstats in=array do={
      :set (\$cout->([:len \$cout] + \$i)) \$ifstats;
    }
  }
  :return \$cout;
}
# Function to collect SystemMetrics
# usage:
#     :put [\$getSystemMetrics];
:global getSystemMetrics do={
  :global diskMetrics;
  :global getCpuLoads;
  :global connectionFailures;
  :global partitionsMetrics;
  # todo (no real value here!)
  :local memBuffers 0;
  :local cout ({});
  :local cachedMem 0;
  # end todo
  :local processCount [:len [/system script job find]];
  :local totalMem ([/system resource get total-memory]);
  :local freeMem ([/system resource get free-memory]);
  :local cpuload [\$getCpuLoads];
  # return: cpuLoadFifteen=5;cpuLoadFive=7;cpuLoadOne=6
  :local disks [\$diskMetrics];
  :if ([:len \$disks] = 0) do={
    :set disks \"[]\";
  }
  :local partitions [\$partitionsMetrics];
  :if ([:len \$partitionsMetrics] = 0) do={
    :set partitions \"[]\";
  }
  :set cout {
    \"load\"={
        \"one\"=(\$cpuload->\"cpuLoadOne\");
        \"five\"=(\$cpuload->\"cpuLoadFive\");
        \"fifteen\"=(\$cpuload->\"cpuLoadFifteen\");
        \"processCount\"=\$processCount
      };
    \"memory\"={
      \"total\"=\$totalMem;
      \"free\"=\$freeMem;
      \"buffers\"=\$memBuffers;
      \"cached\"=\$cachedMem
      };
    \"disks\"=\$disks;
    \"partitions\"=\$partitions;
    \"connDetails\"={
      \"connectionFailures\"=\$connectionFailures
      }
    };
  :return \$cout;
}
:put \"\\t V2 Library loaded! (;\";"

 add dont-require-permissions=yes name=ispappLibraryV3 owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
:global ispappLibraryV3 \"ispappLibraryV3 loaded\";
# Function to collect all wireless interfaces and format them to be sent to server.
# @param \$topDomain - domain of the server
# @param \$topKey - key of the server
# @param \$topListenerPort - port of the server
# @param \$login - login of the server
# @param \$password - password of the server
# @param \$prepareSSL - if true, SSL preparation will be done
# @return \$wlans - array of wireless interfaces
# @return \$status - status of the operation
# @return \$message - message of the operation
:global Wifewave2InterfacesConfigSync do={
:do {
    :global getAllConfigs;
    :global ispappHTTPClient;
    if ([:len [/system script job find script~\"ispappUpdate\"]] > 0) do={
        :return {\"status\"=false; \"message\"=\"waiting update to finish first!\"};
    }
    :local getConfig do={
        # get configuration from the server
        :do {
            :global ispappHTTPClient;
            :global fillGlobalConsts;
            :local res;
            :local i 0;
            # :if ([\$ispappHTTPClient m=\"get\" a=\"update\"]->\"status\" = false) do={
            #     :return { \"response\"=\"firt time config of server error\"; \"status\"=false };
            # }
            :while (([:len [:find [:tostr \$res] \"Err.Raise\"]] != 0 || [:len \$res] = 0) && \$i < 3) do={
                :set res ([\$ispappHTTPClient m=\"get\" a=\"config\"]->\"parsed\");
                :delay 1s;
                :set i (\$i + 1);
            }
            if ([:len [:find [:tostr \$res] \"Err.Raise\"]] != 0) do={
                # check id json received is valid and redy to be used
                :log error \"error while getting config (Err.Raise fJSONLoads)\";
                :return {\"status\"=false; \"message\"=\"error while getting config (Err.Raise fJSONLoads)\"};
            } else={
                :if (\$res->\"host\"->\"Authed\" != true) do={
                    :log error [:tostr \$res];
                    :return {\"status\"=false; \"message\"=\$res};
                } else={
                    :log info \"check id json received is valid and ready to be used with response: \$res\";
                    :put [\$fillGlobalConsts \$res];
                    :return { \"response\"=\$res; \"status\"=true };
                }
            }
        } on-error={
            :log error \"error while getting config (Err.Raise fJSONLoads)\";
            :return {\"status\"=false; \"message\"=\"error while getting config\"};
        }
    };
    :local getLocalWlans do={
        # collect all wireless interfaces from the system
        # format them to be sent to server
        :log info \"start collect all wireless interfaces from the system ...\";
        :local wlans [[:parse \"/interface wifiwave2 print as-value\"]];
        if ([:len \$wlans] > 0) do={
            :local wirelessConfigs ({});
            foreach i,intr in=\$wlans do={
                :local thisWirelessConfig {
                    \"key\"=(\$intr->\"security.passphrase\");
                    \"keytypes\"=[:tostr (\$intr->\"security.authentication-types\")];
                    \"security-profile\"=(\$intr->\"security.name\");
                    \"ssid\"=(\$intr->\"configuration.ssid\")
                };
                :set (\$wirelessConfigs->\$i) \$thisWirelessConfig;
            }
            :log info \"collect all wireless interfaces from the system\";
            :return { \"status\"=true; \"wirelessConfigs\"=\$wirelessConfigs };
        } else={
        :log info \"collect all wireless interfaces from the system: no wireless interfaces found\";
        :return { \"status\"=false; \"message\"=\"no wireless interfaces found\" };
        }
    };
    :delay 1s;
    :log info \"done setting local functions .... 1s\"
    # check if our host is authorized to get configuration
    # and ready to accept interface syncronization
    :local configresponse [\$getConfig];
    :local localwirelessConfigs [\$getLocalWlans];
    :local output;
    :local wirelessConfigs [:toarray \"\"];
    :if (\$configresponse->\"status\" = true) do={
        :set wirelessConfigs (\$configresponse->\"response\"->\"host\"->\"wirelessConfigs\");
    }
    :delay 1s;
    :log info \"done setting wirelessConfigs .... 1s\"
    if ([:len \$wirelessConfigs] > 0) do={
        # this is the case when some interface configs received from the host
        # get security profile with same password as the one on first argument \$1
        :global SyncSecProfile do={
            # add security profile if not found
            :do {
                :if ([:len (\$1->\"key\")] > 0) do={
                    :local key (\$1->\"key\");
                    :local tempName (\"ispapp_\" . (\$1->\"ssid\"));
                    # search for profile with this same password if exist if not just create it.
                    :local currentprfpass [:parse \"/interface wifiwave2 security print where passphrase=\\\$1 as-value\"];
                    # todo: separation of sec profiles ....
                    :local foundSecProfiles [\$currentprfpass \$key]; # error 
                    :log info \"add security profile if not found: \$tempName\";
                    if ([:len \$foundSecProfiles] > 0) do={
                        :return (\$foundSecProfiles->0->\"name\");
                    } else={
                        :local addSec  [:parse \"/interface wifiwave2 security add \\\\
                            wps=disable \\\\
                            name=\\\$tempName \\\\
                            passphrase=(\\\$1->\\\"encKey\\\") \\\\
                            authentication-types=wpa2-psk,wpa3-psk\"];
                        :put [\$addSec \$1];
                        :return \$tempName;
                    }
                } else={
                    :return [/interface wifiwave2 security get *0 name];
                }
            } on-error={
                # return the default dec profile in case of error
                # adding or updating to perform interface setup with no problems
                :return [/interface wifiwave2 security get *0 name];
            }
        }
        :global convertToValidFormat;
        ## start comparing local and remote configs
        foreach conf in=\$wirelessConfigs do={
            :log info \"## start comparing local and remote configs ##\";
            :local existedinterf [[:parse \"/interface wifiwave2 configuration find\"] ssid=(\$conf->\"ssid\")];
            :local newSecProfile [\$SyncSecProfile \$conf];
            if ([:len [[:parse \"/interface wifiwave2 channel find\"]]] = 0) do={
                :do {
                    [[:parse \"/interface wifiwave2 channel add name=ch-2ghz frequency=2412,2432,2472 width=20mhz\"]]
                    [[:parse \"/interface wifiwave2 channel add name=ch-5ghz frequency=5180,5260,5500 width=20/40/80mhz\"]]
                    :log debug \"add name=ch-2ghz frequency=2412,2432,2472 width=20mhz add name=ch-5ghz frequency=5180,5260,5500 width=20/40/80mhz\";
                } on-error={
                    :local existchnls [:tostr [[:parse \"/interface wifiwave2 channel print as-value\"]]];
                    :log error \"faild to dual-band channels \\n existing channels: \$existchnls\"
                }
            }
            if ([:len \$existedinterf] = 0) do={
                # add new interface
                :local NewInterName (\"ispapp_\" . [\$convertToValidFormat (\$conf->\"ssid\")]);
                :log info \"## add new interface -> \$NewInterName ##\";
                :local addConfig [:parse \"/interface/wifiwave2/configuration add \\\\
                    ssid=(\\\$1->\\\"ssid\\\") \\\\
                    security=(\\\$1->\\\"newSecProfile\\\") \\\\
                    country=\\\"United States\\\" \\\\
                    manager=\\\"local\\\" \\\\
                    name=(\\\$1->\\\"NewInterName\\\");\"];
                :local addInter [:parse \"/interface/wifiwave2 add \\\\
                    disabled=no \\\\
                    channel=\\\$2 \\\\
                    configuration=(\\\$1->\\\"NewInterName\\\");\"];
                :local newinterface (\$conf + {\"newSecProfile\"=\$newSecProfile; \"NewInterName\"=\$NewInterName});
                :log debug (\"new interface details \\n\" . [:tostr \$newinterface]);
                :put [\$addConfig \$newinterface];
                :foreach i,k in=[[:parse \"/interface wifiwave2 channel print as-value\"]] do={
                    # solution for muti bands 
                    :put [\$addInter \$newinterface (\$k->\"name\")];
                }
                :put [/interface wifiwave2 enable \$NewInterName];
                :delay 3s; # wait for interface to be created
                :log info \"## wait for interface to be created 3s ##\";
            } else={
                :local setInter [:parse \"/interface/wifiwave2/configuration/set \\\$2 \\\\
                    ssid=(\\\$1->\\\"ssid\\\") \\\\
                    security=(\\\$1->\\\"newSecProfile\\\") \\\\
                    country=Latvia \\\\ 
                    name=(\\\$1->\\\"NewInterName\\\");\"];
                # set the first interface to the new config
                :local newSecProfile [\$SyncSecProfile \$conf];
                :local NewInterName (\"ispapp_\" . [\$convertToValidFormat (\$conf->\"ssid\")]);
                :log info \"## update new interface -> \$NewInterName ##\";
                [\$setInter (\$conf + {\"newSecProfile\"=\$newSecProfile; \"NewInterName\"=\$NewInterName}) (\$existedinterf->0)];
                :delay 3s; # wait for interface to be setted
                :log info \"## wait for interface to be created 3s ##\";
                if ([:len \$existedinterf] > 1) do={
                    # remove all interfaces except the first one
                    :foreach k,intfid in=\$existedinterf do={
                        if (\$k != 0) do={
                            [[:parse \"/interface wifiwave2 configuration remove [/interface wifiwave2 configuration get \$intfid name]\"]];
                            :delay 1s; # wait for interface to be removed
                        }
                    }
                }
            }
        }
        :local message (\"syncronization of \" . [:len \$wirelessConfigs] . \" interfaces completed\");
        :log info \$message;
        :set output {
            \"status\"=true;
            \"message0\"=\$message;
            \"configs\"=\$wirelessConfigs
        };
    }
    if ([\$localwirelessConfigs]->\"status\" = true) do={
        ## start uploading local configs to host
        # item sended example from local: \"{\\\"if\\\":\\\"\$wIfName\\\",\\\"ssid\\\":\\\"\$wIfSsid\\\",\\\"key\\\":\\\"\$wIfKey\\\",\\\"keytypes\\\":\\\"\$wIfKeyTypeString\\\"}\"
        :log info \"## wait for interfaces changes to be applied and can be retrieved from the device 5s ##\";
        :delay 5s; # wait for interfaces changes to be applied and can be retrieved from the device
        :local InterfaceslocalConfigs;
        :foreach k,wifiwave in=[[:parse \"/interface wifiwave2 print detail as-value\"]] do={
            :set (\$InterfaceslocalConfigs->\$k) {
                \"if\"=(\$wifiwave->\"name\");
                \"ssid\"=(\$wifiwave->\"configuration.ssid\");
                \"key\"=(\$getsecurity->\"security.passphrase\");
                \"technology\"=\"wifiwave2\";
                \"security_profile\"=(\$wifiwave->\"security\")
            };
        };
        :local SecProfileslocalConfigs; 
        :foreach k,secprof in=[[:parse \"/interface wifiwave2 security print as-value\"]] do={
            :local authtypes (\$secprof->\"authentication-types\");
            :if ([:len \$authtypes] = 0) do={ :set authtypes \"[]\";}
            :set (\$SecProfileslocalConfigs->\$k) (\$secprof+{
                \"name\"=(\$secprof->\"name\");
                \"authentication-types\"=\$authtypes;
                \"technology\"=\"wifiwave2\"
            });
        };
        # i need a device with wifiwave2 active to finish this part.
        :local sentbody \"{}\";
        :local message (\"uploading \" . [:len \$InterfaceslocalConfigs] . \" interfaces to ispapp server\");
        :if ([:len \$InterfaceslocalConfigs] = 0) do={
            :set InterfaceslocalConfigs \"[]\";
        }
        :if ([:len \$SecProfileslocalConfigs] = 0) do={
            :set SecProfileslocalConfigs \"[]\";
        }
        :global getAllConfigs;
        :global ispappHTTPClient;
        :set sentbody ([\$getAllConfigs \$InterfaceslocalConfigs \$SecProfileslocalConfigs]->\"json\");
        :local returned  [\$ispappHTTPClient m=post a=config b=\$sentbody];
        :return (\$output+{
            \"status\"=true;
            \"body\"=\$sentbody;
            \"response\"=\$returned;
            \"message1\"=\$message
        });
    } else={
        :log info \"no local wifiwave interfaces found (from WifiwaveInterfacesConfigSync function in ispLibrary.rsc)\";
        :return (\$output+{
            \"status\"=true;
            \"message1\"=\"no wifiwave interfaces found\"
        });
    }
} on-error={
    :return (\$output+{
        \"status\"=false;
        \"message1\"=\"no wifiwave support found\"
    });
}
};
# Function to collect all Caps manager interfaces and format them to be sent to server.
:global CapsConfigSync do={
    :global getAllConfigs;
    :global ispappHTTPClient;
    if ([:len [/system script job find script~\"ispappUpdate\"]] > 0) do={
        :return {\"status\"=false; \"message\"=\"waiting update to finish first!\"};
    }
    :local getConfig do={
        # get configuration from the server
        :do {
            :global ispappHTTPClient;
            :global fillGlobalConsts;
            :local res;
            :local i 0;
            :while (([:len [:find [:tostr \$res] \"Err.Raise\"]] != 0 || [:len \$res] = 0) && \$i < 3) do={
                :set res ([\$ispappHTTPClient m=\"get\" a=\"config\"]->\"parsed\");
                :delay 1s;
                :set i (\$i + 1);
            }
            if ([:len [:find [:tostr \$res] \"Err.Raise\"]] != 0) do={
                # check id json received is valid and redy to be used
                :log error \"error while getting config (Err.Raise fJSONLoads)\";
                :return {\"status\"=false; \"message\"=\"error while getting config (Err.Raise fJSONLoads)\"};
            } else={
                :if (\$res->\"host\"->\"Authed\" != true) do={
                    :log error [:tostr \$res];
                    :return {\"status\"=false; \"message\"=\"Authed false\"};
                } else={
                    :log info \"check id json received is valid and redy to be used with response: \$res\";
                    :put [\$fillGlobalConsts \$res];
                    :return { \"response\"=\$res; \"status\"=true };
                }
            }
        } on-error={
            :log error \"error while getting config (Err.Raise fJSONLoads)\";
            :return {\"status\"=false; \"message\"=\"error while getting config\"};
        }
    };
    :local getLocalWlans do={
        # collect all wireless interfaces from the system
        # format them to be sent to server
        :log info \"start collect all wireless interfaces from the system ...\";
        :local wlans [[:parse \"/caps-man interface print as-value\"]];
        if ([:len \$wlans] > 0) do={
            :local wirelessConfigs ({});
            foreach i,intr in=\$wlans do={
                :local cmdsectemp [:parse \"/caps-man security print as-value where  name=\\\$1\"];
                :local cmdconftemp [:parse \"/caps-man configuration print as-value where  name=\\\$1\"];
                :local conftemp [\$cmdconftemp (\$intr->\"configuration\")];
                :local secTemp [\$cmdsectemp (\$conftemp->\"security\")];
                :local thisWirelessConfig {
                    \"key\"=(\$secTemp->0->\"passphrase\");
                    \"keytypes\"=[:tostr (\$secTemp->0->\"authentication-types\")];
                    \"security-profile\"=(\$secTemp->0->\"name\");
                    \"ssid\"=(\$conftemp->0->\"ssid\")
                };
                :set (\$wirelessConfigs->\$i) \$thisWirelessConfig;
            }
            :log info \"collect all wireless interfaces from the system\";
            :return { \"status\"=true; \"wirelessConfigs\"=\$wirelessConfigs };
        } else={
        :log info \"collect all wireless interfaces from the system: no wireless interfaces found\";
        :return { \"status\"=false; \"message\"=\"no wireless interfaces found\" };
        }
    };
    :delay 1s;
    :log info \"done setting local functions .... 1s\"
    # check if our host is authorized to get configuration
    # and ready to accept interface syncronization
    :local configresponse [\$getConfig];
    :local localwirelessConfigs [\$getLocalWlans];
    :local output;
    :local wirelessConfigs [:toarray \"\"];
    :if (\$configresponse->\"status\" = true) do={
        :set wirelessConfigs (\$configresponse->\"response\"->\"host\"->\"wirelessConfigs\");
    }
    :delay 1s;
    :log info \"done setting wirelessConfigs .... 1s\"
    if ([:len \$wirelessConfigs] > 0) do={
        # this is the case when some interface configs received from the host
        # get security profile with same password as the one on first argument \$1
        :global SyncSecProfile do={
            # add security profile if not found
            :do {
                :local key (\$1->\"key\");
                :local tempName (\"ispapp_\" . (\$1->\"ssid\"));
                # search for profile with this same password if exist if not just create it.
                :local currentprfpass [:parse \"/caps-man security print as-value where passphrase=\\\$1\"];
                # todo: separation of sec profiles ....
                :local foundSecProfiles [\$currentprfpass \$key]; # error 
                :log info \"add security profile if not found: \$tempName\";
                if ([:len \$foundSecProfiles] > 0) do={
                    :return (\$foundSecProfiles->0->\"name\");
                } else={
                    :local addSec  [:parse \"/caps-man security add \\\\
                        name=\\\$tempName \\\\
                        passphrase=(\\\$1->\\\"encKey\\\") \\\\
                        authentication-types=wpa2-psk,wpa-psk\"];
                    :put [\$addSec \$1];
                    :return \$tempName;
                }
            } on-error={
                # return the default dec profile in case of error
                # adding or updating to perform interface setup with no problems
                :return [/caps-man security get *0 name];
            }
        }
        :global convertToValidFormat;
        ## start comparing local and remote configs
        foreach conf in=\$wirelessConfigs do={
            :log info \"## start comparing local and remote configs ##\";
            :local existedinterf [[:parse \"/caps-man configuration find\"] ssid=(\$conf->\"ssid\")];
            :local newSecProfile [\$SyncSecProfile \$conf];
            if ([:len [[:parse \"/caps-man channel find\"]]] = 0) do={
                :do {
                    :local set2ghz [:parse \"/caps-man channel add name=ch-2ghz frequency=2412,2432,2472 control-channel-width=20mhz band=2ghz-b/g/n\"]
                    :local set5ghz [:parse \"/caps-man channel add name=ch-5ghz frequency=5180,5260,5500 control-channel-width=40mhz-turbo band=5ghz-a/n/ac\"]
                    :put [\$set2ghz]
                    :put [\$set5ghz]
                    :log debug \"add name=ch-2ghz frequency=2412,2432,2472 width=20mhz add name=ch-5ghz frequency=5180,5260,5500 width=20/40/80mhz\";
                } on-error={
                    :log error \"faild to dual-band channels caps\"
                }
            }
            if ([:len \$existedinterf] = 0) do={
                # add new interface
                :local NewInterName (\"ispapp_\" . [\$convertToValidFormat (\$conf->\"ssid\")]);
                :log info \"## add new interface -> \$NewInterName ##\";
                :local addconfig [:parse \"/caps-man configuration add \\\\
                    ssid=(\\\$1->\\\"ssid\\\") \\\\
                    security=(\\\$1->\\\"newSecProfile\\\") \\\\
                    name=(\\\$1->\\\"NewInterName\\\");\"];
                :local addInter [:parse \"/caps-man interface add \\\\
                    disabled=no \\\\
                    channel=\\\$2 \\\\
                    configuration=(\\\$1->\\\"NewInterName\\\");\"];
                :foreach i,k in=[[:parse \"/caps-man channel print\"] as-value] do={
                    # solution for muti bands 
                    :put [\$addInter \$newinterface (\$k->\"name\")];
                }
                # Latvia added as default country for now...
                :local newinterface (\$conf + {\"newSecProfile\"=\$newSecProfile; \"NewInterName\"=\$NewInterName});
                :log debug (\"new interface details \\n\" . [:tostr \$newinterface]);
                :put [\$addconfig \$newinterface];
                :put [/caps-man interface enable \$NewInterName];
                :delay 3s; # wait for interface to be created
                :log info \"## wait for caps interface to be created 3s ##\";
            } else={
                :local setInter [:parse \"/caps-man configuration set \\\$2 \\\\
                    ssid=(\\\$1->\\\"ssid\\\") \\\\
                    security=(\\\$1->\\\"newSecProfile\\\") \\\\
                    name=(\\\$1->\\\"NewInterName\\\");\"];
                # set the first interface to the new config
                :local newSecProfile [\$SyncSecProfile \$conf];
                :local NewInterName (\"ispapp_\" . [\$convertToValidFormat (\$conf->\"ssid\")]);
                :log info \"## update new interface -> \$NewInterName ##\";
                [\$setInter (\$conf + {\"newSecProfile\"=\$newSecProfile; \"NewInterName\"=\$NewInterName}) (\$existedinterf->0)];
                :delay 3s; # wait for interface to be setted
                :log info \"## wait for interface to be created 3s ##\";
                if ([:len \$existedinterf] > 1) do={
                    # remove all interfaces except the first one
                    :foreach k,intfid in=\$existedinterf do={
                        if (\$k != 0) do={
                            :local ifnamebycfg [[:parse \"/caps-man configuration get\"] \$intfid name];
                            :local ifsecbycfg [[:parse \"/caps-man configuration get\"] \$intfid security];
                            if (any \$ifnamebycfg) do={
                                [[:parse \"/caps-man interface remove [/caps-man interface find configuration=\$ifnamebycfg]\"]];
                                [[:parse \"/caps-man configuration remove \$intfid\"]];
                                [[:parse \"/caps-man security remove [/caps-man security find name=\$ifsecbycfg]\"]];
                            }
                            :delay 1s; # wait for interface to be removed
                        }
                    }
                }
            }
        }
        :local message (\"syncronization of \" . [:len \$wirelessConfigs] . \" interfaces completed\");
        :log info \$message;
        :set output {
            \"status\"=true;
            \"message0\"=\$message;
            \"configs\"=\$wirelessConfigs
        };
    }
    if ([\$localwirelessConfigs]->\"status\" = true) do={
        ## start uploading local configs to host
        # item sended example from local: \"{\\\"if\\\":\\\"\$wIfName\\\",\\\"ssid\\\":\\\"\$wIfSsid\\\",\\\"key\\\":\\\"\$wIfKey\\\",\\\"keytypes\\\":\\\"\$wIfKeyTypeString\\\"}\"
        :log info \"## wait for interfaces changes to be applied and can be retrieved from the device 5s ##\";
        :delay 5s; # wait for interfaces changes to be applied and can be retrieved from the device
        :local InterfaceslocalConfigs;
        :local getconfiguration  [:parse \"/caps-man configuration print where name=\\\$1 as-value\"];
        :local getsecurity  [:parse \"/caps-man security print where name=\\\$1 as-value\"];
        :foreach k,mancap in=[[:parse \"/caps-man interface print as-value\"]] do={
            :local currentconfigs [\$getconfiguration (\$mancap->\"configuration\")]
            :local currentsec [\$getsecurity (\$currentconfigs->\"security\")]
            :set (\$InterfaceslocalConfigs->\$k) {
                \"if\"=(\$mancap->\"name\");
                \"ssid\"=(\$currentconfigs->\"ssid\");
                \"key\"=(\$getsecurity->\"passphrase\");
                \"technology\"=\"cap\";
                \"channel\"=[:tostr (\$mancap->\"channel\")];
                \"security_profile\"=(\$currentconfigs->\"security\")
            };
        };
        :local SecProfileslocalConfigs; 
        :foreach k,secprof in=[[:parse \"/caps-man security print as-value\"]] do={
            :local authtypes (\$secprof->\"authentication-types\");
            :if ([:len \$authtypes] = 0) do={ :set authtypes \"[]\";}
            :set (\$SecProfileslocalConfigs->\$k) (\$secprof+{
                \"name\"=(\$secprof->\"name\");
                \"authentication-types\"=\$authtypes;
                \"technology\"=\"cap\"
            });
        };
        # i need a device with wifiwave2 active to finish this part.
        :local sentbody \"{}\";
        :local message (\"uploading \" . [:len \$InterfaceslocalConfigs] . \"caps interfaces to ispapp server\");
        :if ([:len \$InterfaceslocalConfigs] = 0) do={
            :set InterfaceslocalConfigs \"[]\";
        }
        :if ([:len \$SecProfileslocalConfigs] = 0) do={
            :set SecProfileslocalConfigs \"[]\";
        }
        :global getAllConfigs;
        :global ispappHTTPClient;
        :set sentbody ([\$getAllConfigs \$InterfaceslocalConfigs \$SecProfileslocalConfigs]->\"json\");
        :local returned  [\$ispappHTTPClient m=post a=config b=\$sentbody];
        :return (\$output+{
            \"status\"=true;
            \"body\"=\$sentbody;
            \"response\"=\$returned;
            \"message1\"=\$message
        });
    } else={
        :log info \"no local caps interfaces found (from capsInterfacesConfigSync function in ispLibrary.rsc)\";
        :return (\$output+{
            \"status\"=true;
            \"message1\"=\"no caps interfaces found\"
        });
    }
};
# Function to collect disks metrics
# usage: 
#       :put [\$diskMetrics];
:global diskMetrics do={
    :local cout ({});
    :foreach i,disk in=[/disk find] do={
      :local diskName [/disk get \$disk slot];
      :local diskFree [/disk get \$disk free];
      :local diskSize [/disk get \$disk size];
      :if ([:len \$diskFree] = 0) do={
        :set diskFree 0;
      }
      :if ([:len \$diskSize] = 0) do={
        :set diskSize 0;
      }
      :local diskUsed ((\$diskSize - \$diskFree));
      # skip disks with no slot
      :if ([:len \$diskName] > 0) do={
        :set (\$cout->\$i) {
            \"mount\"=\$diskName;
            \"used\"=\$diskUsed;
            \"avail\"=\$diskFree
        };
      }
    }
    :return \$cout;
}
# Function to collect partitions metrics
# usage: 
#       :put [\$partitionsMetrics];
:global partitionsMetrics do={
    :local cout ({});
    :foreach i,part in=[/partitions find] do={
        :set (\$cout->\$i) {
            \"name\"=[/partitions get \$part name];
            \"fallback-to\"=[/partitions get \$part fallback-to];
            \"version\"=[/partitions get \$part version]
            \"running\"=[/partitions get \$part running]
            \"active\"=[/partitions get \$part active]
            \"size\"=[/partitions get \$part size]
        };
    }
    :return \$cout;
}
:put \"\\t V3 Library loaded! (;\";"

 add dont-require-permissions=yes name=ispappLibraryV4 owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
# Function to collect pinging stats from device to \$topdomain;
:global getPingingMetrics do={
    :global topDomain;
    :local avgRtt 0;
    :local minRtt 0;
    :local maxRtt 0;
    :local totalpingsreceived 0;
    :local totalpingssend 5;
    :local oneStepPercent (100 / \$totalpingssend);
    :local percentage 100;
    :do {
      /tool flood-ping address=[:resolve \$topDomain] count=\$totalpingssend size=64 timeout=00:00:00.1 do={
        :if (\$sent = \$totalpingssend) do={  
            :set totalpingsreceived \$received;
            :set avgRtt (\$\"avg-rtt\");
            :set minRtt (\$\"min-rtt\");
            :set maxRtt (\$\"max-rtt\");
            :set percentage (100 - ((\$totalpingsreceived / \$totalpingssend)*100))
        }
      }
      :return ({
        \"host\"=\"\$topDomain\";
        \"avgRtt\"=([:tonum \$avgRtt]);
        \"loss\"=([:tonum \$percentage]);
        \"minRtt\"=([:tonum \$minRtt]);
        \"maxRtt\"=([:tonum \$maxRtt])
      });
    } on-error={
      :return ({
        \"host\"=\"\$topDomain\";
        \"avgRtt\"=([:tonum \$avgRtt]);
        \"loss\"=([:tonum \$percentage]);
        \"minRtt\"=([:tonum \$minRtt]);
        \"maxRtt\"=([:tonum \$maxRtt])
      });
    }
}
# get public ip
:global getPublicIp do={
  :do {
    :return [:tostr [:resolve myip.opendns.com server=208.67.222.222]];
  } on-error={
    :return \"0.0.0.0\";
  }
}
# Function to join all collectect metrics
:global getCollections do={
    :local cout ({});
    :global getSystemMetrics;
    :global getPingingMetrics;
    :global wapCollector;
    :global toJson;
    :global collectInterfacesMetrics;
    :global getCpuLoads;
    :local wapArray [\$wapCollector];
    :local dhcpLeaseCount 0;
    :local systemArray [\$getSystemMetrics];
    :local ifaceDataArray [\$collectInterfacesMetrics];
    :local pings ({});
    :local gauge ({});
    :do {
        # count the number of dhcp leases
        :set dhcpLeaseCount [:len [/ip dhcp-server lease find]];
        # add IPv6 leases
        :set dhcpLeaseCount (\$dhcpLeaseCount + [:len [/ipv6 address find]]);
    } on-error={
        :set dhcpLeaseCount \$dhcpLeaseCount;
    }
    :set (\$gauge->0) ({\"name\"=\"Total DHCP Leases\"; \"point\"=\$dhcpLeaseCount});
    :set (\$pings->0) ([\$getPingingMetrics]);
    :set cout {
        \"ping\"=\$pings;
        \"wap\"=\$wapArray;
        \"interface\"=\$ifaceDataArray;
        \"system\"=\$systemArray;
        \"gauge\"=\$gauge
        };
    # :set cout [\$toJon \$cout]
    :return \$cout;
};
# Function to remove special chars (\\n, \\r, \\t) from strings;
# usages:
#   :put [\$removeSpecialCharacters  [:tostr \"Hello\\nWorld!\\r\\t\"]]
#   :put [:toarray [\$removeSpecialCharacters ([/tool fetch url=\"https://cloudflare.com/cdn-cgi/trace\" mode=http as-value output=user]->\"data\") t=\";\"]];
:global removeSpecialCharacters do={
  :local inputString \$1;
  :local splitern \$n;
  :local spliters \$s;
  :local splitert \$t;
  :local cleanString \"\";
  :local charcode \"\";
  :local lastidx 0;
  :local char [:convert [:tostr \$inputString] to=hex];
  :for i from=2 to=[:len \$char] step=2 do={
    :set charcode [:pick \$char \$lastidx \$i];
    :if (\$charcode != \"0a\" && \$charcode != \"0d\" && \$charcode != \"09\") do={
        :set cleanString (\$cleanString . \$charcode);
    } else={
        :if (any\$splitern) do={
            :set cleanString (\$cleanString . [:convert [:tostr \$splitern] to=hex]);
        }
        :if (any\$splitern) do={
            :set cleanString (\$cleanString . [:convert [:tostr \$splitern] to=hex]);
        }
        :if (any\$splitert) do={
            :set cleanString (\$cleanString . [:convert [:tostr \$splitert] to=hex]);
        }
    }
    :set lastidx \$i;
  }
  :return [:convert \$cleanString from=hex];
}

# Function to get wanIp
# usage:
#   :put [\$getWanIp]
:global getWanIp do={
    # WAN Port IP Address
    :local wanIp;
    # Check for PPPoE interface
    :local pppoeInterface [/interface pppoe-client find where running=yes disabled=no]
    :if ([:len \$pppoeInterface] > 0) do={
      :set wanIp [ip address get [find where interface=[/interface pppoe-client get (\$pppoeInterface->0) name]] address]
    } else={
      # Check for DHCP client
      :local dhcpClientIp [/ip dhcp-client get [find where status=bound] address]
      :if ([:len \$dhcpClientIp] > 0) do={
        :set wanIp \$dhcpClientIp;
      } else={
        # Check for IP address on the first Ethernet interface
        # get the first running ether interface name and find the matched ip address in that same vlan
        :set wanIp [:tostr [/ip address get [ find where interface=[/interface get ([find where running=yes type=ether]->0) name]] address]];
        # If none of the above, try using external service to determine public IP
        :if ([:len \$wanIp] = 0) do={
          :set wanIp \"\";
        }
      }
    }
    :return [:pick \$wanIp 0 [:find \$wanIp \"/\"]];
}
# Function to construct update request
:global getUpdateBody do={
  :global getCollections;
  :global rosTsSec;
  :global getWanIp;
  :global toJson;
  :local upTime [/system resource get uptime];
  :local runcount 1;
  :set upTime [\$rosTsSec \$upTime];
  :if ([:len [/system script find where name~\"ispappUpdate\"]] > 0) do={
    :set runcount [/system script get ispappUpdate run-count];
  }
  :return [\$toJson ({
    \"collectors\"=[\$getCollections];
    \"wanIp\"=[\$getWanIp];
    \"uptime\"=([:tonum \$upTime]);
    \"sequenceNumber\"=\$runcount
  })];
}
# Function to send update request and get back update response
# usage:
#   :local update ([\$sendUpdate]); if (\$update->\"status\") do={ :put (\$update->\"output\"->\"parsed\"); }  
:global sendUpdate do={
  :global ispappHTTPClient;
  :global getUpdateBody;
  :global connectionFailures;
  :local response ({});
  :local requestBody \"{}\";
  :do {
    :set requestBody [\$getUpdateBody];
    :set response [\$ispappHTTPClient m=post a=update b=\$requestBody];
    :return {
      \"status\"=true;
      \"output\"=\$response;
    };
  } on-error={
    :log info (\"HTTP Error, no response for /update request to ISPApp, sent \" . [:len \$requestBody] . \" bytes.\");
    :set connectionFailures (\$connectionFailures + 1);
    :error \"HTTP error with /update request, no response receieved.\";
    :return {
      \"status\"=false;
      \"reason\"=\$response;
    };
  }
}
# Function toperform speedtest and send results back to bandwith end point
:global SpeedTest do={
  :global ispappHTTPClient;
  :global toJson;
  :do {
    :local txAvg 0 
    :local rxAvg 0 
    :local txDuration 
    :local rxDuration 
    :local ds [/system clock get date];
    :local currentTime [/system clock get time];
    :set currentTime ([:pick \$currentTime 0 2].[:pick \$currentTime 3 5].[:pick \$currentTime 6 8])
    :set ds ([:pick \$ds 7 11].[:pick \$ds 0 3].[:pick \$ds 4 6])
    /tool bandwidth-test protocol=tcp direction=transmit address=\$ipbandswtestserver user=\$btuser password=\$btpwd duration=5s do={
      :set txAvg (\$\"tx-total-average\");
      :set txDuration (\$\"duration\")
      }
    /tool bandwidth-test protocol=tcp direction=receive address=\$ipbandswtestserver user=\$btuser password=\$btpwd duration=5s do={
    :set rxAvg (\$\"rx-total-average\");
    :set rxDuration (\$\"duration\")
    }
    :local results {
      \"date\"=\"\$ds\";
      \"time\"=\"\$currentTime\",
      \"txAvg\"=\"\$txAvg\";
      \"rxAvg\"=\"\$rxAvg\";
      \"rxDuration\"=\"\$rxDuration\";
      \"txDuration\"=\"\$txDuration\"
    };
    :local jsonResult [\$toJson \$results];
    :log debug (\$jsonResult);
    :local result [\$ispappHTTPClient a=bandwidth m=post b=\$jsonResult];
    :put (\$result);
  } on-error={
    :log info (\"HTTP Error, no response for speedtest request with command error to ISPApp.\");
  }
}
# Function to fetch Upgrade script and execute it
:global execActions do={
  :if (\$a = \"upgrade\") do={
    :global topDomain;
    :global SpeedTest;
    :global login;
    :global topKey;
    :global topServerPort;
    :local upgradeUrl (\"https://\" . \$topDomain . \":\" . \$topServerPort . \"/v1/host_fw?login=\" . \$login . \"&key=\" . \$topKey);
    :do {
          /tool fetch check-certificate=yes url=\"\$upgradeUrl\" output=file dst-path=\"ispapp-upgrade.rsc\";
          /import \"/ispapp-upgrade.rsc\";
    } on-error={
      :error \"HTTP error downloading upgrade file\";
    }
    :return \"\";
  }
  :if (\$a = \"reboot\") do={
    /system reboot;
    :return \"\";
  }
  :if (\$a = \"executeSpeedtest\") do={
    :put [\$SpeedTest];
    :return \"\";
  }
  :return \"usage:\\n\\t \\\$execActions  a=<upgrade|reboot>\";
}

# Functions to submit cmds to ispappConsole
:global submitCmds do={
  :global cmdsarray;
  :local added 0;
  if ([:typeof \$1] != \"array\") do={
    :log error \"Cmds comming from update response can't be submited\";
    :return 0;
  };
  :local nextindex 0; 
  if (!any\$cmdsarray) do={
    :set cmdsarray ({});
  } else={
    :set nextindex ([:len \$cmdsarray]);
  }
  :foreach i,command in=\$1 do={
    if (!any[:find [:tostr \$command] \"Err.Rais\"]) do={
      :local cmd (\$command->\"cmd\");
      :local stderr (\$command->\"stderr\");
      :local stdout (\$command->\"stdout\");
      :local uuidv4 (\$command->\"uuidv4\");
      :local wsid (\$command->\"ws_id\");
      :local cmdtraited false;
      :foreach i,scmd in=\$cmdsarray do={
        if (\$scmd->\"uuidv4\" = \$uuidv4) do={
          :set cmdtraited true;
        }
      }
      :delay 1s;
      if (!\$cmdtraited) do={
        :set (\$cmdsarray->\$nextindex) ({
          \"cmd\"=\$cmd;
          \"stderr\"=\$stderr;
          \"stdout\"=\$stdout;
          \"uuidv4\"=\$uuidv4;
          \"ws_id\"=\$wsid;
          \"executed\"=false
        });
        :set added (\$added + 1);
      }
    }
    :set nextindex ([:len \$cmdsarray]);
  }
  :return \"\$added Commands was sent for processing ~\\n\";
}

# function to parse commands from web terminal
:global executeCmds do={
  :global cmdsarray;
  :global execCmd;
  :global base64EncodeFunct;
  :global toJson;
  :global ispappHTTPClient;
  :local output \"\";
  :local out ({});
  :local cmdJsonData \"\";
  :local object ({});
  :local lenexecuted 0;
  :local runcount 1;
  :if ([:len [/system script find where name~\"ispappUpdate\"]] > 0) do={
    :set runcount [/system script get ispappUpdate run-count];
  }
  if ([:len \$cmdsarray] > 0) do={
    :foreach i,cmd in=\$cmdsarray do={
      if (\$cmd=>\"executed\" = false) do={
        :set output [\$execCmd (\$cmd->\"cmd\") (\$cmd->\"uuidv4\")];
        :set object ({
          \"cmd\"=(\$cmd->\"cmd\");
          \"uuidv4\"=(\$cmd->\"uuidv4\");
          \"ws_id\"=(\$cmd->\"ws_id\");
          \"sequenceNumber\"=\$runcount;
          \"executed\"=true
        }+\$output);
        :set cmdJsonData [\$toJson \$object];
        :local nextidx [:len \$out];
        :set (\$out->\$nextidx) ([\$ispappHTTPClient a=update m=post b=\$cmdJsonData]->\"status\");
        :set (\$cmdsarray->\$i) \$object;
        :set lenexecuted (\$lenexecuted + 1);
      }
    } 
  }
  if ([:len \$cmdsarray] > 5) do={
    :set \$cmdsarray [:pick \$cmdsarray ([:len \$cmdsarray] - 5) ([:len \$cmdsarray])]; 
  }
  :return {
    \"responses\"=\$out;
    \"msg\"=\"\$lenexecuted commands was executed with success.\"
  };
};
# Function to exec a cmd for ROS older than 7.8 and newer ones too
# usage: :put [\$execCmd \"/ip address print\" \"uuid\"];
# return: {\"stderr\"=...; \"stdout\"=...}
:global execCmd do={
  :global cmpversion;
  :global base64EncodeFunct;
  :local output \"error timeout!\";
  :local parsedcmd;
  :local timeout 30;
  :local wait 0;
  :local cmd \$1;
  :local outputFilename \"_filename_.txt\";
  :global scriptname;
  if ([:len \$2] > 0) do={
    :set outputFilename (\$2 . \"ispappCommandOutput.txt\");
    :set scriptname (\$2 . \"ispappCommand\");
  } else={
    :set output [\$base64EncodeFunct stringVal=\"❌ no uuidv4 with command!\"];
    :return {\"stderr\"=\"\$output\"; \"stdout\"=\"\"};
  }
  :do {
    :set parsedcmd [:parse (\$cmd)]; # check if cmd have correct syntax
    if ([:len [/system script find name~\"\$scriptname\"]] = 0) do={
      /system script add name=\"\$scriptname\" source=\"\$cmd\";
    } else={
       /system script set [find name~\"\$scriptname\"] source=\"\$cmd\";
    }
    :local jobid [:execute script={/system script run \"\$scriptname\";} file=\$outputFilename];
    :delay 2s;
    # :put ([:len [/system script job find where script~\"\$scriptname\"]] > 0 && \$wait <= \$timeout);
    :while ([:len [/system script job find where script~\"\$scriptname\"]] > 0 && \$wait <= \$timeout) do={
      :local remains (\$timeout - \$wait);
      :put \"waiting \$remains seconds more for job with id:\$jobid\";
      :delay 1s;
      :set wait (\$wait + 1);
    }
    if (\$wait > \$timeout && [:len [/file get \$outputFilename size]] = 0) do={
      :do { /system script job remove \$jobid } on-error={}
      /file remove [find where name~\"\$outputFilename\"];
      /system script remove [find where name~\"\$scriptname\"];
      :set output [\$base64EncodeFunct stringVal=\$output];
      :return {\"stderr\"=\"\$output\"; \"stdout\"=\"\"};
    } else={
      :set output [/file get \$outputFilename contents];
      :set output [\$base64EncodeFunct stringVal=\$output];
      /file remove [find where name~\"\$outputFilename\"];
      /system script remove [find where name~\"\$scriptname\"];
      if ([:len \$output] = 0) do={
        :set output [\$base64EncodeFunct stringVal=\"✅ Executed with success\"];
      }
      :return {\"stderr\"=\"\"; \"stdout\"=\"\$output\"};
    }
  } on-error={
    :set output [\$base64EncodeFunct stringVal=\"❌ Command can't be executed\"];
    /file remove [find where name~\"\$outputFilename\"];
    /system script remove [find where name~\"\$scriptname\"];
    :return {\"stderr\"=\"\$output\"; \"stdout\"=\"\"};
  }
}
# Function to back up router config and sent result back vi an email
:global ConfigBackup do={
  :global rosTimestringSec;
  :do {
      # get the unix timestamp
      :global lastLocalConfigurationBackupSendTs;
      # non documented typeof value of nothing happens when you delete an environment variable, RouterOS 6.49.7
      if ([:typeof \$lastLocalConfigurationBackupSendTs] = \"nil\" || [:typeof \$lastLocalConfigurationBackupSendTs] = \"nothing\") do={
        # set first value
        :set lastLocalConfigurationBackupSendTs 0;
      }
      :local currentTimestring ([/system clock get date] . \" \" . [/system clock get time]);
      :local currentTs [\$rosTimestringSec \$currentTimestring];
      :local lastBackupDiffSec (\$currentTs - \$lastLocalConfigurationBackupSendTs);
      #:log info (\"lastBackupDiffSec\", \$lastBackupDiffSec);
      if (\$lastBackupDiffSec > 60 * 60 * 12) do={
        # send a new local configuration backup every 12 hours
        :log info (\"sending new local configuration backup\");
        :execute {
          # set last backup time
          :local lastLocalConfigurationBackupSendTimestring ([/system clock get date] . \" \" . [/system clock get time]);
          :global lastLocalConfigurationBackupSendTs [\$rosTimestringSec \$lastLocalConfigurationBackupSendTimestring];
          # send backup
          # run the script and place the output in a known file
          :local scriptJobId [:execute script={/export terse;} file=ispappBackup.txt];
          # wait 10 minutes for the export to finish
          :delay 600s;
          :global login;
          :global simpleRotatedKey;
          :global topDomain;
          :global topSmtpPort;
          /tool e-mail send server=(\$topDomain) from=(\$login . \"@\" . \$simpleRotatedKey . \".ispapp.co\") to=(\"backup@\" . \$topDomain) port=(\$topSmtpPort) file=\"ispappBackup.txt\" subject=\"c\" body=\"{}\";
        };
      }
  } on-error={
    :log info (\"ISPApp, error with configuration backups.\");
  }
};

# Function to get system version and compare to input version
# usage:
#       :put [\$cmpversion] or :put [\$cmpversion cmp=\"6.8\"]
:global cmpversion do={
  :local thisversion [/system resource get version];
  :set thisversion [:pick \$thisversion 0 [:find \$thisversion \" \"]];
  :local cmp \$1;
  if (!any\$1) do={
    :set cmp \$thisversion;
  }
  :local version do={
    :local v \"\";
    :for i from=0 to=[:len \$1] do={
      :local char [:pick \$1 \$i (\$i+1)];
      if (any[:tonum \$char]) do={
        :set v (\$v . \$char);
      }
    }
    if ([:len \$1] > [len \$v]) do={
      :for i from=[len \$v] to=[:len \$1] do={ 
        :set v (\$v . \"0\");
      }
    }
    :return [:tonum \$v];
  }
  :return {
    \"current\"=([\$version \$thisversion]);
    \"target\"=([\$version \$cmp]);
    \"compatible\"=([\$version \$thisversion] >= [\$version \$cmp])
  }
};
# convert buit-time to timestamp
:global getTimestamp do={
  # Nov/09/2023 07:45:06 - input ›
  :if (!any\$1) do={:return 0;}
  :global strcaseconv;
  :local pYear [:pick \$1 7 11];
  :local pday [:pick \$1 4 6];
  :local pmonth [:pick \$1 0 3];
  :local phour [:pick \$1 12 14];
  :local pminute [:pick \$1 15 17];
  :local psecond [:pick \$1 18 20];
  :local monthNames [:toarray \"jan,feb,mar,apr,may,jun,jul,aug,sep,oct,nov,dec\"];
  :local monthDays (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
  :local monthName ([\$strcaseconv \$pmonth]->\"lower\");
  :local monthNum ([:find \$monthNames \$monthName]);
  :put (\$monthNum);
  :local month 0;
  :foreach i in=[:pick \$monthDays 0 \$monthNum] do={ :set month (\$month + ([:tonum \$1] * 86400)) };
  :local day (([:tonum \$pday] - 1) * 86400)
  :local years ([:tonum \$pYear] - 1970);
  :local leapy (([:tonum \$pYear] - 1972) / 4);
  :local noleapy (\$years - \$leapy)
  if ((([:tonum \$pYear] - 1970) % 4) = 2) do={
    :set leapy (\$leapy - 1);
    if ((\$monthNum + 1) >= 2) do={ :set month (\$month - 86400); }
  } else={ :set noleapy (\$noleapy - 1) }
  :set years ((\$leapy * 31622400) + (\$noleapy * 31536000))
  :local time ((([:tonum \$phour] - 1)*3600)+(([:tonum \$pminute] - 1)*60)+([:tonum \$psecond]))
  :return (\$month + \$day + \$years + \$time);
}
:put \"\\t V4 Library loaded! (;\";"