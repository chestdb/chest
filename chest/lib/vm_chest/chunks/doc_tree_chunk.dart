import 'package:chest/chunky/chunky.dart';

import 'utils.dart';

/// A chunk that is a node in the document tree.
///
/// # Layout
///
/// ```
/// | 4  | num keys | chunk id | doc id | chunk id | doc id | ...   | chunk id |
/// | 1B | 2B       | 8B       | 8B     | 8B       | 8B     |       | 8B       |
/// ```
extension DocTreeChunk on Chunk {
  static const type = 4;

  int getNumberOfKeys() => getUint16(1);
  void setNumberOfKeys(int index) => setUint16(1, index);

  int getChunkIdByIndex(int index) => getChunkId(1 + 16 * index);
  void setChunkIdByIndex(int index, int chunkId) =>
      setChunkId(1 + 16 * index, chunkId);

  int getDocId(int index) => getDocId(9 + 16 * index);
  void setDocId(int index, int docId) => setDocId(9 + 16 * index, docId);

  void apply() {
    setUint8(0, type);
    clear(1, chunkSize);
  }
}
