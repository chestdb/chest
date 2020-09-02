import 'vm_chest/vm_chest.dart';

part 'query.dart';

/// A representation of a single database.
///
/// You can open a [Chest] like this (you don't have to use a taco as the name):
///
/// ```dart
/// var chest = Chest('🌮');
/// ```
///
/// Chest stores data in documents (or docs for short), which are stored in
/// boxes. Chest creates boxes and docs implicitly the first time you add data
/// to the doc. You do not need to explicitly create boxes or docs.
///
/// Boxes have a name, which is a [String] and contain [Doc]s. [Doc]s have a key
/// and a value, both of which can be any type (with some caveats). Boxes are
/// also strongly typed, meaning that the types of keys and values are enforced
/// at compile time.
///
/// For example, you might have a box called 'users' which contains documents.
///
/// ```dart
/// final users = chest.box<String, User>('users');
/// final me = users.doc('marcel');
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

  Future<void> close();
}

/// A container for [Doc]s.
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
