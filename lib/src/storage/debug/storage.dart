import 'dart:async';

import '../storage.dart';

class DebugStorage implements Storage {
  DebugStorage(this._value);

  final UpdatableBlock _value;
  final _controller = StreamController<Update>.broadcast();

  @override
  Stream<Update> get updates => _controller.stream;

  Future<UpdatableBlock?> getValue() async => _value;

  @override
  void setValue(Path<Block> path, Block value) {
    _value.update(path, value, createImplicitly: true);
    _controller.add(Update(path, value));
  }

  @override
  Future<void> flush() async {}

  Future<UpdatableBlock> migrate() async {
    _value.update(Path.root(), _value.getAtRoot().toObject().toBlock(),
        createImplicitly: false);
    return _value;
  }

  @override
  Future<void> compact() async {}

  @override
  Future<void> close() async {}
}
