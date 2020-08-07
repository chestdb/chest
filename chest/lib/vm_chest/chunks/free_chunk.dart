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
  FreeChunk(this.chunk) : super(ChunkTypes.free);

  final Chunk chunk;

  int get next => chunk.getChunkIndex(1);
  set next(int id) => chunk.setChunkIndex(1, id);
}

class ChunkManager {
  ChunkManager(this._chunky);

  final Transaction _chunky;

  TransactionChunk reserve() {
    final main = _chunky.mainChunk;

    if (main.firstFreeChunk == 0) {
      return _chunky.add();
    } else {
      final freeChunk = _chunky[main.firstFreeChunk];
      main.firstFreeChunk = FreeChunk(freeChunk).next;
      return freeChunk;
    }
  }

  void free(int index) {
    final main = _chunky.mainChunk;
    FreeChunk(_chunky[index]).next = main.firstFreeChunk;
    main.firstFreeChunk = index;
  }
}
