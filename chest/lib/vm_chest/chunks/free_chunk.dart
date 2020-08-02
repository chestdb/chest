import 'package:chest/chunky/chunky.dart';

import 'utils.dart';

/// A chunk that contains no functional data and is free to re-use.
///
/// # Layout
///
/// ```
/// | type | next free chunk id | garbage                                      |
/// | 1B   | 8B                 | fill                                         |
/// ```
extension FreeChunk on Chunk {
  static const type = 0;

  int getNextChunkId() => getChunkId(1);
  void setNextChunkId(int id) => setChunkId(1, id);
}
