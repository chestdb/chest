import 'dart:io';
import 'dart:typed_data';

import 'chunk.dart';

/// A file representation that only offers synchronous operations useful to the
/// [ChunkManager].
class SyncFile {
  SyncFile(String name) {
    _file = File(name).openSync(mode: FileMode.append);

    _intData = ByteData(8);
    _intList = Uint8List.view(_intData.buffer);
  }

  RandomAccessFile _file;

  /// [ByteData] and [Uint8List] are quite heavy to create, so we create these
  /// buffers which can be used in a number of places.
  ByteData _intData;
  Uint8List _intList;

  int length() => _file.lengthSync();
  void clear() => _file.truncateSync(0);
  void flush() => _file.flushSync();

  void goTo(int position) => _file.setPositionSync(position);
  void goToIndex(int index) => goTo(index * chunkSize);
  void goToEnd() => goTo(length());

  void writeByte(int value) => _file.writeByteSync(value);
  int readByte() => _file.readByteSync();

  String get name => _file.path;
  void writeInt(int value) {
    print('Writing int to $name (${_file.positionSync()}).');
    _intData.setInt64(0, value);
    _file.writeFromSync(_intList);
  }

  int readInt() {
    print('Reading int from $name (${_file.positionSync()}).');
    _file.readIntoSync(_intList);
    return _intData.getInt64(0);
  }

  void writeChunk(Chunk chunk) => _file.writeFromSync(chunk.bytes);
  void readChunkInto(Chunk chunk) => _file.readIntoSync(chunk.bytes);

  void close() => _file.closeSync();
}
