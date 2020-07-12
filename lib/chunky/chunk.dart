import 'dart:typed_data';

const chunkSize = 4 * 1024; // 4 KiB

class Chunk {
  Chunk._(this.data, this.list)
      : assert(data.lengthInBytes == chunkSize),
        assert(list.length == chunkSize);
  Chunk(ByteData data) : this._(data, Uint8List.view(data.buffer));
  Chunk.empty() : this(ByteData(chunkSize));

  final ByteData data;
  final Uint8List list;
}
