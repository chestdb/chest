import 'dart:math';
import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';

import 'chunks.dart';
import 'utils.dart';

/// A chunk that stores part of a document that is so large that it doesn't fit
/// into a single chunk.
///
/// The next chunk id points to either another [BigDocChunk] which is completely
/// filled with data or to a [BigDocContinuationChunk], which is only partially
/// filled with data and indicates the end of the document bytes.
///
/// # Layout
///
/// ```
/// | type | doc id | length | next | data                                     |
/// | 1B   | 8B     | 8B     | 8B   | fill                                     |
/// ```
class BigDocChunk extends StorageChunk {
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
  bool get hasNext => next != 0;
}

/// A chunk that continues the chain of data for big docs.
///
/// # Layout
///
/// ```
/// | type | next | data                                                       |
/// | 1B   | 8B   | fill                                                       |
/// ```
class BigDocContinuationChunk extends ChunkWrapper {
  static const headerLength = 1 + chunkIndexLength;
  static const maxPayload = chunkSize - headerLength;

  BigDocContinuationChunk(this.chunk) : super(ChunkTypes.bigDocEnd);

  final TransactionChunk chunk;

  int get next => chunk.getChunkIndex(1);
  set next(int index) => chunk.setChunkIndex(1, index);
  bool get hasNext => next != 0;
}
