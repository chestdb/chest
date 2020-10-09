import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';

import 'chunk_manager/chunks.dart';
import 'doc_storage/chunks.dart';
import 'int_map/chunks.dart';
import 'main_chunk.dart';

export 'chunk_manager/chunk_manager.dart';
export 'doc_storage/doc_storage.dart';
export 'int_map/int_map.dart';
export 'main_chunk.dart';
export 'utils.dart';

const chunkHeaderLength = 1; // Length of a chunk header.
const docIdLength = 8; // Length of a document id.
const offsetLength = 2; // Length of an offset inside a chunk.

/// All chunks in a chest file also contain a header indicating their type.
///
/// # Layout
///
/// ```
/// | any Chunk saved in a .chest file                                         |
/// | chunk header      | rest                                                 |
/// ```
/// For info about the actual size, see [chunkHeaderLength].
///
/// The actual header is layouted like this:
/// TODO: Extend this to also contain a checksum.
///
/// ```
/// | type |
/// | 1 B  |
/// ```
extension ChunkWithHeader on Chunk {
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

  void clear([int start = 0, int end = chunkLength]) {
    for (var i = start; i < end; i++) {
      setUint8(i, 0);
    }
  }
}

abstract class ChunkWrapper {
  ChunkWrapper(int type) {
    chunk.type = type;
  }

  TransactionChunk get chunk;

  int get index => chunk.index;

  String toString() => chunk.toString();
}

class ChunkTypes {
  static const main = 0;
  static const free = 1;
  static const bucket = 2;
  static const bigDoc = 3;
  static const bigDocEnd = 4;
  static const intMapInternalNode = 5;
  static const intMapLeafNode = 6;
  static const payloadToIntTreeInner = 7;
  static const payloadToIntTreeLeaf = 8;
  static const overflow = 9;
}

/*extension ChunkAbstractions on Chunk {
  T parse<T extends ChunkWrapper>() {
    final abstractions = {
      ChunkTypes.main: (chunk) => MainChunk(chunk),
      ChunkTypes.free: (chunk) => FreeChunk(chunk),
      ChunkTypes.bucket: (chunk) => BucketChunk(chunk),
      ChunkTypes.intMapInternalNode: (chunk) => IntMapInternalNodeChunk(chunk),
      ChunkTypes.intMapLeafNode: (chunk) => IntMapLeafNodeChunk(chunk),
    };
    return abstractions[type](this) as T;
  }
}*/

extension TypedAddingOfChunks on Transaction {
  TransactionChunk addTyped(int type) {
    final chunk = add();
    chunk.type = type;
    return chunk;
  }
}
