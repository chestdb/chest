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

/// The in-memory representation of a value. It's partially updatable.
class Value {
  Value(this._baseValue);

  Block _baseValue;
  final _deltas = <Block, Value>{};

  void update(Path<Block> path, Block value) {
    if (path.isRoot) {
      _baseValue = value;
      _deltas.clear();
    } else {
      final firstKey = path.keys.first;
      _deltas
          // TOOD: Better error handling.
          .putIfAbsent(
            firstKey,
            () => Value(_baseValue.cast<MapBlock>()[firstKey]!),
          )
          .update(path.withoutFirst(), value);
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
    }
    final matchingDelta = _deltas[path.keys.first];
    if (matchingDelta != null) {
      return matchingDelta.getAt(path.withoutFirst());
    }
    var value = _baseValue;
    while (!path.isRoot) {
      value = value.cast<MapBlock>()[path.keys.first] ??
          (throw 'No key ${path.keys.first} found. Keys: '
              '${_baseValue.cast<MapBlock>().entries.map((it) => it.key).toSet().union(_deltas.keys.toSet())}');
      path = path.withoutFirst();
    }
    print('Found value: $value');
    return value;
  }
}
