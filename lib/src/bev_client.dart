library dslink.bev.client;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dslink/utils.dart' show logger;

/// Client which handles communication to the REST server.
class BevClient {
  static final Map<String, BevClient> _cache = <String, BevClient>{};

  /// HTTP Digest Authentication Username
  final String username;
  /// HTTP Digest Authentication Username
  final String password;
  /// Root URI for requests. Each requested is appended to this value.
  final Uri rootUri;

  HttpClient _client;
  HttpClientDigestCredentials _auth;
  List<String> _dataPoints;

  factory BevClient(String username, String password, Uri rootUri) =>
      _cache.putIfAbsent(rootUri.toString(),
          () => new BevClient._(username, password, rootUri));

  BevClient._(this.username, this.password, this.rootUri) {
    _client = new HttpClient();
    _auth = new HttpClientDigestCredentials(username, password);

    _client.authenticate = (Uri uri, String scheme, String realm) async {
      _client.addCredentials(uri, realm, _auth);
      return true;
    };
  }

  /// Query the [rootUri] for available datapoints on this connection.
  /// If [force] is `true` then it will force a new query to the server.
  /// If [force] is `false` (default value) then it may returned cached values.
  Future<List<String>> getDatapoints({bool force: false}) async {
    if (_dataPoints == null || force) {
      var jsonMap = await _getRequest(rootUri);
      _dataPoints = jsonMap['hrefs'];
    }
    return _dataPoints;
  }

  /// Perform a `GET` request on the specified url fragment. Fragment will be
  /// appended to the client's [rootUri] to query.
  /// Returns a Future list of map values returned from the server.
  Future<List> getData(String url) async {
    var uri = Uri.parse('${rootUri.toString()}$url');
    var jsonMap = await _getRequest(uri);

    return jsonMap['datapoints'];
  }

  /// Perform a `GET` request for multiple URL fragments. Multiple values will
  /// be requested simultaneously. Returns a future list of map values.
  Future<List> getBatchData(Iterable<String> ids) async {
    var queryStr = '?ids=${ids.join(',')}';
    var uri = Uri.parse('${rootUri.toString()}$queryStr');
    var map = await _getRequest(uri);
    return map['datapoints'];
  }

  /// Perform a `PUT` request for the specified URL fragment. The specified
  /// [value] will be sent with ContentType Application/json; charset=utf-8.
  /// Returns a future list of map values for the response.
  Future<List> setData(String url, dynamic value) async {
    var body = JSON.encode({'value' : value});
    var uri = Uri.parse('${rootUri.toString()}$url');
    var map = await _setRequest(uri, body);
    return map['datapoints'];
  }

  Future<Map> _getRequest(Uri uri) async {
    var req = await _client.getUrl(uri);
    var resp = await req.close();
    var body = await resp.transform(UTF8.decoder).join();
    Map result;
    try {
      result = JSON.decode(body);
    } catch (e) {
      logger.warning('Unable to decode response', e);
      logger.fine('Address was: $uri');
      logger.fine('Response was: $body');
      return {'datapoints': []};
    }
    return result;
  }

  Future<Map> _setRequest(Uri uri, String data) async {
    var req = await _client.putUrl(uri);
    req.headers.contentType = ContentType.JSON;
    req.write(data);
    var resp = await req.close();
    var body = await resp.transform(UTF8.decoder).join();
    Map result;
    try {
      result = JSON.decode(body);
    } catch (e) {
      logger.warning('Unable to decode response', e);
      logger.fine('Address was: $uri');
      logger.fine('Response was: $body');
      return {'datapoints': []};
    }
    return result;
  }

  /// Force the connection to close.
  void close() => _client.close(force: true);
}