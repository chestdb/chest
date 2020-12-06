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

Like regular variables, chest variables are completely type-safe.
Unlike regular variables, they don't actually exist as real Dart objects until you access their `value`.

**But isn't treating databases like variables inefficient?**
Not at all! To be clear, you don't need to save the whole object every time you make a change.
Chest allows you to only change part of a value, even if the class is immutable.

```dart
var me = await Chest.open('me', ifNew: () => User());
me.value; // Decodes the whole user.
me.pet.value; // Only decodes the pet.
me.pet.favoriteFood.color.value = Color.red; // Only changes the color.
```

The critical thing is that `me` is not a `User`, but a reference to a user – a `Ref<User>`.
Only when you use the `.value` getters and setters, you actually decode and change a subtree of the data.

This is especially handy if dealing with large maps:

```dart
var users = await Chest.open<Map<String, User>>('users', ifNew: () => {});
var marcel = users['marcel'].value; // Only decodes Marcel.
users['jonas'].value = User(...); // Only saves Jonas.
```

**Wait a minute. How does Chest know how to serialize my types?**
Chest comes with its own encoding called *tape*. For built-in types, it already comes prepacked with lots of tapers (serializers for objects).
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

Each `Chest.open` call creates a new `Isolate` that handles all interactions with the file.
This means that we can use the faster, synchronous I/O operations.
Also, CPU-heavy tasks like compression don't cause jank in the rest of the app.
And the debugging tooling can inspect which isolates are opened and communicate with all of them separately, making it easy to debug them.
Only the necessary data is transferred to the main isolate.

Each `Chest.open` call is condensed to one `Chest` instance per `Isolate`. Instances of the same chest – even across multiple `Isolate`s – communicate with the same `ChestBackend`, which is responsible for actually acessing the file.

```
+------+ +------+  +------+ +------+
| open | | open |  | open | | open |
+----------------+ +----------------+
| Chest instance | | Chest instance |
+-----------------------------------+
| Chest Backend                     |
+-----------------------------------+
| Files                             |
+-----------------------------------+
```

Chest instances carry a whole model of the chest's content.
The backend is responsible for syncing that model across `Isolate`s and with the file.

## TODO before 1.0.0

- [x] Support saving to and reading from chests
- [x] Support updating parts of chests
- [x] Support watching (parts of) chests
- [x] Properly handle multiple opens of the same Chest
- [x] Revisit value access syntax
- [ ] Implement compaction
- [ ] Support references
- [ ] Support lazy chests
- [ ] Properly handle opening a chest on multiple isolates
- [ ] Support transactions (?)
- [ ] Add cycle detection
  - [ ] during serialization
  - [ ] during deserialization
- [ ] Handle errors gracefully
- [ ] Write tapers for various common types
  - [ ] dart:core
  - [ ] dart:math
  - [ ] dart:typed_data
  - [ ] tuple
  - [ ] Flutter
- [ ] Write docs on how to get started
- [ ] Write docs on how to write tapers
- [ ] Write docs on how it works in principle
- [ ] Document the tape format
- [ ] Document the file format
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
