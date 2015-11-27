library dslink.bev.link_manager;

import 'dart:async';
import 'package:dslink/client.dart';

class LinkManager {
  final LinkProvider _link;
  static LinkManager _cache;

  factory LinkManager([LinkProvider link]) {
    if (_cache == null && link != null) {
      _cache ??= new LinkManager._(link);
    }
    return _cache;
  }

  LinkManager._(this._link);

  save() => _link.save();
}