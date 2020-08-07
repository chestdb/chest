import 'dart:developer';

import 'package:chest/chunky/chunky.dart';

import 'chunks.dart';
import 'main_chunk.dart';
import 'utils.dart';

// To make sense of all the code here, you should first understand B+ trees:
// https://en.wikipedia.org/wiki/B%2B_tree

// The [IntMap] maps [int]s to [int]s.

// Keys and values are both encoded as 64-bit integers.
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

  final Chunk chunk;

  int get numKeys => chunk.getUint16(1);
  set numKeys(int numKeys) => chunk.setUint16(1, numKeys);
  int get numChildren => numKeys == 0 ? 0 : numKeys + 1;

  int getKey(int index) =>
      chunk.getKey(_headerLength + _childLength + _entryLength * index);
  void setKey(int index, int key) =>
      chunk.setKey(_headerLength + _childLength + _entryLength * index, key);

  int getChild(int index) =>
      chunk.getChild(_headerLength + _entryLength * index);
  void setChild(int index, int child) =>
      chunk.setChild(_headerLength + _entryLength * index, child);
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

  final Chunk chunk;

  int get numKeys => chunk.getUint16(1);
  set numKeys(int numKeys) => chunk.setUint16(1, numKeys);
  int get numValues => numKeys;

  int get nextLeaf => chunk.getChunkIndex(3);
  set nextLeaf(int id) => chunk.setChunkIndex(3, id);

  int getKey(int index) => chunk.getKey(_headerLength + _entryLength * index);
  void setKey(int index, int key) =>
      chunk.setKey(_headerLength + _entryLength * index, key);

  int getValue(int index) =>
      chunk.getValue(_headerLength + _entryLength * index + _keyLength);
  void setValue(int index, int value) =>
      chunk.setValue(_headerLength + _entryLength * index + _keyLength, value);
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
      return LeafNode(this, index);
    } else if (chunk is IntMapInternalNodeChunk) {
      return InternalNode(this, index);
    }
    debugger();
    throw 'Chunk found that is neither an internal nor a leaf node but a '
        '${chunk.runtimeType} instead.';
  }
}

abstract class Node {
  void write();

  int get index;
  var keys = <int>[];

  int get numKeys => keys.length;
  int getValue(int key);
  void deleteValue(int key);
  void insertValue(int key, int value);
  int get firstLeafKey;
  void merge(Node sibling);
  Node split();
  bool get overflows;
  bool get underflows;
}

class InternalNode extends Node {
  InternalNode(this.tree, this.index) {
    final chunk = tree.chunky[index].parse<IntMapInternalNodeChunk>();
    for (var i = 0; i < chunk.numKeys; i++) {
      keys.add(chunk.getKey(i));
    }
    for (var i = 0; i < chunk.numChildren; i++) {
      children.add(chunk.getChild(i));
    }
    print('Read $index:  $this');
  }

  void write() {
    final chunk = IntMapInternalNodeChunk(tree.chunky[index]);
    chunk.numKeys = keys.length;
    for (var i = 0; i < keys.length; i++) {
      chunk.setKey(i, keys[i]);
    }
    for (var i = 0; i < children.length; i++) {
      chunk.setChild(i, children[i]);
    }
    print('Wrote $index: $this');
  }

  final IntMap tree;
  final int index;
  var children = <int>[];

  int getValue(int key) => getChild(key).getValue(key);
  void deleteValue(int key) {
    final child = getChild(key);
    child.deleteValue(key);
    if (child.underflows) {
      final childLeftSibling = getChildLeftSibling(key);
      final childRightSibling = getChildRightSibling(key);
      final left = childLeftSibling ?? child;
      final right = childLeftSibling != null ? child : childRightSibling;
      left.merge(right);
      deleteChild(right.numKeys == 0 ? key : right.firstLeafKey);
      if (left.overflows) {
        final sibling = left.split();
        insertChild(sibling.firstLeafKey, sibling);
        sibling.write();
      }
      left.write();
      // right.write();
      print('Free ${right.index}');
      write();
      if (tree._root.numKeys == 0) {
        tree._root = left;
      }
    }
  }

  void insertValue(int key, int value) {
    // debugger();
    final child = getChild(key);
    child.insertValue(key, value);
    if (child.overflows) {
      print('InternalNode: Child $child overflows.');
      final sibling = child.split();
      insertChild(sibling.firstLeafKey, sibling);
      sibling.write();
      child.write();
    }
    if (tree._root.overflows) {
      print('InternalNode: Root ${tree._root} overflows.');
      final sibling = split();
      final newRootChunk = tree.chunky.add();
      IntMapInternalNodeChunk(newRootChunk);
      final newRoot = InternalNode(tree, newRootChunk.index)
        ..keys.add(sibling.firstLeafKey)
        ..children.addAll([index, sibling.index]);
      tree._root = newRoot;
      sibling.write();
      newRoot.write();
    }
    write();
  }

  int get firstLeafKey => tree.readNode(children.first).firstLeafKey;

  void merge(Node sibling) {
    final node = sibling as InternalNode;
    keys.addAll([
      node.firstLeafKey,
      ...node.keys,
    ]);
    children.addAll(node.children);
  }

  Node split() {
    final from = numKeys ~/ 2 + 1;
    final to = numKeys;
    final siblingChunk = tree.chunky.add();
    final sibling = InternalNode(tree, siblingChunk.index)
      ..keys.addAll(keys.sublist(from, to))
      ..children.addAll(children.sublist(from, to + 1));
    keys.removeRange(from - 1, to);
    children.removeRange(from, to + 1);
    return sibling;
  }

