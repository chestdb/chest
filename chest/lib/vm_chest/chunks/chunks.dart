export 'big_doc_chunk.dart';
export 'bucket_chunk.dart';
export 'int_map.dart';
export 'free_chunk.dart';
export 'main_chunk.dart';
export 'utils.dart';

import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';

import 'bucket_chunk.dart';
import 'int_map.dart';
import 'free_chunk.dart';
import 'main_chunk.dart';
import 'utils.dart';

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

abstract class StorageChunk extends ChunkWrapper {
  StorageChunk(int type) : super(type);
}

extension TypedAddingOfChunks on Transaction {
  TransactionChunk addTyped(int type) {
    final chunk = add();
    chunk.type = type;
    return chunk;
  }
}
