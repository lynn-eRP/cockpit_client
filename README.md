# cockpit_client

REST API client for cockpit

## How Initialize

```dart
import 'package:cockpit_client/cockpit_client.dart';

// Init cockpit client
Cockpit.init({
    "server": "[SERVER NAME]",
    "baseUrl": "[URL of Cockpit folder]", //Default /
    "token": "[API TOKEN]",
    "filter": { //Global filter
      r"$or": [
        {"delete": false},
        {
          "delete": {r"$exists": false}
        }
      ]
    },
    "api": { // Collections
      "myCollection" :  {
        "collection": "users",
        "sort": {"login": 1},
        "fields": [
          "nom",
          "prenom",
          "parent",
          "login",
          "enabled",
          "_create_by"
        ]
      },
      "myForm" :  {
        "form": "sendmail"
      },
      "mySingleton" : {
        "singleton": "configurations"
      },
      "slides" : {
        "collection": "collection_or_form_name", //collection or form name in cockpit
        "limit": 5, // limit when get data from server
        "sort": { // sort results
          "_o": 1
        },
        "fields": [ // fields to gets from the server, other will be ignored
          "title",
          "image",
          "description",
          "backgroundColor",
          "fontColor"
        ],
        "map": { // change value of a property or set new property in result object
          // you can build string from a template
          "image": "{{SERVER}}{{image.path}}",
          // or map a property's value to another
          "body" : "{{description}}"
        },
      },
    }
  },
);
```

## How Use

### Read data

```dart
// get all elements
List<Map<String, dynamic>> results = await Cockpit("api_access").find(
  cache: Duration(hours : 1), // [optional] cache result
);

// get first element
Map<String, dynamic> result = await Cockpit("user").findOne(
  filter: {
    "login" : "root",
    "pwd" : "secret",
    r"$or": [
      {"disable": false},
      {
        "disable": {
          r"$exists": false,
        },
      },
    ],
  },
);
// get specific element
Map<String, dynamic> result = await Cockpit("user").get(1);
Map<String, dynamic> result = await Cockpit("user").get(1, fields : ["nom", "prenom"]);

// get one page of elements
List<Map<String, dynamic>> results = await Cockpit("api_access").find(
  limit : 10,
  page : 2
); // page start by 0, also set page to 0 for the first page, page to 1 for the second page

// get filtered elements , you can use page, limit, sort, etc. with filter
List<Map<String, dynamic>> results = await Cockpit("api_access").find(
  filter: {
    published : true,
  },
);
```

### Save data

```dart
// post data to cockpit (form and collection)
Map<String, dynamic> data = await Cockpit("api_access").save(
  data : {
    published : false,
    title : "Cool",
    description : "I'm juste a test :-p",
  },
);
```
