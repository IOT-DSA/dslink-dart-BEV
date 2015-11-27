library dslink.bev.client;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class BevClient {
  static final Map<String, BevClient> _cache = <String, BevClient>{};

  final String username;
  final String password;
  final Uri rootUri;

  HttpClient _client;
  HttpClientDigestCredentials _auth;
  List<String> _dataPoints;

  factory BevClient(String username, String password, Uri rootUri) =>
      _cache[rootUri.toString()] ??= new BevClient._(username, password, rootUri);

  BevClient._(this.username, this.password, this.rootUri) {
    _client = new HttpClient();
    _auth = new HttpClientDigestCredentials(username, password);

    _client.authenticate = (Uri uri, String scheme, String realm) async {
      _client.addCredentials(uri, realm, _auth);
      return true;
    };
  }

  Future<List<String>> getDatapoints({force: false}) async {
    if (_dataPoints == null || force) {
      var jsonMap = await _getRequest(rootUri);
      _dataPoints = jsonMap['hrefs'];
    }
    return _dataPoints;
  }

  Future<List> getData(String url) async {
    var uri = Uri.parse('${rootUri.toString()}$url');
    var jsonMap = await _getRequest(uri);

    return jsonMap['datapoints'];
  }

  Future<List> getMultiData(Iterable<String> ids) async {
    var queryStr = '?ids=${ids.join(',')}';
    var uri = Uri.parse('${rootUri.toString()}$queryStr');
    var map = await _getRequest(uri);
    return map['datapoints'];
  }

  Future<Map> _getRequest(Uri uri) async {
    var req = await _client.getUrl(uri);
    var resp = await req.close();
    var body = await resp.transform(UTF8.decoder).join();
    Map result;
    try {
      result = JSON.decode(body);
    } catch (e, stack) {
      print('Error decoding response: ${e.message}');
      print('Address was: $uri');
      print('Response was: $body');
      return {'datapoints': []};
    }
    return result;
  }

  // Force the connection to close.
  void close() => _client.close(force: true);
}