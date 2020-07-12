import 'dart:io' as io;
import 'dart:typed_data';

import 'chunk.dart';

/// A file with only synchronous operations and several utility methods.
class File {
  File.open(String fileName) {
    _file = io.File(fileName).openSync(mode: io.FileMode.append);
    _intBufferData = ByteData.view(_intBufferList.buffer);
  }

  io.RandomAccessFile _file;

  /// General purpose buffers.
  /// [ByteData] and [Uint8List] are quite heavy to create, so we create these
  /// buffers which can be used in a number of places.
  Uint8List _intBufferList = Uint8List(8);
  ByteData _intBufferData;

  int length() => _file.lengthSync();

  /// Allows for terser syntax like `file.to(8).readInt(8);` without verbose
  /// cascades.
  File toOffset(int position) {
    _file.setPositionSync(position);
    return this;
  }

  File toChunk(int address) {
    _file.setPositionSync(address * chunkSize);
    return this;
  }

  File toChunkAndOffset(int chunkAddress, int offset) {
    _file.setPositionSync(chunkAddress * chunkSize + offset);
    return this;
  }

  void flush() => _file.flushSync();

  int readInt() {
    _file.readIntoSync(_intBufferList);
    return _intBufferData.getUint64(0);
  }

  void writeInt(int value) {
    _intBufferData.setUint64(0, value);
    _file.writeFromSync(_intBufferList);
  }

  int readByte() => _file.readByteSync();
  void writeByte(int byte) => _file.writeByteSync(byte);

  void readChunkInto(Chunk chunk) => _file.readIntoSync(chunk.list);
  void writeChunkFrom(Chunk chunk) => _file.writeFromSync(chunk.list);
}
