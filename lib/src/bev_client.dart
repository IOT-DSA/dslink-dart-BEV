library dslink.bev.client;

import 'dart:async';
import 'dart:convert';
import 'dart:collection' show Queue;
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

  int _requestPending = 0;
  static const maxRequestPending = 2;
  HttpClient _client;
  HttpClientDigestCredentials _auth;
  List<Cookie> _cookie;
  List<String> _dataPoints;
  Queue<PendingRequest> _pendingRequests;

  factory BevClient(String username, String password, Uri rootUri) =>
      _cache.putIfAbsent(rootUri.toString(),
          () => new BevClient._(username, password, rootUri));

  BevClient._(this.username, this.password, this.rootUri) {
    _pendingRequests = new Queue<PendingRequest>();
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

  /// Add request to [url] to the current Request Queue. Returns a Future<List>
  /// Which will be the results from the request when completed.
  /// This adds requests to a queue to possible be batch processed with other
  /// requests. Optional [now] argument will trigger requests to send immediately
  /// (default), if false, it will wait for another queueRequest with [now] set
  /// to true, or a call to [triggerRequests]
  Future<List> queueRequest(String url, {bool now: true}) {
    var pr = new PendingRequest(url);
    _pendingRequests.add(pr);
    if (now) {
      _sendRequests();
    }
    return pr.done;
  }

  /// Start requests if there are waiting in the queue and no request is
  /// currently pending.
  void triggerRequests() {
    _sendRequests();
  }

  Future<List> _getData(String url) async {
    var uri = Uri.parse('${rootUri.toString()}$url');
    var jsonMap = await _getRequest(uri);
    return jsonMap['datapoints'];
  }

  Future<List> _getBatchData(Iterable<String> ids) async {
    var queryStr = '?ids=${ids.join(',')}';
    var uri = Uri.parse('${rootUri.toString()}$queryStr');
    var map = await _getRequest(uri);
    return map['datapoints'];
  }

  /// Perform a `PUT` request for the specified URL fragment. The specified
  /// [value] will be sent with ContentType Application/json; charset=utf-8.
  /// Returns a future list of map values for the response.
  Future<List> setData(String url, dynamic value) async {
    var body = JSON.encode({'value': value});
    var uri = Uri.parse('${rootUri.toString()}$url');
    var map = await _setRequest(uri, body);
    return map['datapoints'];
  }

  BevClient updateClient(String username, String password, Uri uri) {
    close();
    _cache.remove(rootUri.toString());
    return new BevClient(username, password, uri);
  }

  Future<Map> _getRequest(Uri uri) async {
    HttpClientRequest req;
    HttpClientResponse resp;
    String body;
    var sw = new Stopwatch();
    sw.start();
    try {
      req = await _client.getUrl(uri);
      if (_cookie != null && _cookie.isNotEmpty) {
        req.cookies.addAll(_cookie);
      }
      resp = await req.close();
      if (resp.cookies != null && resp.cookies.isNotEmpty) {
        _cookie = resp.cookies.toList(growable: false);
      }
      sw.stop();
      body = await resp.transform(UTF8.decoder).join();
    } on HttpException catch (e) {
      logger.warning('Unable to connect to: $uri', e);
      return {'datapoints': []};
    } finally {
      logger.fine('Request duration: ${sw.elapsedMilliseconds}ms');
    }

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

  void _sendRequests() {
    if (_requestPending >= maxRequestPending) return;
    _requestPending += 1;
    var pollFor = (_pendingRequests.length < 15 ? _pendingRequests.length : 15);
    if (pollFor == 0) {
      _requestPending -= 1;
      return;
    } else if (pollFor == 1) {
      var pr = _pendingRequests.removeFirst();
      _getData(pr.url).then((result) {
        _requestPending -= 1;
        pr._completer.complete(result);
      });
    } else {
      List pendingList = [];
      for (var i = 0; i < pollFor; i++) {
        pendingList.add(_pendingRequests.removeFirst());
      }
      _getBatchData(pendingList.map((el) => el.url)).then((List<Map> results) {
        _requestPending -= 1;
        for (PendingRequest pr in pendingList) {
          var map = results
              .where((Map m) =>
                  (m['id'] as String).replaceAll(',', '%2C') == pr.url)
              .toList();
          pr._completer.complete(map);
        }
      });
    }
    if (_requestPending < maxRequestPending) {
      _sendRequests();
    }
  }

  /// Force the connection to close.
  void close() => _client.close(force: true);
}

class PendingRequest {
  Completer<List> _completer;
  String url;

  Future get done => _completer.future;

  PendingRequest(this.url) {
    _completer = new Completer<List>();
  }
}
