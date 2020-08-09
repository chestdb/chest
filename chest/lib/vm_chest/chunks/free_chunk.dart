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

  final TransactionChunk chunk;

  int get next => chunk.getChunkIndex(1);
  set next(int id) => chunk.setChunkIndex(1, id);

  String toString() => 'FreeChunk(next: $next)';
}

extension ChunkManager on Transaction {
  TransactionChunk reserve() {
    final main = mainChunk;

    if (main.firstFreeChunk == 0) {
      return add();
    } else {
      final freeChunk = this[main.firstFreeChunk];
      main.firstFreeChunk = FreeChunk(freeChunk).next;
      return freeChunk..clear();
    }
  }

  void free(int index) {
    final main = mainChunk;
    FreeChunk(this[index]).next = main.firstFreeChunk;
    main.firstFreeChunk = index;
  }
}
