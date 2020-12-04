import 'storage/debug/storage.dart';
import 'storage/storage.dart';

part 'query.dart';

/// A container for a variable that's persisted beyond the app's lifetime.
class Chest<T> implements Ref<T> {
  static Future<Chest<T>> open<T>(
    String name, {
    required T Function() ifNew,
  }) async {
    // TODO: Conditionally use VmStorage or WebStorage.
    final storage = DebugStorage();
    final firstUpdate = await storage.events
        .where((event) => event is ValueUpdateEvent)
        .cast<ValueUpdateEvent>()
        .first;
    return Chest._(
      name: name,
      storage: storage,
      initialValue: firstUpdate.value,
    );
  }

  Chest._({
    required this.name,
    required Storage storage,
    required List<int> initialValue,
  })   : _storage = storage,
        _value = initialValue {
    _storage.events.listen((event) {
      if (event is ValueUpdateEvent) {
        print('Value set to $event.');
        _value = event.value;
      } else {
        throw UnimplementedError('Handling of $event not implemented.');
      }
    });
  }

  final String name;
  final Storage _storage;
  List<int> _value;

  Future<void> flush() async {
    _storage.run(FlushAction());
    // TODO: Wait for storage to answer.
  }

  Future<void> close() async {
    _storage.run(CloseAction());
    // TODO: Wait for storage to answer.
    // TODO: Make this invalid.
  }

  set value(T newValue) {
    // TODO: Encode new value.
    _storage.run(SetValueAction(Path([]), [42]));
  }

  T get value => get();

  @override
  T get() => getAt(Path.root);

  R getAt<R>(Path path) {
    if (path.keys.isEmpty) {
      return _value.first as R;
    }
    throw UnimplementedError();
  }

  Ref<R> child<R>(Object key) => _FieldRef<R>(this, Path([key]));
}

class Path {
  const Path(this.keys);
  static const root = Path([]);

  final List<Object?> keys;
}

/// A reference to an interior part of the same [Chest].
abstract class Ref<T> {
  Ref<R> child<R>(Object key);
  T get();
}

class _FieldRef<T> implements Ref<T> {
  _FieldRef(this.chest, this.path);

  final Chest chest;
  final Path path;

  Ref<R> child<R>(Object key) => _FieldRef(chest, Path([...path.keys, key]));
  T get() => chest.getAt(path);
}

final chests = <String, Chest>{};
