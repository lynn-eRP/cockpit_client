library cockpit_client;
// dependencies:
//   http: ^0.12.1

// Cockpit REST Client
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_engine/liquid_engine.dart';

final fetch = http.Client();
Map<String, String> _cache = {};
Map<String, Timer> _cacheTTL = {};
Map<String, dynamic> _config = {};
dynamic _templateEngine(String tmpl, Map<String, dynamic> data) {
  Context context = Context.create();
  context.variables.addAll(data);
  Template template = Template.parse(context, Source.fromString(tmpl));
  return template.render(context);
}

Future<List<T>> Function({
  dynamic fields,
  int? page,
  String? id,
  int? limit,
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
}) {
  return ({
    page,
    id,
    fields,
    save,
    filter,
    cache,
    ignoreDefaultFilter,
    limit,
    populate,
  }) async {
    if (_config.isEmpty) throw "config is not defined";
    final Map<String, dynamic> obj = _config["api"];
    Map<String, dynamic> params = {};
    final Map<String, dynamic> api = {};

    if ((notConfigured ?? false)) {
      api["url"] = prop;
    } else if (!obj.containsKey(prop))
      return [];
    else {
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
      // print("FILTRE ${jsonEncode(tmp)}");
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
    if (!isApi!) {
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

    // print("URL $url");
    var body = isSingleton!
        ? null
        : (save != null)
            ? jsonEncode({"${isForm! ? 'form' : 'data'}": save})
            : jsonEncode(params);
    // print("BODY $body");
    response() => fetch.post(
          url,
          headers: isSingleton! ? null : {'Content-Type': 'application/json'},
          body: body,
        );

    var resBody = "";
    if (cache != null) {
      // check cache
      String cacheUrl = "$url :: $body";
      if (!_cache.containsKey(cacheUrl)) {
        _cache[cacheUrl] = (await response()).body;
        _cacheTTL[cacheUrl] = Timer(cache, () {
          // clear Cache
          _cache.remove(cacheUrl);
          _cacheTTL.remove(cacheUrl);
        });
      }

      resBody = _cache[cacheUrl]!;
    } else {
      resBody = (await response()).body;
    }

    var res = await decodeJSON(resBody);
    if (res is Map && res.length == 1 && res.containsKey("error"))
      throw res["error"];
    if (res is Map &&
        res.length == 2 &&
        res.containsKey("error") &&
        res["error"] != null &&
        res["error"] == true &&
        res.containsKey("message")) throw res["message"];
    res = ((isSingleton! || save != null) ? [res] : res); //<Map<String, dynamic>>;
    if(res != null && res is List)
      res = res.map((value) => map(value)).toList();
    return res ?? [];
  };
}

decodeString(String json) async {
  dynamic res;
  try {
    res = jsonDecode(json);
  } catch (e) {
    debugPrint("JSON DECODE  ==> $json");
    debugPrint("JSON DECODE ERROR ==> $e");
  }
  return res;
}

decodeJSON(String json) async {
  return compute(decodeString, json);
}

class Cockpit {
  noSuchMethod(Invocation invocation) {
    print(invocation);
  }

  // static API collection(String collection) => ;
  static init(Map<String, dynamic> config) {
    //  console.log(config);
    Map<String, bool Function(dynamic)> tmp = {
      "server": (s) => s is String,
      "baseUrl": (s) => s is String,
      "token": (s) => s is String,
      "api": (s) =>
          [
            'Map<String, Object>',
            'Map<String, dynamic>',
            '_InternalLinkedHashMap<String, Map<String, Object>>',
            '_InternalLinkedHashMap<String, Map<String, dynamic>>',
            '_InternalLinkedHashMap<String, Object>',
            '_InternalLinkedHashMap<String, dynamic>'
          ].indexOf(s.runtimeType.toString()) ==
          -1
    };
    tmp.forEach((e, val) => {
          if (config[e] == null || !val(config[e].runtimeType.toString()))
            throw "$e is bad type ${config[e].runtimeType}"
        });
    // console.log("set config", config);
    _config = config;
    if (_config["baseUrl"].endsWith("/"))
      _config["baseUrl"] =
          _config["baseUrl"].substr(0, _config["baseUrl"].length - 1);
    if (_config["server"].endsWith("/"))
      _config["server"] =
          _config["server"].substr(0, _config["server"].length - 1);
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
  Cockpit(String collection)
      : _collection = _getOrSetData<Map<String, dynamic>>(collection);
  Future<List<Map<String, dynamic>>> find({
    dynamic fields,
    int? limit,
    int? page,
    bool ?ignoreDefaultFilter = false,
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
    ));
    return (ret.isEmpty ? null : ret)?.first;
  }

  Future<Map<String, dynamic>?> save({
    required Map<String, dynamic> data,
  }) async {
    var ret = (await _collection(
      save: data,
    ));
    return (ret.isEmpty ? null : ret)?.elementAt(0);
  }
}
