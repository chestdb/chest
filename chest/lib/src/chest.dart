import 'dart:async';

import 'blocks.dart';
import 'storage/storage.dart';
import 'storage/vm/storage.dart';
import 'tapers.dart';
import 'value.dart';

/// A container for a variable that's persisted beyond the app's lifetime.
class Chest<T> implements Ref<T> {
  static Future<Chest<T>> open<T>(
    String name, {
    required FutureOr<T> Function() ifNew,
  }) async {
    assert(tape.isInitialized);
    // TODO: Conditionally use VmStorage or WebStorage.
    final storage = await VmStorage.open(name); // DebugStorage
    print('Initialized storage $storage.');
    var initialValue = await storage.getValue();
    print('First update is $initialValue.');
    if (initialValue == null) {
      final newValue = (await ifNew()).toBlock();
      storage.setValue(Path.root(), newValue);
      initialValue = Value(newValue);
    }
    return Chest._(
      name: name,
      storage: storage,
      initialValue: initialValue,
    );
  }

  Chest._({
    required this.name,
    required Storage storage,
    required Value initialValue,
  })   : _storage = storage,
        _value = initialValue {
    _storage.updates
        .listen((update) => _value.update(update.path, update.value));
  }

  final String name;

  /// A local, dense in-memory representation of the database.
  final Value _value;
  final Storage _storage;

  Future<void> flush() => _storage.flush();
  Future<void> close() => _storage.close();

  // Value setters.

  @override
  void set(T value) => _setAt(Path.root(), value.toBlock());
  void _setAt(Path<Block> path, Block value) {
    _value.update(path, value);
    _storage.setValue(path, value);
  }

  set value(T value) => set(value);

  // Value getters.

  @override
  T get() => _getAt(Path.root());
  R _getAt<R>(Path<Block> path) => _value.getAt(path).toObject() as R;
  T get value => get();

  Ref<R> child<R>(Object key) => _FieldRef<R>(this, Path([key]));
}

/// A reference to an interior part of the same [Chest].
abstract class Ref<T> {
  Ref<R> child<R>(Object key);
  void set(T value);
  T get();
}

class _FieldRef<T> implements Ref<T> {
  _FieldRef(this.chest, this.path);

  final Chest chest;
  final Path<Object?> path;

  Ref<R> child<R>(Object key) =>
      _FieldRef(chest, Path<Object?>([...path.keys, key]));

  void set(T value) => chest._setAt(path.serialize(), value.toBlock());
  T get() => chest._getAt(path.serialize());
}

final _chests = <String, Chest>{};
