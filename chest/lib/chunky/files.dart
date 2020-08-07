import 'dart:io';
import 'dart:typed_data';

import 'chunky.dart';

/// A file representation that only offers synchronous operations useful to the
/// [ChunkManager].
class SyncFile {
  SyncFile(String name) {
    _file = File(name).openSync(mode: FileMode.append);

    _intData = ByteData(8);
    _intList = Uint8List.view(_intData.buffer);
  }

  RandomAccessFile _file;
  String get path => _file.path;

  /// [ByteData] and [Uint8List] are quite heavy to create, so we create these
  /// buffers for efficient access.
  ByteData _intData;
  Uint8List _intList;

  int length() => _file.lengthSync();
  void clear() => _file.truncateSync(0);
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

/// The file that contains the actual chunks.
///
/// # Layout
///
/// | chunk        | chunk        | chunk        | ... |
/// | [chunkSize]B | [chunkSize]B | [chunkSize]B |     |
class ChunkFile {
  ChunkFile(this.file);

  final SyncFile file;

  int get numberOfChunks => file.length() ~/ chunkSize;
  void writeChunk(int index, ChunkData chunk) => file
    ..goTo(index * chunkSize)
    ..writeBytes(chunk.bytes);
  void readChunkInto(int index, ChunkData chunk) => file
    ..goTo(index * chunkSize)
    ..readBytesInto(chunk.bytes);
}

/// A chunk that stores a copy of the chunks to be written to the actual file.
///
/// Writes don't get applied to the chunk file directly, because the program may
/// be aborted while writing, causing changes to be partially written to the
/// file. That's why during a transaction, the changes are written to this
/// transaction file and then to the actual file.
///
/// # Layout
///
/// | committed? | index | chunk        | index | chunk        | ... |
/// | 1B         | 8B    | [chunkSize]B | 8B    | [chunkSize]B |     |
///
/// The commit byte indicates whether the changes are ready to be applied to the
/// [ChunkFile] (it's 0 or 255). For each change, the chunk index and
/// chunk data are saved.
///
/// To do a transaction, the file is cleared. Then, the commit byte is written
/// (zero) and then all the changes are written into the file. At the end, the
/// commit byte is set to 255. Then, the changes are applied to the [ChunkFile].
///
/// Whenever [Chunky] is started, it also opens this [TransactionFile] and
/// decides what to do:
/// - If the [TransactionFile] is empty, no transaction was in progress when the
///   program was stopped, so the [ChunkFile] is consistent.
/// - If the [TransactionFile] is not empty, but the commit byte is a zero, then
///   the [ChunkFile] is consistent, because no changes have been applied yet.
/// - If the [TransactionFile] is not empty and the commit byte is non-zero, the
///   changes may have been partially written to the [ChunkFile]. Go over the
///   changes and apply each one of them to the [ChunkFile].
class TransactionFile {
  TransactionFile(this.file);

  SyncFile file;

  // Starts a transaction.
  void start() {
    file
      ..clear()
      ..goToStart()
      ..writeByte(0);
  }

  void addChange(int index, ChunkData chunk) {
    file
      ..goToEnd()
      ..writeInt(index)
      ..writeBytes(chunk.bytes);
  }

  void commit() {
    file
      ..flush()
      ..goToStart()
      ..writeByte(255)
      ..flush();
  }

  bool get isCommitted {
    file.goToStart();
    return file.length() > 0 && file.readByte() != 0;
  }

  TransactionFileReader get reader => TransactionFileReader(file);
}

class TransactionFileReader {
  TransactionFileReader(this._file) {
    _length = _file.length();
    _file.goToStart();
    _file.readByte() != 0;
  }

  final SyncFile _file;
  int _length;
  var _cursor = 1;

  bool get isAtEnd => _cursor >= _length;

  /// Advances to the next change. Returns the index of the change and saves the
  /// data in the given [chunk].
  int next(ChunkData chunk) {
    _file.goTo(_cursor);
    _cursor += 8 + chunkSize;
    final index = _file.readInt();
    _file.readBytesInto(chunk.bytes);
    return index;
  }
}
