import 'dart:convert';
import 'dart:typed_data';

import 'basics.dart';

extension TapersPackageForDartCore on TapersForPackageApi {
  Map<int, Taper<dynamic>> forDartCore() {
    return {
      -1: taper.forNull(),
      -2: taper.forBool(),
      -3: taper.forString(),
      -4: taper.forInt(),
      -5: taper.forDouble(),
      // -6: taper.forBigInt(),
      -7: taper.forDateTime(),
      -8: taper.forDuration(),
      -9: taper.forList<bool>(),
      -10: taper.forList<String>(),
      -11: taper.forList<int>(),
      -12: taper.forList<double>(),
      // -13: taper.forList<BigInt>(),
      -14: taper.forMap<String, bool>(),
      -15: taper.forMap<String, String>(),
      -16: taper.forMap<String, int>(),
      -17: taper.forMap<String, double>(),
      // -18: taper.forMap<String, BigInt>(),
      -19: taper.forMap<int, bool>(),
      -20: taper.forMap<int, String>(),
      -21: taper.forMap<int, int>(),
      -22: taper.forMap<int, double>(),
      // -23: taper.forMap<int, BigInt>(),
      // -24: taper.forMap<BigInt, bool>(),
      // -25: taper.forMap<BigInt, String>(),
      // -26: taper.forMap<BigInt, int>(),
      // -27: taper.forMap<BigInt, double>(),
      // -28: taper.forMap<BigInt, BigInt>(),
    };
  }
}

extension TapersForForDartCore on TaperApi {
  Taper<Null> forNull() => _TaperForNull();
  Taper<bool> forBool() => _TaperForBool();
  Taper<String> forString() => _TaperForString();
  Taper<int> forInt() => _TaperForInt();
  Taper<double> forDouble() => _TaperForDouble();
  // Taper<BigInt> forBigInt() => _TaperForBigInt();
  Taper<DateTime> forDateTime() => _TaperForDateTime();
  Taper<Duration> forDuration() => _TaperForDuration();
  Taper<List<T>> forList<T>() => _TaperForList<T>();
  Taper<Map<K, V>> forMap<K, V>() => _TaperForMap<K, V>();
}

// "Don't use the Null type, unless your are positive that you don't want void."
// We are positive.
// ignore: prefer_void_to_null
class _TaperForNull extends BytesTaper<Null> {
  const _TaperForNull();

  List<int> toBytes(Null _) => [];
  Null fromBytes(List<int> _) => null;
}

class _TaperForBool extends BytesTaper<bool> {
  const _TaperForBool();

  List<int> toBytes(bool value) => [value ? 1 : 0];
  bool fromBytes(List<int> bytes) => bytes.single != 0;
}

class _TaperForString extends BytesTaper<String> {
  const _TaperForString();

  List<int> toBytes(String value) => utf8.encode(value);
  String fromBytes(List<int> bytes) => utf8.decode(bytes);
}

class _TaperForInt extends BytesTaper<int> {
  const _TaperForInt();

  List<int> toBytes(int value) {
    final data = ByteData(8);
    data.setInt64(0, value);
    return Uint8List.view(data.buffer);
  }

  int fromBytes(List<int> bytes) {
    final data = ByteData(8);
    for (var i = 0; i < 8; i++) {
      data.setUint8(i, bytes[i]);
    }
    return data.getInt64(0);
  }
}

class _TaperForDouble extends BytesTaper<double> {
  const _TaperForDouble();

  List<int> toBytes(double value) {
    final data = ByteData(8);
    data.setFloat64(0, value);
    return Uint8List.view(data.buffer);
  }

  double fromBytes(List<int> bytes) {
    final data = ByteData(8);
    for (var i = 0; i < 8; i++) {
      data.setUint8(i, bytes[i]);
    }
    return data.getFloat64(0);
  }
}

/*class _TaperForBigInt extends BytesTaper<BigInt> {
  const _TaperForBigInt();

  List<int> toBytes(BigInt value) {
    final isNegative = number.isNegative;

    // From https://github.com/dart-lang/sdk/issues/32803
    var x = number.abs();
    final numBytes = (x.bitLength + 7) >> 3;
    final b256 = BigInt.from(256);
    final bytes = Uint8List(numBytes);
    for (var i = 0; i < numBytes; i++) {
      bytes[i] = x.remainder(b256).toInt();
      x = x >> 8;
    }

    return Fields({
      0: isNegative,
      1: bytes,
    });
  }

  @override
  BigInt fromBytes(List<int> bytes) {
    final isNegative = fields.get<bool>(0, orDefault: false);
    final bytes = fields.get<List<int>>(1);

    // From https://github.com/dart-lang/sdk/issues/32803
    BigInt read(int start, int end) {
      if (end - start <= 4) {
        var result = 0;
        for (var i = end - 1; i >= start; i--) {
          result = result * 256 + bytes[i];
        }
        return BigInt.from(result);
      }
      final mid = start + ((end - start) >> 1);
      final result = read(start, mid) +
          read(mid, end) * (BigInt.one << ((mid - start) * 8));
      return result;
    }

    final absolute = read(0, bytes.length);
    return isNegative ? -absolute : absolute;
  }
}*/

class _TaperForDateTime extends ClassTaper<DateTime> {
  const _TaperForDateTime();

  @override
  Map<String, Object> toFields(DateTime value) {
    return {
      'isUtc': value.isUtc,
      'microsecondsSinceEpoch': value.microsecondsSinceEpoch,
    };
  }

  @override
  DateTime fromFields(Map<String, Object?> fields) {
    return DateTime.fromMicrosecondsSinceEpoch(
      fields['microsecondsSinceEpoch'] as int,
      isUtc: fields['isUtc'] as bool,
    );
  }
}

extension ChildrenOfDateTime on Ref<DateTime> {
  Ref<int> get microsecondsSinceEpoch => child('microsecondsSinceEpoch');
  Ref<bool> get isUtc => child('isUtc');
}

class _TaperForDuration extends ClassTaper<Duration> {
  const _TaperForDuration();

  @override
  Map<String, Object> toFields(Duration value) {
    return {'microseconds': value.inMicroseconds};
  }

  @override
  Duration fromFields(Map<String, Object?> fields) {
    return Duration(microseconds: fields['microseconds'] as int);
  }
}

extension ChildrenOfDuration on Ref<Duration> {
  Ref<int> get microseconds => child('microseconds');
}

class _TaperForList<T> extends MapTaper<List<T>> {
  const _TaperForList();

  @override
  Map<int, T> toMap(List<T> list) {
    return {for (var i = 0; i < list.length; i++) i: list[i]};
  }

  @override
  List<T> fromMap(Map<Object?, Object?> map) {
    return <T>[for (var i = 0; i < map.length; i++) map[i] as T];
  }
}

extension ChildrenOfList<T> on Ref<List<T>> {
  Ref<T> operator [](int index) => child(index);
}

class _TaperForMap<K, V> extends MapTaper<Map<K, V>> {
  const _TaperForMap();

  @override
  Map<Object?, Object?> toMap(Map<K, V> value) => value;

  @override
  Map<K, V> fromMap(Map<Object?, Object?> map) => map.cast<K, V>();
}

extension ChildrenOfMap<K, V> on Ref<Map<K, V>> {
  Ref<V> operator [](K key) => child(key, createImplicitly: true);
}
