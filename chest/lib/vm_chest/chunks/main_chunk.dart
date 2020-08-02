import 'package:chest/chunky/chunky.dart';

import 'chunks.dart';
import 'utils.dart';

/// The frist chunk, which is the entry point to all actions.
///
/// # Layout
///
/// ```
/// | type | first free chunk | doc tree root | padding                          |
/// | 1B   | 8B               | 8B            | fill                             |
/// ```
class MainChunk extends ChunkWrapper {
  MainChunk(this.chunk) {
    chunk.type = ChunkTypes.main;
  }

  final Chunk chunk;

  int get firstFreeChunk => chunk.getChunkId(1);
  set firstFreeChunk(int id) => chunk.setChunkId(1, id);

  int get docTreeRoot => chunk.getChunkId(9);
  set docTreeRoot(int id) => chunk.setChunkId(9, id);
}
