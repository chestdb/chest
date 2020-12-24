import 'dart:async';

import 'api.dart';
import 'blocks.dart';
import 'bytes.dart';
import 'storage/storage.dart';
import 'storage/debug/storage.dart';
import 'storage/web/storage.dart'
    if (dart.library.io) 'storage/vm/storage.dart';
import 'tapers.dart';

/// A container for a value that's persisted beyond the app's lifetime.
///
/// This is how [Chest]s are typically used:
///
/// ```dart
/// var counter = await Chest.open('counter', ifNew: () => 0);
/// print('This program ran ${counter.value} times.');
/// counter.value++;
/// await counter.close();
/// ```
///
/// You don't need to [close] [Chest]s if you're not absolutely sure you don't
/// need them later on: Even if your program exists while a [Chest] is opened or
/// its value is being changed, a valid state of the chest is recovered.
class Chest<T> implements Reference<T> {
  /// Creates a new [Chest].
  Chest(this.name, {required this.ifNew});

  // TODO: Support mocking for boxes that are closed and then re-opened.
  static void mock<T>(String name, T value) {
    if (_mockBackends.containsKey(name)) {
      panic('Called Chest.mock, but chest "$name" is already mocked.');
    }
    if (_backends.isNotEmpty) {
      panic('Called Chest.mock after you opened a chest. All mock calls should '
          'occur before opening the first chest.');
    }
    final updatable = UpdatableBlock(value.toBlock());
    _mockBackends[name] = _Backend<T>(updatable, DebugStorage(updatable));
  }

  final String name;
  final T Function() ifNew;
  _Backend<T>? _backend;
  bool get isOpened => _backend != null;

  Future<void> open() async {
    if (_mockBackends.containsKey(name)) {
      _backend = _mockBackends[name]!.cast<T>(name);
    } else if (_backends.containsKey(name)) {
      _backend = _backends[name]!.cast<T>(name);
    } else {
      _backend = await _Backend.open(name, ifNew);
      _backends[name] = _backend!;
    }
  }

  Future<void> flush() async {
    assert(isOpened);
    await _backend!._flush();
  }

  Future<void> compact() async {
    assert(isOpened);
    await _backend!._compact();
  }

  Future<void> close() async {
    assert(isOpened);
    await _backend!._close();
    _backend = null;
    _backends.remove(name);
  }

  @override
  Reference<R> child<R>(Object? key, {bool createImplicitly = false}) =>
      _FieldRef<R>(this, Path([key]), createImplicitly);

  @override
  set value(T value) => _setAt(Path.root(), value, true);
  void _setAt(Path<Block> path, T value, bool createImplicitly) {
    assert(isOpened);
    _backend!._setAt(path, value.toBlock(), createImplicitly);
  }

  @override
  T get value => _getAt(Path.root());
  T _getAt(Path<Block> path) {
    assert(isOpened);
    return _backend!._getAt(path);
  }

  @override
  Stream<T?> watch() => _watchAt<T>(Path.root());
  Stream<R?> _watchAt<R>(Path<Block> path) {
    assert(isOpened);
    return _backend!._watchAt(path);
  }
}

final _mockBackends = <String, _Backend<dynamic>>{};
final _backends = <String, _Backend<dynamic>>{};

/// The logic of a currently opened [Chest].
class _Backend<T> {
  _Backend(this._value, this._storage) {
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

  static Future<_Backend<T>> open<T>(String name, T Function() ifNew) async {
    final storage = await openStorage(name);
    var initialValue = await storage.getValue();
    if (initialValue == null) {
      final newValue = (await ifNew()).toBlock();
      storage.setValue(Path.root(), newValue);
      initialValue = UpdatableBlock(newValue);
    }
    // TODO: Check that the content is indeed of type T.
    return _Backend<T>(initialValue, storage);
  }

  Future<void> _flush() => _storage.flush();
  Future<void> _compact() => _storage.compact();
  Future<void> _close() async {
    // Let the actual value be garbage collected by replacing it with a small
    // one.
    _value.update(Path.root(), MapBlock(0, {}), createImplicitly: false);
    _onValueChangedController.close();
    await _storage.close();
  }

  void _setAt(Path<Block> path, Block value, bool createImplicitly) {
    _value.update(path, value, createImplicitly: createImplicitly);
    _onValueChangedController.add(path);
    _storage.setValue(path, value);
  }

  R? _getAt<R>(Path<Block> path) => _value.getAt(path)?.toObject() as R;

  Stream<R?> _watchAt<R>(Path<Block> path) {
    return _onValueChanged
        .where((changedPath) {
          // Only deserialize on those events that could have changed the value.
          return path.startsWith(path) || path.startsWith(changedPath);
        })
        .map((_) => _getAt<R>(path))
        .distinct();
  }

  _Backend<R> cast<R>(String name) {
    if (this is! _Backend<R>) {
      throw ChestDoesNotMatchTypeError(
        name: name,
        expectedType: R,
        actualType: _type,
      );
    }
    return this as _Backend<R>;
  }
}

/// A reference to an interior part of a [Chest].
abstract class Reference<T> {
  Reference<R> child<R>(Object? key, {bool createImplicitly = false});
  set value(T value);
  T get value;
  Stream<T?> watch();
}

class _FieldRef<T> implements Reference<T> {
  _FieldRef(this.chest, this.path, this.createImplicitly);

  final Chest chest;
  final Path<Object?> path;
  final bool createImplicitly;

  Reference<R> child<R>(Object? key, {bool createImplicitly = false}) =>
      _FieldRef(chest, Path<Object?>([...path.keys, key]), createImplicitly);

  set value(T value) =>
      chest._setAt(path.serialize(), value.toBlock(), createImplicitly);
  T get value => chest._getAt(path.serialize());
  Stream<T?> watch() => chest._watchAt(path.serialize());
}

extension on Path<Object?> {
  Path<Block> serialize() {
    return Path(keys.map((it) => it.toBlock()).toList());
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
