library dslink.bev.connections;

import 'dart:async';

import 'package:dslink/responder.dart';

import 'package:dslink_bev/src/BevClient.dart';
import 'package:dslink_bev/link_manager.dart';

part 'src/BevNode.dart';

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
        'name' : 'username',
        'type' : 'string'
      },
      {
        'name' : 'password',
        'type' : 'string',
        'editor' : 'password'
      },
      {
        'name' : 'url',
        'type' : 'string'
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
    if (params['username'] == null || params['password'] == null ||
        params['url'] == null) {
      return {
        'success' : false,
        'message' : 'Invalid Credentials'
      };
    }

    String url = params['url'].trim();
    if (!url.endsWith('/')) {
      url += '/';
    }
    url += 'api/v1/datapoints';

    Uri uri;
    try {
      uri = Uri.parse(params['url']);
    } on FormatException catch (e) {
      return {
        'success' : false,
        'message' : e.message
      };
    }

    provider.addNode('/${params['name']}',
        BevNode.definition(params['username'], params['password'], url));

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
    return {};
  }
}