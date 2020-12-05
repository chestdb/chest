import 'dart:async';
import 'dart:typed_data';

import 'blocks.dart';
import 'storage/debug/storage.dart';
import 'storage/storage.dart';
import 'storage/vm/storage.dart';
import 'tapers.dart';
import 'utils.dart';
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
    _storage.updates.listen((delta) => _value.update(delta));
  }

  final String name;

  /// A local, dense in-memory representation of the database.
  final Value _value;
  final Storage _storage;

  Future<void> flush() => _storage.flush();
  Future<void> close() => _storage.close();

  set value(T newValue) {
    print('Setting value to $newValue.');
    final block = newValue.toBlock();
    _value.update(Delta(Path.root(), block));
    _storage.setValue(Path.root(), block);
  }

  T get value => get();

  @override
  T get() => getAt(Path.root());
  R getAt<R>(Path path) => _value.getAt(Path.root()).toObject() as R;

  Ref<R> child<R>(Object key) => _FieldRef<R>(this, Path([key]));
}

/// A reference to an interior part of the same [Chest].
abstract class Ref<T> {
  Ref<R> child<R>(Object key);
  T get();
}

class _FieldRef<T> implements Ref<T> {
  _FieldRef(this.chest, this.path);

  final Chest chest;
  final Path<Object?> path;

  Ref<R> child<R>(Object key) =>
      _FieldRef(chest, Path<Object?>([...path.keys, key]));
  T get() => chest.getAt(path);
}

final chests = <String, Chest>{};
