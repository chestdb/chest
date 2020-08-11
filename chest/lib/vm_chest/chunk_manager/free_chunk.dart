import 'package:chest/chunky/chunky.dart';

import '../chunks.dart';
import '../utils.dart';

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
