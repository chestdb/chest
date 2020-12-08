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
    if (_chests.containsKey(name)) {
      final chest = _chests[name]!;
      if (chest is! Chest<T>) {
        throw 'Chest with name $name is already opened and not of type $T.';
      }
      return chest;
    }
    // TODO: Conditionally use VmStorage or WebStorage.
    final storage = await VmStorage.open(name); // DebugStorage
    var initialValue = await storage.getValue();
    if (initialValue == null) {
      final newValue = (await ifNew()).toBlock();
      storage.setValue(Path.root(), newValue);
      initialValue = Value(newValue);
    }
    final chest = Chest<T>._(
      name: name,
      storage: storage,
      initialValue: initialValue,
    );
    _chests[name] = chest;
    return chest;
  }

  Chest._({
    required this.name,
    required Storage storage,
    required Value initialValue,
  })   : _storage = storage,
        _value = initialValue {
    _storage.updates.listen((update) {
      _value.update(update.path, update.value);
      _valueChangedController.add(null);
    });
  }

  final String name;

  /// A local, dense in-memory representation of the database.
  final Value _value;
  final Storage _storage;

  /// A stream that emits an event every time the value changes.
  final _valueChangedController = StreamController<void>.broadcast();
  Stream<void> get _valueChanged => _valueChangedController.stream;

  Future<void> flush() => _storage.flush();
  Future<void> close() async {
    // TODO: Dispose value.
    _valueChangedController.close();
    await _storage.close();
  }

  @override
  Ref<R> child<R>(Object? key) => _FieldRef<R>(this, Path([key]));

  @override
  set value(T value) => _setAt(Path.root(), value.toBlock());
  void _setAt(Path<Block> path, Block value) {
    _value.update(path, value);
    _valueChangedController.add(null);
    _storage.setValue(path, value);
  }

  @override
  T get value => _getAt(Path.root());
  R _getAt<R>(Path<Block> path) => _value.getAt(path).toObject() as R;

  @override
  Stream<T> watch() => _watchAt(Path.root());
  Stream<R> _watchAt<R>(Path<Block> path) {
    return _valueChanged.map((_) => _getAt<R>(path)).distinct();
  }
}

/// A reference to an interior part of the same [Chest].
abstract class Ref<T> {
  Ref<R> child<R>(Object? key);
  set value(T value);
  T get value;
  Stream<T> watch();
}

class _FieldRef<T> implements Ref<T> {
  _FieldRef(this.chest, this.path);

  final Chest chest;
  final Path<Object?> path;

  Ref<R> child<R>(Object? key) =>
      _FieldRef(chest, Path<Object?>([...path.keys, key]));

  set value(T value) => chest._setAt(path.serialize(), value.toBlock());
  T get value => chest._getAt(path.serialize());
  Stream<T> watch() => chest._watchAt(path.serialize());
}

final _chests = <String, Chest>{};
