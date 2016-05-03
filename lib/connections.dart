library dslink.bev.connections;

import 'dart:async';

import 'package:dslink/dslink.dart';
import 'package:dslink/responder.dart';
import 'package:dslink/nodes.dart' show NodeNamer;
import 'package:dslink/utils.dart';

import 'package:dslink_bev/src/bev_client.dart';
import 'package:dslink_bev/link_manager.dart';

part 'src/bev_node.dart';

class AddConnectionNode extends SimpleNode {
  static final String isType = 'addConnection';
  static String pathName() => 'Add_Connection';
  static Map definition() => {
    r'$is' : isType,
    r'$invokable' : 'write',
    r'$result' : 'values',
    r'$name' : 'Add Connection',
    r'$params' : [
      {
        'name' : 'name',
        'description' : 'Connection Name',
        'type' : 'string'
      },
      {
        'name' : 'url',
        'type' : 'string',
        'placeholder' : 'http://youraddress.com'
      },
      {
        'name' : 'username',
        'type' : 'string'
      },
      {
        'name' : 'password',
        'type' : 'string',
        'editor' : 'password'
      },
      {
        'name' : 'refreshRate',
        'type' : 'int',
        'default' : 30
      }
    ],
    r'$columns' : [
      {
        'name' : 'success',
        'type' : 'bool',
        'default' : false
      },
      {
        'name' : 'message',
        'type' : 'string',
        'default' : ''
      }
    ]
  };

  AddConnectionNode(String path) : super(path);

  @override
  Future<Map> onInvoke(Map<String, dynamic> params) async {
    var ret = { 'success' : true, 'message' : ''};

    if (params['username'] == null || params['username'] == '') {
      ret['success'] = false;
      ret['message'] = 'Invalid username';
    } else if (params['password'] == null || params['password'] == '') {
      ret['success'] = false;
      ret['message'] = 'Invalid password';
    } else if (params['url'] == null || params['url'] == '' ||
        !(params['url'].startsWith('http'))) {
      ret['success'] = false;
      ret['message'] = 'Invalid address';
    }
    var url = params['url'].trim();
    if (!url.endsWith('/')) {
      url += '/';
    }

    url += 'api/v1/datapoints';

    Uri uri;
    try {
      uri = Uri.parse(params['url']);
    } catch (_) {
      ret['success'] = false;
      ret['message'] = 'Invalid address';
    }

    if (ret['success'] == false) {
      return ret;
    }

    provider.addNode('/${params['name']}',
        BevNode.definition(params, url));

    var lm = new LinkManager();
    lm.save();
    return {
      'success' : true,
      'message' : 'Added Successfully'
    };

  }
}

class RemoveConnectionNode extends SimpleNode {
  static final String isType = 'removeConnection';
  static String pathName() => 'Remove_Connection';
  static Map definition() => {
    r'$is' : isType,
    r'$name' : 'Remove Connection',
    r'$invokable' : 'write',
    r'$result' : 'values',
    r'$params' : [],
    r'$columns' : []
  };

  RemoveConnectionNode(String path) : super(path);

  @override
  dynamic onInvoke(Map<String, dynamic> params) {
    var p = parent.path;
    provider.removeNode(p);
    var lm = new LinkManager();
    if (lm != null) {
      lm.save();
    }
    return {};
  }
}

class EditConnectionNode extends SimpleNode {
  static final String isType = 'editConnection';
  static String pathName() => 'Edit_Connection';
  static Map definition(String url, Map param) => {
    r'$is': isType,
    r'$name' : 'Edit Connection',
    r'$invokable': 'write',
    r'$result' : 'values',
    r'$params' : [
      {
        'name' : 'url',
        'type' : 'string',
        'default' : url.replaceFirst('/api/v1/datapoints', '')
      },
      {
        'name' : 'username',
        'type' : 'string',
        'default' : param['username']
      },
      {
        'name' : 'password',
        'type' : 'string',
        'editor' : 'password',
        'default' : param['password']
      },
      {
        'name' : 'refreshRate',
        'type' : 'int',
        'default' : param['refreshRate']
      }
    ],
    r'$columns' : [
      {
        'name' : 'success',
        'type' : 'bool',
        'default' : false
      },
      {
        'name' : 'message',
        'type' : 'string',
        'default' : ''
      }
    ]
  };

  EditConnectionNode(String path) : super(path);

  @override
  dynamic onInvoke(Map<String, dynamic> params) {
    var ret = { 'success' : true, 'message' : ''};

    if (params['username'] == null || params['username'] == '') {
      ret['success'] = false;
      ret['message'] = 'Invalid username';
    } else if (params['password'] == null || params['password'] == '') {
      ret['success'] = false;
      ret['message'] = 'Invalid password';
    } else if (params['url'] == null || params['url'] == '' ||
        !(params['url'].startsWith('http'))) {
      ret['success'] = false;
      ret['message'] = 'Invalid address';
    }
    var url = params['url'].trim();
    if (!url.endsWith('/')) {
      url += '/';
    }

    url += 'api/v1/datapoints';

    Uri uri;
    try {
      uri = Uri.parse(params['url']);
    } catch (_) {
      ret['success'] = false;
      ret['message'] = 'Invalid address';
    }

    if (ret['success'] == false) {
      return ret;
    }
    var p = parent as BevNode;
    var childList = p.children.keys.toList(growable: false);
    for (var child in childList) {
      if (p.children[child].getConfig(r'$invokable') == 'write') {
        continue;
      }
      provider.removeNode('${p.path}/$child');
    }
    p.updateBevSettings(url, params);

    var lm = new LinkManager();
    lm.save();

    p.loadData(force: true).then((_) {
    });
    return {
      'success' : true,
      'message' : 'Updated Successfully'
    };

  }
}

class RefreshConnectionNode extends SimpleNode {
  static final String isType = 'refreshConnection';
  static String pathName() => 'Refresh_Connection';
  static Map definition() => {
    r'$is' : isType,
    r'$name': 'Refresh Nodes',
    r'$invokable' : 'write',
    r'$results' : 'values',
    r'$params' : [],
    r'$columns' : []
  };

  RefreshConnectionNode(String path) : super(path);

  @override
  dynamic onInvoke(Map<String, dynamic> params) {
    var p = parent as BevNode;
    var childList = p.children.keys.toList(growable: false);
    for (var child in childList) {
      if (p.children[child].getConfig(r'$invokable') == 'write') continue;
      provider.removeNode('${p.path}/$child');
    }
    p.loadData(force: true);
    return {};
  }
}