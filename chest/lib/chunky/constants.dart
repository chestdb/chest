import 'chunky.dart';

/// The length of a single chunk.
// const chunkLength = 1024;
const chunkLength = 32;

/// The length of a chunk index.
///
/// Chunk indizes are used wherever code needs to point to another chunk. For
/// example, if chunk 1 refers to chunk 2, it may have to save a "2". This
/// length determines how many bytes each chunk index takes and thereby, how
/// how many chunks can exist in total.
///
/// Together with the [chunkLength], the [chunkIndexLength] determines the
/// maximum length of the file: [chunkLength] * 256^[chunkIndexLength]
const chunkIndexLength = 1;

extension ChunkIndexOperations on Chunk {
  int readChunkIndex(int offset) => getUint8(offset);
  void writeChunkIndex(int offset, int index) => setUint8(offset, index);
}
