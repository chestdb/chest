import 'dart:convert';
import 'dart:typed_data';

import 'basics.dart';

extension TapersForDartCore on TapersNamespace {
  Map<int, Taper<dynamic>> get forDartCore {
    return {
      -11: taper.forNull(),
      -12: taper.forBool(),
      -13: taper.forString(),
      -14: taper.forInt(),
      -15: taper.forDouble(),
      // -16: taper.forBigInt(),
      -17: taper.forDateTime(),
      -18: taper.forDuration(),
      -19: taper.forList<Object?>(),
      -20: taper.forMap<Object?, Object?>(),
      -21: taper.forSet<Object?>(),
    };
  }
}

extension TaperForNull on TaperNamespace {
  // "Don't use the Null type, unless your are positive that you don't want void."
  // We are positive.
  // ignore: prefer_void_to_null
  Taper<Null> forNull() {
    return BytesTaper(toBytes: (_) => [], fromBytes: (_) => null);
  }
}

extension TaperForBool on TaperNamespace {
  Taper<bool> forBool() {
    return BytesTaper(
      toBytes: (value) => [value ? 1 : 0],
      fromBytes: (bytes) => bytes.first != 0,
    );
  }
}

extension ReferenceToBool on Reference<bool> {
  void toggle() => value = !value;
}

extension TaperForString on TaperNamespace {
  Taper<String> forString() {
    return BytesTaper(toBytes: utf8.encode, fromBytes: utf8.decode);
  }
}

extension TaperForInt on TaperNamespace {
  Taper<int> forInt() {
    return BytesTaper(
      toBytes: (value) {
        final data = ByteData(8);
        data.setInt64(0, value);
        return Uint8List.view(data.buffer);
      },
      fromBytes: (bytes) {
        final data = ByteData(8);
        for (var i = 0; i < 8; i++) {
          data.setUint8(i, bytes[i]);
        }
        return data.getInt64(0);
      },
    );
  }
}

extension TaperForDouble on TaperNamespace {
  Taper<double> forDouble() {
    return BytesTaper(
      toBytes: (value) {
        final data = ByteData(8);
        data.setFloat64(0, value);
        return Uint8List.view(data.buffer);
      },
      fromBytes: (bytes) {
        final data = ByteData(8);
        for (var i = 0; i < 8; i++) {
          data.setUint8(i, bytes[i]);
        }
        return data.getFloat64(0);
      },
    );
  }
}

extension TaperForBigInt on TaperNamespace {
  /*Taper<BigInt> forBigInt() {
    return BytesTaper(
      toBytes: (bigInt) {
        throw 'Implement taper for BigInt.';
        // final isNegative = number.isNegative;

        // // From https://github.com/dart-lang/sdk/issues/32803
        // var x = number.abs();
        // final numBytes = (x.bitLength + 7) >> 3;
        // final b256 = BigInt.from(256);
        // final bytes = Uint8List(numBytes);
        // for (var i = 0; i < numBytes; i++) {
        //   bytes[i] = x.remainder(b256).toInt();
        //   x = x >> 8;
        // }

        // return Fields({
        //   0: isNegative,
        //   1: bytes,
        // });
      },
      fromBytes: (bytes) {
        throw 'Implement taper for BigInt.';
        // final isNegative = fields.get<bool>(0, orDefault: false);
        // final bytes = fields.get<List<int>>(1);

        // // From https://github.com/dart-lang/sdk/issues/32803
        // BigInt read(int start, int end) {
        //   if (end - start <= 4) {
        //     var result = 0;
        //     for (var i = end - 1; i >= start; i--) {
        //       result = result * 256 + bytes[i];
        //     }
        //     return BigInt.from(result);
        //   }
        //   final mid = start + ((end - start) >> 1);
        //   final result = read(start, mid) +
        //       read(mid, end) * (BigInt.one << ((mid - start) * 8));
        //   return result;
        // }

        // final absolute = read(0, bytes.length);
        // return isNegative ? -absolute : absolute;
      },
    );
  }*/
}

extension TaperForDateTime on TaperNamespace {
  Taper<DateTime> forDateTime() {
    return MapTaper(
      toMap: (dateTime) {
        return {
          'isUtc': dateTime.isUtc,
          'microsecondsSinceEpoch': dateTime.microsecondsSinceEpoch,
        };
      },
      fromMap: (map) {
        return DateTime.fromMicrosecondsSinceEpoch(
          map['microsecondsSinceEpoch'] as int,
          isUtc: map['isUtc'] as bool,
        );
      },
    );
  }
}

extension ReferenceToDateTime on Reference<DateTime> {
  Reference<int> get microsecondsSinceEpoch => child('microsecondsSinceEpoch');
  Reference<bool> get isUtc => child('isUtc');
}

extension TaperForDuration on TaperNamespace {
  Taper<Duration> forDuration() {
    return MapTaper(
      toMap: (duration) => {'microseconds': duration.inMicroseconds},
      fromMap: (map) {
        return Duration(microseconds: map['microseconds'] as int);
      },
    );
  }
}

extension ReferenceToDuration on Reference<Duration> {
  Reference<int> get microseconds => child('microseconds');
}

extension TaperForList on TaperNamespace {
  Taper<List<T>> forList<T>() {
    return MapTaper(
      toMap: (list) => {for (var i = 0; i < list.length; i++) i: list[i]},
      fromMap: (map) => <T>[for (var i = 0; i < map.length; i++) map[i] as T],
    );
  }
}

extension ReferenceToList<T> on Reference<List<T>> {
  Reference<T> operator [](int index) => child(index);
}

extension TaperForMap on TaperNamespace {
  Taper<Map<K, V>> forMap<K, V>() {
    return MapTaper(toMap: (map) => map, fromMap: (map) => map.cast<K, V>());
  }
}

extension ReferenceToMap<K, V> on Reference<Map<K, V>> {
  Reference<V> operator [](K key) => child(key, createImplicitly: true);
}

extension TaperForSet on TaperNamespace {
  Taper<Set<T>> forSet<T>() {
    return MapTaper(
      toMap: (set) => {for (final key in set) key: null},
      fromMap: (map) => map.values.cast<T>().toSet(),
    );
  }
}

extension ReferenceToSet<T> on Reference<Set<T>> {
  bool contains(T value) => child(value, createImplicitly: false).exists;
}
