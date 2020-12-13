import 'dart:typed_data';

/// Compresses the bytes with a tape-specific compression.
///
/// Tape encodings typically have long runs of zeros in them because type codes,
/// lengths, and pointers don't usually fill the whole uint64 assigned to them.
/// So this compression turns multiple zeros into a zero followed by the number
/// of zeros follwed.
///
/// A few examples:
///
/// Five zeros become one zero followed by a four indicating four more zeroes:
/// original:   1 2 3 0 0 0 0 0 4 5 6
/// compressed: 1 2 3 0 4 4 5 6
///
/// A single zero becomes a zero followed by a zero indicating no more zero:
/// original:   1 0 1 0 1 0 1
/// compressed: 1 0 0 1 0 0 1 0 0 1
///
/// A good property of this compression is that it's simple, fast, and can be
/// applied on-the-fly. As seen above, maliciously designed values can cause it
/// to actually increase the needed space. But that happens rarely with values
/// encoded in the real world, so compressing is still a good decision in 99 %
/// of the cases.
/// For cases where space really matters, you should use general compression
/// algorithms anyways – those will handle runs of 1s and 0s like in the second
/// example gracefully.
extension Compression on List<int> {
  Uint8List compress() {
    // TODO: Make this more efficient and safe (the encoding might also be longer).
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
