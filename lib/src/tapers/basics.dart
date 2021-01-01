import '../tapers.dart';

export '../api.dart';
export '../chest.dart';
export '../tapers.dart';

/// A [Taper] that turns a value into a `Map<Object?, Object?>`.
abstract class MapTaper<T> extends Taper<T> {
  const MapTaper();

  Map<Object?, Object?> toMap(T value);
  T fromMap(Map<Object?, Object?> fields);

  TapeData toData(T value) {
    return MapTapeData(toMap(value).map((key, value) => MapEntry(key, value)));
  }

  T fromData(TapeData data) {
    if (data is! MapTapeData) {
      throw 'Expected MapTapeData, got ${data.runtimeType}';
    }
    return fromMap(data.map.cast<String, Object?>());
  }
}

/// A [Taper] that turns a value into a `List<int>` containing bytes.
abstract class BytesTaper<T> extends Taper<T> {
  const BytesTaper();

  List<int> toBytes(T value);
  T fromBytes(List<int> bytes);

  TapeData toData(T value) => BytesTapeData(toBytes(value));
  T fromData(TapeData data) {
    if (data is! BytesTapeData) {
      throw 'Expected BytesTapeData, got ${data.runtimeType}';
    }
    return fromBytes(data.bytes);
  }
}

/// A [Taper] that turns an object into a `Map<String, Object?>`. Especially
/// useful for classes.
abstract class ClassTaper<T> extends MapTaper<T> {
  const ClassTaper();

  Map<String, Object?> toFields(T value);
  T fromFields(Map<String, Object?> fields);

  Map<Object?, Object?> toMap(T value) => toFields(value);
  T fromMap(Map<Object?, Object?> map) {
    if (map is! Map<String, Object?>) {
      throw 'Expected class map to have String keys, but type is '
          "${map.runtimeType}. Here's the value: $map";
    }
    return fromFields(map);
  }
}
