import 'package:chest/chunky/chunky.dart';

import 'chunk_manager.dart';
import 'chunks/int_map.dart';
import 'chunks/chunks.dart';

class IntMap {
  IntMap(this.chunky) {
    final mainChunk = chunky.mainChunk;
    if (mainChunk.docTreeRoot == 0) {
      final chunk = chunky.reserve();
      IntMapLeafNodeChunk(chunk);
      mainChunk.docTreeRoot = chunk.index;
    }
  }

  final Transaction chunky;

  Node get _root => readNode(chunky.mainChunk.docTreeRoot);
  set _root(Node newRoot) => chunky.mainChunk.docTreeRoot = newRoot.index;

  int find(int key) => _root.getValue(key);
  void insert(int key, int value) => _root.insertValue(key, value);
  void remove(int key) => _root.removeValue(key);
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
  void insertValue(int key, int value);
  void removeValue(int key);

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
  bool get overflows => chunk.numChildren > IntMapInternalNodeChunk.maxChildren;
  bool get underflows =>
      chunk.numChildren < (IntMapInternalNodeChunk.maxChildren / 2).ceil();

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
      final newRootChunk = IntMapInternalNodeChunk(tree.chunky.reserve())
        ..initialize(
          keys: [sibling.firstLeafKey],
          children: [index, sibling.index],
        );
      final newRoot = InternalNode(tree, newRootChunk);
      tree._root = newRoot;
    }
  }

  void removeValue(int key) {
    final child = getChild(key);
    child.removeValue(key);
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
    final siblingChunk = IntMapInternalNodeChunk(tree.chunky.reserve())
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

  void removeChild(int key) {
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
  bool get overflows => chunk.numEntries > IntMapLeafNodeChunk.maxKeys - 1;
  bool get underflows => chunk.numEntries < IntMapLeafNodeChunk.maxKeys ~/ 2;

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
      final newRootChunk = IntMapInternalNodeChunk(tree.chunky.reserve())
        ..keys.add(sibling.firstLeafKey)
        ..numKeys = 0
        ..children[0] = index
        ..children.add(sibling.index)
        ..numKeys = 1;
      tree._root = InternalNode(tree, newRootChunk);
    }
  }

  void removeValue(int key) {
    final result = _searchForKey(key);
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
    final siblingChunk = IntMapLeafNodeChunk(tree.chunky.reserve())
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
