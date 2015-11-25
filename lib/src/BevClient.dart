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

  Future<List<String>> getDatapoints() async {
    if (_dataPoints != null) {
      return _dataPoints;
    }

    var req = await _client.getUrl(rootUri);
    var resp = await req.close();
    var body = await resp.transform(UTF8.decoder).join();
    var jsonMap = JSON.decode(body);
    return jsonMap['hrefs'];
  }

  // Force the connection to close.
  void close() => _client.close(force: true);
}