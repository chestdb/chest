import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';

// Note: In this document, you'll see several memory layout ascii arts. They may
// have several abstraction layers for more clarity. The bottom line contains
// the actual size of the data, which is either a number of bytes, "var" to
// indicate a variable length, or "fill" to indicate the data fills the rest.

/// The first byte of all chunks contains a value indicating their type.
///
/// # Layout
///
/// ```
/// | n  | rest                                                                |
/// | 1B | fill                                                                |
/// ```
extension TypedChunk on Chunk {
  int getType() => getUint8(0);
  void setType(int type) => setUint8(0, type);
}

/// A chunk that can store multiple documents.
///
/// Stores at least one document. Abstracts from the order of the documents.
///
/// # Layout
///
/// ```
/// | 0  | num | header 1    | header 2    | padding         | data 2 | data 1 |
/// |    |     | id | offset | id | offset |                 |        |        |
/// | 1B | 2B  | 8B | 2B     | 8B | 2B     | fill            | var    | var    |
/// ```
extension BucketChunk on Chunk {
  static const type = 0;

  int _getNumObjects() => getUint16(1);
  void _setNumObjects(int n) => setUint16(1, n);

  int _getDocId(int index) => getInt64(3 + 10 * index);
  void _setDocId(int index, int docId) => setInt64(3 + 10 * index, docId);

  int _getDocOffset(int index) => getUint16(11 + 10 * index);
  void _setDocOffset(int index, int offset) =>
      setUint16(11 + 10 * index, offset);

  int _getDocEnd(int index) => (index == _getNumObjects() - 1)
      ? chunkSize
      : getUint16(11 + 10 * (index));

  int get _freeBytes {
    final numObjects = _getNumObjects();
    final headerEnd = 3 + 10 * numObjects;
    final dataBegin = _getDocOffset(numObjects - 1);
    return dataBegin - headerEnd;
  }

  Uint8List getDocView(int docId) {
    final numObjects = _getNumObjects();

    var index = 0;
    while (_getDocId(index) != docId) {
      index++;
      if (index >= numObjects) {
        // This bucket doesn't contain the document with the given id.
        return null;
      }
    }

    final start = _getDocOffset(index);
    final end = _getDocEnd(index);
    return Uint8List.view(bytes.buffer, start, end - start);
  }

  bool addDoc(int docId, List<int> docBytes) {
    if (_freeBytes < docBytes.length + 10) {
      return false;
    }
    final index = _getNumObjects();
    final dataEnd = index == 0 ? chunkSize : _getDocOffset(index - 1);
    final dataStart = dataEnd - docBytes.length;

    for (var i = 0; i < docBytes.length; i++) {
      setUint8(dataStart + i, docBytes[i]);
    }
    _setDocId(index, docId);
    _setDocOffset(index, dataStart);
    _setNumObjects(index + 1);

    return true;
  }

  bool removeDoc(int docId) {
    // TODO: implement
    throw UnimplementedError();
  }
}

/// A chunk that stores part of a document that is so large that it doesn't fit
/// into a single chunk.
///
/// The next chunk id points to either another [BigDocChunk] which is completely
/// filled with data or to a [BigDocEndChunk], which is only partially filled
/// with data and indicates the end of the document bytes.
///
/// # Layout
///
/// ```
/// | 1  | next chunk id | data                                                |
/// | 1B | 8B            | fill                                                |
/// ```
extension BigDocChunk on Chunk {
  static const type = 1;

  int getNextChunkId() => getUint16(1);
  void setNextChunkId(int id) => setUint16(1, id);

  Uint8List getDataView() => Uint8List.view(bytes.buffer, 9, chunkSize - 9);
  void setData(Uint8List data) {
    assert(data.length == chunkSize - 9);
    for (var i = 0; i < data.length; i++) {
      setUint8(9 + i, data[i]);
    }
  }
}

/// A chunk that marks the end of a chain of [BigDocChunk]s.
///
/// # Layout
///
/// ```
/// | 2  | length | pad | data                  | padding                      |
/// | 1B | 2B     | 6B  | var                   | fill                         |
/// ```
extension BigDocEndChunk on Chunk {
  static const type = 2;

  int _getLength() => getUint16(1);
  void _setLength(int id) => setUint16(1, id);

  void getDataView() => Uint8List.view(buffer, 9, _getLength());
}
