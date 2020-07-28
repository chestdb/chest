import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';

import 'utils.dart';

/// A chunk that can store multiple documents.
///
/// Stores at least one document. Abstracts from the order of the documents.
///
/// # Layout
///
/// ```
/// | 1  | num | header 1    | header 2    | padding         | data 2 | data 1 |
/// |    |     | id | offset | id | offset |                 |        |        |
/// | 1B | 2B  | 8B | 2B     | 8B | 2B     | fill            | var    | var    |
/// ```
extension BucketChunk on Chunk {
  static const type = 1;

  int _getNumObjects() => getUint16(1);
  void _setNumObjects(int n) => setUint16(1, n);

  int _getDocIdByIndex(int index) => getDocId(3 + 10 * index);
  void _setDocIdByIndex(int index, int docId) =>
      setDocId(3 + 10 * index, docId);

  int _getDocOffset(int index) => getOffset(11 + 10 * index);
  void _setDocOffset(int index, int offset) =>
      setOffset(11 + 10 * index, offset);

  int _getDocEnd(int index) => (index == _getNumObjects() - 1)
      ? chunkSize
      : getOffset(11 + 10 * (index));

  int get _freeBytes {
    final numObjects = _getNumObjects();
    final headerEnd = 3 + 10 * numObjects;
    final dataBegin = _getDocOffset(numObjects - 1);
    return dataBegin - headerEnd;
  }

  Uint8List getDocView(int docId) {
    final numObjects = _getNumObjects();

    var index = 0;
    while (_getDocIdByIndex(index) != docId) {
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

    writeCopy(docBytes, dataStart);
    _setDocIdByIndex(index, docId);
    _setDocOffset(index, dataStart);
    _setNumObjects(index + 1);

    return true;
  }

  bool removeDoc(int docId) {
    // TODO: implement
    throw UnimplementedError();
  }
}
