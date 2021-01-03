import '../tapers.dart';

export '../api.dart';
export '../chest.dart';
export '../tapers.dart';

/// A [Taper] that turns a value into a `Map<Object?, Object?>`.
class MapTaper<T> extends Taper<T> {
  MapTaper({required this.toMap, required this.fromMap});

  final Map<Object?, Object?> Function(T value) toMap;
  final T Function(Map<Object?, Object?> fields) fromMap;

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
class BytesTaper<T> extends Taper<T> {
  BytesTaper({required this.toBytes, required this.fromBytes});

  final List<int> Function(T value) toBytes;
  final T Function(List<int> bytes) fromBytes;

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
class ClassTaper<T> extends MapTaper<T> {
  ClassTaper({required this.toFields, required this.fromFields})
      : super(
          toMap: (value) => toFields(value),
          fromMap: (map) {
            if (map is! Map<String, Object?>) {
              throw 'Expected class map to have String keys, but type is '
                  "${map.runtimeType}. Here's the value: $map";
            }
            return fromFields(map);
          },
        );

  final Map<String, Object?> Function(T value) toFields;
  final T Function(Map<String, Object?> fields) fromFields;
}

extension ReferenceToClass on Reference<dynamic> {
  field<T>(String name) => child(name) as T;
}
