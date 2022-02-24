library cockpit_client;
// dependencies:
//   http: ^0.12.1

// Cockpit REST Client
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_engine/liquid_engine.dart';
import 'package:hash/hash.dart';
import 'package:dbcrypt/dbcrypt.dart';


Map<Key, http.Client> _fetch = {};
Map<String, String> _cache = {};
Map<String, Timer> _cacheTTL = {};
Map<String, dynamic> _config = {};
dynamic _templateEngine(String tmpl, Map<String, dynamic> data) {
  Context context = Context.create();
  context.variables.addAll(data);
  Template template = Template.parse(context, Source.fromString(tmpl));
  return template.render(context);
}

_closeFetch(Key collectionName) {
  if (_fetch.containsKey(collectionName)) {
    debugPrint("Close last request $collectionName");
    _fetch[collectionName]!.close();
    _fetch.remove(collectionName);
  }
}

Future<List<T>> Function({
  int? limit,
  int? page,
  String? id,
  dynamic fields,
  bool? populate,
  Map<String, dynamic>? filter,
  bool? ignoreDefaultFilter,
  Map<String, dynamic>? save,
  Duration? cache,
}) _getOrSetData<T>(
  String prop, {
  bool? isSingleton,
  bool? isForm,
  bool? isApi,
  bool? notConfigured,
  Key? key,
}) {
  return ({
    page,
    id,
    fields,
    filter,
    save,
    cache,
    ignoreDefaultFilter = false,
    limit = 10,
    populate = true,
  }) async {
    // limit = limit ?? 10;
    // populate = populate ?? true;
    // save = save ?? null;
    // cache = cache ?? Duration(hours: 1);
    // ignoreDefaultFilter = ignoreDefaultFilter ?? false;
    if (!Cockpit.isConfigured) throw "config is not defined";
    final Map<String, dynamic> obj = _config["api"];
    Map<String, dynamic> params = {};
    final Map<String, dynamic> api = {};

    if (!obj.containsKey(prop)){
      if(RegExp(r"^(@|#|\*|!)").hasMatch(prop)){
        api[({
          "@" : "singleton",
          "#" : "form",
          "*" : "collection",
          "!" : "api"
        })[prop[0]]!] = prop.substring(1);
      }else{
        api["collection"] = prop;
      }
    }else{
      // populate api
      (obj[prop] as Map<String, dynamic>).forEach((key, value) {
        api[key] = value;
      });
    }

    if (api.containsKey("form")) {
      api["isForm"] = true;
      api["isSingleton"] = false;
      api["isApi"] = false;
    }
    if (api.containsKey("singleton")) {
      api["isForm"] = false;
      api["isSingleton"] = true;
      api["isApi"] = false;
    }
    if (api.containsKey("collection")) {
      api["isForm"] = false;
      api["isSingleton"] = false;
      api["isApi"] = false;
    }
    if (api.containsKey("api")) {
      api["isForm"] = false;
      api["isSingleton"] = false;
      api["isApi"] = true;
    }

    if (api["isForm"] != null && api["isForm"] && save == null)
      throw "$prop is a form";
    if (api["isSingleton"] != null && api["isSingleton"] && save != null)
      throw "$prop is a singleton";
    if (save == null) {
      fields =
          fields ?? (id != null ? api["findOneFields"] : api["fields"]) ?? {};
      if (fields is List) {
        List tmp = fields;
        fields = {};
        tmp.forEach((b) {
          fields[b] = true;
        });
      } else if (fields is String) {
        fields = {"$fields": true};
      } else if (!(fields is Map)) {
        fields = {};
      }
      Map<String, dynamic> tmp = {};
      if (id != null && save == null) {
        tmp.addAll({"_id": id});
      } else if (save == null) {
        tmp.addAll(filter ?? {});
      }
      if ((ignoreDefaultFilter ?? false) == false) {
        tmp = {
          r"$and": [
            if (_config["filter"] != null) _config["filter"] ?? {},
            if (api["filter"] != null) api["filter"] ?? {},
            tmp
          ]
        };
        if (tmp[r"$and"].length == 1) tmp = tmp[r"$and"][0];
      }
      bool _populate = (populate ?? api["populate"] ?? true);
      params = {
        "limit": id != null ? null : (limit ?? api["limit"] ?? 10),
        "skip": id != null
            ? null
            : (page != null ? ((page + 1) * (limit ?? api["limit"])) : 0),
        "sort": id != null ? null : (api["sort"] ?? {"_created": -1}),
        "simple": 1,
        "populate": _populate ? 1 : 0,
        "fields": fields ?? {},
        "filter": tmp
      };
    }
    String collectionName;
    isSingleton = isSingleton ??
        api["isSingleton"] != null &&
            api["isSingleton"] is bool &&
            api["isSingleton"] == true;
    isForm = isForm ??
        api["isForm"] != null && api["isForm"] is bool && api["isForm"] == true;
    isApi = isApi ??
        api["isApi"] != null && api["isApi"] is bool && api["isApi"] == true;
    if (isForm!)
      collectionName = api["form"] ?? api["url"];
    else if (isSingleton!)
      collectionName = api["singleton"] ?? api["url"];
    else if (isApi!)
      collectionName = api["api"] ?? api["url"];
    else
      collectionName = api["collection"] ?? api["url"];

    var url = (api["server"] ?? _config["server"]) +
        (api["baseUrl"] ?? _config["baseUrl"] ?? "") +
        "/api/";
    if (!(isApi!)) {
      if (save != null)
        url += (isForm! ? 'forms/submit/' : 'collections/save/');
      else
        url += (isSingleton! ? 'singletons' : 'collections') + '/get/';
    }
    url += collectionName;
    url += "?token=${api["token"] ?? _config["token"]}";
    T map(Map<String, dynamic>? el) {
      if (el != null) {
        Map<String, dynamic> map = api["map"] ?? {};
        map.forEach((e, value) {
          el[e] = _templateEngine(map[e], {
            ...el,
            "SERVER": (api["server"] ?? _config["server"]),
            "BASEURL": (api["baseUrl"] ?? _config["baseUrl"] ?? "")
          });
        });
      }
      return el as T;
    }
    // print("URL $url $api");


    Key _key = key ?? Key(collectionName);
    _closeFetch(_key);
    _fetch[_key] = http.Client();

    var body = isSingleton!
        ? null
        : (save != null)
            ? jsonEncode({"${isForm! ? 'form' : 'data'}": save})
            : jsonEncode(params);
    // print("BODY $body");
    response() => _fetch[_key]!.post(
          Uri.parse(url),
          headers: isSingleton! ? null : {'Content-Type': 'application/json'},
          body: body,
        );
    var resBody = "";
    var res;
    try {
      if (cache != null) {
        // check cache
        String cacheUrl = String.fromCharCodes(
            MD5().update("$url :: ${body ?? ''}".codeUnits).digest());
        // print("cacheUrl $cacheUrl");
        if (!_cache.containsKey(cacheUrl)) {
          resBody = (await response()).body;
          res = await compute(_decodeString, resBody);
          _cache[cacheUrl] = resBody;
          _cacheTTL[cacheUrl] = Timer(cache, () {
            // clear Cache
            _cache.remove(cacheUrl);
            _cacheTTL.remove(cacheUrl);
          });
        } else
          resBody = _cache[cacheUrl]!;
      } else {
        resBody = (await response()).body;
        res = await compute(_decodeString, resBody);
      }
      // print("resBody $resBody");
    } finally {
      _closeFetch(_key);
    }

    if (res is Map && res.length == 1 && res.containsKey("error"))
      throw res["error"];
    if (res is Map &&
        res.length == 2 &&
        res.containsKey("error") &&
        res["error"] != null &&
        res["error"] == true &&
        res.containsKey("message")) throw res["message"];
    res = ((isSingleton! || save != null) ? [res] : res); //<Map<String, dynamic>>;
    if(res is List)
      res = res.map((value) => map(value)).toList().whereType<T>().toList();
    
    return res is List ? (res as List<T>) : [];
  };
}

