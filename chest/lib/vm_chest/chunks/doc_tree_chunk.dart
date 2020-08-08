import 'dart:developer';

import 'package:chest/chunky/chunky.dart';
import 'package:meta/meta.dart';

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

  IntMapInternalNodeChunk(this.chunk) : super(ChunkTypes.intMapInternalNode) {
    keys = BackedList<int>(
      setLength: (length) => numKeys = length,
      getLength: () => numKeys,
      setItem: (index, key) => chunk.setKey(
          _headerLength + _childLength + _entryLength * index, key),
      getItem: (index) =>
          chunk.getKey(_headerLength + _childLength + _entryLength * index),
    );
    children = BackedList<int>(
      setLength: (length) => numKeys = length - 1,
      getLength: () => numChildren,
      setItem: (index, child) =>
          chunk.setChild(_headerLength + _entryLength * index, child),
      getItem: (index) => chunk.getChild(_headerLength + _entryLength * index),
    );
  }

  final TransactionChunk chunk;
  BackedList<int> keys;
  BackedList<int> children;

  int get numKeys => chunk.getUint16(1);
  set numKeys(int numKeys) => chunk.setUint16(1, numKeys);
  int get numChildren => numKeys + 1;

  void initialize({
    @required List<int> keys,
    @required List<int> children,
  }) {
    assert(keys.length + 1 == children.length);
    numKeys = 0;
    this.children.first = children.first;
    this.children.addAll(children.sublist(1));
    numKeys = 0;
    this.keys.addAll(keys);
  }

  void insertKeyAndChild(int index, int key, int child) {
    keys.insert(index, key);
    numKeys--;
    children.insert(index + 1, child);
  }

  void removeKeyAndChildAt(int keyIndex, int childIndex) {
    print('Removing key at $keyIndex and chlid at $childIndex.');
    keys.removeAt(keyIndex);
    numKeys++;
    children.removeAt(childIndex);
    print('numKeys is $numKeys');
  }

  String toString() {
    final buffer = StringBuffer()..write('[');
    for (var i = 0; i < numKeys; i++) {
      buffer.write('child ${children[i]}, ${keys[i]}, ');
    }
    if (numChildren > 0) {
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
  static const maxValues = (chunkSize - _headerLength) ~/ _entryLength;

  IntMapLeafNodeChunk(this.chunk) : super(ChunkTypes.intMapLeafNode) {
    keys = BackedList<int>(
      setLength: (length) => numEntries = length,
      getLength: () => numEntries,
      setItem: (index, key) =>
          chunk.setKey(_headerLength + _entryLength * index, key),
      getItem: (index) => chunk.getKey(_headerLength + _entryLength * index),
    );
    values = BackedList<int>(
      setLength: (length) => numEntries = length,
      getLength: () => numEntries,
      setItem: (index, value) => chunk.setValue(
          _headerLength + _entryLength * index + _keyLength, value),
      getItem: (index) =>
          chunk.getValue(_headerLength + _entryLength * index + _keyLength),
    );
  }

  final TransactionChunk chunk;
  BackedList<int> keys;
  BackedList<int> values;

  int get numEntries => chunk.getUint16(1);
  set numEntries(int value) => chunk.setUint16(1, value);

  int get nextLeaf => chunk.getChunkIndex(3);
  set nextLeaf(int id) => chunk.setChunkIndex(3, id);

  void insertKeyAndValue(int index, int key, int value) {
    keys.insert(index, key);
    numEntries--;
    values.insert(index, value);
  }

  void removeKeyAndValueAt(int index) {
    keys.removeAt(index);
    numEntries++;
    values.removeAt(index);
  }

  String toString() {
    final buffer = StringBuffer()..write('{');
    buffer.write([
      for (var i = 0; i < numEntries; i++) '${keys[i]}: ${values[i]}',
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
  int get firstLeafKey => tree.readNode(chunk.children.first).firstLeafKey;
  bool get overflows => chunk.numChildren > _branchingFactor;
  bool get underflows => chunk.numChildren < (_branchingFactor / 2).ceil();

  int getValue(int key) => getChild(key).getValue(key);

  void insertValue(int key, int value) {
    // debugger(when: key == 5);
    final child = getChild(key);
    child.insertValue(key, value);
    if (child.overflows) {
      final sibling = child.split();
      insertChild(sibling.firstLeafKey, sibling);
    }
    if (tree._root.overflows) {
      final sibling = split();
      final newRootChunk = IntMapInternalNodeChunk(tree.chunky.add())
        ..initialize(
          keys: [sibling.firstLeafKey],
          children: [index, sibling.index],
        );
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
      debugger(when: key == 9);
      if (!tree._root.hasKeys) {
        print('Free former root ${tree._root.index}');
        tree._root = left;
      }
    }
  }

  void merge(Node sibling) {
    final node = sibling as InternalNode;
    final numAddedEntries = node.chunk.numChildren;
    chunk.keys.addAll([
      node.firstLeafKey,
      ...node.chunk.keys,
    ]);
    chunk.numKeys -= numAddedEntries;
    chunk.children.addAll(node.chunk.children);
  }

  Node split() {
    final splitIndex = chunk.numKeys ~/ 2 + 1;
    final siblingChunk = IntMapInternalNodeChunk(tree.chunky.add())
      ..initialize(
        keys: chunk.keys.skip(splitIndex).toList(),
        children: chunk.children.skip(splitIndex).toList(),
      );
    chunk.numKeys = splitIndex - 1;
    return InternalNode(tree, siblingChunk);
  }

  SearchResult _searchForKey(int key) => chunk.keys.find(key);

  Node getChild(int key) {
    final result = _searchForKey(key);
    final index = result.wasFound ? result.index + 1 : result.insertionIndex;
    return tree.readNode(chunk.children[index]);
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
      chunk.children[result.index] = child.index;
    } else {
      chunk.insertKeyAndChild(result.insertionIndex, key, child.index);
    }
  }

  Node getChildLeftSibling(int key) {
    final childIndex = _searchForKey(key).insertionIndex;
    if (childIndex > 0) {
      return tree.readNode(chunk.children[childIndex - 1]);
    } else {
      return null;
    }
  }

  Node getChildRightSibling(int key) {
    final childIndex = _searchForKey(key).insertionIndex;
    if (childIndex < chunk.numKeys) {
      return tree.readNode(chunk.children[childIndex + 1]);
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
  bool get hasKeys => chunk.numEntries > 0;
  int get firstLeafKey => chunk.keys[0];
  bool get overflows => chunk.numEntries > _branchingFactor - 1;
  bool get underflows => chunk.numEntries < _branchingFactor ~/ 2;

  // Returns the index of the child that can possibly contains the given key.
  // Doesn't guarantee that the child actually contains that key.
  SearchResult _searchForKey(int key) => chunk.keys.find(key);

  int getValue(int key) {
    final result = _searchForKey(key);
    return result.wasFound ? chunk.values[result.index] : null;
  }

  void insertValue(int key, int value) {
    final result = _searchForKey(key);
    if (result.wasFound) {
      chunk.values[result.index] = value;
    } else {
      chunk.insertKeyAndValue(result.insertionIndex, key, value);
    }
    if (tree._root.overflows) {
      LeafNode sibling = split();
      final newRootChunk = IntMapInternalNodeChunk(tree.chunky.add())
        ..keys.add(sibling.firstLeafKey)
        ..numKeys = 0
        ..children[0] = index
        ..children.add(sibling.index)
        ..numKeys = 1;
      tree._root = InternalNode(tree, newRootChunk);
    } else {
      print('LeafNode: Root ${tree._root} does not overflow.');
    }
  }

  void deleteValue(int key) {
    final result = _searchForKey(key);
    print('Removing the value for key $key of ${chunk.keys}. Was found? '
        '${result.wasFound}');
    if (result.wasFound) {
      chunk.removeKeyAndValueAt(result.index);
    }
  }

  void merge(Node sibling) {
    final node = sibling as LeafNode;
    chunk
      ..keys.addAll(node.chunk.keys)
      ..numEntries -= node.chunk.keys.length
      ..values.addAll(node.chunk.values)
      ..nextLeaf = node.chunk.nextLeaf;
  }

  Node split() {
    final from = (chunk.numEntries + 1) ~/ 2;
    final siblingChunk = IntMapLeafNodeChunk(tree.chunky.add())
      ..keys.addAll(chunk.keys.skip(from))
      ..numEntries = 0
      ..values.addAll(chunk.values.skip(from))
      ..nextLeaf = chunk.nextLeaf;
    chunk
      ..numEntries = from
      ..nextLeaf = siblingChunk.chunk.index;
    return LeafNode(tree, siblingChunk);
  }

  String toString() => chunk.toString();
}
