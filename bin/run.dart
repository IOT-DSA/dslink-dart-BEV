library dslink.bev;

import 'dart:async';

import 'package:dslink/client.dart';

import 'package:dslink_bev/connections.dart';
import 'package:dslink_bev/link_manager.dart';

Future main(List<String> args) async {
  var link = new LinkProvider(args, 'BelimoEnergyValve-', command: 'run',
      profiles: {
    AddConnectionNode.isType : (String path) => new AddConnectionNode(path),
    RemoveConnectionNode.isType : (String path) => new RemoveConnectionNode(path),
    BevNode.isType : (String path) => new BevNode(path),
    BevValueNode.isType : (String path) => new BevValueNode(path)
  }, encodePrettyJson: true);

  link.addNode('/${AddConnectionNode.pathName()}',
      AddConnectionNode.definition());
  link.init();
  link.connect();

  var lm = new LinkManager(link);
}