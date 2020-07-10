import 'package:cockpit_client/cockpit_client.dart';

main() async {
// Init cockpit client
  Cockpit.init({
    "server": "http://192.168.2.1",
    "baseUrl": "/",
    "token": "58e20fae9f86dc1a493d11bc5d6a18",
    "filter": {
      //Global filter
      r"$or": [
        {"delete": false},
        {
          "delete": {r"$exists": false}
        }
      ]
    },
    "api": {
      // Collections
      "myCollection": {
        "collection": "users",
        "sort": {"login": 1},
        "fields": ["nom", "prenom", "parent", "login", "enabled", "_create_by"]
      },
      "myForm": {"form": "sendmail"},
      "mySingleton": {"singleton": "configurations"},
      "slides": {
        "collection":
            "collection_or_form_name", //collection or form name in cockpit
        "limit": 5, // limit when get data from server
        "sort": {
          // sort results
          "_o": 1
        },
        "fields": [
          // fields to gets from the server, other will be ignored
          "title",
          "image",
          "description",
          "backgroundColor",
          "fontColor"
        ],
        "map": {
          // change value of a property or set new property in result object
          // you can build string from a template
          "image": "{{SERVER}}{{image.path}}",
          "body": "{{description}}"
        },
      },
    }
  });

  print(await Cockpit("api_access").find(
    cache: Duration(hours: 1), // [optional] cache result
  ));
}
