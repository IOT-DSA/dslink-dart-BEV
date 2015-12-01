part of dslink.bev.connections;

class BevNode extends SimpleNode {
  static final String isType = 'bevNode';
  static Map definition(Map parameters, String url) => {
    r'$is' : isType,
    r'$$bev_user' : parameters['username'],
    r'$$bev_pass' : parameters['password'],
    r'$$bev_url' : url,
    r'$$bev_refresh' : parameters['refreshRate'],
    RemoveConnectionNode.pathName() : RemoveConnectionNode.definition(),
    RefreshConnectionNode.pathName() : RefreshConnectionNode.definition(),
    EditConnectionNode.pathName() : EditConnectionNode.definition(url, parameters)
  };

  String _username;
  String _password;
  String _rootUri;
  int _refreshRate;
  bool _isRefreshing = false;
  Set<BevValueNode> _subscribed;
  //HashMap<String, BevValueNode> _subscribed;

  BevClient client;
  Timer refreshTimer;

  BevNode(String path) : super(path) {
    //_subscribed = new HashMap<String, BevValueNode>();
    _subscribed = new Set<BevValueNode>();
  }

  @override
  void onCreated() {
    _username = getConfig(r'$$bev_user');
    _password = getConfig(r'$$bev_pass');
    _rootUri = getConfig(r'$$bev_url');

    _refreshRate = int.parse(getConfig(r'$$bev_refresh'), onError: (_) => 30);
    if (refreshTimer == null) {
      refreshTimer =
          new Timer.periodic(new Duration(seconds: _refreshRate), _refreshData);
    }

    client = new BevClient(_username, _password, Uri.parse(_rootUri));
    loadData();
  }

  void updateBevSettings(String url, Map parameters) {
    if (_username != parameters['username'] || _password != parameters['password']
      || url != _rootUri) {
      _username = parameters['username'];
      _password = parameters['passsword'];
      _rootUri = url;
      client.updateClient(_username, _password, Uri.parse(_rootUri));
    }
    configs[r'$$bev_user'] = _username;
    configs[r'$$bev_pass'] = _password;
    configs[r'$$bev_url'] = _rootUri;
    configs[r'$$bev_refresh'] = parameters['refreshRate'];

    var refresh = int.parse(parameters['refreshRate'], onError: (_) => 30);
    if (refresh != _refreshRate) {
      refreshTimer.cancel();
      _refreshRate = refresh;
      refreshTimer =
          new Timer.periodic(new Duration(seconds: _refreshRate), _refreshData);
    }
  }

  Future loadData({force: false}) async {
    Map allNodes = {};

    generateNode(String uri) {
      var map = allNodes;
      String str = Uri.decodeComponent(uri);
      String tempVal;
      var index = 1;
      var start = 0;
      bool done() => index >= str.length;

      String sanitize(String s) => s.replaceAll('/', '');

      try {
        while (!done()) {
          if (str[index] == '(') {
            while (!done() && str[index] != ')') index++;
          }
          if (!done() && str[index] == '/') {
            tempVal =
                NodeNamer.createName(sanitize(str.substring(start + 1, index)));
            start = index;
            map.putIfAbsent(tempVal, () => new Map());
            map = map[tempVal];
          }
          index++;
        }
      } catch (e) {

      }
      tempVal = sanitize(str.substring(start + 1));
      map[NodeNamer.createName(tempVal)] = {
        r'$is' : BevValueNode.isType,
        r'$type' : 'string',
        r'$name' : tempVal,
        r'?value' : '',
        r'$$bev_url' : uri.replaceAll(',', '%2C')
      };
    }

    var data = await client.getDatapoints(force: force);
    if (data == null || data.length < 1) {
      logger.warning('Unable to get datapoints from: $_rootUri');
      client.close();
      var myChildren = children.keys.toList();
      for (var child in myChildren) {
        if (children[child].getConfig(r'$invokable') == 'write') continue;
        provider.removeNode('$path/$child');
      }
      return;
    }

    for (var url in data) {
      var item = url.split('api/v1/datapoints');
      generateNode(item[1]);
    }

    allNodes.forEach((key, val) {
      provider.addNode('$path/$key', val);
    });
  }

  @override
  void onRemoving() {
    client.close();
  }

  void _refreshData(Timer t) {
    if (_isRefreshing || _subscribed.length < 1) return;

    _isRefreshing = true;
    List<Future> waitFor = new List<Future>();

    for (var el in _subscribed) {
      if (el.isQueued) continue;

      el.isQueued = true;
      waitFor.add(client.queueRequest(el.id).then((result) {
        if (result.isEmpty) {
          el.receiveData(null);
        } else {
          el.receiveData(result[0]);
        }
      })
      );
    }

    Future.wait(waitFor).then((_) {
      _isRefreshing = false;
    });
  }

  void addSubscribed(BevValueNode node) {
    _subscribed.add(node);
  }

  void removeSubscribed(BevValueNode node) {
    _subscribed.remove(node);
  }

}


class BevValueNode extends SimpleNode {
  static const String isType = 'bevValue';

  bool isQueued = false;
  String get id => _uri;
  String _uri;
  BevClient _client;
  BevNode _myParent;

  BevValueNode(String path) : super(path);

  void onSubscribe() {
    if (_myParent == null) {
      var tmp = parent;
      while (tmp is! BevNode) {
        tmp = tmp.parent;
      }
      _myParent = tmp;
      _client = tmp.client;
    }
    _myParent.addSubscribed(this);

    getData();
  }

  @override
  void onUnsubscribe() {
    if (_myParent != null) _myParent.removeSubscribed(this);
  }

  @override
  void onCreated() {
    _uri = getConfig(r'$$bev_url');
  }

  /// Called when value is Set. Will trigger request to the REST server
  /// for this value to `PUT` this value.
  @override
  bool onSetValue(dynamic val) {
    _client.setData(_uri, val).then((result) {
      if (result.length < 1) return;
      receiveData(result[0]);
    });
    return false;
  }

  /// Process received data map [data]. Convert date/time stamps to
  /// ISO8601 strings. `DOUBLE`, `BOOLEAN`, and `INTEGER` will be converted
  /// to their specified types. Other values are updated as Strings.
  void receiveData(Map data) {
    isQueued = false;
    var value;
    if (data == null) {
      updateValue(null);
      return;
    }
    switch (data['type']) {
      case 'DATE_TIME':
        var tmp = int.parse(data['value'], onError: (_) => -1);
        value = (tmp == -1 ? 'Error' :
        new DateTime.fromMillisecondsSinceEpoch(tmp).toIso8601String());
        break;
      case 'DOUBLE' :
        value = double.parse(data['value'], (_) => null);
        type = 'double';
        break;
      case 'INTEGER' :
        value = int.parse(data['value'], onError: (_) => null);
        type = 'int';
        break;
      case 'BOOLEAN' :
        value = (data['value'] == 'true');
        type = 'bool';
        break;
      default:
        value = data['value'];
    }
    if (data['readonly'] != null && data['readonly'] == 'false') {
      writable = 'write';
    }
    updateValue(value);
  }

  /// Query the URI for this value from the server.
  Future getData() async {
    if (isQueued) return;

    isQueued = true;
    var dataList = await _client.queueRequest(_uri);
    if (dataList.isEmpty) return;
    var data = dataList[0];

    receiveData(data);
  }
}