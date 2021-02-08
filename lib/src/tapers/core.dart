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

/// [Null] is encoded to zero bytes, because a [null] value carries no
/// information (it's the initial type in the type category).
extension TaperForNull on TaperNamespace {
  // "Don't use the Null type, unless your are positive that you don't want void."
  // We are positive.
  // ignore: prefer_void_to_null
  Taper<Null> forNull() => _TaperForNull();
}

class _TaperForNull extends BytesTaper<Null> {
  const _TaperForNull();

  @override
  List<int> toBytes(Null _) => [];

  @override
  Null fromBytes(List<int> bytes) => null;
}

/// A [bool] is encoded using one byte that's either [1] for [true] or [0] for
/// [false].
extension TaperForBool on TaperNamespace {
  Taper<bool> forBool() => const _TaperForBool();
}

class _TaperForBool extends BytesTaper<bool> {
  const _TaperForBool();

  @override
  List<int> toBytes(bool value) => [value ? 1 : 0];

  @override
  bool fromBytes(List<int> bytes) => bytes.single != 0;
}

extension ReferenceToBool on Reference<bool> {
  void toggle() => value = !value;
}

/// [String]s are utf8-encoded.
extension TaperForString on TaperNamespace {
  Taper<String> forString() => const _TaperForString();
}

class _TaperForString extends BytesTaper<String> {
  const _TaperForString();

  @override
  List<int> toBytes(String string) => utf8.encode(string);

  @override
  String fromBytes(List<int> bytes) => utf8.decode(bytes);
}

/// [int]s are 64-bit integers in the DartVM.
extension TaperForInt on TaperNamespace {
  Taper<int> forInt() => const _TaperForInt();
}

class _TaperForInt extends BytesTaper<int> {
  const _TaperForInt();

  @override
  List<int> toBytes(int value) {
    final data = ByteData(8);
    data.setInt64(0, value);
    return Uint8List.view(data.buffer);
  }

  @override
  int fromBytes(List<int> bytes) {
    final data = ByteData(8);
    for (var i = 0; i < 8; i++) {
      data.setUint8(i, bytes[i]);
    }
    return data.getInt64(0);
  }
}

/// [double]s are 64-bit floating point number in the DartVM.
extension TaperForDouble on TaperNamespace {
  Taper<double> forDouble() => const _TaperForDouble();
}

class _TaperForDouble extends BytesTaper<double> {
  const _TaperForDouble();

  @override
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

extension _TaperForBigInt on TaperNamespace {
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

/// [DateTime]s are simply encoded as maps.
extension TaperForDateTime on TaperNamespace {
  Taper<DateTime> forDateTime() => const _TaperForDateTime();
}

class _TaperForDateTime extends MapTaper<DateTime> {
  const _TaperForDateTime();

  @override
  Map<Object?, Object?> toMap(DateTime dateTime) {
    return {
      'isUtc': dateTime.isUtc,
      'microsecondsSinceEpoch': dateTime.microsecondsSinceEpoch,
    };
  }

  @override
  DateTime fromMap(Map<Object?, Object?> map) {
    return DateTime.fromMicrosecondsSinceEpoch(
      map['microsecondsSinceEpoch'] as int,
      isUtc: map['isUtc'] as bool,
    );
  }
}

extension ReferenceToDateTime on Reference<DateTime> {
  Reference<int> get microsecondsSinceEpoch => child('microsecondsSinceEpoch');
  Reference<bool> get isUtc => child('isUtc');
}

/// [Duration]s are simply encoded using maps.
extension TaperForDuration on TaperNamespace {
  Taper<Duration> forDuration() => const _TaperForDuration();
}

class _TaperForDuration extends MapTaper<Duration> {
  const _TaperForDuration();

  @override
  Map<Object?, Object?> toMap(Duration duration) =>
      {'microseconds': duration.inMicroseconds};

  @override
  Duration fromMap(Map<Object?, Object?> map) =>
      Duration(microseconds: map['microseconds'] as int);
}

extension ReferenceToDuration on Reference<Duration> {
  Reference<int> get microseconds => child('microseconds');
}

/// [List]s are encoded as a map from indizes to values. That makes random
/// access to items possible. Inserting items in the middle of the list is quite
/// expensive, but that's okay because it's typically not done that often.
extension TaperForList on TaperNamespace {
  Taper<List<T>> forList<T>() => _TaperForList<T>();
}

class _TaperForList<T> extends MapTaper<List<T>> {
  @override
  Map<Object?, Object?> toMap(List<T> list) =>
      {for (var i = 0; i < list.length; i++) i: list[i]};

  @override
  List<T> fromMap(Map<Object?, Object?> map) =>
      <T>[for (var i = 0; i < map.length; i++) map[i] as T];
}

extension ReferenceToList<T> on Reference<List<T>> {
  int get length => numberOfChildren;
  bool get isEmpty => length == 0;
  bool get isNotEmpty => !isEmpty;

  Reference<T> operator [](int index) => child(index);

  void add(T item) => child<T>(length, createImplicitly: true).value = item;
  void removeLast() => child<T>(length - 1).remove();

  Iterable<Reference<T>> get references sync* {
    final length = this.length;
    for (var i = 0; i < length; i++) {
      yield this[i];
    }
  }
}

/// [Map]s are obviously encoded as maps. No surprise there.
extension TaperForMap on TaperNamespace {
  Taper<Map<K, V>> forMap<K, V>() => _TaperForMap<K, V>();
}

class _TaperForMap<K, V> extends MapTaper<Map<K, V>> {
  @override
  Map<Object?, Object?> toMap(Map<K, V> map) => map;

  @override
  Map<K, V> fromMap(Map<Object?, Object?> map) => map.cast<K, V>();
}

extension ReferenceToMap<K, V> on Reference<Map<K, V>> {
  int get length => numberOfChildren;
  bool get isEmpty => length == 0;
  bool get isNotEmpty => !isEmpty;

  bool containsKey(K key) => child<V>(key).exists;
  Reference<V> operator [](K key) => child<V>(key, createImplicitly: true);

  void put(K key, V value) => this[key].value = value;

  V? remove(K key) {
    final value = containsKey(key) ? this[key].value : null;
    this[key].remove();
    return value;
  }

  V putIfAbsent(K key, V Function() ifAbsent) {
    if (containsKey(key)) return this[key].value;
    final value = ifAbsent();
    this[key].value = value;
    return value;
  }
}

/// [Set]s are encoded as maps from elements to [Null].
extension TaperForSetExtension on TaperNamespace {
  Taper<Set<T>> forSet<T>() => TaperForSet<T>();
}

class TaperForSet<T> extends MapTaper<Set<T>> {
  @override
  Map<Object?, Object?> toMap(Set<T> set) => {for (final key in set) key: true};

  @override
  Set<T> fromMap(Map<Object?, Object?> map) => map.entries
      .where((entry) => entry.value as bool)
      .map((entry) => entry.key as T)
      .toSet();
}

extension ReferenceToSet<T> on Reference<Set<T>> {
  int get length => numberOfChildren;
  bool get isEmpty => length == 0;
  bool get isNotEmpty => !isEmpty;

  bool contains(T element) => child<Null>(element).exists;
  Reference<void> operator [](T element) => child(element);

  void add(T element) =>
      child<Null>(element, createImplicitly: true).value = null;

  void remove(T element) => this[element].remove();

  void toggle(T element) {
    if (contains(element)) {
      remove(element);
    } else {
      add(element);
    }
  }
}
