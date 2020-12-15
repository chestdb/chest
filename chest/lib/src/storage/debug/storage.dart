import 'dart:async';
import 'dart:convert';

import '../storage.dart';

class DebugStorage implements Storage {
  static Future<DebugStorage> open(String name) async {
    return DebugStorage();
  }

  DebugStorage() : updatesController = StreamController<Update>.broadcast() {
    // _sendEvents();
  }

  final StreamController<Update> updatesController;
  @override
  Stream<Update> get updates => updatesController.stream;

  Future<UpdatableBlock?> getValue() async {
    return null;
  }

  Future<void> _sendEvents() async {
    await Future.delayed(Duration(milliseconds: 100));
    updatesController
        .add(Update(Path.root(), BytesBlock(-1, utf8.encode('bar'))));
    await Future.delayed(Duration(milliseconds: 100));
    updatesController
        .add(Update(Path.root(), BytesBlock(-1, utf8.encode('baz'))));
    await Future.delayed(Duration(milliseconds: 100));
    updatesController
        .add(Update(Path.root(), BytesBlock(-1, utf8.encode('blub'))));
  }

  @override
  void setValue(Path<Block> path, Block value) {
    updatesController.add(Update(path, value));
  }

  @override
  Future<void> flush() {
    // TODO: implement flush
    throw UnimplementedError();
  }

  @override
  Future<void> close() {
    // TODO: implement close
    throw UnimplementedError();
  }
}
