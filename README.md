⚠ This package is currently in active development and is not production-ready just yet. Breaking changes are still to be expected. Stay tuned!

---

<p align="center">
<img src="https://raw.githubusercontent.com/marcelgarus/chest/master/logo.svg" width="300px" alt="Chest" />
</p>
<h2 align="center"> An in-memory database with amazing developer experience</h2>

**What's a database?**
It's just a place where you can persist data beyond your app's lifetime. Chest offers exactly that: persistent variables called *chests*.

```dart
var counter = Chest<int>('counter', ifNew: () => 0);
await counter.open();
print('This program ran ${counter.value} times.');
counter.value++;
await counter.close();
```

**But isn't treating databases like variables inefficient?**
Not at all! To be clear, you don't need to read or save the whole object every time you make a change.
Chest allows you to only change part of a value, even fields marked with `final`.

```dart
var me = Chest('me', ifNew: () => User());
await me.open();
me.value; // Decodes the whole user.
me.pet.value; // Only decodes the pet.
me.pet.favoriteFood.color.value = Color.red; // Only changes the color.
```

The important thing is that `me` is not a `User`, but a `Reference<User>`.
Only when you use the `.value` getters or setters, you actually decode or change a subtree of the data.

This is especially handy if you're dealing with large maps:

```dart
var users = Chest<Map<String, User>>('users', ifNew: () => {});
await users.open();
var marcel = users['marcel'].value; // Only decodes Marcel.
users['jonas'].value = User(...); // Only saves Jonas.
```

**Hang on. How does Chest know how to handle my types?**
Chest comes with its own encoding called *tape*. Some types already have built-in tapers (serializers for objects).
You can annotate your types with `@tape` and let Chest generate tapers automatically:

```dart
// Run `dart pub run build_runner build` in the command line.
part 'this_file.g.dart';

@tape
class Fruit {
  final String name;
  final Color color;
}
```

<!-- Tapers for types from other packages are also available to plug and play – for example, for tuple, Flutter, and TODO. -->

## Other perks

- ❤️ **Amazing developer experience.** Just like you can inspect your program with Dart's DevTools, you can inspect, debug, and edit your database with ChestTools live in your browser.
- 🎈 **Lightweight.** Chest is written in pure Dart and has no native dependencies. That means it works on any platform.
<!-- - ⚡ **Fast.** Chest is fast. Unlike most other in-memory databases, it also minimizes startup-time. And if you want to tweak performance, profiling and statistics are built-in. -->

## How does it work?

Databases usually store data in files and Chest is no different.
When you open a chest, the file's raw bytes are loaded into memory without doing any deserialization.
So, to Dart's garbage collector, the chest's content is just one big object.

Those bytes are optimized for quick partial deserialization and a low memory footprint.
That makes accessing values pretty fast.

If you change part of the value, only the update is appended to the end of the file.
As more updates accumulate, Chest periodically merges the updates with the existing value.

By the way:
Merging updates and accessing files happen on another `Isolate` (Dart's version of threads), so they don't impact performance of your main `Isolate`.
And if you open a chest multiple times, the same instance is reused.
