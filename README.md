# Chest

A database with amazing developer experience.

## In memory or not?

Chest is an in-memory database similar to Hive or Sembast.
It tries to improve startup time by only doing the necessary work there.
It also offloads non-synchronous performance-intensive tasks to other isolates, so the main thread is free to run.
And finally, debuggability is a huge concern.

## Dart or not?

For simplicity, Chest uses pure Dart.

A great advantage of pure Dart is that it doesn't require any native configuration or dealing with native build systems – the code automatically runs (almost) everywhere where Dart runs, be that Windows, Linux, MacOS, Android, iOS, or Fuchsia. Only web would need to be handled differently.

## API

You should be able to open a box inside a chest and get and set docs easily:

```dart
// A program that prints how many times it has been called. 
final foo = await Chest.open<int>('🌮', ifNew: () => 0);
foo.value++;
print(foo.value);
```

## Debugging

This section only applies to debug mode builds.

For debugging, similar to Dart DevTools, Chest should have a web interface.
It should have some tabs, which contain useful functionality:

- Performance
  - How long was the startup loading time? file + updates
  - Response time and latency of queries?
  - Scheduling information: How many queries are active at a time?
  - Cache hit rates
  - Insert events into the Dart Debugging Timeline and link to it
- Storage
  - File layout
  - Trigger manual compaction
- Data
  - Boxes and their content
  - View and update live data
  - See updates

## General architecture

Each `Chest.open` call creates a new `Isolate` that handles all interactions with the file.
This means that we can use the faster, synchronous I/O operations.
Also, CPU-heavy tasks like compression don't cause jank in the rest of the app.
And the debugging tooling can inspect which isolates are opened and communicate with all of them separately, making it easy to debug them.
Only the necessary data is transferred to the main isolate.

Each `Chest.open` call is condensed to one `Chest` instance per `Isolate`. Instances of the same chest – even across multiple `Isolate`s – communicate with the same `ChestBackend`, which is responsible for actually acessing the file.

```
+-------+ +-------+ +------+ +------+
| Chest | | Chest | | open | | open |
+-----------------+ +----------------+
| Chest instance  | | Chest instance |
+-----------------------------------+
| Chest Backend                     |
+-----------------------------------+
| Files                             |
+-----------------------------------+
```

Chest instances carry a whole model of the chest's content.
The backend is responsible for syncing that model across `Isolate`s and with the file.

## Data layout

### High-level

🌮.chest

object

🌮.chest.updates

path & updated value
path & updated value
path & updated value

### Low-level

type
number of fields
field ids to offsets
fields

* values are self-contained (can be moved)
* order of fields is specified -> equality is simply comparing bytes

For example, the object `User('Marcel', Pet('Katzi'))` may be turned into this:

- type(0) map
  - name: (type(1) raw: 'name'; type(1) raw: 'Marcel')
  - pet
    - key: type(1) raw: 'pet'
    - value
      - type(2) map
        - name: {name: type(1) raw: 'name'; type(1) raw: 'Katzi'}

Compressed:

- object 0: type(0) map
  - name: (see 1; see 2)
  - pet: (see 3; see 4)
- object 1: type(1) raw 'name'
- object 2: type(1) raw 'Marcel'
- object 3: type(1) raw 'pet'
- object 4: type(2) map
  - name: (see 1; see 5)
- object 5: type(1) raw 'Katzi'

### How does it work?

Object level
Block level
Byte level

