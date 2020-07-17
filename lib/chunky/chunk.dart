import 'dart:typed_data';

const chunkSize = 4 * 1024; // 4 KiB

class Chunk {
  Chunk._(this._data, this._list)
      : assert(_data.lengthInBytes == chunkSize),
        assert(_list.length == chunkSize);
  Chunk(ByteData data) : this._(data, Uint8List.view(data.buffer));
  Chunk.empty() : this(ByteData(chunkSize));

  final ByteData _data;
  final Uint8List _list;

  Uint8List get bytes => _list;

  void setUint8(offset, value) => _data.setUint8(offset, value);
  int getUint8(offset) => _data.getUint8(offset);
}
