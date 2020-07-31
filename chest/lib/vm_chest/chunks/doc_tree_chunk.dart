import 'package:chest/chunky/chunky.dart';

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
class DocTreeInternalNodeChunk {
  static const maxChildren = (chunkSize - _headerLength) ~/ _entryLength;

  const DocTreeInternalNodeChunk(this.chunk);

  final Chunk chunk;

  int get numKeys => chunk.getUint16(1);
  set numKeys(int numKeys) => chunk.setUint16(1, numKeys);
  int get numChildren => numKeys + 1;

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
/// | type | num keys | next leaf id | doc id | chunk id | ...      | chunk id |
/// | 1B   | 2B       | 8B           | 8B     | 8B       |          | 8B       |
/// ```
class DocTreeLeafNodeChunk {
  const DocTreeLeafNodeChunk(this.chunk);

  final Chunk chunk;

  int get numKeys => chunk.getUint16(1);
  set numKeys(int numKeys) => chunk.setUint16(1, numKeys);

  void getNextLeafId() => chunk.getChunkId(3);
  void setNextLeafId(int nextLeafId) => chunk.setChunkId(3, nextLeafId);

  static const _headerLength = 3 + chunkIdLength;
  static const _entryLength = chunkIdLength + docIdLength;

  int getKey(int index) => chunk.getDocId(_headerLength + _entryLength * index);
  void setKey(int index, int docId) => chunk.setDocId(
      _headerLength + chunkIdLength + _entryLength * index, docId);