  bool get overflows => children.length > _branchingFactor;
  bool get underflows => children.length < (_branchingFactor / 2).ceil();
  Node getChild(int key) {
    int loc = _binarySearch(keys, key);
    final childIndex = loc >= 0 ? loc + 1 : -loc - 1;
    return tree.readNode(children[childIndex]);
  }

  void deleteChild(int key) {
    int loc = _binarySearch(keys, key);
    if (loc >= 0) {
      keys.removeAt(loc);
      children.removeAt(loc + 1);
    }
  }

  void insertChild(int key, Node child) {
    final loc = _binarySearch(keys, key);
    final childIndex = loc >= 0 ? loc + 1 : -loc - 1;
    if (loc >= 0) {
      children[childIndex] = child.index;
    } else {
      keys.insert(childIndex, key);
      children.insert(childIndex + 1, child.index);
    }
  }

  Node getChildLeftSibling(int key) {
    final loc = _binarySearch(keys, key);
    final childIndex = loc >= 0 ? loc + 1 : -loc - 1;
    if (childIndex > 0) {
      return tree.readNode(children[childIndex - 1]);
    } else {
      return null;
    }
  }

  Node getChildRightSibling(int key) {
    final loc = _binarySearch(keys, key);
    final childIndex = loc >= 0 ? loc + 1 : -loc - 1;
    if (childIndex < numKeys) {
      return tree.readNode(children[childIndex + 1]);
    } else {
      return null;
    }
  }

  String toString() {
    final buffer = StringBuffer()..write('[');

    for (var i = 0; i < numKeys; i++) {
      buffer.write('child ${children[i]}, ${keys[i]}, ');
    }
    if (children.isNotEmpty) {
      buffer.write('child ${children.last}');
    }
    buffer.write(']');
    return buffer.toString();
  }
}

class LeafNode extends Node {
  LeafNode(this.tree, this.index) {
    // print('Chunk at index $index is ${tree.chunky.read(index)}');
    final chunk = tree.chunky[index].parse<IntMapLeafNodeChunk>();
    // debugger();
    for (var i = 0; i < chunk.numKeys; i++) {
      keys.add(chunk.getKey(i));
    }
    for (var i = 0; i < chunk.numValues; i++) {
      values.add(chunk.getValue(i));
    }
    print('Read $index:  $this');
  }

  void write() {
    final chunk = tree.chunky[index].parse<IntMapLeafNodeChunk>();
    chunk.numKeys = keys.length;
    for (var i = 0; i < keys.length; i++) {
      chunk.setKey(i, keys[i]);
    }
    for (var i = 0; i < values.length; i++) {
      chunk.setValue(i, values[i]);
    }
    print('Wrote $index: $this');
  }

  final IntMap tree;
  final int index;
  final values = [];
  LeafNode next;

  int getValue(int key) {
    final loc = _binarySearch(keys, key);
    return loc >= 0 ? values[loc] : null;
  }

  void deleteValue(int key) {
    final loc = _binarySearch(keys, key);
    if (loc >= 0) {
      keys.removeAt(loc);
      values.removeAt(loc);
    }
    write();
  }

  void insertValue(int key, int value) {
    final loc = _binarySearch(keys, key);
    final valueIndex = loc >= 0 ? loc : -loc - 1;
    if (loc >= 0) {
      values[valueIndex] = value;
    } else {
      keys.insert(valueIndex, key);
      values.insert(valueIndex, value);
    }
    if (tree._root.overflows) {
      print('LeafNode: Root ${tree._root} overflows.');
      LeafNode sibling = split();
      final newRootChunk = tree.chunky.addTyped(ChunkTypes.intMapInternalNode);
      final newRoot = InternalNode(tree, newRootChunk.index)
        ..keys.add(sibling.firstLeafKey)
        ..children.addAll([index, sibling.index]);
      sibling.write();
      newRoot.write();
      tree._root = newRoot;
    } else {
      print('LeafNode: Root ${tree._root} does not overflow.');
    }
    write();
  }

  int get firstLeafKey => keys.first;

  void merge(Node sibling) {
    final node = sibling as LeafNode;
    keys.addAll(node.keys);
    values.addAll(node.values);
    next = node.next;
  }

  Node split() {
    final from = (numKeys + 1) ~/ 2;
    final to = numKeys;
    final siblingChunk = tree.chunky.addTyped(ChunkTypes.intMapLeafNode);
    final sibling = LeafNode(tree, siblingChunk.index)
      ..keys.addAll(keys.sublist(from, to))
      ..values.addAll(values.sublist(from, to));
    keys.removeRange(from, to);
    values.removeRange(from, to);

    sibling.next = next;
    next = sibling;
    return sibling;
  }

  bool get overflows => values.length > _branchingFactor - 1;
  bool get underflows => values.length < _branchingFactor ~/ 2;

  String toString() {
    final buffer = StringBuffer()..write('{');

    buffer.write([
      for (var i = 0; i < numKeys; i++) '${keys[i]}: ${values[i]}',
    ].join(', '));
    buffer.write('}');
    return buffer.toString();
  }
}

int _binarySearch(List<int> list, int key) {
  int min = 0;
  int max = list.length;
  while (min < max) {
    int mid = min + ((max - min) >> 1);
    final currentItem = list[mid];
    final res = currentItem.compareTo(key);
    // print('Result of comparing $currentItem to $key is $res');
    if (res == 0) {
      return mid;
    } else if (res < 0) {
      min = mid + 1;
    } else {
      max = mid;
    }
  }
  // print('Binary search didnt find the value. min=$min max=$max');
  return -(min + 1);
}
