import 'dart:io';

import 'dart:typed_data';

/// A file representation that only offers synchronous operations useful to the
/// [ChunkManager].
class SyncFile {
  SyncFile(String name) {
    _file = File(name).openSync(mode: FileMode.append);

    _intData = ByteData(8);
    _intList = Uint8List.view(_intData.buffer);
  }

  late RandomAccessFile _file;
  String get path => _file.path;

  /// [ByteData] and [Uint8List] are quite heavy to create, so we create these
  /// buffers for efficient access.
  late ByteData _intData;
  late Uint8List _intList;

  int length() => _file.lengthSync();
  void clear() {
    _file.truncateSync(0);
    goToStart();
  }

  void flush() => _file.flushSync();

  void goTo(int position) => _file.setPositionSync(position);
  void goToStart() => goTo(0);
  void goToEnd() => goTo(length());

  void writeByte(int value) => _file.writeByteSync(value);
  int readByte() => _file.readByteSync();

  void writeInt(int value) {
    _intData.setInt64(0, value);
    writeBytes(_intList);
  }

  int readInt() {
    readBytesInto(_intList);
    return _intData.getInt64(0);
  }

  void writeBytes(Uint8List bytes) => _file.writeFromSync(bytes);
  void readBytesInto(Uint8List bytes) => _file.readIntoSync(bytes);

  void close() => _file.closeSync();
}
