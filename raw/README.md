**$toJson Funtion Usage** ([**_code_**](#_tojson-funtion-usage))

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

- **_results_**:
  - JSON String: `{"age":30,"hobbies":{"music":{"0":"pop","rock":2},"sports":{"0":"football","basketball":"karim"}},"name":"John","numbers":[42,77,"letter"]}`
