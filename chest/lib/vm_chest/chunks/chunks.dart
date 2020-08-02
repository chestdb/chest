export 'big_doc_chunk.dart';
export 'bucket_chunk.dart';
export 'doc_tree_chunk.dart';
export 'free_chunk.dart';
export 'main_chunk.dart';
class ChunkTypes {
  static const main = 0;
  static const free = 1;
  static const bucket = 2;
  static const bigDoc = 3;
  static const bigDocEnd = 4;
  static const docTreeInternalNode = 5;
  static const docTreeLeafNode = 6;
}
