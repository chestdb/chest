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

class ChunkManager {
  ChunkManager(this.chunky);

  final ChunkyTransaction chunky;

  Chunk reserveChunk() {
    final main = MainChunk(chunky.read(0));
    final chunk = Chunk();
    final freeChunkIndex = main.firstFreeChunk;
    if (freeChunkIndex == 0) {
      chunky.add(chunk);
    } else {
      chunky.readInto(freeChunkIndex, chunk);
      final nextFreeChunkIndex = FreeChunk(chunk).nextChunkId;
      main.firstFreeChunk = nextFreeChunkIndex;
      chunky.write(0, main);
    }
    return chunk;
  }

  void freeChunk(int index) {
    final main = MainChunk(chunky.read(0));
    final freeChunkIndex = main.firstFreeChunk;
    if (freeChunkIndex == 0) {
      main.firstFreeChunk = index;
      chunky.write(0, main);
    } else {
      final chunk = FreeChunk(chunky.read(index));
      chunk.nextChunkId = freeChunkIndex;
      main.firstFreeChunk = index;
      chunky..write(index, chunk)..write(0, main);
    }
  }
}
