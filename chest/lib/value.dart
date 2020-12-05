/// This file contains everything needed to describe partially updatable values.

import 'blocks.dart';

/// A path that can reference part of a value that's nested inside.
class Path<T> {
  const Path(this.keys);
  const Path.root() : this(const []);

  final List<T> keys;
  bool get isRoot => keys.isEmpty;

  Path<T> withoutFirst() => Path(keys.skip(1).toList());
  bool startsWith(Block other) => !isRoot && keys.first == other;
  Path<Block> serialize() {
    return Path(keys.map((it) => it.toBlock()).toList());
  }
}

/// An update for a part of a value.
class Delta {
  Delta(this.path, this.value);

  final Path<Block> path;
  final Block value;

  bool get isForRoot => path.isRoot;
  Delta withoutFirstPathKey() => Delta(path.withoutFirst(), value);
}

/// The in-memory representation of a value. It's partially updatable.
class Value {
  Value(this._baseValue);

  Block _baseValue;
  final _deltas = <Block, Value>{};

  void update(Delta delta) {
    if (delta.isForRoot) {
      _baseValue = delta.value;
      _deltas.clear();
    } else {
      final firstKey = delta.path.keys.first;
      _deltas
          // TOOD: Better error handling.
          .putIfAbsent(
              firstKey, () => Value(_baseValue.cast<MapBlock>()[firstKey]!))
          .update(delta.withoutFirstPathKey());
    }
  }

  Block getAt(Path<Block> path) {
    if (path.isRoot) {
      if (_deltas.isEmpty) {
        return _baseValue;
      } else {
        return _baseValue.cast<MapBlock>().copyWith({
          for (final entry in _deltas.entries)
            entry.key: entry.value.getAt(Path.root()),
        });
      }
    } else {
      final firstKey = path.keys.first;
      return _deltas[firstKey]?.getAt(path.withoutFirst()) ??
          _baseValue.cast<MapBlock>()[firstKey]!;
    }
  }
}
