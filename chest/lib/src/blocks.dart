import 'package:more/more.dart';

import 'utils.dart';

/// An intermediary format that doesn't contain arbitrary [Object]s anymore, but
/// rather consists of two simple primitives: `MapBlock`s and `ByteBlock`s.
///
/// This is comparable to JSON, where also only a handful of primitives are
/// allowed (numbers, strings, maps, lists, etc.). The difference is that
/// [Block]s are more memory efficient and also contain type information.
abstract class Block implements Comparable<Block> {
  const Block();

  int get typeCode;

  A cast<A>() => this is A ? this as A : throw 'Block type not expected';

  @override
  String toString([int indentation]);
}

/// A block that contains a [Map] from [Block]s to other [Block]s.
///
/// Turns out, maps are a very useful datastructure: Lookup is very fast and
/// most types can be reduced to a map:
///
/// * Classes can be seen as maps from field names to values.
/// * [Map]s are maps.
/// * [List]s can be seen as maps from integers (indexes) to values.
/// * [Set]s can be seen as maps from values to nulls (either a key exists in
///   the map or it doesn't).
abstract class MapBlock extends Block {
  factory MapBlock(int typeCode, Map<Block, Block> map) = _DefaultMapBlock;
  const MapBlock.noop();

  Block? operator [](Block key);
  operator []=(Block key, Block value);
  List<MapEntry<Block, Block>> get entries;

  /// Returns a copy of this [MapBlock] with the given changes. Changes with a
  /// [null] as value are deletions.
  MapBlock copyWith(Map<Block, Block?> changes) {
    final entries = this.entries.toMap();
    for (final entry in changes.entries) {
      if (entry.value == null) {
        entries.remove(entry.key);
      } else {
        entries[entry.key] = entry.value!;
      }
    }
    return MapBlock(typeCode, entries);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapBlock &&
          typeCode == other.typeCode &&
          entries.deeplyEquals(other.entries);

  @override
  int get hashCode => hash2(typeCode, hash(entries));

  @override
  int compareTo(Block other) {
    if (identical(this, other)) return 0;

    var result = typeCode.compareTo(other.typeCode);
    if (result != 0) return result;

    if (other is! MapBlock) return -1;

    final entries = this.entries;
    final otherEntries = other.entries;

    result = entries.length.compareTo(otherEntries.length);
    if (result != 0) return result;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final otherEntry = otherEntries[i];

      result = entry.key.compareTo(otherEntry.key);
      if (result != 0) return result;

      result = entry.value.compareTo(otherEntry.value);
      if (result != 0) return result;
    }

    return 0;
  }

  @override
  String toString([int indentation = 0]) {
    final buffer = StringBuffer()..writeln('$typeCode@{');
    for (final entry in entries) {
      buffer
        ..write('  ' * (indentation + 1))
        ..write(entry.key.toString(indentation + 1))
        ..write(': ')
        ..write(entry.value.toString(indentation + 1))
        ..writeln();
    }
    buffer..write('  ' * indentation)..write('}');
    return buffer.toString();
  }
}

class _DefaultMapBlock extends MapBlock {
  _DefaultMapBlock(this.typeCode, this.map) : super.noop();

  final int typeCode;
  final Map<Block, Block> map;

  Block? operator [](Block key) => map[key];
  operator []=(Block key, Block value) => map[key] = value;
  List<MapEntry<Block, Block>> get entries => map.entries.toList();
}

/// A block that contains some bytes.
///
/// While [MapBlock] is an internal node in the [Block] tree, this is a leaf
/// node. It's the most basic abstraction over raw data.
abstract class BytesBlock extends Block {
  factory BytesBlock(int typeCode, List<int> bytes) = _DefaultBytesBlock;
  const BytesBlock.noop();

  List<int> get bytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BytesBlock &&
          typeCode == other.typeCode &&
          bytes.deeplyEquals(other.bytes);

  int get hashCode => hash2(typeCode, hash(bytes));

  @override
  int compareTo(Block other) {
    if (identical(this, other)) return 0;

    var result = typeCode.compareTo(other.typeCode);
    if (result != 0) return result;

    if (other is! BytesBlock) return -1;

    final bytes = this.bytes;
    final otherBytes = other.bytes;

    result = bytes.length.compareTo(otherBytes.length);
    if (result != 0) return result;

    for (var i = 0; i < bytes.length; i++) {
      result = bytes[i].compareTo(otherBytes[i]);
      if (result != 0) return result;
    }

    return 0;
  }

  String toString([int indentation = 0]) {
    return '$typeCode@[${bytes.map((byte) => byte.toRadixString(16)).join(' ')}]';
  }
}

class _DefaultBytesBlock extends BytesBlock {
  _DefaultBytesBlock(this.typeCode, this.bytes)
      : assert(bytes.every((byte) => byte >= 0 && byte < 256)),
        super.noop();

  final int typeCode;
  final List<int> bytes;
}

/// A reference to part of a [Block].
///
/// The [Path] is similar to file system paths like `/usr/lib/bin`, but the
/// segments/keys (the parts of the path) don't have to be `String`s – they can
/// be any `T`.
class Path<T> {
  const Path(this.keys);
  const Path.root() : this(const []);

