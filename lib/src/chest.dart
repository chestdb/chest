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
    if (_mockedBackends.containsKey(name)) {
      panic('Called Chest.mock, but chest "$name" is already mocked.');
    }
    if (_openedBackends.isNotEmpty) {
      panic('Called Chest.mock after you opened a chest. All mock calls should '
          'occur before opening the first chest.');
    }
    final updatable = UpdatableBlock(value.toBlock());
    _mockedBackends[name] = Backend<T>(updatable, DebugStorage(updatable));
  }

  final String name;
  final T Function() ifNew;
  Backend<T>? _backend;
  bool get isOpened => _backend != null;

  Future<void> open() async {
    if (_mockedBackends.containsKey(name)) {
      _backend = _mockedBackends[name]!.cast<T>(name);
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
  Reference<R> child<R>(Object? key, {bool createImplicitly = false}) {
    return InteriorReference<R>(this, Path([key]), createImplicitly);
  }

  @override
  set value(T value) => _setAt(Path.root(), value, true);
  void _setAt(Path<Object?> path, T value, bool createImplicitly) {
    assert(isOpened);
    _backend!.setAt(path, value, createImplicitly);
  }

  @override
  T get value => _getAt(Path.root());
  T _getAt(Path<Object?> path) {
    assert(isOpened);
    return _backend!.getAt(path);
  }

  @override
  Stream<T?> watch() => _watchAt<T>(Path.root());
  Stream<R?> _watchAt<R>(Path<Object?> path) {
    assert(isOpened);
    return _backend!.watchAt(path);
  }
}

final _mockedBackends = <String, Backend<dynamic>>{};
final _openedBackends = <String, Backend<dynamic>>{};

/// A reference to an interior part of a [Chest].
abstract class Reference<T> {
  Reference<R> child<R>(Object? key, {bool createImplicitly = false});
  set value(T value);
  T get value;
  Stream<T?> watch();
}

class InteriorReference<T> implements Reference<T> {
  InteriorReference(this.chest, this.path, this.createImplicitly);

  final Chest chest;
  final Path<Object?> path;
  final bool createImplicitly;

  Reference<R> child<R>(Object? key, {bool createImplicitly = false}) {
    return InteriorReference(
      chest,
      Path<Object?>([...path.keys, key]),
      createImplicitly,
    );
  }

  set value(T value) => chest._setAt(path, value.toBlock(), createImplicitly);
  T get value => chest._getAt(path);
  Stream<T?> watch() => chest._watchAt(path);
}
