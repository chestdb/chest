part 'query.dart';

/// A representation of a single database.
///
/// # Usage
///
/// ```
/// final chest = Chest('my_database');
/// final users = chest.box<String, User>('users');
/// final me = users.doc('marcelgarus');
/// print(await me.get());
/// final myTodos = me.box('todos');
/// final alsoMyTodos = chest.box('users').doc('marcelgarus').box('todos');
/// ```
///
/// # Limitations
///
/// - Queries cannot cover multiple [Chest]s.
/// - On the VM, each [Chest] is stored in one file. Your OS may limit the
///   number of simultaneously opened files (typically a huge number).
abstract class Chest {
  factory Chest(String name) {
    // TODO: Conditionally use VmChest or WebChest.
    return VmChest(name);
  }

  Box<K, V> box<K, V>(String name);
}

/// A part of the [Chest] that contains some [Doc]s.
abstract class Box<K, V> {
  Doc<V> doc(K key);
  QueryResult<V> rawQuery(Query<IndexedClass<V>> query) {
    print('Executing raw query $query.');
    return null;
  }
}

/// A [Doc]ument holding some data.
///
/// Can have [Box]es as children.
abstract class Doc<V> {
  Box<K, W> box<K, W>(String name);

  Future<bool> exists();
  Future<void> set(V value);
  Future<V> get();
  Future<void> remove();
  Stream<V> watch();
}
