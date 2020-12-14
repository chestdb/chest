⚠ This package is currently in active development and is not production-ready just yet. Breaking changes are still to be expected. Stay tuned!

---

<h2 align="center">
An in-memory database with amazing developer experience.
</h2>

<!-- ❤️🧽🧼🌌 -->

<!-- - ❤️ **Amazing developer experience.** Just like you can inspect your code with Dart's DevTools, you can inspect, debug, and edit your database with ChestTools live in your browser. -->
- 🌌 **Scalable.** Chest can store anything from single `int`s to huge collections.
- 🎈 **Lightweight.** Chest is written in pure Dart and has no native dependencies. That also means it works on mobile and desktop.
<!-- - 🔒 **Secure.** Chest has encryption built-in. -->
<!-- - ⚡ **Fast.** Chest is fast. Unlike most other in-memory databases, it also minimizes startup-time. And if you want to tweak performance, profiling and statistics are built-in. -->

## Chest's philosophy

**What's a database?**
In its purest form, it's just a place to persist data beyond the lifetime of your app. Chest offers exactly that: persistent variables called *chests*.

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
Chest comes with its own encoding called *tape*. Built-in types already have prepacked tapers (serializers for objects).
You can annotate your types with `@tape` and let Chest generate tapers automatically:

```dart
@tape
class Fruit {
  final String name;
  final Color color;
}
```

<!-- Tapers for types from other packages are also available to plug and play – for example, for tuple, Flutter, and TODO. -->

<!-- **In like it's going to eat an awful lot of RAM.**
True. If your app stores homungous amounts of data, Chest is probably not the right fit for you.
Chest tries to mitigate this issue by storing the data not as actual Dart objects, but as a dense byte representation.
Values are only decoded on demand. -->

## How does it work?

When you call `Chest.open`, Chest opens the file where the value is stored and loads its content into memory.
It only loads the raw bytes into memory, so no deserialization is happening yet (although it does freshen the bytes up a bit using on-the-fly-decompression). That means, opening Chests is pretty fast.

The bytes that are stored in memory are optimized for quick deserialization and a low memory footprint – for example, global deduplication makes it possible that for `{'foo': User('Marcel', Pet('cat')), 'bar': User('Jonas', Pet('cat'))}`, the `Pet('cat')` is only saved once.
This also means that the garbage collector doesn't need to worry about thousands of unused objects cluttering memory (well, it probably does, but Chest doesn't add much to that). To the garbage collector, the content of a chest is just one big object.

When you access parts of a chest using `.value`, only the part of the value is deserialized on-the-fly.

If you change a part, only this update is appended to the end of the file. As more updates accumulate, Chest periodically merges the updates with the existing value.
Of course, merging and file access happen on another `Isolate` (Dart's version of threads), so they don't impact performance of your main `Isolate`.

By the way: If you open a chest multiple times, the same instance is reused. And if you open it on multiple `Isolate`s, they all communicate with the same backend.

## TODO before 1.0.0

- [x] Support saving to and reading from chests
- [x] Support updating parts of chests
- [x] Support watching (parts of) chests
- [x] Properly handle multiple opens of the same Chest
- [x] Revisit value access syntax
- [x] Handle errors gracefully
- [x] Write docs on how it works in principle
- [ ] Implement compaction
- [ ] Properly handle opening a chest in multiple isolates
- [ ] cross-Isolate adapter registry?
- [ ] Support taper migration
- [ ] Support storing references
- [ ] Support lazy chests
- [ ] Make errors more beautiful
  - [ ] Suggest tapers
- [ ] Add cycle detection
  - [ ] during serialization
  - [ ] during deserialization
- [ ] Write tapers for various common types
  - [x] dart:core
  - [x] dart:math
  - [x] dart:typed_data
  - [ ] tuple
  - [ ] Flutter
- [ ] Write docs on how to get started
- [ ] Write docs on how to write tapers
- [ ] Write docs on how to migrate tapers
- [ ] Document the tape format
- [ ] Document the file format
- [ ] Write tests
- [ ] Add CI
- [ ] Benchmark
  - [ ] Write performance suite
  - [ ] Compare with other databases:
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
- [ ] Develop Brand & Logo
  - [x] Color palette
  - [x] Font
  - [ ] Logo
