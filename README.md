
# Client for cockpit CMS

A http-client for your Cockpit CMS content.


[![Version](https://img.shields.io/pub/v/cockpit_client.svg?color=8e44ad&logo=flutter)](https://pub.dev/packages/cockpit_client) ![GitHub license](https://img.shields.io/badge/license-MIT-white.svg?style=flat&style=for-the-badge&logo=github)  ![By lynn](https://img.shields.io/badge/aut-Lynn-d35400.svg?label=Author&style=flat&style=for-the-badge&logo=open-collective&labelColor=2980b9)

## How Install

### Flutter:

```bash
$ flutter pub add cockpit_client
```

### Pubspec.yaml

Add a line like this to your package's pubspec.yaml 

```yaml
dependencies:
  cockpit_client: ^1.0.6-b
```

And run if your editor don't support flutter

```bash
flutter pub get
```

### And import it

Now in your Dart code, add

```dart
import 'package:cockpit_client/cockpit_client.dart';
```

## How Initialize
---

### Minimal

```dart
import 'package:cockpit_client/cockpit_client.dart';

// Minimal Initialisation 
Cockpit.init(
    server: Uri.parse("http://[SERVER HOST]"),
    token: "[API TOKEN]",
);
```

### Cocpit is not in root web folder 

```dart
import 'package:cockpit_client/cockpit_client.dart';

// Custom path 
Cockpit.init(
    server: Uri.https("[SERVER HOST]"."/cockpit/folder"),
    // OR
    //server: Uri.http("[SERVER HOST]"."/cockpit/folder"),
    // OR
    //server: Uri.parse("http://[SERVER HOST]/cockpit/folder"),
    token: "[API TOKEN]",
);
```


### Filter for all request 

```dart
import 'package:cockpit_client/cockpit_client.dart';

// never get deleted fields
Cockpit.init(
    server: Uri.https("[SERVER HOST]"."/cockpit/folder"),
    token: "[API TOKEN]",
    defaultFilter : {
      r"$or" :[
        { "delete" : {$eq : false} },
        { "delete" : {$eq : null} },
        {
          "delete" : {
            r"$exist" : false
          }
        }
      ]
    }
);
```

### (Optional) Declare endpoint

```dart
import 'package:cockpit_client/cockpit_client.dart';

// Api declaration
Cockpit.init(
    server: Uri.https("[SERVER HOST]"."/cockpit/folder"),
    token: "[API TOKEN]",
    api : { 
      // Collection
      "myCollection" :  {
        "collection": "users", // real collection name
        "sort": {"login": 1}, // default sort
        "fields": [ // get only this fields
          "nom",
          "prenom",
          "parent",
          "login",
          "enabled",
          "_create_by"
        ]
      },
      // Form
      "myForm" :  {
        "form": "sendmail" // real form name
      },
      // Singleton
      "mySingleton" : {
        "singleton": "configurations" // real singleton name
      },
      // clollection with virtual properties (map)
      "slides" : {
        "collection": "collection_name", //collection name in cockpit
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
        "map": { // change value of a property or set  a new property in result object
          // you can build string from a template
          "image": "{{SERVER}}{{image.path}}",
          // or map a property's value to another
          "body" : "{{description}}"
        },
      },
    }
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
Map<String, dynamic> result = await Cockpit("user").get("[My Super ID]");
// get only some fields
Map<String, dynamic> result = await Cockpit("user").get("[My Super ID]", fields : ["nom", "prenom"]
);

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

### Read undeclared endpoint


To read an undelared endpoint you can just pass the name and use a prefix to specify the type (form, singleton,collection or custom url)


| Prefix | Type               | Usage                                                         |
|--------|--------------------|---------------------------------------------------------------|
| *      | Collection         | `Cockpit("my_collection")` OR  `Cockpit("*my_collection")` |
| @      | Singleton          | `Cockpit("@my_singleton")`                                  |
| #      | Form               | `Cockpit("#my_form")`                                       |
| !      | Custom Cockpit Api | `Cockpit("!my/custom/url")`                                 |

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

### post to a Custom Url

```dart
// post data to a custom cockpit url
Map<String, dynamic> data = await Cockpit("!/addons/save/gps").get(
  data : {
    lat : -19.016682,
    long : 26.806641,
    alt : 15,
  },
);
```

## Cockpit urls


### Authenticate user

```dart
Cockpit.authUser('username','xxpasswordxx')
```

### Create / Update user

```dart
Cockpit.saveUser({...}) // user data (user, name, email, active, group)
```

### Get users.

```dart
Cockpit.listUsers([Map<String, dynamic> filter]) // (optional) you can pass filter
```

### Get assets

```dart
Cockpit.assets([Map<String, dynamic> filter]) // (optional) you can pass filter
```

### Get thumbnail url

```dart
Cockpit.image(imagePath, 
  width : width,
  height : height,
  quality : quality,
  domain : domain,
  o : o,
  base64 : base64,
);
```

### Get all singletons

```javascript
Cockpit.listSingletons()
```

### Get all collections

```javascript
Cockpit.listCollections();
```

### Get collection schema

```javascript
Cockpit("collectionname").schema();
```

### Update collection schema

```javascript
Cockpit("collectionname").updateSchema(fields); // fields is List<Map<String,dynamic>>
```
