import 'dart:math';
import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';
import 'package:meta/meta.dart';

import 'chunks.dart';
import 'utils.dart';

/// A chunk that can store multiple documents.
///
/// Stores at least one document. Abstracts from the order of the documents.
///
/// # Layout
///
/// ```
/// | type | num | header 1    | header 2    | padding       | data 2 | data 1 |
/// |      |     | id | offset | id | offset |               |        |        |
/// | 1B   | 2B  | 8B | 2B     | 8B | 2B     | fill          | var    | var    |
/// ```
class BucketChunk extends ChunkWrapper {
  final Chunk chunk;

  BucketChunk(this.chunk) {
    chunk.type = ChunkTypes.bucket;
  }

  int get _numDocs => getUint16(1);
  set _numDocs(int value) => setUint16(1, value);

  static const _headerEntryLength = docIdLength + offsetLength;

  int _getDocId(int index) => getDocId(3 + _headerEntryLength * index);
  void _setDocId(int index, int id) =>
      setDocId(3 + _headerEntryLength * index, id);

  int _getOffset(int index) => getOffset(11 + _headerEntryLength * index);
  void _setOffset(int index, int offset) =>
      setOffset(11 + _headerEntryLength * index, offset);

  int _getIndexOfId(int docId) => binarySearch(_numDocs, _getDocId, docId);
  int _getOffsetOfId(int docId) => _getOffset(_getIndexOfId(docId));

  bool contains(int docId) => _getIndexOfId(docId) != null;
  bool get isEmpty => _numDocs == 0;
  bool get isNotEmpty => _numDocs > 0;

  int get _freeSpaceStart => 3 + _headerEntryLength * _numDocs;
  int get _freeSpaceEnd => isEmpty ? chunkSize : _getOffset(_numDocs - 1);
  int get _freeSpace => _freeSpaceEnd - _freeSpaceStart;
  bool doesFit(int length) => _freeSpace >= _headerEntryLength + length;

  Uint8List get(int docId) {
    final index = _getIndexOfId(docId);
    if (index == null) {
      return null;
    }
    final dataStart = _getOffset(index);
    final dataEnd = (index == _numDocs - 1) ? chunkSize : _getOffset(index + 1);
    final length = dataEnd - dataStart;
    final bytes = Uint8List(length);
    getBytes(dataStart, length);
    return bytes;
  }

  void add(int docId, List<int> docBytes) {
    assert(!contains(docId),
        'This chunk already contains a document with id $docId.');
    assert(doesFit(docBytes.length), 'Not enough space.');

    final headerOffset = _freeSpaceStart;
    final dataOffset = _freeSpaceEnd - docBytes.length;
    setDocId(headerOffset, docId);
    setOffset(headerOffset + 8, dataOffset);
    setBytes(dataOffset, docBytes);
    _numDocs++;
  }

  void remove(int docId) {
    assert(contains(docId));

    final numDocs = _numDocs;
    final index = _getIndexOfId(docId);
    var previousEnd = index == 0 ? chunkSize : _getOffset(index - 1);

    for (var i = index + 1; i < numDocs; i++) {
      final start = _getOffset(i);
      final end = _getOffset(i - 1);
      final length = end - start;
      final newStart = previousEnd - length;

      for (var j = 0; j < length; j++) {
        final byte = chunk.getUint8(start + j);
        setUint8(newStart + j, byte);
      }
      _setDocId(i - 1, _getDocId(i));
      _setOffset(i - 1, newStart);
      previousEnd = newStart;
    }
    _numDocs--;
  }
}

class Bucket {
  int _numFreeBytes;
  Map<int, List<int>> _docsById;

  Bucket.fromChunk(Chunk chunk) {
    final numObjects = chunk.getUint16(1);
    final headers = <MapEntry<int, int>>[
      for (var i = 0; i < numObjects; i++)
        MapEntry<int, int>(
          chunk.getUint16(3 + 10 * i),
          chunk.getOffset(11 + 10 * i),
        ),
    ];

    final headersEnd = 3 + 10 * numObjects;
    final dataBegin = headers.map((oi) => oi.value).reduce(min);
    _numFreeBytes = dataBegin - headersEnd;

    _docsById = <int, List<int>>{};
    for (var i = 0; i < numObjects; i++) {
      final header = headers[i];
      final start = header.value;
      final end = i == numObjects - 1 ? chunkSize : headers[i + 1].value;
      _docsById[header.key] =
          List.from(Uint8List.view(chunk.buffer, start, end));
    }
  }

  void intoChunk(Chunk chunk) {
    chunk..setUint16(1, _docsById.length);
    var dataPointer = chunkSize;
    final docs = _docsById.entries.toList()..sort((a, b) => a.key - b.key);
    for (var i = 0; i < docs.length; i++) {
      final doc = docs[i];
      var dataStart = dataPointer - doc.value.length - 1;
      chunk
        ..setDocId(3 + 10 * i, doc.key)
        ..setOffset(11 + 10 * i, dataStart)
        ..setBytes(dataStart, doc.value);
    }
  }

  bool contains(int docId) => _docsById.containsKey(docId);
  bool doesFit(List<int> docBytes) => _numFreeBytes > docBytes.length + 10;

  void add(int docId, List<int> docBytes) {
    assert(!contains(docId));
    assert(doesFit(docBytes));
    _docsById[docId] = docBytes;
  }

  void update(int docId, List<int> docBytes) {
    assert(contains(docId));
    assert(_numFreeBytes > docBytes.length - _docsById[docId].length);
    _docsById[docId] = docBytes;
  }
}
