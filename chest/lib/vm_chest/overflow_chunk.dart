import 'package:chest/chunky/chunky.dart';

import 'utils.dart';

/// A general-purpose chunk for payload overflowing somewhere else.
class OverflowChunk extends ChunkWrapper {
  static const payloadOffset = chunkHeaderLength + chunkIndexLength;
  static const payloadLength = chunkLength - payloadOffset;

  OverflowChunk(this.chunk) : super(ChunkTypes.overflow);

  final TransactionChunk chunk;

  int get next => chunk.getChunkIndex(chunkHeaderLength);
  set next(int value) => chunk.setChunkIndex(chunkHeaderLength, value);
}
