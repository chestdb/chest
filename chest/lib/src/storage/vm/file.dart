import 'dart:io';

import 'dart:typed_data';

/// A file representation that only offers synchronous operations useful to the
/// [ChunkManager].
class SyncFile {
  SyncFile(String name) {
    _open(name);
    _intData = ByteData(8);
    _intList = Uint8List.view(_intData.buffer);
  }

  RandomAccessFile? _file;
  String get path => _file!.path;

  /// [ByteData] and [Uint8List] are quite heavy to create, so we create these
  /// buffers for efficient access.
  late ByteData _intData;
  late Uint8List _intList;

  void _open(String path) {
    _file = File(path).openSync(mode: FileMode.append)
      ..lockSync(FileLock.blockingExclusive);
  }

  void delete() {
    final path = this.path;
    close();
    File(path).deleteSync();
  }

  void close() {
    _file
      ?..unlockSync()
      ..closeSync();
    _file = null;
  }

  void renameTo(String newPath) {
    final path = this.path;
    close();
    File(path).renameSync(newPath);
    _open(newPath);
  }

  int length() => _file!.lengthSync();
  void truncate(int length) => _file!.truncateSync(length);
  void clear() {
    truncate(0);
    goToStart();
  }

  int position() => _file!.positionSync();

  void flush() => _file!.flushSync();

  void goTo(int position) => _file!.setPositionSync(position);
  void goToStart() => goTo(0);
  void goToEnd() => goTo(length());

  void writeByte(int value) => _file!.writeByteSync(value);
  int readByte() => _file!.readByteSync();

  void writeInt(int value) {
    _intData.setInt64(0, value);
    writeBytes(_intList);
  }

  int readInt() {
    readBytesInto(_intList);
    return _intData.getInt64(0);
  }

  void writeBytes(Uint8List bytes) => _file!.writeFromSync(bytes);
  void readBytesInto(Uint8List bytes) => _file!.readIntoSync(bytes);
}
