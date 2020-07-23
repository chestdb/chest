# Chest

A database.

## In memory or not?

In-memory databases are great for storing small amounts of data.
They're amazingly fast and allows synchronous access (see Hive or Sembast).

Only loading records on an as-needed basis is better suited for large volumes of data though – it improves startup time and makes it possible to store huge amounts of data.

Chest aims to use a hybrid approach – it prefetches and caches a certain amount of records in memory and loads new ones as needed.
You're also able to preload some records so they will always be kept in memory.

TODO: Think about how a synchronous API could work.

## Dart or not?

A low-level language like Rust would be the obvious contender.

Obviously, Rust itself is much more performant than Dart. Also, its advanced memory management features make it safe to quickly spawn lightweight threads operating on the same data structure instead of falling back on Dart's monolithic Isolate model and having to deal with message passing.
For example, that would make it possible to execute a query by spawning numerous threads that search the database in parallel.

Using a low-level wrapper also means we could use established database solutions like SQLite or indexdb. These provide amazing performance for queries as well as advanced indexing capabilities.

That being said, database performance is usually I/O-bound and Dart's `RandomAccessFile` would allow us to implement some indexing and query capabilities in Dart as well.
Together with spawning a separate isolate for each database instance, this would probably also result in reasonable performance, although probably a magnitude slower than a battle-tested native solution.

A great advantage of pure Dart, on the other hand, is that it doesn't require any native configuration or dealing with native build systems – the code automatically runs (almost) everywhere where Dart runs, be that Windows, Linux, MacOS, Android, iOS, or Fuchsia. Only web would need to be handled differently.

Writing everything in Dart does come at the cost of having to implement basic database functionalities, like indizes, but it also mean less overhead dealing with the boundary between native code and Dart and being able to debug across those boundaries.

There are already several native wrapper libraries like <kbd>sqflite</kbd> out there.
So, I believe that using pure Dart puts Chest in a very unique position in that allows for deep integration with the Dart ecosystem and language.

## API

### Collections

You should be able to open a collection inside a database/box and get and set records easily:

```dart
final box = Chest.box('sample');
final users = box.collection<String, String>('users');
users['foo'] = 'bar';
users['foo'] = 'baz';
final baz = await users['foo'];
await users.remove('foo');
```

### Queries

Queries are like `.where` but more limited.
Why's that? Because they're really efficient (they work in logarithmic time).

```dart
final someUsers = users.query((user) {
  return user.firstName.equals('Marcel')
    & user.lastName.startsWith('G')
    | user.age.isBetween(12, 25);
}).sortedBy((user) => user.age).limitTo(10);
```

## Debugging

This section only applies to debug mode builds.

For debugging, similar to Dart DevTools, Chest should have a web interface.
It should have some tabs, which contain useful functionality:

- Performance
  - Which chunks are loaded?
  - How long does loading chunks take?
  - Response time and latency of queries?
  - Scheduling information: How many queries are active at a time?
  - Cache hit rates
  - Insert events into the Dart Debugging Timeline and link to it
- Storage
  - Number of chunks
  - File layout
  - Trigger manual compaction?
- Data
  - Collections and their content
  - View and update live data
  - Indexes
  - Watched queries and boxes

## General architecture

Each `Chest.box` call creates a new `Isolate` that handles all interactions with the file.
This means that we can use the faster, synchronous I/O operations.
Also, compaction, compression, etc. don't cause jank in the rest of the app.
Only the necessary data is transferred to the main isolate.

## Data layout

Most operating systems load files in chunks of around 4 KiB. Most databases use a chunk size of 4 KiB or a multiple of that.  
Chest also organizes its data in those chunks, which allows for updating the data structure and inserting data in the middle (well, actually at the end but the extra indirection abstracts from the actual layout).

There are a few types of chunks:

### Data chunks

A data chunk holds one or multiple records.
Those chunks start with the offsets of the data as well as the lengths of them.
New records are added at the end so that both a large number of small chunks as well as a small number of large chunks can be handled gracefully.

Storage layout of a partially filled data chunk, one with many small records and one with few big records:

```
header 1 | header 2 |                                       | data 2 | data 1 |
header 1 | header 2 | header 3 | header 4 | data 4 | data 3 | data 2 | data 1 |
header 1 | header 2 | really really large data 2 | really really large data 1 |
```

### Big data chunks

Sometimes, data is just too big – not just too big to fit into an existing partially-filled chunk, but even too big to fit into a completely new chunk. In this case, it needs to be split up and saved in multiple chunks.

These look like this:

```
0 | next chunk id  | soooooooooooooooooooooooooooooooooooooooooooo many bytes |
0 | next chunk id  | mooooooooooooooooooooooooooooooooooooooooooooooore bytes |
1 | length of data | some data |                                              |
```

### Index chunk

Data needs to be accessed based on a key or a property of the value.
These data are organized in a B⁺-tree so that access works in O(log n).

The layout of those still needs to be figured out.

```
```

## Queries

Queries could work by making certain types indexable. One could imagine writing `IndexForType` similar to the existing `AdapterForType`s.
Then, class fields could get annotated with `@Index` to indicate that an index should be generated for them.

Consider this `User` class:

```dart
// Data class. User-written.
@TapeClass(nextFieldId: 3)
class User {
  User({this.firstname, this.lastName, this.age});

  @TapeField(fieldId: 0)
  final String firstName;

  @TapeField(fieldId: 1)
  final String lastName;

  @Index
  String get name => '$firstName $lastName';

  @Index
  @TapeField(2)
  final int age;
}

// or

@freezed
abstract class User with _$User {
  @TapeClass(nextFieldId: 2)
  factory User(
    @TapeField(0) String firstName,
    @TapeField(1) String lastName,
    @TapeField(2) @Index int age,
  ) = _User;

  @Index
  String get name => '$firstName $lastName';
}
```

Note that the `@Index` annotations can only be used on types that are registered as keys.
Some primitive types like `String` and `int` could already implement them:

```dart
// Keys. Contained in Chest.
extension StringKey on String {
  Bytes toKeyBytes() => utf8.encode(this);
}
extension IntKey on int {
  Bytes toKeyBytes() => ...;
}

Chest
  ..registerKeyType<String>((string) => string.toKey())
  ..registerKeyType<int>((value) => value.toKey());

extension FancyStringIndex on IndexedProperty<String> {
  Query startsWith(String string) {
    final lower = string.toKey();
    final upper = lower + 1;
    return rawIsBetweenInclusive(lower, upper);
  }
}
```

Chest could declare that it runs after <kbd>tapegen</kbd> and handle fields annotated with `@Index`.
Based on the `User` above, this class could get generated:

```dart
// IndexedUser. Generated.
class _IndexedUser extends Indexed<User> {
  final name = IndexedProperty<User, String>((user) => user.name);
  final age = IndexedProperty<User, int>((user) => user.age);
  
  final indexes = <IndexedProperty<User, dynamic>>[name, age];
}

extension QueryableIndexedUser<T> on Box<T, User> {
  QueryResult query(Query Function(_IndexedUser user) queryBuilder) =>
      runQuery(queryBuilder(IndexedUser()));
}
```

This `_IndexedUser` could then get passed into the lambda passed to `query`:

```dart
final someUsers = users.query((user) {
  return user.name.startsWith('Marcel G') | user.age.isBetween(12, 25);
}).sortedBy((user) => user.age).limitTo(10);
```
