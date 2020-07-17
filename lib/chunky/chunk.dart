import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';

// const chunkSize = 4 * 1024; // 4 KiB
const chunkSize = 64;

class Chunk {
  Chunk._(this._data, this._list)
      : assert(_data.lengthInBytes == chunkSize),
        assert(_list.length == chunkSize);
  Chunk(ByteData data) : this._(data, Uint8List.view(data.buffer));
  Chunk.empty() : this(ByteData(chunkSize));

  final ByteData _data;
  final Uint8List _list;

  Uint8List get bytes => _list;

  void setUint8(int offset, int value) => _data.setUint8(offset, value);
  int getUint8(int offset) => _data.getUint8(offset);
  void setUint16(int offset, int value) => _data.setUint16(offset, value);
  int getUint16(int offset) => _data.getUint16(offset);

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
