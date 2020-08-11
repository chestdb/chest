import 'package:chest/chunky/chunky.dart';
import 'package:meta/meta.dart';

import '../chunks.dart';
import '../utils.dart';

// To make sense of all the code here, you should first understand B+ trees:
// https://en.wikipedia.org/wiki/B%2B_tree

// The [IntMap] maps [int]s to [int]s.

// Keys, children (child chunk ids) and values are both encoded as 64-bit integers.
extension on Chunk {
  int getKey(int offset) => getInt64(offset);
  void setKey(int offset, int key) => setInt64(offset, key);

  int getChild(int offset) => getChunkIndex(offset);
  void setChild(int offset, int child) => setChunkIndex(offset, child);

  int getValue(int offset) => getInt64(offset);
  void setValue(int offset, int value) => setInt64(offset, value);
}

const _keyLength = 8;
const _childLength = chunkIndexLength;
const _valueLength = 8;

/// A chunk that represents an internal node in an [IntMap].
///
/// The keys of the node are [int]s, the children are indizes of chunks.
///
/// # Layout
///
/// ```
/// | type | num keys | child | key | child | key | child | ...  | key | child |
/// | 1B   | 2B       | 8B    | 8B  | 8B    | 8B  | 8B    |      | 8B  | 8B    |
/// ```
/// Note it always contains one more child than keys.
class IntMapInternalNodeChunk extends ChunkWrapper {
  static const _headerLength = 3;
  static const _entryLength = _keyLength + _childLength;
  static const maxKeys =
      (chunkSize - _headerLength - _childLength) ~/ _entryLength - 1;
  static const maxChildren = maxKeys + 1;

  IntMapInternalNodeChunk(this.chunk) : super(ChunkTypes.intMapInternalNode) {
    keys = BackedList<int>(
      setLength: (length) => _numKeys = length,
      getLength: () => _numKeys,
      setItem: (index, key) => chunk.setKey(
          _headerLength + _childLength + _entryLength * index, key),
      getItem: (index) =>
          chunk.getKey(_headerLength + _childLength + _entryLength * index),
    );
    // If this chunk is newly initialized, we don't have any keys or children
    // yet. In all other cases, we have one child more than keys.
    _numChildren = keys.length == 0 ? 0 : keys.length + 1;
    children = BackedList<int>(
      setLength: (length) => _numChildren = length,
      getLength: () => _numChildren,
      setItem: (index, child) =>
          chunk.setChild(_headerLength + _entryLength * index, child),
      getItem: (index) => chunk.getChild(_headerLength + _entryLength * index),
    );
  }

  final TransactionChunk chunk;
  BackedList<int> keys;
  BackedList<int> children;

  int get _numKeys => chunk.getUint16(1);
  set _numKeys(int numKeys) => chunk.setUint16(1, numKeys);

  /// Because the [children] list is always one element longer than the [keys]
  /// list, the length is only encoded once in the binary format.
  /// The [ListMixin] asserts that the length changes appropriately when doing
  /// operations on the lists – of course, that doesn't work if both lists share
  /// the same length variable. That's why we stores the [children]'s length
  /// separately in-memory.
  /// Because this variable isn't ever serialized, the number of keys is the
  /// ultimate source of truth.
  int _numChildren;

  String toString() {
    final buffer = StringBuffer()..write('[');
    for (var i = 0; i < _numKeys; i++) {
      buffer.write('child ${children[i]}, ${keys[i]}, ');
    }
    if (_numChildren > 0) {
      buffer.write('child ${children.last}');
    }
    buffer.write(']');
    return buffer.toString();
  }
}

/// A chunk that is a leaf node in the [IntMap].
///
/// The keys and values are [int]s.
///
/// # Layout
///
/// ```
/// | type | num keys | next leaf | key | value | ...            | key | value |
/// | 1B   | 2B       | 8B        | 8B  | 8B    |                | 8B  | 8B    |
/// ```
class IntMapLeafNodeChunk extends ChunkWrapper {
  static const _headerLength = 11;
  static const _entryLength = _keyLength + _valueLength;
  static const maxKeys = (chunkSize - _headerLength) ~/ _entryLength - 1;
  static const maxValues = maxKeys;

  IntMapLeafNodeChunk(this.chunk) : super(ChunkTypes.intMapLeafNode) {
    keys = BackedList<int>(
      setLength: (length) => _numKeys = length,
      getLength: () => _numKeys,
      setItem: (index, key) =>
          chunk.setKey(_headerLength + _entryLength * index, key),
      getItem: (index) => chunk.getKey(_headerLength + _entryLength * index),
    );
    _numValues = keys.length;
    values = BackedList<int>(
      setLength: (length) => _numValues = length,
      getLength: () => _numValues,
      setItem: (index, value) => chunk.setValue(
          _headerLength + _entryLength * index + _keyLength, value),
      getItem: (index) =>
          chunk.getValue(_headerLength + _entryLength * index + _keyLength),
    );
  }

  final TransactionChunk chunk;
  BackedList<int> keys;
  BackedList<int> values;

  int get _numKeys => chunk.getUint16(1);
  set _numKeys(int value) => chunk.setUint16(1, value);

  /// Similar to [IntMapInternalNodeChunk]'s `_numKeys` field, we also have an
  /// in-memory copy of the value length here.
  int _numValues;

  int get nextLeaf => chunk.getChunkIndex(3);
  set nextLeaf(int id) => chunk.setChunkIndex(3, id);

  String toString() {
    final buffer = StringBuffer()..write('{');
    buffer.write([
      for (var i = 0; i < _numKeys; i++) '${keys[i]}: ${values[i]}',
    ].join(', '));
    buffer.write('}');
    return buffer.toString();
  }
}
