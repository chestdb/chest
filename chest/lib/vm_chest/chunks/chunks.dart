export 'big_doc_chunk.dart';
export 'bucket_chunk.dart';
export 'doc_tree_chunk.dart';
export 'free_chunk.dart';
export 'main_chunk.dart';

import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';

import 'bucket_chunk.dart';
import 'doc_tree_chunk.dart';
import 'main_chunk.dart';
import 'utils.dart';

class ChunkTypes {
  static const main = 0;
  static const free = 1;
  static const bucket = 2;
  static const bigDoc = 3;
  static const bigDocEnd = 4;
  static const docTreeInternalNode = 5;
  static const docTreeLeafNode = 6;
}

extension ChunkAbstractions on Chunk {
  T parse<T extends ChunkWrapper>() {
    final abstractions = {
      ChunkTypes.main: (chunk) => MainChunk(chunk),
      // ChunkIds.free: (chunk) => FreeChunk(chunk),
      ChunkTypes.bucket: (chunk) => BucketChunk(chunk),
      // ChunkIds.bigDoc: (chunk) => BigDocChunk(chunk),
      // ChunkIds.bigDocEnd: (chunk) => BigDocEndChunk(chunk),
      ChunkTypes.docTreeInternalNode: (chunk) =>
          DocTreeInternalNodeChunk(chunk),
      ChunkTypes.docTreeLeafNode: (chunk) => DocTreeLeafNodeChunk(chunk),
    };
    return abstractions[type](this) as T;
  }
}
