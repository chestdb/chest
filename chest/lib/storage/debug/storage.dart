import 'dart:async';
import 'dart:convert';

import '../storage.dart';

class DebugStorage implements Storage {
  DebugStorage() : updatesController = StreamController<Delta>.broadcast() {
    // _sendEvents();
  }

  final StreamController<Delta> updatesController;
  @override
  Stream<Delta> get updates => updatesController.stream;

  Future<Value?> getValue() async {
    return null;
  }

  Future<void> _sendEvents() async {
    await Future.delayed(Duration(milliseconds: 100));
    updatesController
        .add(Delta(Path.root(), DefaultBytesBlock(-1, utf8.encode('bar'))));
    await Future.delayed(Duration(milliseconds: 100));
    updatesController
        .add(Delta(Path.root(), DefaultBytesBlock(-1, utf8.encode('baz'))));
    await Future.delayed(Duration(milliseconds: 100));
    updatesController
        .add(Delta(Path.root(), DefaultBytesBlock(-1, utf8.encode('blub'))));
  }

  @override
  void setValue(path, Block value) {
    print('Setting value to $value.');
    updatesController.add(Delta(Path.root(), value));
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