  final List<T> keys;
  bool get isRoot => keys.isEmpty;
  int get length => keys.length;

  T get firstKey => keys.first;
  Path<T> withoutFirst() => Path(keys.skip(1).toList());
  bool startsWith(Path<T> other) {
    return other.isRoot ||
        !isRoot &&
            firstKey == other.firstKey &&
            withoutFirst().startsWith(other.withoutFirst());
  }

  @override
  String toString() => isRoot ? '<root>' : keys.join('/');
}

/// Wrapper for a [Block] and the updates made to it.
///
/// You can get a part of it and update a part of it.
///
/// [UpdatableBlock]s have a block as the base and a map of updates, organized
/// by the first path key that they apply to. Here's an example of how it works:
///
/// ```
/// UpdatableBlock(
///   block: User('Marcel', Pet('fish')),
///   updates: {},
/// ),
/// ```
///
/// Updating the user's name to 'Jonas' and the pet's name to kitten, this is
/// the new [UpdatableBlock]:
///
/// ```
/// UpdatableBlock(
///   block: User('Marcel', Pet('fish')),
///   updates: {
///     'name': UpdatableBlock(block: 'Jonas', updates: {}),
///     'pet': UpdatableBlock(
///       block: Pet('fish'),
///       updates: {
///         'name': 'fish',
///       },
///     ),
///   },
/// ),
/// ```
///
/// Then, deleting the whole pet would result in this structure:
///
/// ```
/// UpdatableBlock(
///   block: User('Marcel', Pet('fish')),
///   updates: {
///     'name': UpdatableBlock(block: 'Jonas', updates: {}),
///     'pet': null,
///   },
/// ),
/// ```
///
/// Note that the `null` value overwrites the pet from the base block – so
/// there's a difference between the `Map` having no value for a key and the
/// value being `null`.
class UpdatableBlock {
  UpdatableBlock(this.block, [Map<Block, UpdatableBlock?>? updates])
      : this.updates = updates ?? {};

  Block block;
  final Map<Block, UpdatableBlock?> updates;
  bool get _hasUpdates => updates.isNotEmpty;

  Block? getAt(Path<Block> path) {
    if (path.isRoot) return getAtRoot();

    final firstKey = path.firstKey;
    if (updates.containsKey(firstKey)) {
      return updates[firstKey]?.getAt(path.withoutFirst());
    }

    final keys = List.of(path.keys);
    var value = block;
    while (!keys.isEmpty) {
      if (value is! MapBlock) _throwInvalid(path);
      value = value[keys.removeAt(0)] ?? _throwInvalid(path);
    }
    return value;
  }

  /// Returns this block with all updates applied.
  Block getAtRoot() {
    final block = this.block;
    if (!_hasUpdates) return block;
    if (block is! MapBlock) {
      panic('UpdatableBlock has updates, although its not a MapBlock.');
    }
    final map = block.entries.toMap();
    updates.forEach((key, block) {
      if (block == null) {
        map.remove(key);
      } else {
        map[key] = block.getAtRoot();
      }
    });
    return MapBlock(block.typeCode, map);
  }

  void update(
    Path<Block> path,
    Block? updatedBlock, {
    required bool createImplicitly,
  }) {
    if (path.isRoot) {
      if (updatedBlock == null) throw TriedToDeleteRootValueError();
      // The updatedBlock replaces the current block, so all updates become
      // irrelevant.
      this.block = updatedBlock;
      updates.clear();
      return;
    }

    final block = this.block;
    if (block is! MapBlock) _throwInvalid(path);
    final key = path.firstKey;

    if (path.length > 1) {
      /// Delegate the request to a child. Throw if it doesn't exist – even if
      /// [createImplicitly] is set, that doesn't create the whole path to the
      /// child, only the last entry.
      final child = updates.putIfAbsent(key, () {
            return UpdatableBlock(block[key] ?? _throwInvalid(path));
          }) ??
          _throwInvalid(path);
      child.update(
        path.withoutFirst(),
        updatedBlock,
        createImplicitly: createImplicitly,
      );
      return;
    }

    assert(path.length == 1);

    if (updatedBlock == null) {
      // Delete a key.
      updates[key] = null;
      return;
    }

    final previousValue = updates.containsKey(key) ? updates[key] : block[key];
    if (!createImplicitly && previousValue == null) {
      _throwInvalid(path);
    }
    updates[key] = UpdatableBlock(updatedBlock);
  }

  Never _throwInvalid(Path<Block> path) => throw InvalidPathException(path);

  @override
  String toString() {
    return 'UpdatableBlock(base: $block, updates: $updates)';
  }
}

/// Indicates that you attempted to perform an operation with an invalid path.
class InvalidPathException implements ChestException {
  InvalidPathException(this.path);

  final Path<Object> path;

  String toString() => 'The path $path is invalid.';
}

class TriedToDeleteRootValueError extends ChestError {
  String toString() => 'You tried to delete the root value.';
}
