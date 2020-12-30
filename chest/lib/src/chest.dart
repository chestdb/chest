import 'dart:async';

import 'backend.dart';
import 'blocks.dart';
import 'bytes.dart';
import 'storage/storage.dart';
import 'storage/debug/storage.dart';

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

  static void mock<T>(String name, T value) {
    if (_mockBackends.containsKey(name)) {
      panic('Called Chest.mock, but chest "$name" is already mocked.');
    }
    if (_openedBackends.isNotEmpty) {
      panic('Called Chest.mock after you opened a chest. All mock calls should '
          'occur before opening the first chest.');
    }
    final updatable = UpdatableBlock(value.toBlock());
    _mockBackends[name] = Backend<T>(updatable, DebugStorage(updatable));
  }

  final String name;
  final T Function() ifNew;
  Backend<T>? _backend;
  bool get isOpened => _backend != null;

  Future<void> open() async {
    if (_mockBackends.containsKey(name)) {
      _backend = _mockBackends[name]!.cast<T>(name);
    } else if (_openedBackends.containsKey(name)) {
      _backend = _openedBackends[name]!.cast<T>(name);
    } else {
      _backend = await Backend.open(name, ifNew);
    }
    _openedBackends[name] = _backend!;
  }

  Future<void> flush() async {
    assert(isOpened);
    await _backend!.flush();
  }

  Future<void> compact() async {
    assert(isOpened);
    await _backend!.compact();
  }

  Future<void> close() async {
    assert(isOpened);
    await _backend!.close();
    _backend = null;
    _openedBackends.remove(name);
  }

  @override
  Reference<R> child<R>(Object? key, {bool createImplicitly = false}) =>
      _FieldRef<R>(this, Path([key]), createImplicitly);

  @override
  set value(T value) => _setAt(Path.root(), value, true);
  void _setAt(Path<Block> path, T value, bool createImplicitly) {
    assert(isOpened);
    _backend!.setAt(path, value.toBlock(), createImplicitly);
  }

  @override
  T get value => _getAt(Path.root());
  T _getAt(Path<Block> path) {
    assert(isOpened);
    return _backend!.getAt(path);
  }

  @override
  Stream<T?> watch() => _watchAt<T>(Path.root());
  Stream<R?> _watchAt<R>(Path<Block> path) {
    assert(isOpened);
    return _backend!.watchAt(path);
  }
}

final _mockBackends = <String, Backend<dynamic>>{};
final _openedBackends = <String, Backend<dynamic>>{};

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
