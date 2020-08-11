import 'package:chest/chunky/chunky.dart';

import 'chunk_manager/free_chunk.dart';
import 'doc_storage/chunks.dart';
import 'int_map/chunks.dart';
import 'main_chunk.dart';
import 'utils.dart';

export 'chunk_manager/chunk_manager.dart';
export 'doc_storage/doc_storage.dart';
export 'int_map/int_map.dart';
export 'main_chunk.dart';
export 'utils.dart';

class ChunkTypes {
  static const main = 0;
  static const free = 1;
  static const bucket = 2;
  static const bigDoc = 3;
  static const bigDocEnd = 4;
  static const intMapInternalNode = 5;
  static const intMapLeafNode = 6;
}

extension ChunkAbstractions on Chunk {
  T parse<T extends ChunkWrapper>() {
    final abstractions = {
      ChunkTypes.main: (chunk) => MainChunk(chunk),
      ChunkTypes.free: (chunk) => FreeChunk(chunk),
      ChunkTypes.bucket: (chunk) => BucketChunk(chunk),
      // ChunkTypes.bigDoc: (chunk) => BigDocChunk(chunk),
      // ChunkTypes.bigDocEnd: (chunk) => BigDocEndChunk(chunk),
      ChunkTypes.intMapInternalNode: (chunk) => IntMapInternalNodeChunk(chunk),
      ChunkTypes.intMapLeafNode: (chunk) => IntMapLeafNodeChunk(chunk),
    };
    return abstractions[type](this) as T;
  }
}

extension TypedAddingOfChunks on Transaction {
  TransactionChunk addTyped(int type) {
    final chunk = add();
    chunk.type = type;
    return chunk;
  }
}
