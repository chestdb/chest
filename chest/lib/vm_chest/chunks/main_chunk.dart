import 'package:chest/chunky/chunky.dart';

import 'utils.dart';

/// The frist chunk, which is the entry point to all actions.
///
/// # Layout
///
/// ```
/// | 42 | first free chunk | doc tree root | padding                          |
/// | 1B | 8B               | 8B            | fill                             |
/// ```
extension MainChunk on Chunk {
  static const type = 42;

  void apply() {
    setUint8(0, 42);
    setChunkId(1, 0);
    setChunkId(9, 1);
  }
}