  int getChild(int index) =>
      chunk.getChunkId(_headerLength + chunkIdLength + _entryLength * index);
  void setChild(int index, int chunkId) => chunk.setChunkId(
      _headerLength + chunkIdLength + _entryLength * index, chunkId);
}

/*class DocTree {
  DocTree(this.chunky) {
    root = LeafNode(this);
  }

  final Chunky chunky;
  Node root;

  int find(int docId) => root.getValueByKey(docId);
  void insert(int key, int value) => root.insertValueForKey(key, value);
  void remove(int key) => root.removeValueByKey(key);
  String toString() => root.toString();
}

abstract class Node<V> {
  int get numKeys;
  bool get overflows;
  bool get underflows;
  int get firstLeafKey;

  int getKey(int index);
  void setKey(int index, int key);
  int getChild(int index);
  void setChild(int index, int child);

  void merge(Node<V> sibling);
  Node<V> split();

  V getValueByKey(int key);
  void insertValueForKey(int key, V value);
  void removeValueByKey(int key);
}

class _InternalNode extends Node {
  _InternalNode(this.tree, Chunk chunk)
      : this.chunk = DocTreeInternalNodeChunk(chunk);

  final DocTree tree;
  final DocTreeInternalNodeChunk chunk;

  int get numKeys => chunk.numKeys;
  int get numChildren => chunk.numChildren;
  bool get overflows => numChildren > DocTreeInternalNodeChunk.maxChildren;
  bool get underflows =>
      numChildren < (DocTreeInternalNodeChunk.maxChildren / 2).ceil();
  int get firstLeafKey {
    final child = Chunk();
    tree.chunky.readInto(chunk.getChild(0), child);
    return _InternalNode(tree, child).firstLeafKey;
  }

  int getKey(int index) => chunk.getKey(index);
  void setKey(int index, int key) => chunk.setKey(index, key);
  int getChild(int index) => chunk.getChild(index);
  void setChild(int index, int child) => chunk.setChild(index, child);

  void merge(Node sibling) {
    final node = sibling as _InternalNode;
    final filled = numKeys;

    for (var i = 0; i < node.numKeys; i++) {
      chunk.setKey(filled + i, i == 0 ? node.firstLeafKey : node.getKey(i - 1));
    }
    for (var i = 0; i < node.numChildren; i++) {
      chunk.setChild(
          filled + i, i == 0 ? node.firstLeafKey : node.getChild(i - 1));
    }
  }

  _InternalNode split() {
    final from = numKeys ~/ 2 + 1;
    final to = numKeys;
    final sibling = _InternalNode(tree, Chunk());
      ..keys.addAll(keys.sublist(from, to))
      ..children.addAll(children.sublist(from, to + 1));
    keys.removeRange(from - 1, to);
    children.removeRange(from, to + 1);
    return sibling;
  }
}

class InternalNode<V> extends Node<V> {
  V getValue(int key) => getChild(key).getValue(key);
  void deleteValue(int key) {
    // TODO:
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
      if (tree.root.numKeys == 0) {
        tree.root = left;
      }
    }
  }

  void insertValue(int key, V value) {
    final child = getChild(key);
    child.insertValue(key, value);
    if (child.overflows) {
      final sibling = child.split();
      insertChild(sibling.firstLeafKey, sibling);
    }
    if (tree.root.overflows) {
      final sibling = split();
      final newRoot = InternalNode(tree)
        ..keys.add(sibling.firstLeafKey)
        ..children.addAll([this, sibling]);
      tree.root = newRoot;
    }
  }

  Node<V> getChild(int key) {
    int loc = _binarySearch(keys, key);
    final childIndex = loc >= 0 ? loc + 1 : -loc - 1;
    return children[childIndex];
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
      children[childIndex] = child;
    } else {
      keys.insert(childIndex, key);
      children.insert(childIndex + 1, child);
    }
  }

  Node getChildLeftSibling(int key) {
    final loc = _binarySearch(keys, key);
    final childIndex = loc >= 0 ? loc + 1 : -loc - 1;
    if (childIndex > 0) {
      return children[childIndex - 1];
    } else {
      return null;
    }
  }

  Node getChildRightSibling(int key) {
    final loc = _binarySearch(keys, key);
    final childIndex = loc >= 0 ? loc + 1 : -loc - 1;
    if (childIndex < numKeys) {
      return children[childIndex + 1];
    } else {
      return null;
    }
  }

  String toString() {
    final buffer = StringBuffer()..write('[');

    for (var i = 0; i < numKeys; i++) {
      buffer.write('${children[i]}, ${keys[i]}, ');
    }
    buffer.write('${children[numKeys]}]');
    return buffer.toString();
  }
}

class LeafNode<V> extends Node<V> {
  LeafNode(this.tree);

  final Tree<V> tree;
  final values = <V>[];
  LeafNode<V> next;

  V getValue(int key) {
    final loc = _binarySearch(keys, key);
    return loc >= 0 ? values[loc] : null;
  }

  void deleteValue(int key) {
    final loc = _binarySearch(keys, key);
    if (loc >= 0) {
      keys.removeAt(loc);
      values.removeAt(loc);
    }
  }

  void insertValue(int key, V value) {
    final loc = _binarySearch(keys, key);
    final valueIndex = loc >= 0 ? loc : -loc - 1;
    if (loc >= 0) {
      values[valueIndex] = value;
    } else {
      keys.insert(valueIndex, key);
      values.insert(valueIndex, value);
    }
    if (tree.root.overflows) {
      Node sibling = split();
      final newRoot = InternalNode(tree)
        ..keys.add(sibling.firstLeafKey)
        ..children.addAll([this, sibling]);
      tree.root = newRoot;
    }
  }

  int get firstLeafKey => keys.first;

  void merge(Node<V> sibling) {
    final node = sibling as LeafNode<V>;
    keys.addAll(node.keys);
    values.addAll(node.values);
    next = node.next;
  }

  Node<V> split() {
    final from = (numKeys + 1) ~/ 2;
    final to = numKeys;
    final sibling = LeafNode(tree)
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
    final buffer = StringBuffer()..write('[');

    for (var i = 0; i < numKeys; i++) {
      buffer.write('${keys[i]}: ${values[i]},');
    }
    buffer.write(']');
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
}*/
