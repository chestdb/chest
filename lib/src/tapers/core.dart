import 'dart:convert';
import 'dart:typed_data';

import 'basics.dart';

extension TapersPackageForDartCore on TapersForPackageApi {
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
  Taper<Set<T>> forSet<T>() => _TaperForSet<T>();
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

extension UtilsForRefOfBool on Reference<bool> {
  void toggle() => value = !value;
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

extension ChildrenOfDateTime on Reference<DateTime> {
  Reference<int> get microsecondsSinceEpoch => child('microsecondsSinceEpoch');
  Reference<bool> get isUtc => child('isUtc');
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

extension ChildrenOfDuration on Reference<Duration> {
  Reference<int> get microseconds => child('microseconds');
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

extension ChildrenOfList<T> on Reference<List<T>> {
  Reference<T> operator [](int index) => child(index);
}

class _TaperForMap<K, V> extends MapTaper<Map<K, V>> {
  const _TaperForMap();

  @override
  Map<Object?, Object?> toMap(Map<K, V> value) => value;

  @override
  Map<K, V> fromMap(Map<Object?, Object?> map) => map.cast<K, V>();
}

extension ChildrenOfMap<K, V> on Reference<Map<K, V>> {
  Reference<V> operator [](K key) => child(key, createImplicitly: true);
}

class _TaperForSet<T> extends MapTaper<Set<T>> {
  const _TaperForSet();

  @override
  Map<Object?, Object?> toMap(Set<T> value) =>
      {for (final key in value) key: null};

  @override
  Set<T> fromMap(Map<Object?, Object?> map) => map.values.cast<T>().toSet();
}

extension ChildrenOfSet<T> on Reference<Set<T>> {
  bool contains(T value) => child(value, createImplicitly: false).exists;
}