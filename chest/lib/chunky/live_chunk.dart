import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'chunky.dart';

class LiveChunk implements Chunk {
  LiveChunk({
    @required this.chunky,
    @required this.index,
    @required this.chunk,
  });

  final ChunkyTransaction chunky;
  final int index;
  final Chunk chunk;

  @override
  ByteData get byteData => chunk.byteData;

  @override
  Uint8List get bytes => chunk.bytes;

  @override
  ByteBuffer get buffer => chunk.buffer;

  void _update() => chunky.write(index, chunk);

  @override
  int getUint8(int offset) => chunk.getUint8(offset);

  @override
  void setUint8(int offset, int value) {
    chunk.setUint8(offset, value);
    _update();
  }

  @override
  int getUint16(int offset) => chunk.getUint16(offset);

  @override
  void setUint16(int offset, int value) {
    chunk.setUint16(offset, value);
    _update();
  }

  @override
  int getInt64(int offset) => chunk.getInt64(offset);

  @override
  void setInt64(int offset, int value) {
    chunk.setInt64(offset, value);
    _update();
  }

  @override
  Uint8List getBytes(int offset, int length) => chunk.getBytes(offset, length);

  @override
  void setBytes(int offset, List<int> bytes) {
    chunk.setBytes(offset, bytes);
    _update();
  }

  @override
  void copyTo(Chunk other) => other.copyFrom(chunk);

  @override
  void copyFrom(Chunk other) {
    chunk.copyFrom(other);
    _update();
  }

  @override
  String toString() => chunk.toString();
}
