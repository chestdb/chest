import 'dart:developer';

import 'package:chest/chunky/chunky.dart';

import 'chunks.dart';
import 'main_chunk.dart';
import 'utils.dart';

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
  static const maxChildren =
      (chunkSize - _headerLength - _childLength) ~/ _entryLength + 1;

  IntMapInternalNodeChunk(this.chunk) : super(ChunkTypes.intMapInternalNode);

  final TransactionChunk chunk;

  int get numKeys => chunk.getUint16(1);
  set numKeys(int numKeys) => chunk.setUint16(1, numKeys);
  int get numChildren => numKeys == 0 ? 0 : numKeys + 1;

  int getKey(int index) =>
      chunk.getKey(_headerLength + _childLength + _entryLength * index);
  Iterable<int> get keys => Iterable.generate(numKeys, getKey);
  void setKey(int index, int key) =>
      chunk.setKey(_headerLength + _childLength + _entryLength * index, key);
  void addKey(int key) => setKey(numKeys++, key);
  void addKeys(Iterable<int> keys) => keys.forEach(addKey);

  int getChild(int index) =>
      chunk.getChild(_headerLength + _entryLength * index);
  Iterable<int> get children => Iterable.generate(numChildren, getChild);
  void setChild(int index, int child) =>
      chunk.setChild(_headerLength + _entryLength * index, child);
  void addChild(int child) => setChild(numKeys++, child);
  void addChildren(Iterable<int> children) => children.forEach(addChild);

  void insertKeyAndChild(int index, int key, int child) {
    for (var i = numKeys - 1; i > index; i--) {
      setKey(i, getKey(i - 1));
    }
    setKey(index, key);
    for (var i = numChildren - 1; i > index + 1; i--) {
      setChild(i, getChild(i - 1));
    }
    setChild(index + 1, child);
  }

  void removeKeyAndChildAt(int keyIndex, int childIndex) {
    for (var i = keyIndex; i < numKeys - 1; i++) {
      setKey(i, getKey(i + 1));
    }
    for (var i = childIndex; i < numChildren - 1; i++) {
      setChild(i, getChild(i + 1));
    }
    numKeys--;
  }

  String toString() {
    final buffer = StringBuffer()..write('[');

    for (var i = 0; i < numKeys; i++) {
      buffer.write('child ${getChild(i)}, ${getKey(i)}, ');
    }
    if (numChildren > 0) {
      buffer.write('child ${getChild(numChildren - 1)}');
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
  static const maxValues = (chunkSize - _headerLength) ~/ _entryLength;

  IntMapLeafNodeChunk(this.chunk) : super(ChunkTypes.intMapLeafNode);

  final TransactionChunk chunk;

  int get numKeys => chunk.getUint16(1);
  set numKeys(int numKeys) => chunk.setUint16(1, numKeys);
  int get numValues => numKeys;

  int get nextLeaf => chunk.getChunkIndex(3);
  set nextLeaf(int id) => chunk.setChunkIndex(3, id);

  int getKey(int index) => chunk.getKey(_headerLength + _entryLength * index);
  Iterable<int> get keys => Iterable.generate(numKeys, getKey);
  void setKey(int index, int key) =>
      chunk.setKey(_headerLength + _entryLength * index, key);
  void addKey(int key) => setKey(numKeys++, key);
  void addKeys(Iterable<int> keys) => keys.forEach(addKey);

  int getValue(int index) =>
      chunk.getValue(_headerLength + _entryLength * index + _keyLength);
  Iterable<int> get values => Iterable.generate(numValues, getValue);
  void setValue(int index, int value) =>
      chunk.setValue(_headerLength + _entryLength * index + _keyLength, value);
  void addValue(int value) => setValue(numKeys++, value);
  void addValues(Iterable<int> values) => values.forEach(addValue);

  void insertKeyAndValue(int index, int key, int value) {
    for (var i = numKeys - 1; i > index; i--) {
      setKey(i, getKey(i - 1));
    }
    setKey(index, key);
    for (var i = numValues - 1; i > index; i--) {
      setValue(i, getValue(i - 1));
    }
    setValue(index, value);
  }

  void removeKeyAndValueAt(int index) {
    for (var i = index; i < numKeys - 1; i++) {
      setKey(i, getKey(i + 1));
    }
    for (var i = index; i < numValues - 1; i++) {
      setValue(i, getValue(i + 1));
    }
    numKeys--;
  }

  String toString() {
    final buffer = StringBuffer()..write('{');

    buffer.write([
      for (var i = 0; i < numKeys; i++) '${getKey(i)}: ${getValue(i)}',
    ].join(', '));
    buffer.write('}');
    return buffer.toString();
  }
}

const _branchingFactor = 3;

class IntMap {
  IntMap(this.chunky) {
    final mainChunk = chunky.mainChunk;
    if (mainChunk.docTreeRoot == 0) {
      final chunk = chunky.addTyped(ChunkTypes.intMapLeafNode);
      print('Chunk is now $chunk.');
      print('And the index is ${chunk.index}.');
      mainChunk.docTreeRoot = chunk.index;
    }
  }

  final Transaction chunky;

  Node get _root => readNode(chunky.mainChunk.docTreeRoot);
  set _root(Node newRoot) => chunky.mainChunk.docTreeRoot = newRoot.index;

  int find(int key) => _root.getValue(key);
  void insert(int key, int value) => _root.insertValue(key, value);
  void delete(int key) => _root.deleteValue(key);
  String toString() => _root.toString();
}

extension on IntMap {
  Node readNode(int index) {
    final chunk = chunky[index].parse();
    if (chunk is IntMapLeafNodeChunk) {
      return LeafNode(this, chunk);
    } else if (chunk is IntMapInternalNodeChunk) {
      return InternalNode(this, chunk);
    }
    debugger();
    throw 'Chunk found that is neither an internal nor a leaf node but a '
        '${chunk.runtimeType} instead.';
  }
}

abstract class Node {
  int get index;
  bool get hasKeys;
  int get firstLeafKey;
  bool get overflows;
  bool get underflows;

  int getValue(int key);
  void insertValue(int key, int value);
  void deleteValue(int key);

  void merge(Node sibling);
  Node split();
}

class InternalNode extends Node {
  InternalNode(this.tree, this.chunk);

  final IntMap tree;
  final IntMapInternalNodeChunk chunk;

  int get index => chunk.chunk.index;
  bool get hasKeys => chunk.numKeys > 0;
  int get firstLeafKey => tree.readNode(chunk.getChild(0)).firstLeafKey;
  bool get overflows => chunk.numChildren > _branchingFactor;
  bool get underflows => chunk.numChildren < (_branchingFactor / 2).ceil();

  int getValue(int key) => getChild(key).getValue(key);

  void insertValue(int key, int value) {
    final child = getChild(key);
    child.insertValue(key, value);
    if (child.overflows) {
      print('InternalNode: Child $child overflows.');
      final sibling = child.split();
      insertChild(sibling.firstLeafKey, sibling);
    }
    if (tree._root.overflows) {
      print('InternalNode: Root ${tree._root} overflows.');
      final sibling = split();
      final newRootChunk = IntMapInternalNodeChunk(tree.chunky.add())
        ..setKey(0, sibling.firstLeafKey)
        ..setChild(0, index)
        ..setChild(1, sibling.index)
        ..numKeys = 1;
      final newRoot = InternalNode(tree, newRootChunk);
      tree._root = newRoot;
    }
  }

  void deleteValue(int key) {
    final child = getChild(key);
    child.deleteValue(key);
    if (child.underflows) {
      final childLeftSibling = getChildLeftSibling(key);
      final childRightSibling = getChildRightSibling(key);
      final left = childLeftSibling ?? child;
      final right = childLeftSibling != null ? child : childRightSibling;
      left.merge(right);
      deleteChild(right.hasKeys ? right.firstLeafKey : key);
      if (left.overflows) {
        final sibling = left.split();
        insertChild(sibling.firstLeafKey, sibling);
      }
      print('Free ${right.index}');
      if (!tree._root.hasKeys) {
        tree._root = left;
      }
    }
  }

  void merge(Node sibling) {
    final node = sibling as InternalNode;
    chunk.addKeys([
      node.firstLeafKey,
      ...node.chunk.keys,
    ]);
    chunk.addChildren(node.chunk.children);
  }

  Node split() {
    final splitIndex = chunk.numKeys ~/ 2 + 1;
    final siblingChunk = IntMapInternalNodeChunk(tree.chunky.add())
      ..addKeys(chunk.keys.skip(splitIndex))
      ..addChildren(chunk.children.skip(splitIndex));
    chunk.numKeys = splitIndex - 1;
    return InternalNode(tree, siblingChunk);
  }

  SearchResult _searchForKey(int key) => _binarySearch(chunk.keys, key);

  Node getChild(int key) {
    final result = _searchForKey(key);
    return result.wasFound ? tree.readNode(chunk.getChild(result.index)) : null;
  }

  void deleteChild(int key) {
    final result = _searchForKey(key);
    if (result.wasFound) {
      chunk.removeKeyAndChildAt(result.index, result.index + 1);
    }
  }

  void insertChild(int key, Node child) {
    final result = _searchForKey(key);
    if (result.wasFound) {
      chunk.setChild(result.index, child.index);
    } else {
      chunk.insertKeyAndChild(result.insertionIndex, key, child.index);
    }
  }

  Node getChildLeftSibling(int key) {
    final childIndex = _searchForKey(key).insertionIndex;
    if (childIndex > 0) {
      return tree.readNode(chunk.getChild(childIndex - 1));
    } else {
      return null;
    }
  }

  Node getChildRightSibling(int key) {
    final childIndex = _searchForKey(key).insertionIndex;
    if (childIndex < chunk.numKeys) {
      return tree.readNode(chunk.getChild(childIndex + 1));
    } else {
      return null;
    }
  }

  String toString() => chunk.toString();
}

class LeafNode extends Node {
  LeafNode(this.tree, this.chunk);

  final IntMap tree;
  final IntMapLeafNodeChunk chunk;

  int get index => chunk.chunk.index;
  bool get hasKeys => chunk.numKeys > 0;
  int get firstLeafKey => chunk.getKey(0);
  bool get overflows => chunk.numValues > _branchingFactor - 1;
  bool get underflows => chunk.numValues < _branchingFactor ~/ 2;

  // Returns the index of the child that can possibly contains the given key.
  // Doesn't guarantee that the child actually contains that key.
  SearchResult _searchForKey(int key) => _binarySearch(chunk.keys, key);

  int getValue(int key) {
    final result = _searchForKey(key);
    return result.wasFound ? chunk.getValue(result.index) : null;
  }

  void insertValue(int key, int value) {
    final result = _searchForKey(key);
    if (result.wasFound) {
      chunk.setValue(result.index, value);
    } else {
      chunk.insertKeyAndValue(result.insertionIndex, key, value);
    }
    if (tree._root.overflows) {
      print('LeafNode: Root ${tree._root} overflows.');
      LeafNode sibling = split();
      final newRootChunk = IntMapInternalNodeChunk(tree.chunky.add())
        ..addKey(sibling.firstLeafKey)
        ..addChildren([index, sibling.index]);
      tree._root = InternalNode(tree, newRootChunk);
    } else {
      print('LeafNode: Root ${tree._root} does not overflow.');
    }
  }

  void deleteValue(int key) {
    final result = _searchForKey(key);
    if (result.wasFound) {
      chunk.removeKeyAndValueAt(result.index);
    }
  }

  void merge(Node sibling) {
    final node = sibling as LeafNode;
    chunk.addKeys(node.chunk.keys);
    chunk.addValues(node.chunk.values);
    chunk.nextLeaf = node.chunk.nextLeaf;
  }

  Node split() {
    final from = (chunk.numKeys + 1) ~/ 2;
    final siblingChunk = IntMapLeafNodeChunk(tree.chunky.add())
      ..addKeys(chunk.keys.skip(from))
      ..addValues(chunk.values.skip(from));
    final sibling = LeafNode(tree, siblingChunk);
    chunk.numKeys = from;

    sibling.chunk.nextLeaf = chunk.nextLeaf;
    chunk.nextLeaf = sibling.index;
    return sibling;
  }

  String toString() => chunk.toString();
}

SearchResult _binarySearch(List<int> list, int key) {
  int min = 0;
  int max = list.length;
  while (min < max) {
    final mid = min + ((max - min) >> 1);
    final currentItem = list[mid];
    final res = currentItem.compareTo(key);
    // print('Result of comparing $currentItem to $key is $res');
    if (res == 0) {
      return SearchResult._(true, mid);
    } else if (res < 0) {
      min = mid + 1;
    } else {
      max = mid;
    }
  }
  // print('Binary search didnt find the value. min=$min max=$max');
  return SearchResult._(false, min);
}

class SearchResult {
  SearchResult._(this.wasFound, this._index);

  final bool wasFound;
  bool get wasNotFound => !wasFound;

  final int _index;

  int get index {
    assert(wasFound);
    return _index;
  }

  // The index where the key would be inserted.
  int get insertionIndex => wasFound ? _index + 1 : _index;
}
