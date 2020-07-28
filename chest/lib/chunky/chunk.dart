import 'dart:typed_data';

import 'package:convert/convert.dart';

// const chunkSize = 4 * 1024; // 4 KiB
const chunkSize = 64;

class Chunk {
  Chunk._(this._data, this._list)
      : assert(_data.lengthInBytes == chunkSize),
        assert(_list.length == chunkSize);
  Chunk() : this.fromByteData(ByteData(chunkSize));
  Chunk.fromByteData(this._data) : _list = Uint8List.view(_data.buffer);
  Chunk.fromUint8List(this._list) : _data = ByteData.view(_list.buffer);

  final ByteData _data;
  final Uint8List _list;

  Uint8List get bytes => _list;
  ByteBuffer get buffer => _list.buffer;

  void setUint8(int offset, int value) => _data.setUint8(offset, value);
  int getUint8(int offset) => _data.getUint8(offset);
  void setUint16(int offset, int value) => _data.setUint16(offset, value);
  int getUint16(int offset) => _data.getUint16(offset);
  void setInt64(int offset, int value) => _data.setInt64(offset, value);
  int getInt64(int offset) => _data.getInt64(offset);

  void setBytes(int offset, List<int> bytes) {
    for (var i = 0; i < bytes.length; i++) {
      setUint8(offset + i, bytes[i]);
    }
  }

  List<int> getBytes(int offset, int length) {
    return <int>[for (var i = 0; i < length; i++) getUint8(offset + i)];
  }

  String toString() => hex.encode(_list);
}
