import 'dart:typed_data';

import 'package:convert/convert.dart';

// const chunkSize = 4 * 1024; // 4 KiB
const chunkSize = 64;

class Chunk {
  Chunk() : this.fromByteData(ByteData(chunkSize));
  Chunk.fromByteData(this.byteData)
      : assert(byteData.lengthInBytes == chunkSize),
        bytes = Uint8List.view(byteData.buffer);
  Chunk.fromUint8List(this.bytes)
      : assert(bytes.length == chunkSize),
        byteData = ByteData.view(bytes.buffer);
  factory Chunk.copyOf(Chunk other) => Chunk()..copyFrom(other);

  final ByteData byteData;
  final Uint8List bytes;
  ByteBuffer get buffer => bytes.buffer;

  int getUint8(int offset) => byteData.getUint8(offset);
  void setUint8(int offset, int value) => byteData.setUint8(offset, value);
  int getUint16(int offset) => byteData.getUint16(offset);
  void setUint16(int offset, int value) => byteData.setUint16(offset, value);
  int getInt64(int offset) => byteData.getInt64(offset);
  void setInt64(int offset, int value) => byteData.setInt64(offset, value);

  Uint8List getBytes(int offset, int length) =>
      Uint8List.view(buffer, offset, length);
  void setBytes(int offset, List<int> bytes) {
    for (var i = 0; i < bytes.length; i++) {
      setUint8(offset + i, bytes[i]);
    }
  }

  void copyTo(Chunk other) => other.setBytes(0, bytes);
  void copyFrom(Chunk other) => other.copyTo(this);

  String toString() => hex.encode(bytes);
}