_decodeString(String json) async {
  dynamic res;
  try {
    res = jsonDecode(json);
  } catch (e) {
    debugPrint("JSON DECODE  ==> $json");
    debugPrint("JSON DECODE ERROR ==> $e");
  }
  return res;
}

class Cockpit {
  final String collection;
  final key;
  noSuchMethod(Invocation invocation) {
    debugPrint("noSuchMethod#${invocation.memberName.toString()}");
  }
  static String hash(String plainPassword){
    return  DBCrypt().hashpw(plainPassword, new DBCrypt().gensaltWithRounds(10)).replaceFirst(RegExp(r"^\$.{2}\$"), r"$2y$");
  }
  static bool get isConfigured => _config.keys.isNotEmpty;
  // static API collection(String collection) => ;
  static init({
    // cockpit host (url)
    required Uri server,
    required String token,
    Map<String, dynamic>? defaultFilter,
    Map<String, dynamic> api = const {}
  }) {
    var baseUrl = server.path;
    server = server.replace(path: "", query: "");
    Map<String, dynamic> config = {
      "api" : api,
      "server" : server.toString(),
      "token" : token,
      "baseUrl" : baseUrl,
      "filter" : defaultFilter
    };

    if(config["api"] ==  null)
      config["api"] = <String,dynamic>{};
    if(config["baseUrl"] ==  null)
      config["baseUrl"] = "";
    _config = config;
    if ((_config["baseUrl"] as String).endsWith("/"))
      _config["baseUrl"] =
          _config["baseUrl"].substring(0, _config["baseUrl"].length - 1);
    _config["baseUrl"] =
        ("/"+_config["baseUrl"]).replaceAll(RegExp(r"/+"), "/");
    if (_config["server"].endsWith("/"))
      _config["server"] =
          _config["server"].substring(0, _config["server"].length - 1);
  }

