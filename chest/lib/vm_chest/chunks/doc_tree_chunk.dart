import 'dart:developer';

import 'package:chest/chunky/chunky.dart';

import 'chunks.dart';
import 'main_chunk.dart';
import 'utils.dart';

/// A chunk that is an internal node in the doc tree.
///
/// The keys of the node are the doc ids, the children are the pointed to by the
/// chunk id. It always contains one more chunk id than doc ids.
///
/// # Layout
///
/// ```
/// | type | num keys | chunk id | doc id | chunk id | doc id | ... | chunk id |
/// | 1B   | 2B       | 8B       | 8B     | 8B       | 8B     |     | 8B       |
/// ```
/// Note it contains space for one more chunk id than doc ids.
class DocTreeInternalNodeChunk extends ChunkWrapper {
  static const maxChildren = (chunkSize - _headerLength) ~/ _entryLength;

  DocTreeInternalNodeChunk(this.chunk) {
    chunk.type = ChunkTypes.docTreeInternalNode;
  }

  final Chunk chunk;

  int get numKeys => chunk.getUint16(1);
  set numKeys(int numKeys) => chunk.setUint16(1, numKeys);
  int get numChildren => numKeys == 0 ? 0 : numKeys + 1;

  static const _headerLength = 3;
  static const _entryLength = chunkIdLength + docIdLength;

  int getChild(int index) =>
      chunk.getChunkId(_headerLength + _entryLength * index);
  void setChild(int index, int chunkId) =>
      chunk.setChunkId(_headerLength + _entryLength * index, chunkId);

  int getKey(int index) =>
      chunk.getDocId(_headerLength + chunkIdLength + _entryLength * index);
  void setKey(int index, int docId) => chunk.setDocId(
      _headerLength + chunkIdLength + _entryLength * index, docId);
}

/// A chunk that is a leaf node in the doc tree.
///
/// The keys are doc ids, the values are chunk ids pointing to [BucketChunk]s or
/// [BigDocChunk]s.
///
/// # Layout
///
/// ```
/// | type | num keys | chunk id | doc id | chunk id | ...  | doc id | next id |
/// | 1B   | 2B       | 8B       | 8B     | 8B       |      | 8B     | 8B      |
/// ```
class DocTreeLeafNodeChunk extends DocTreeInternalNodeChunk {
  static const maxChildren = DocTreeInternalNodeChunk.maxChildren - 1;

  DocTreeLeafNodeChunk(Chunk chunk) : super(chunk) {
    chunk.type = ChunkTypes.docTreeLeafNode;
  }

  int get numChildren => numKeys;

  static const _nextLeafIdOffset = DocTreeInternalNodeChunk._headerLength +
      DocTreeInternalNodeChunk._entryLength *
          (DocTreeInternalNodeChunk.maxChildren - 1);
  int get nextLeafId => chunk.getChunkId(_nextLeafIdOffset);
  set nextLeafId(int id) => chunk.setChunkId(_nextLeafIdOffset, id);
}

int _branchingFactor = 3;

class DocTree {
  DocTree(this.chunky) {
    final mainChunk = MainChunk(chunky.read(0));
    var rootIndex = mainChunk.docTreeRoot;
    if (rootIndex == 0) {
      final chunk = DocTreeLeafNodeChunk(Chunk());
      rootIndex = chunky.add(chunk);
      print('Tree added at $rootIndex');
      mainChunk.docTreeRoot = chunky.add(Chunk());
    }
    root = LeafNode(this, rootIndex);
    print('Root is $root');
  }

  final ChunkyTransaction chunky;
  Node root;

  int find(int key) => root.getValue(key);
  void insert(int key, int value) => root.insertValue(key, value);
  void delete(int key) => root.deleteValue(key);
  String toString() => root.toString();
}

