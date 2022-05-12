import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../utils.dart';

/// A higher-level abstraction of a `.chest` file.
///
/// The file content is a header followed by a number of updates:
///
/// | header | update | update | ... |
///
/// The first update should be for the root value, all others ones can be for
/// parts of the value.
///
/// [ChestFileHeader] and [ChestFileUpdate] are representations for both of
/// these kinds of content.
///
/// ## Header layout
///
/// | magic bytes                | version |
/// | 5 bytes ("chest" in ASCII) | 8 byte  |
///
/// ## Update layout
///
/// | isValid | path                     | type              | value           |
/// |         | length | key | key | ... | 0=update 1=remove | length | bytes  |
/// | 1 byte  | many bytes               | 1 byte            | many bytes      |
class ChestFile {
  ChestFile(String path) : this._file = SyncFile(path);

  final SyncFile _file;

  ChestFileHeader? readHeader() {
    if (_file.length() < 5 + 8) {
      return null;
    }
    _file.goToStart();
    for (final char in 'chest'.codeUnits) {
      if (_file.readByte() != char) return null;
    }
    final version = _file.readInt();
    return ChestFileHeader(version);
  }

  ChestFileUpdate? readUpdate() {
    if (_file.position() >= _file.length()) return null;

    final validity = _file.readByte();
    if (validity == 0) {
      _file.truncate(_file.position() - 1);
      return null;
    }

    final pathLength = _file.readInt();
    final keys = <Block>[];
    for (var i = 0; i < pathLength; i++) {
      final keyLength = _file.readInt();
      final keyBytes = Uint8List(keyLength);
      _file.readBytesInto(keyBytes);
      keys.add(BlockView.of(keyBytes.buffer));
    }
    final path = Path(keys);

    final isRemoval = _file.readByte() == 1;
    if (isRemoval) {
      return ChestFileUpdate(path, null);
    }

    final valueLength = _file.readInt();
    final valueBytes = Uint8List(valueLength);
    _file.readBytesInto(valueBytes);
    final valueBlock = BlockView.of(valueBytes.buffer);

    return ChestFileUpdate(path, valueBlock);
  }

  void writeHeader(ChestFileHeader header) {
    _file
      ..clear()
      ..writeBytes(ascii.encode('chest'))
      ..writeInt(header.version)
      ..flush();
  }

  void appendUpdate(ChestFileUpdate update) {
    final start = _file.length();
    _file
      ..goToEnd()
      ..writeByte(0) // validity byte
      ..flush()
      ..writeInt(update.path.length);
    for (final key in update.path.keys) {
      final keyBytes = key.toBytes();
      _file
        ..writeInt(keyBytes.length)
        ..writeBytes(keyBytes);
    }
    _file.writeByte(update.isRemoval ? 1 : 0);
    if (!update.isRemoval) {
      final bytes = update.value!.toBytes();
      _file
        ..writeInt(bytes.length)
        ..writeBytes(bytes)
        ..flush()
        ..goTo(start)
        ..writeByte(1) // make transaction valid
        ..flush();
    }
  }

  String get path => _file.path;
  void delete() => _file.delete();
  void renameTo(String path) => _file.renameTo(path);
  void flush() => _file.flush();
  void close() => _file.close();

  bool get shouldBeCompacted {
    readHeader();
    _file
      ..readByte() // Validity byte.
      ..readInt(); // Path length of the root object (always 0).
    final lengthOfFirstUpdate = _file.readInt();
    final totalLength = _file.length();
    return totalLength / lengthOfFirstUpdate > 1.4;
  }
}

class ChestFileHeader {
  ChestFileHeader(this.version);

  final int version;
}

class ChestFileUpdate {
  ChestFileUpdate(this.path, this.value);

  final Path<Block> path;
  final Block? value;

  bool get isRemoval => value == null;
}

/// A file representation that only offers synchronous operations. This makes
/// sure that you don't call an asynchronous one by accident.
class SyncFile {
  SyncFile(String path) {
    _open(path);
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
    // TODO: Lock file?
    // TODO: Throw if file is already opened and locked.
    _file = File(path).openSync(mode: FileMode.append);
    // ..lockSync(FileLock.blockingExclusive);
  }

  void delete() {
    final path = this.path;
    close();
    File(path).deleteSync();
  }

  void close() {
    _file
      // ?..unlockSync()
      ?..closeSync();
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
