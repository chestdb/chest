import 'dart:typed_data';

extension Compress on List<int> {
  Uint8List compress() {
    // TODO: Make this more efficient.
    final out = ByteData(length);
    var cursor = 0;

    var i = 0;
    while (i < length) {
      if (this[i] != 0) {
        out.setUint8(cursor, this[i]);
        cursor++;
        i++;
      } else {
        out.setUint8(cursor, 0);
        cursor++;
        i++;
        var counter = 0;
        while (i < length && this[i] == 0 && counter < 255) {
          counter++;
          i++;
        }
        out.setUint8(cursor, counter);
        cursor++;
      }
    }

    return Uint8List.view(out.buffer, 0, cursor);
  }
}

extension Decompress on List<int> {
  Uint8List decompress() {
    final out = BytesBuilder();

    for (var i = 0; i < length; i++) {
      if (this[i] != 0) {
        out.addByte(this[i]);
      } else {
        out.addByte(0);
        i++;
        final counter = this[i];
        for (var j = 0; j < counter; j++) {
          out.addByte(0);
        }
      }
    }

    return out.toBytes();
  }
}
