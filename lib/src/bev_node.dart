part of dslink.bev.connections;

class BevNode extends SimpleNode {
  static final String isType = 'bevNode';
  static Map definition(String username, String password, String rootUri) => {
    r'$is' : isType,
    r'$$bev_user' : username,
    r'$$bev_pass' : password,
    r'$$bev_url' : rootUri,
    RemoveConnectionNode.pathName() : RemoveConnectionNode.definition(),
    RefreshConnectionNode.pathName() : RefreshConnectionNode.definition()
  };

  String _username;
  String _password;
  String _rootUri;
  BevClient client;

  BevNode(String path) : super(path);

  @override
  void onCreated() {
    _username = getConfig(r'$$bev_user');
    _password = getConfig(r'$$bev_pass');
    _rootUri = getConfig(r'$$bev_url');
    client = new BevClient(_username, _password, Uri.parse(_rootUri));
    loadData();
  }

  Future loadData({force: false}) async {
    Map allNodes = {};

    generateNode(String uri, String fullUrl) {
      var map = allNodes;
      String str = Uri.decodeComponent(uri);
      String tempVal;
      var index = 1;
      var start = 0;
      bool done() => index >= str.length;

      String sanitize(String s) {
        StringBuffer b = new StringBuffer();
        for (var i = 0; i < s.length; i++) {
          switch (s[i]) {
            case ' ':
            case '-':
              b.write('_');
              break;
            case '/':
            case '|':
            case ':':
            case r'$':
            case ';':
            case '%':
              break;
            default:
              b.write(s[i]);
              break;
          }
        }
        return b.toString();
      }

      try {
        while (!done()) {
          if (str[index] == '(') {
            while (!done() && str[index] != ')') index++;
          }
          if (!done() && str[index] == '/') {
            tempVal = sanitize(str.substring(start + 1, index));
            start = index;
            map[tempVal] ??= new Map();
            map = map[tempVal];
          }
          index++;
        }
      } catch (e) {
        print('ERROR: ${e.message}');
        print('URI: $uri');
      }
      tempVal = sanitize(str.substring(start + 1));
      map[tempVal] = {
        r'$is' : BevValueNode.isType,
        r'$type' : 'string',
        r'$name' : tempVal,
        r'?value' : '',
        r'$$bev_url' : fullUrl
      };
    }

    var data = await client.getDatapoints(force: force);
    for (var url in data) {
      var item = url.split('api/v1/datapoints');
      generateNode(item[1], '$_rootUri${item[1]}');
    }

    print(allNodes);
    allNodes.forEach((key, val) {
      provider.addNode('$path/$key', val);
    });
    print('added nodes');
  }

  @override
  void onRemoving() {
    client.close();
  }
}

class BevValueNode extends SimpleNode {
  static const String isType = 'bevValue';

  String _uri;
  BevClient _client;

  BevValueNode(String path) : super(path);

  void onSubscribe() {
    if (_client == null) {
      var tmp = parent;
      while (tmp is! BevNode) {
        tmp = tmp.parent;
      }
      _client = tmp.client;
    }

    getData();
  }

  void onCreated() {
    _uri = getConfig(r'$$bev_url');
  }

  Future getData() async {
    var dataList = await _client.getData(_uri);
    print(dataList);
    if (dataList.isEmpty) return;
    var data = dataList[0];

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
}