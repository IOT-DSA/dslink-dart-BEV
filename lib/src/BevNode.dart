part of dslink.bev.connections;

class BevNode extends SimpleNode {
  static final String isType = 'bevNode';
  static String pathName(Uri uri) => '${uri.host}:${uri.port}';
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
  void onCreated() async {
    _username = getConfig(r'$$bev_user');
    _password = getConfig(r'$$bev_pass');
    _rootUri = getConfig(r'$$bev_url');
    client = new BevClient(_username, _password, Uri.parse(_rootUri));
//    var data = await client.getDatapoints();
  }

  @override
  void onRemoving() {
    client.close();
  }
}