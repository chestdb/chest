import 'dart:async';

import 'api.dart';
import 'blocks.dart';
import 'bytes.dart';
import 'storage/debug/storage.dart';
import 'storage/storage.dart';
import 'storage/vm/storage.dart';
import 'tapers.dart';

/// A container for a variable that's persisted beyond the app's lifetime.
class Chest<T> implements Ref<T> {
  static Future<Chest<T>> open<T>(
    String name, {
    required FutureOr<T> Function() ifNew,
  }) async {
    assert(tape.isInitialized);
    if (_openedChests.containsKey(name)) {
      final chest = _openedChests[name]!;
      if (chest is! Chest<T>) {
        throw ChestDoesNotMatchTypeError(
          name: name,
          expectedType: T,
          actualType: chest._type,
        );
      }
      return chest;
    }
    final storage = await openStorage(name);
    var initialValue = await storage.getValue();
    if (initialValue == null) {
      final newValue = (await ifNew()).toBlock();
      storage.setValue(Path.root(), newValue);
      initialValue = UpdatableBlock(newValue);
    }
    // TODO: Check that the content is indeed of type T.
    final chest = Chest<T>._(
      name: name,
      storage: storage,
      initialValue: initialValue,
    );
    _openedChests[name] = chest;
    return chest;
  }

  static void mock<T>(String name, T value) {
    if (_openedChests.containsKey(name)) {
      throw 'Called mock, but chest already mocked or opened.';
    }
    final initialValue = UpdatableBlock(value.toBlock());
    _openedChests[name] = Chest<T>._(
      name: name,
      storage: DebugStorage(initialValue),
      initialValue: initialValue,
    );
  }

  Chest._({
    required this.name,
    required Storage storage,
    required UpdatableBlock initialValue,
  })   : _storage = storage,
        _value = initialValue {
    _storage.updates.listen((update) {
      _value.update(update.path, update.value, createImplicitly: true);
      _valueChangedController.add(Path.root());
    });
  }

  final String name;
  Type get _type => T;

  /// A local, dense in-memory representation of the database.
  final UpdatableBlock _value;
  final Storage _storage;

  /// A stream that emits an event every time the value changes.
  final _valueChangedController = StreamController<Path<Block>>.broadcast();
  Stream<Path<Block>> get _valueChanged => _valueChangedController.stream;

  Future<void> flush() => _storage.flush();
  Future<void> compact() => _storage.compact();
  Future<void> close() async {
    // Let the actual value be garbage collected by replacing it with a small
    // one.
    _value.update(Path.root(), MapBlock(0, {}), createImplicitly: false);
    _valueChangedController.close();
    await _storage.close();
  }

  @override
  Ref<R> child<R>(Object? key, {bool createImplicitly = false}) =>
      _FieldRef<R>(this, Path([key]), createImplicitly);

  @override
  set value(T value) =>
      _setAt(Path.root(), value.toBlock(), createImplicitly: false);
  void _setAt(Path<Block> path, Block value, {required bool createImplicitly}) {
    _value.update(path, value, createImplicitly: createImplicitly);
    _valueChangedController.add(path);
    _storage.setValue(path, value);
  }

  @override
  T get value => _getAt(Path.root());
  R? _getAt<R>(Path<Block> path) => _value.getAt(path)?.toObject() as R;

  @override
  Stream<T?> watch() => _watchAt(Path.root());
  Stream<R?> _watchAt<R>(Path<Block> path) {
    return _valueChanged
        .where((changedPath) {
          // Only deserialize on those events that can the value.
          return path.startsWith(path) || path.startsWith(changedPath);
        })
        .map((_) => _getAt<R>(path))
        .distinct();
  }
}

/// A reference to an interior part of the same [Chest].
abstract class Ref<T> {
  Ref<R> child<R>(Object? key, {bool createImplicitly = false});
  set value(T value);
  T get value;
  Stream<T?> watch();
}

class _FieldRef<T> implements Ref<T> {
  _FieldRef(this.chest, this.path, this.createImplicitly);

  final Chest chest;
  final Path<Object?> path;
  final bool createImplicitly;

  Ref<R> child<R>(Object? key, {bool createImplicitly = false}) =>
      _FieldRef(chest, Path<Object?>([...path.keys, key]), createImplicitly);

  set value(T value) => chest._setAt(path.serialize(), value.toBlock(),
      createImplicitly: createImplicitly);
  T get value => chest._getAt(path.serialize());
  Stream<T?> watch() => chest._watchAt(path.serialize());
}

final _openedChests = <String, Chest>{};

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