extension on ChunkyTransaction {
  Node readNode(DocTree tree, int index) {
    final chunk = read(index).parse();
    if (chunk is DocTreeLeafNodeChunk) {
      return LeafNode(tree, index);
    } else if (chunk is DocTreeInternalNodeChunk) {
      return InternalNode(tree, index);
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
    final chunk = tree.chunky.read(index).parse<DocTreeInternalNodeChunk>();
    for (var i = 0; i < chunk.numKeys; i++) {
      keys.add(chunk.getKey(i));
    }
    for (var i = 0; i < chunk.numChildren; i++) {
      children.add(chunk.getChild(i));
    }
    print('Read $index: $this');
  }

  void write() {
    final chunk = DocTreeInternalNodeChunk(Chunk());
    chunk.numKeys = keys.length;
    for (var i = 0; i < keys.length; i++) {
      chunk.setKey(i, keys[i]);
    }
    for (var i = 0; i < children.length; i++) {
      chunk.setChild(i, children[i]);
    }
    tree.chunky.write(index, chunk);
    print('Wrote $index: $this');
  }

  final DocTree tree;
  final int index;
  var children = <int>[];

  int getValue(int key) => getChild(key).getValue(key);
  void deleteValue(int key) {
    final child = getChild(key);
    child.deleteValue(key);
    print('Deleted $key from child.');
    if (child.underflows) {
      print('Child underflows.');
      final childLeftSibling = getChildLeftSibling(key);
      final childRightSibling = getChildRightSibling(key);
      final left = childLeftSibling ?? child;
      final right = childLeftSibling != null ? child : childRightSibling;
      left.merge(right);
      deleteChild(right.firstLeafKey);
      if (left.overflows) {
        final sibling = left.split();
        insertChild(sibling.firstLeafKey, sibling);
      }
      left.write();
      right.write();
      write();
      if (tree.root.numKeys == 0) {
        tree.root = left;
      }
    }
  }

  void insertValue(int key, int value) {
    // debugger();
    final child = getChild(key);
    child.insertValue(key, value);
    if (child.overflows) {
      final sibling = child.split();
      insertChild(sibling.firstLeafKey, sibling);
    }
    if (tree.root.overflows) {
      final sibling = split();
      final rootIndex = tree.chunky.add(Chunk());
      final newRoot = InternalNode(tree, rootIndex)
        ..keys.add(sibling.firstLeafKey)
        ..children.addAll([index, sibling.index]);
      tree.root = newRoot;
    }
  }

  int get firstLeafKey =>
      tree.chunky.readNode(tree, children.first).firstLeafKey;

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
    final siblingIndex = tree.chunky.add(Chunk());
    final sibling = InternalNode(tree, siblingIndex)
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
    return tree.chunky.readNode(tree, children[childIndex]);
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
      return tree.chunky.readNode(tree, children[childIndex - 1]);
    } else {
      return null;
    }
  }

  Node getChildRightSibling(int key) {
    final loc = _binarySearch(keys, key);
    final childIndex = loc >= 0 ? loc + 1 : -loc - 1;
    if (childIndex < numKeys) {
      return tree.chunky.readNode(tree, children[childIndex + 1]);
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
    final chunk = tree.chunky.read(index).parse<DocTreeLeafNodeChunk>();
    // debugger();
    for (var i = 0; i < chunk.numKeys; i++) {
      keys.add(chunk.getKey(i));
    }
    for (var i = 0; i < chunk.numChildren; i++) {
      values.add(chunk.getChild(i));
    }
    print('Read $index: $this');
  }

  void write() {
    final chunk = DocTreeLeafNodeChunk(Chunk());
    chunk.numKeys = keys.length;
    for (var i = 0; i < keys.length; i++) {
      chunk.setKey(i, keys[i]);
    }
    for (var i = 0; i < values.length; i++) {
      chunk.setChild(i, values[i]);
    }
    tree.chunky.write(index, chunk);
    print('Wrote $index: $this');
  }

  final DocTree tree;
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
    if (tree.root.overflows) {
      print('Node is overflowing.');
      LeafNode sibling = split();
      print('Split into $this and $sibling.');
      final newRootIndex = tree.chunky.add(DocTreeInternalNodeChunk(Chunk()));
      print('New root is at $newRootIndex.');
      print('The key is ${sibling.firstLeafKey}.');
      print('The children are $index and ${sibling.index}.');
      final newRoot = InternalNode(tree, newRootIndex)
        ..keys.add(sibling.firstLeafKey)
        ..children.addAll([index, sibling.index]);
      sibling.write();
      newRoot.write();
      tree.root = newRoot;
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
    final siblingChunk = DocTreeLeafNodeChunk(Chunk());
    final siblingIndex = tree.chunky.add(siblingChunk);
    final sibling = LeafNode(tree, siblingIndex)
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
