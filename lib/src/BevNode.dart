part of dslink.bev.connections;

class BevNode extends SimpleNode {
  static final String isType = 'bevNode';
  static Map definition(String username, String password, String rootUri) => {
    r'$is' : isType,
    r'$$bev_user' : username,
    r'$$bev_pass' : password,
    r'$$bev_url' : rootUri,
    RemoveConnectionNode.pathName() : RemoveConnectionNode.definition()
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

  Future loadData() async {
    Map allNodes = {};

    Map generateNode(String uri) {
      var map = {};
      String str = Uri.decodeComponent(uri);
      String tempVal;
      var index = 1;
      var start = 0;
      var segments = [];

      bool done() => index >= str.length;

      try {
        while (!done()) {
          if (str[index] == '(') {
            while (!done() && str[index] != ')') index++;
          }
          if (!done() && str[index] == '/') {
            segments.add(str.substring(start + 1, index));
            start = index;
          }
          index++;
        }
      } catch (e) {
        print('ERROR: ${e.message}');
        print('URI: $uri');
      }
      segments.add(str.substring(start + 1));

      Map genMap(List list) {
        if (list.length == 1) {
          return { list[0] : {
            r'$is' : BevValueNode.isType,
            r'$type' : 'string',
            r'$name' : list[0],
            r'?value' : ''
          }};
        } else {
          return { list[0] : genMap(list.sublist(1)) };
        }
      }

      return genMap(segments);
    }

    var data = await client.getDatapoints();
    var mapList = [];
    for (var url in data) {
      var item = url.split('api/v1/datapoints');
      mapList.add(generateNode(item[1]));
      //provider.addNode('${path}${item[1]}', map);
    }
    //provider.addNode('$path/application', mapList[0]);
    print('added nodes');
  }

  @override
  void onRemoving() {
    client.close();
  }
}

class BevValueNode extends SimpleNode {
  static const String isType = 'bevValue';


  BevValueNode(String path) : super(path);
}