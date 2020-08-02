import 'package:chest/chunky/chunky.dart';

import 'chunks.dart';
import 'utils.dart';

/// A chunk that contains no functional data and is free to re-use.
///
/// # Layout
///
/// ```
/// | type | next free chunk id | garbage                                      |
/// | 1B   | 8B                 | fill                                         |
/// ```
class FreeChunk extends ChunkWrapper {
  FreeChunk(this.chunk) {
    chunk.type = ChunkTypes.free;
  }

  final Chunk chunk;

  int get nextChunkId => chunk.getChunkId(1);
  set nextChunkId(int id) => chunk.setChunkId(1, id);
}
