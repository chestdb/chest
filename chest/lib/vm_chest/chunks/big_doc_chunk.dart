import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';

import 'utils.dart';

/// A chunk that stores part of a document that is so large that it doesn't fit
/// into a single chunk.
///
/// The next chunk id points to either another [BigDocChunk] which is completely
/// filled with data or to a [BigDocEndChunk], which is only partially filled
/// with data and indicates the end of the document bytes.
///
/// # Layout
///
/// ```
/// | 2  | next chunk id | data                                                |
/// | 1B | 8B            | fill                                                |
/// ```
extension BigDocChunk on Chunk {
  static const type = 2;

  int getNextChunkId() => getInt64(1);
  void setNextChunkId(int id) => setInt64(1, id);

  Uint8List getDataView() => Uint8List.view(bytes.buffer, 9, chunkSize - 9);
  void setData(Uint8List data) {
    assert(data.length == chunkSize - 9);
    writeCopy(data, 9);
  }
}

/// A chunk that marks the end of a chain of [BigDocChunk]s.
///
/// # Layout
///
/// ```
/// | 3  | length | pad | data                  | padding                      |
/// | 1B | 2B     | 6B  | var                   | fill                         |
/// ```
extension BigDocEndChunk on Chunk {
  static const type = 3;

  int _getLength() => getUint16(1);
  void _setLength(int id) => setUint16(1, id);

  void getDataView() => Uint8List.view(buffer, 9, _getLength());
}
