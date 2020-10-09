import 'dart:collection';

import 'package:chest/chunky/chunky.dart';

import '../overflow_chunk.dart';
import '../utils.dart';

/// Helper for reading a key in a [PayloadToIntTree].
///
/// Just instantiate a [KeyReader] with [chunky], a [chunk], and an [offset] to
/// get an [Iterable] over the bytes of the key.
///
/// # Layout
///
/// Depending on the key length, it's either
/// - inlined in the tree or
/// - only the beginning is inlined and the rest is saved into [OverflowChunk]s.
///
/// If the key is shorter than 255 bytes, this is the layout:
///
/// ```
/// | length | data |
/// | 1 B    | ...  |
/// ```
///
/// If the key is longer than 254 bytes, this is the layout:
///
/// ```
/// | 255 | total length | overflow chunk | first 254 bytes of data |
/// | 1 B | 4 B          | 8 B            | 254 B                   |
/// ```
///
/// The `overflow chunk` field points to a chain of [OverflowChunk]s containing
/// the rest of the data.
/*class KeyReader with IterableMixin<int> {
  KeyReader(this.chunky, this.chunk, this.offset);

  final Transaction chunky;
  final TransactionChunk chunk;
  final int offset;

  @override
  Iterator<int> get iterator => KeyIterator(chunky, chunk, offset);
}

class KeyIterator implements Iterator<int> {
  KeyIterator(this.chunky, this.chunk, this.offset) {
    final firstByte = chunk.getUint8(offset);
    if (firstByte == 255) {
      lengthLeft = chunk.getUint32(offset + 1);
      lengthLeftInThisChunk = lengthLeft;
      nextChunkIndex = chunk.getChunkIndex(offset);
      offset += 4 + chunkIndexLength;
    } else {
      lengthLeft = firstByte;
      lengthLeftInThisChunk = 254;
      nextChunkIndex = null;
      offset++;
    }
  }

  final Transaction chunky;
  TransactionChunk chunk;
  int offset;
  int lengthLeft;
  int lengthLeftInThisChunk;
  int nextChunkIndex;

  @override
  int get current => chunk.getUint8(offset);

  @override
  bool moveNext() {
    if (lengthLeft == 0) {
      return false;
    }

    if (lengthLeftInThisChunk > 0) {
      offset++;
      lengthLeft--;
      lengthLeftInThisChunk--;
    }

    if (lengthLeftInThisChunk == 0) {
      final nextChunk = chunky[nextChunkIndex].parse<OverflowChunk>();
      chunk = nextChunk.chunk;
      offset = OverflowChunk.payloadOffset;
      lengthLeftInThisChunk = OverflowChunk.payloadLength;
      nextChunkIndex = nextChunk.next;
    }
    return true;
  }
}*/
