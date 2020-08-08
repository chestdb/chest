part of 'chunky.dart';

// const chunkSize = 4 * 1024; // 4 KiB
const chunkSize = 64;

abstract class Chunk {
  void setUint8(int offset, int value);
  int getUint8(int offset);

  void setUint16(int offset, int value);
  int getUint16(int offset);

  void setUint32(int offset, int value);
  int getUint32(int offset);

  void setInt64(int offset, int value);
  int getInt64(int offset);

  void setBytes(int offset, List<int> bytes);
  Uint8List getBytes(int offset, int length);

  void copyFrom(Chunk other);
  void copyTo(Chunk other);
}

class ChunkData implements Chunk {
  ChunkData() : this.fromByteData(ByteData(chunkSize));
  ChunkData.fromByteData(this.byteData)
      : assert(byteData.lengthInBytes == chunkSize),
        bytes = Uint8List.view(byteData.buffer);
  ChunkData.fromUint8List(this.bytes)
      : assert(bytes.length == chunkSize),
        byteData = ByteData.view(bytes.buffer);
  factory ChunkData.copyOf(ChunkData other) => ChunkData()..copyFrom(other);

  final ByteData byteData;
  final Uint8List bytes;
  ByteBuffer get buffer => bytes.buffer;

  void setUint8(int offset, int value) => byteData.setUint8(offset, value);
  int getUint8(int offset) => byteData.getUint8(offset);

  void setUint16(int offset, int value) => byteData.setUint16(offset, value);
  int getUint16(int offset) => byteData.getUint16(offset);

  void setUint32(int offset, int value) => byteData.setUint32(offset, value);
  int getUint32(int offset) => byteData.getUint32(offset);

  void setInt64(int offset, int value) => byteData.setInt64(offset, value);
  int getInt64(int offset) => byteData.getInt64(offset);

  void setBytes(int offset, List<int> bytes) {
    for (var i = 0; i < bytes.length; i++) {
      setUint8(offset + i, bytes[i]);
    }
  }

  Uint8List getBytes(int offset, int length) =>
      Uint8List.view(buffer, offset, length);

  void copyFrom(Chunk other) => other.copyTo(this);
  void copyTo(Chunk other) => other.setBytes(0, bytes);

  String toString() => hex.encode(bytes);

  operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChunkData) return false;

    final chunk = other as ChunkData;
    for (var offset = 0; offset < bytes.length; offset += 8) {
      if (getInt64(offset) != chunk.getInt64(offset)) return false;
    }
    return true;
  }

  int get hashCode => bytes.fold(0, (val, byte) => val << 1 + byte);
}

class TransactionChunk implements Chunk {
  TransactionChunk(this.index, this._data);

  final int index;
  final ChunkData _data;
  bool _isDirty = false;
  bool get isDirty => _isDirty;

  void _makeDirty(void Function() callback) {
    _isDirty = true;
    callback();
    // print('$index: $_data');
  }

  void setUint8(int offset, int value) =>
      _makeDirty(() => _data.setUint8(offset, value));
  int getUint8(int offset) => _data.getUint8(offset);

  void setUint16(int offset, int value) =>
      _makeDirty(() => _data.setUint16(offset, value));
  int getUint16(int offset) => _data.getUint16(offset);

  void setUint32(int offset, int value) =>
      _makeDirty(() => _data.setUint32(offset, value));
  int getUint32(int offset) => _data.getUint32(offset);

  void setInt64(int offset, int value) =>
      _makeDirty(() => _data.setInt64(offset, value));
  int getInt64(int offset) => _data.getInt64(offset);

  void setBytes(int offset, List<int> bytes) =>
      _makeDirty(() => _data.setBytes(offset, bytes));
  Uint8List getBytes(int offset, int length) => _data.getBytes(offset, length);

  void copyFrom(Chunk other) => _makeDirty(() => _data.copyFrom(other));
  void copyTo(Chunk other) => _data.copyTo(other);

  ChunkData snapshot() => ChunkData.copyOf(_data);

  String toString() => _data.toString();
}
