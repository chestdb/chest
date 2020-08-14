import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';
import 'package:meta/meta.dart';

import '../chunks.dart';
import '../utils.dart';

abstract class StorageChunk extends ChunkWrapper {
  StorageChunk(int type) : super(type);
}

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
class BucketChunk extends StorageChunk {
  static const _headerEntryLength = docIdLength + offsetLength;
  static const maxPayload = chunkSize - 1 - 2 - _headerEntryLength;

  BucketChunk(this.chunk) : super(ChunkTypes.bucket) {
    _headers = BackedList(
        setLength: (length) => _numDocs = length,
        getLength: () => _numDocs,
        setItem: (index, header) {
          chunk
            ..setDocId(3 + _headerEntryLength * index, header.docId)
            ..setOffset(11 + _headerEntryLength * index, header.offset);
        },
        getItem: (index) {
          return _Header(
            docId: chunk.getDocId(3 + _headerEntryLength * index),
            offset: chunk.getOffset(11 + _headerEntryLength * index),
          );
        });
  }

  final TransactionChunk chunk;
  List<_Header> _headers;

  set _numDocs(int value) => chunk.setUint16(1, value);
  int get _numDocs => chunk.getUint16(1);

  bool contains(int docId) => _headers.findHeader(docId).wasFound;
  bool get isEmpty => _headers.length == 0;
  bool get isNotEmpty => !isEmpty;

  int get _freeSpaceStart => 3 + _headerEntryLength * _headers.length;
  int get _freeSpaceEnd => isEmpty ? chunkSize : (_headers.last.offset - 1);
  int get _freeSpace => _freeSpaceEnd - _freeSpaceStart;
  bool doesFit(int length) => _freeSpace >= _headerEntryLength + length;

  Uint8List get(int docId) {
    final result = _headers.findHeader(docId);
    if (result.wasNotFound) {
      return null;
    }
    final dataStart = result.item.offset;
    final dataEnd = result.nextItem?.offset ?? chunkSize;
    final length = dataEnd - dataStart;
    return Uint8List.fromList(chunk.getBytes(dataStart, length));
  }

  void add(int docId, List<int> docBytes) {
    assert(!contains(docId),
        'This chunk already contains a document with id $docId.');
    assert(doesFit(docBytes.length), 'Not enough space.');

    final dataOffset = _freeSpaceEnd - docBytes.length;
    chunk.setBytes(dataOffset, docBytes);
    _headers.insertHeaderSorted(_Header(docId: docId, offset: dataOffset));
  }

  void remove(int docId) {
    assert(contains(docId));

    final result = _headers.findHeader(docId);
    var deletedEnd = result.previousItem?.offset ?? chunkSize;

    for (var i = result.index; i < _headers.length - 1; i++) {
      final nextHeader = _headers[i + 1];

      final deletedStart = _headers[i].offset;
      final nextStart = nextHeader.offset;
      final nextEnd = deletedStart;

      final nextLength = nextEnd - nextStart;

      final translatedStart = deletedEnd - nextLength;

      for (var j = 0; j < nextLength; j++) {
        final byte = chunk.getUint8(nextStart + j);
        chunk.setUint8(translatedStart + j, byte);
      }
      _headers[i] = _Header(docId: nextHeader.docId, offset: translatedStart);
      deletedEnd = deletedStart;
    }
    _numDocs--;
  }
}

class _Header {
  _Header({@required this.docId, @required this.offset});

  final int docId;
  final int offset;
}

extension on List<_Header> {
  SearchResult<_Header> findHeader(int docId) =>
      find(docId, (header) => header.docId);
  void insertHeaderSorted(_Header header) =>
      insertSorted(header, (header) => header.docId);
}

abstract class BigDocStorageChunk extends StorageChunk {
  BigDocStorageChunk(int type) : super(type);

  int get next;
  set next(int chunkId);
  bool get hasNext => next != 0;
}

/// A chunk that stores part of a document that is so large that it doesn't fit
/// into a single chunk.
///
/// The next chunk id points to either another [BigDocChunk] which is completely
/// filled with data or to a [BigDocNextChunk], which is only partially
/// filled with data and indicates the end of the document bytes.
///
/// # Layout
///
/// ```
/// | type | doc id | length | next | data                                     |
/// | 1B   | 8B     | 8B     | 8B   | fill                                     |
/// ```
class BigDocChunk extends BigDocStorageChunk {
  static const headerLength = 1 + docIdLength + 8 + chunkIndexLength;
  static const maxPayload = chunkSize - headerLength;

  BigDocChunk(this.chunk) : super(ChunkTypes.bigDoc);

  final TransactionChunk chunk;

  int get docId => chunk.getDocId(1);
  set docId(int value) => chunk.setDocId(1, value);

  int get length => chunk.getInt64(1 + docIdLength);
  set length(int value) => chunk.setInt64(1 + docIdLength, value);

  int get next => chunk.getDocId(1 + docIdLength + 8);
  set next(int chunkIndex) => chunk.setDocId(1 + docIdLength + 8, chunkIndex);
}

/// A chunk that continues the chain of data for big docs.
///
/// # Layout
///
/// ```
/// | type | next | data                                                       |
/// | 1B   | 8B   | fill                                                       |
/// ```
class BigDocNextChunk extends BigDocStorageChunk {
  static const headerLength = 1 + chunkIndexLength;
  static const maxPayload = chunkSize - headerLength;

  BigDocNextChunk(this.chunk) : super(ChunkTypes.bigDocEnd);

  final TransactionChunk chunk;

  int get next => chunk.getChunkIndex(1);
  set next(int index) => chunk.setChunkIndex(1, index);
}
