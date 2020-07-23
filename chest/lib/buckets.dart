import 'package:tape/tape.dart';

import 'chunky/chunk.dart';

/// Bucket chunks have the following layout:
///
/// ```
/// 0 | header 1 | header 2 |                               | data 2 | data 1 |
/// 0 | header 1 | header 2 | header 3 |           | data 3 | data 2 | data 1 |
/// 0 | header 1 | header 2 | really huge data 2 | really really large data 1 |
/// ```
///
/// Or, for large amounts data that don't fit into a single chunk:
///
/// ```
/// 1 | next chunk id  | soooooooooooooooooooooooooooooooooooooooo many bytes |
/// 1 | next chunk id  | mooooooooooooooooooooooooooooooooooooooooooore bytes |
/// 2 | length of data | some data |                                          |
/// ```
class Bucket {
  final chunk = Chunk.empty();
  final objects = <Object, List<int>>{};

  int get usedBytes =>
      1 +
      objects.values.fold(0, (sum, bytes) => sum + bytes.length) +
      objects.length * 2;
  int get freeBytes => chunkSize - usedBytes;

  void add(Object obj) {
    final bytes = tape.encode(obj);
    if (objects.length >= 256 || bytes.length > freeBytes) {
      throw "Doesn't fit.";
    }
    objects[obj] = bytes;
    chunk.setUint8(0, objects.length);

    var pointerCursor = 1;
    var objectCursor = chunkSize;

    for (final bytes in objects.values) {
      objectCursor -= bytes.length;
      chunk.setUint16(pointerCursor, objectCursor);
      chunk.setBytes(objectCursor, bytes);
      pointerCursor += 2;
    }
  }
}
