⚠ This package is currently in active development and is not production-ready just yet. Breaking changes are still to be expected. Stay tuned!

---

<center>
<img src="../logo.svg" width="300px" alt="Chest" />

## An in-memory database with amazing developer experience
</center>

**What's a database?**
It's just a place to persist data beyond the lifetime of your app. Chest offers exactly that: persistent variables called *chests*.

```dart
var counter = await Chest.open('counter', ifNew: () => 0);
print('This program ran ${counter.value} times.');
counter.value++;
await counter.close();
```

**But isn't treating databases like variables inefficient?**
Not at all! To be clear, you don't need to read or save the whole object every time you make a change.
Chest allows you to only change part of a value, even if the class is immutable.

```dart
var me = await Chest.open('me', ifNew: () => User());
me.value; // Decodes the whole user.
me.pet.value; // Only decodes the pet.
me.pet.favoriteFood.color.value = Color.red; // Only changes the color.
```

The important thing is that `me` is not a `User`, but a reference to a user – a `Ref<User>`.
Only when you use the `.value` getters or setters, you actually decode or change a subtree of the data.

This is especially handy if you're dealing with large maps:

```dart
var users = await Chest.open<Map<String, User>>('users', ifNew: () => {});
var marcel = users['marcel'].value; // Only decodes Marcel.
users['jonas'].value = User(...); // Only saves Jonas.
```

**Wait a minute. How does Chest know how to handle my types?**
Chest comes with its own encoding called *tape*. Built-in types already have built-in tapers (serializers for objects).
You can annotate your types with `@tape` and let Chest generate tapers automatically:

```dart
@tape
class Fruit {
  final String name;
  final Color color;
}
```

<!-- Tapers for types from other packages are also available to plug and play – for example, for tuple, Flutter, and TODO. -->

## Other perks

- ❤️ **Amazing developer experience.** Just like you can inspect your code with Dart's DevTools, you can inspect, debug, and edit your database with ChestTools live in your browser.
- 🎈 **Lightweight.** Chest is written in pure Dart and has no native dependencies. That also means it works on mobile and desktop.
<!-- - ⚡ **Fast.** Chest is fast. Unlike most other in-memory databases, it also minimizes startup-time. And if you want to tweak performance, profiling and statistics are built-in. -->

## How does it work?

Databases usually store data in files and Chest is no different.

When you call `Chest.open`, Chest opens the file where the value is stored and loads its content into memory.
It only loads the raw bytes into memory, so no deserialization is happening yet (although it does freshen the bytes up a bit using on-the-fly-decompression). That means, opening Chests is pretty fast.

The bytes that are stored in memory are optimized for quick deserialization and a low memory footprint – for example, global deduplication makes it possible that for `{'foo': User('Marcel', Pet('cat')), 'bar': User('Jonas', Pet('cat'))}`, the `Pet('cat')` is only saved once.
This also means that the garbage collector doesn't need to worry about thousands of unused objects cluttering memory (well, it probably does, but Chest doesn't add much to that). To the garbage collector, the content of a chest is just one big object.

When you access parts of a chest using `.value`, only the part of the value is deserialized on-the-fly.

