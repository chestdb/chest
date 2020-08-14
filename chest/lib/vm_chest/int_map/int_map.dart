import 'dart:math';

import 'package:chest/chunky/chunky.dart';

import 'chunks.dart';
import '../chunks.dart';
import '../chunk_manager/chunk_manager.dart';

class IntMap {
  IntMap(this.chunky) {
    final mainChunk = chunky.mainChunk;
    if (!mainChunk.hasDocTreeRoot) {
      final chunk = chunky.reserve();
      IntMapLeafNodeChunk(chunk);
      mainChunk.docTreeRoot = chunk.index;
    }
  }

  final Transaction chunky;

  Node get _root => readNode(chunky.mainChunk.docTreeRoot);
  set _root(Node newRoot) => chunky.mainChunk.docTreeRoot = newRoot.index;

  int operator [](int key) {
    assert(key != null);
    _root.getValue(key);
  }

  operator []=(int key, int value) {
    assert(key != null);
    assert(value != null);

    _root.insertValue(key, value);
    if (_root.overflows) {
      final sibling = _root.split();
      final newRootChunk = IntMapInternalNodeChunk(chunky.reserve())
        ..keys.add(sibling.firstLeafKey)
        ..children.addAll([_root.index, sibling.index]);
      _root = InternalNode(this, newRootChunk);
    }
  }

  int random([Random random]) => _root.getRandomValue(random);
  int remove(int key) => _root.removeValue(key);
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
  int getRandomValue(Random random);
  void insertValue(int key, int value);
  int removeValue(int key);

  void merge(Node sibling);
  Node split();
}

class InternalNode extends Node {
  InternalNode(this.tree, this._chunk);

  final IntMap tree;
  final IntMapInternalNodeChunk _chunk;

  int get index => _chunk.index;
  bool get hasKeys => _chunk.keys.length > 0;
  int get firstLeafKey => tree.readNode(_chunk.children.first).firstLeafKey;
  bool get overflows =>
      _chunk.children.length > IntMapInternalNodeChunk.maxChildren;
  bool get underflows =>
      _chunk.children.length < (IntMapInternalNodeChunk.maxChildren / 2).ceil();

  int getValue(int key) => getChild(key).getValue(key);

  int getRandomValue(Random random) =>
      tree.readNode(_chunk.children.random(random)).getRandomValue(random);

  void insertValue(int key, int value) {
    final child = getChild(key);
    child.insertValue(key, value);
    if (child.overflows) {
      final sibling = child.split();
      insertChild(sibling.firstLeafKey, sibling);
    }
  }

  int removeValue(int key) {
    final child = getChild(key);
    final removedValue = child.removeValue(key);
    if (child.underflows) {
      final childLeftSibling = getChildLeftSibling(key);
      final childRightSibling = getChildRightSibling(key);
      final left = childLeftSibling ?? child;
      final right = childLeftSibling != null ? child : childRightSibling;
      final firstRightKey = right.firstLeafKey;
      left.merge(right);
      removeChild(firstRightKey);
      if (left.overflows) {
        final sibling = left.split();
        insertChild(sibling.firstLeafKey, sibling);
      }
      tree.chunky.free(right.index);
      if (!tree._root.hasKeys) {
        tree.chunky.free(tree._root.index);
        tree._root = left;
      }
    }
    return removedValue;
  }

  void merge(Node sibling) {
    final node = sibling as InternalNode;
    _chunk
      ..keys.addAll([node.firstLeafKey, ...node._chunk.keys])
      ..children.addAll(node._chunk.children);
  }

  Node split() {
    final splitIndex = _chunk.keys.length ~/ 2 + 1;
    final siblingChunk = IntMapInternalNodeChunk(tree.chunky.reserve())
      ..keys.addAll(_chunk.keys.skip(splitIndex))
      ..children.addAll(_chunk.children.skip(splitIndex));
    _chunk
      ..keys.removeRange(splitIndex - 1, _chunk.keys.length)
      ..children.removeRange(splitIndex, _chunk.children.length);
    return InternalNode(tree, siblingChunk);
  }

  SearchResult _searchForKey(int key) => _chunk.keys.find(key);

  Node getChild(int key) {
    final result = _searchForKey(key);
    final index = result.wasFound ? result.index + 1 : result.insertionIndex;
    return tree.readNode(_chunk.children[index]);
  }

  void removeChild(int key) {
    final result = _searchForKey(key);
    if (result.wasFound) {
      _chunk..keys.removeAt(result.index)..children.removeAt(result.index + 1);
    }
  }

  void insertChild(int key, Node child) {
    final result = _searchForKey(key);
    if (result.wasFound) {
      _chunk.children[result.index] = child.index;
    } else {
      _chunk
        ..keys.insert(result.insertionIndex, key)
        ..children.insert(result.insertionIndex + 1, child.index);
    }
  }

  Node getChildLeftSibling(int key) {
    final childIndex = _searchForKey(key).insertionIndex;
    if (childIndex > 0) {
      return tree.readNode(_chunk.children[childIndex - 1]);
    } else {
      return null;
    }
  }

  Node getChildRightSibling(int key) {
    final childIndex = _searchForKey(key).insertionIndex;
    if (childIndex < _chunk.keys.length) {
      return tree.readNode(_chunk.children[childIndex + 1]);
    } else {
      return null;
    }
  }

  String toString() => _chunk.toString();
}

class LeafNode extends Node {
  LeafNode(this.tree, this._chunk);

  final IntMap tree;
  final IntMapLeafNodeChunk _chunk;

  int get index => _chunk.index;
  bool get hasKeys => _chunk.keys.length > 0;
  int get firstLeafKey => _chunk.keys.first;
  bool get overflows => _chunk.keys.length > IntMapLeafNodeChunk.maxKeys - 1;
  bool get underflows => _chunk.keys.length < IntMapLeafNodeChunk.maxKeys ~/ 2;

  // Returns the index of the child that can possibly contains the given key.
  // Doesn't guarantee that the child actually contains that key.
  SearchResult _searchForKey(int key) => _chunk.keys.find(key);

  int getValue(int key) {
    final result = _searchForKey(key);
    return result.wasFound ? _chunk.values[result.index] : null;
  }

  int getRandomValue(Random random) => _chunk.values.random(random);

  void insertValue(int key, int value) {
    final result = _searchForKey(key);
    if (result.wasFound) {
      _chunk.values[result.index] = value;
    } else {
      _chunk
        ..keys.insert(result.insertionIndex, key)
        ..values.insert(result.insertionIndex, value);
    }
  }

  int removeValue(int key) {
    final result = _searchForKey(key);
    if (result.wasFound) {
      _chunk.keys.removeAt(result.index);
      return _chunk.values.removeAt(result.index);
    }
    return null;
  }

  void merge(Node sibling) {
    final node = sibling as LeafNode;
    _chunk
      ..keys.addAll(node._chunk.keys)
      ..values.addAll(node._chunk.values)
      ..nextLeaf = node._chunk.nextLeaf;
  }

  Node split() {
    final from = (_chunk.keys.length + 1) ~/ 2;
    final siblingChunk = IntMapLeafNodeChunk(tree.chunky.reserve())
      ..keys.addAll(_chunk.keys.skip(from))
      ..values.addAll(_chunk.values.skip(from))
      ..nextLeaf = _chunk.nextLeaf;
    _chunk
      ..keys.removeRange(from, _chunk.keys.length)
      ..values.removeRange(from, _chunk.values.length)
      ..nextLeaf = siblingChunk.chunk.index;
    return LeafNode(tree, siblingChunk);
  }

  String toString() => _chunk.toString();
}
