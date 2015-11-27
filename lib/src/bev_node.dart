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
    RefreshConnectionNode.pathName() : RefreshConnectionNode.definition()
  };

  String _username;
  String _password;
  String _rootUri;
  bool _isRefreshing = false;
  HashMap<String, BevValueNode> _subscribed;

  BevClient client;
  Timer refresh;

  BevNode(String path) : super(path) {
    _subscribed = new HashMap<String, BevValueNode>();
  }

  @override
  void onCreated() {
    _username = getConfig(r'$$bev_user');
    _password = getConfig(r'$$bev_pass');
    _rootUri = getConfig(r'$$bev_url');

    if (refresh == null) {
      var rTime = int.parse(getConfig(r'$$bev_refresh'), onError: (_) => 60);
      refresh = new Timer.periodic(new Duration(seconds: rTime), _refreshData);
    }

    client = new BevClient(_username, _password, Uri.parse(_rootUri));
    loadData();
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
            map[tempVal] ??= new Map();
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
      remove();
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
    if (_isRefreshing) return;
    _isRefreshing = true;
    var keys = _subscribed.keys;
    if (keys.length < 1) return;
    client.getMultiData(keys).then((List result) {
      for (var data in result) {
        var node = _subscribed[data['id']];
        node?.receiveData(data);
      }
      _isRefreshing = false;
    });
  }

  void addSubscribed(BevValueNode node) {
    _subscribed[node.id] ??= node;
  }

  void removeSubscribed(BevValueNode node) {
    _subscribed.remove(node.id);
  }

}

class BevValueNode extends SimpleNode {
  static const String isType = 'bevValue';

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
      _myParent.addSubscribed(this);
    }

    getData();
  }

  @override
  void onUnsubscribe() {
    _myParent?.removeSubscribed(this);
  }

  void onCreated() {
    _uri = getConfig(r'$$bev_url');
  }

  void receiveData(Map data) {
    var value;
    switch (data['type']) {
      case 'DATE_TIME':
        var tmp = int.parse(data['value'], onError: (_) => -1);
        value = (tmp == -1 ? 'Error' :
        new DateTime.fromMillisecondsSinceEpoch(tmp).toIso8601String());
        break;
      case 'DOUBLE' :
        value = double.parse(data['value']);
        type = 'double';
        break;
      case 'INTEGER' :
        value = int.parse(data['value']);
        type = 'int';
        break;
      case 'BOOLEAN' :
        value = (data['value'] == 'true');
        type = 'bool';
        break;
      default:
        value = data['value'];
    }
    updateValue(value);
  }

  Future getData() async {
    var dataList = await _client.getData(_uri);
    if (dataList.isEmpty) return;
    var data = dataList[0];

    receiveData(data);
  }
}