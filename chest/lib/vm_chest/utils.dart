import 'dart:collection';
import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';
import 'package:meta/meta.dart';

/// The first byte of all chunks contains a value indicating their type.
///
/// # Layout
///
/// ```
/// | type | rest                                                              |
/// | 1B   | fill                                                              |
/// ```
extension TypedChunk on Chunk {
  int get type => getUint8(0);
  set type(int type) => setUint8(0, type);
}

extension ChunkUtils on Chunk {
  // The index of a chunk.
  int getChunkIndex(int offset) => getInt64(offset);
  void setChunkIndex(int offset, int index) => setInt64(offset, index);

  // The id of a document.
  int getDocId(int offset) => getInt64(offset);
  void setDocId(int offset, int docId) => setInt64(offset, docId);

  // A reference to an offset inside a chunk.
  int getOffset(int offset) => getUint16(offset);
  void setOffset(int offset, int offsetValue) => setUint16(offset, offsetValue);

  // Writes a copy of the given bytes to the offset.
  void writeCopy(Uint8List bytes, int offset) {
    for (var i = 0; i < bytes.length; i++) {
      final byte = bytes[i];
      setUint8(offset + i, byte);
    }
  }

  void clear([int start = 0, int end = chunkSize]) {
    for (var i = start; i < end; i++) {
      setUint8(i, 0);
    }
  }
}

const typeLength = 1;
const chunkIndexLength = 8;
const docIdLength = 8;
const offsetLength = 2;

abstract class ChunkWrapper {
  ChunkWrapper(int type) {
    chunk.type = type;
  }

  TransactionChunk get chunk;

  String toString() => chunk.toString();
}

extension SearchableListWithIntKeys<T> on List<T> {
  SearchResult<T> find(int key, [int Function(T) toKey]) {
    assert(toKey != null || T == int);
    int min = 0;
    int max = length;
    while (min < max) {
      final mid = min + ((max - min) >> 1);
      final currentItem = (toKey == null ? this[mid] as int : toKey(this[mid]));
      final res = currentItem.compareTo(key);
      // print('Result of comparing $currentItem to $key is $res');
      if (res == 0) {
        return SearchResult._(this, true, mid);
      } else if (res < 0) {
        min = mid + 1;
      } else {
        max = mid;
      }
    }
    // print('Binary search didnt find the value. min=$min max=$max');
    return SearchResult._(this, false, min);
  }

  void insertSorted(T element, [int Function(T) toKey]) {
    assert(toKey != null || T == int);
    int actualToKey(T element) {
      return (T == int) ? element : toKey(element);
    }

    final result = find(actualToKey(element), toKey);
    insert(result.insertionIndex, element);
  }
}

class SearchResult<T> {
  SearchResult._(this._backingList, this.wasFound, this._index);

  final List<T> _backingList;
  final bool wasFound;
  bool get wasNotFound => !wasFound;

  final int _index;

  int get index {
    assert(wasFound);
    return _index;
  }

  bool get isFirst => index == 0;
  bool get isLast => index == _backingList.length - 1;

  T get item => _backingList[index];
  T get nextItem => isLast ? null : _backingList[index + 1];
  T get previousItem => isFirst ? null : _backingList[index - 1];

  // The index where the key would be inserted.
  int get insertionIndex => wasFound ? _index + 1 : _index;
}

class BackedList<T> with ListMixin<T> {
  BackedList({
    @required this.setLength,
    @required this.getLength,
    @required this.setItem,
    @required this.getItem,
  });

  final void Function(int) setLength;
  final int Function() getLength;
  final void Function(int, T) setItem;
  final T Function(int) getItem;

  @override
  set length(int value) => setLength(value);
  @override
  int get length => getLength();

  @override
  void operator []=(int index, T value) => setItem(index, value);
  @override
  operator [](int index) => getItem(index);
}

extension FancyList<T> on List<T> {
  T get second => this[1];
  set second(T value) => this[1] = value;
}