  final Future<List<Map<String, dynamic>>> Function({
    dynamic fields,
    int? limit,
    int? page,
    String? id,
    bool? populate,
    bool? ignoreDefaultFilter,
    Map<String, dynamic>? filter,
    Map<String, dynamic>? save,
    Duration? cache,
  }) _collection;
  Cockpit(
    this.collection, {
    this.key,
  }) : _collection = _getOrSetData<Map<String, dynamic>>(collection, key: key);
  Future<List<Map<String, dynamic>>> find({
    dynamic fields,
    int? limit,
    int? page,
    bool? ignoreDefaultFilter,
    bool? populate,
    Map<String, dynamic>? filter,
    Duration? cache,
  }) =>
      _collection(
        limit: limit,
        page: page,
        fields: fields,
        ignoreDefaultFilter: ignoreDefaultFilter ?? false,
        populate: populate ?? true,
        filter: filter,
        cache: cache,
      );
  Future<Map<String, dynamic>?> findOne({
    dynamic fields,
    bool? ignoreDefaultFilter,
    bool? populate,
    Map<String, dynamic>? filter,
    Duration? cache,
  }) async {
    var ret = (await find(
      limit: 1,
      fields: fields,
      ignoreDefaultFilter: ignoreDefaultFilter ?? false,
      populate: populate ?? true,
      filter: filter,
      cache: cache,
    ));
    return (ret.isEmpty ? null : ret)?.first.map((key, value) => MapEntry("$key", value));
  }

  Future<Map<String, dynamic>?> get({
    required String id,
    dynamic fields,
    bool? populate,
    Duration? cache,
  }) async {
    var ret = (await _collection(
      id: id,
      fields: fields,
      populate: populate ?? true,
      cache: cache,
      limit: 1,
    ));
    return (ret.isEmpty ? null : ret)?.first.map((key, value) => MapEntry("$key", value));
  }

  Future<Map<String, dynamic>?> save({
    required Map<String, dynamic> data,
  }) async {
    var ret = (await _collection(
      save: data,
    ));
    return (ret.isEmpty ? null : ret)?.first;
  }

  void cancelLastRequest() {
    _closeFetch(key ?? Key(collection));
  }
}