If you change a part, only this update is appended to the end of the file. As more updates accumulate, Chest periodically merges the updates with the existing value.
Of course, merging and file access happen on another `Isolate` (Dart's version of threads), so they don't impact performance of your main `Isolate`.

By the way: If you open a chest multiple times, the same instance is reused. And if you open it on multiple `Isolate`s, they all communicate with the same backend.

## Getting started

<details>
<summary>Add stuff to pubspec</summary>

```yaml
dependencies:
  chest: ...
  # if you're using Flutter
  flutter_taped: ...

dev_dependencies:
  tapegen: ...
```

</details>
<details>
<summary>Open a basic chest</summary>
</details>
<details>
<summary>Generate tapers</summary>
</details>

## Writing tapers manually

When writing tapers manually, you can choose from one of two options:

* serialize objects into bytes
* serialize objects into maps of serializable objects

For serializing an object into bytes, extend `BytesTaper` and overwrite the `toBytes` and `fromBytes` methods:

```dart
class _TaperForBool extends BytesTaper<bool> {
  const _TaperForBool();

  List<int> toBytes(bool value) => [value ? 1 : 0];
  bool fromBytes(List<int> bytes) => bytes.single != 0;
}
```

For serializing an object into a `Map`, extend `MapTaper`

```dart
class _TaperForUser extends ClassTaper<User> {
  const _TaperForUser();
  
  Map<String, Object> toFields(User value) {
    return {'name': value.name, 'pet': value.pet};
  }

  User fromFields(Map<String, Object?> fields) {
    return User(fields['name'] as String, fields['pet'] as Pet);
  }
}
```

To not clutter your global namespace, it's best practise to make the tapers private, but expose them via the `TapersApi`:

```dart
extension TaperForUser on TapersApi {
  Taper<User> forUser() => _TaperForUser();
}
```

Then, you can register the taper:

```dart
void main() {
  tape.register({
    ...
    3: taper.forUser(),
  });
}
```

## Publishing tapers for a package

1. Write tapers manually, as shown above.
2. Add a type code to the table of type ids. (TODO: Add link)
3. Write code like the following for registering tapers:
   ```dart
   extension TapersPackageForDartMath on TapersForPackageApi {
     Map<int, Taper<dynamic>> get forDartMath {
       return {
         -30: taper.forMutableRectangle<int>(),
         -31: taper.forMutableRectangle<double>(),
         -32: taper.forRectangle<int>(),
         -33: taper.forRectangle<double>(),
         -34: taper.forPoint<int>(),
         -35: taper.forPoint<double>(),
       };
     }
   }
   ```
4. Publish your package under the name `<original package>_chest`

## TODO before 1.0.0

- [x] Support saving to and reading from chests
- [x] Support updating parts of chests
- [x] Support watching (parts of) chests
- [x] Properly handle multiple opens of the same Chest
- [x] Revisit value access syntax
- [x] Handle errors gracefully
- [x] Write docs on how it works in principle
- [x] Implement compaction
- [x] Develop Brand & Logo
  - [x] Color palette
  - [x] Font
  - [x] Logo
- [x] Use more efficient `TransferableTypedData`
- [x] Support manually compacting chests
- [x] Write docs on how to write tapers
- [x] Document the tape format
- [x] Document the file format
- [ ] Support taper migration
- [ ] Support storing references
- [ ] Properly handle opening a chest in multiple isolates (blocked by https://github.com/dart-lang/sdk/issues/44495)
- [ ] cross-Isolate adapter registry? (blocked by https://github.com/dart-lang/sdk/issues/44495)
- [ ] Support lazy chests
- [ ] Make errors more beautiful
  - [ ] Suggest tapers
- [ ] Add cycle detection
  - [ ] during serialization
  - [ ] during deserialization
- [ ] Code generation using tapegen
  - [ ] Create tapers
- [ ] Write tapers for various common types
  - [x] dart:core
  - [x] dart:math
  - [x] dart:typed_data
  - [ ] tuple
  - [ ] Flutter
- [ ] Write docs on how to get started
- [ ] Write docs on how to migrate tapers
- [ ] Write tests
- [ ] Add CI
- [ ] Benchmark
  - [ ] Write performance suite
  - [ ] Compare with other databases
    - [ ] Hive & Lazy Hive
    - [ ] Sembast
    - [ ] SQLite
    - [ ] Shared Preferences
- [ ] Create ChestTools, a web interface for debugging Chest databases
  - [ ] Event stream
  - [ ] Data
    - [ ] See available chests
    - [ ] See chests' contents
    - [ ] See live updates of the content
    - [ ] Edit content
    - [ ] Clear chests
  - [ ] Performance
    - [ ] Startup
    - [ ] Decoding statistics
      - [ ] How many decodings are made?
    - [ ] How many updates occur?
  - [ ] Storage
    - [ ] File layout: Base data vs deltas
    - [ ] Trigger manual compaction
- [ ] Insert events into the Dart Debugging Timeline
