int _branchingFactor = 3;

class Tree<V> {
  Tree() {
    root = LeafNode(this);
  }

  Node<V> root;

  V find(int key) => root.getValue(key);
  void insert(int key, V value) => root.insertValue(key, value);
  void delete(int key) => root.deleteValue(key);
  String toString() => root.toString();
}

abstract class Node<V> {
  var keys = <int>[];

  int get numKeys => keys.length;
  V getValue(int key);
  void deleteValue(int key);
  void insertValue(int key, V value);
  int get firstLeafKey;
  void merge(Node<V> sibling);
  Node<V> split();
  bool get overflows;
  bool get underflows;
}

class InternalNode<V> extends Node<V> {
  InternalNode(this.tree);

  final Tree<V> tree;
  var children = <Node<V>>[];

  V getValue(int key) => getChild(key).getValue(key);
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
      print('Merging $left with $right.');
      left.merge(right);
      print('Merged. Right is now $right.');
      // deleteChild(right.firstLeafKey);
      deleteChild(right.numKeys == 0 ? key : right.firstLeafKey);
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

  int get firstLeafKey => children.first.firstLeafKey;
  void merge(Node sibling) {
    final node = sibling as InternalNode<V>;
    keys.addAll([
      node.firstLeafKey,
      ...node.keys,
    ]);
    children.addAll(node.children);
  }

  Node<V> split() {
    final from = numKeys ~/ 2 + 1;
    final to = numKeys;
    final sibling = InternalNode(tree)
      ..keys.addAll(keys.sublist(from, to))
      ..children.addAll(children.sublist(from, to + 1));
    keys.removeRange(from - 1, to);
    children.removeRange(from, to + 1);
    return sibling;
  }

  bool get overflows => children.length > _branchingFactor;
  bool get underflows => children.length < (_branchingFactor / 2).ceil();
  Node<V> getChild(int key) {
    int loc = _binarySearch(keys, key);
    final childIndex = loc >= 0 ? loc + 1 : -loc - 1;
    return children[childIndex];
  }

  void deleteChild(int key) {
    int loc = _binarySearch(keys, key);
    print('Deleting child for key $key at loc $loc. Keys are $keys and '
        'children are $children.');
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
}
