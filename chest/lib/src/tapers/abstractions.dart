/*/// A [Taper] that turns an object into bytes.
abstract class MapTaper<T> extends Taper<T> {
  const MapTaper();

  Map<Object?, Object?> toMap(T value);
  T fromMap(Map<Object?, Object?> fields);

  TapeData toData(T value) {
    return MapTapeData(toMap(value)
        .map((key, value) => MapEntry(key.toBlock(), value.toBlock())));
  }

  T fromData(TapeData data) {
    if (data is! MapTapeData) {
      throw 'Expected Map<Object?, Object?>, got ${data.runtimeType}';
    }
    return fromMap(data.map);
  }
}

/// A [Taper] that turns an object into bytes.
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
      throw 'Expected class map to have String keys, but type is $map';
    }
    return fromFields(map);
  }
}
*/
