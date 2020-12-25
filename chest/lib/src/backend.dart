import 'dart:async';

import 'blocks.dart';
import 'storage/storage.dart';
import 'storage/web/storage.dart'
    if (dart.library.io) 'storage/vm/storage.dart';

/// The [Backend] for chests that already supports saving and updating a value,
/// but does not yet offer saving and maintaining `References` or saving which
/// tapers are used.
class Backend<T> {
  Backend(this._value, this._storage) {
    _storage.updates.listen((update) {
      _value.update(update.path, update.value, createImplicitly: true);
      _onValueChangedController.add(Path.root());
    });
  }

  final UpdatableBlock _value;
  final Storage _storage;
  final _onValueChangedController = StreamController<Path<Block>>.broadcast();

  Type get _type => T;
  Stream<Path<Block>> get _onValueChanged => _onValueChangedController.stream;

  static Future<Backend<T>> open<T>(String name, T Function() ifNew) async {
    final storage = await openStorage(name);
    var initialValue = await storage.getValue();
    if (initialValue == null) {
      final newValue = (await ifNew()).toBlock();
      storage.setValue(Path.root(), newValue);
      initialValue = UpdatableBlock(newValue);
    }
    // TODO: Check that the content is indeed of type T.
    return Backend<T>(initialValue, storage);
  }

  Future<void> flush() => _storage.flush();
  Future<void> compact() => _storage.compact();
  Future<void> close() async {
    // Let the actual value be garbage collected by replacing it with a small
    // one.
    _value.update(Path.root(), MapBlock(0, {}), createImplicitly: false);
    _onValueChangedController.close();
    await _storage.close();
  }

  void setAt(Path<Block> path, Block value, bool createImplicitly) {
    _value.update(path, value, createImplicitly: createImplicitly);
    _onValueChangedController.add(path);
    _storage.setValue(path, value);
  }

  R? getAt<R>(Path<Block> path) => _value.getAt(path)?.toObject() as R;

  Stream<R?> watchAt<R>(Path<Block> path) {
    return _onValueChanged
        .where((changedPath) {
          // Only deserialize on those events that could have changed the value.
          return path.startsWith(path) || path.startsWith(changedPath);
        })
        .map((_) => getAt<R>(path))
        .distinct();
  }

  Backend<R> cast<R>(String name) {
    if (this is! Backend<R>) {
      throw ChestDoesNotMatchTypeError(
        name: name,
        expectedType: R,
        actualType: _type,
      );
    }
    return this as Backend<R>;
  }
}

class ChestDoesNotMatchTypeError extends ChestError {
  ChestDoesNotMatchTypeError({
    required this.name,
    required this.expectedType,
    required this.actualType,
  });

  final String name;
  final Type expectedType;
  final Type actualType;

  String toString() => 'You tried to open Chest "$name" of type '
      "$expectedType, but it's actually of type $actualType.";
}
