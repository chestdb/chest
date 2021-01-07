import '../tapers.dart';
import '../utils.dart';

export '../api.dart';
export '../chest.dart';
export '../tapers.dart';

/// A [Taper] that turns a value into bytes.
Taper<T> BytesTaper<T>({
  required List<int> Function(T value) toBytes,
  required T Function(List<int> bytes) fromBytes,
  bool isLegacy = false,
}) {
  return Taper(
    toData: (value) => BytesTapeData(toBytes(value)),
    fromData: (data) {
      if (data is! BytesTapeData) {
        panic('Expected BytesTapeData, got ${data.runtimeType}.');
      }
      return fromBytes(data.bytes);
    },
    isLegacy: isLegacy,
  );
}

/// A [Taper] that turns a value into a `Map<Object?, Object?>`.
Taper<T> MapTaper<T>({
  required Map<Object?, Object?> Function(T value) toMap,
  required T Function(Map<Object?, Object?> fields) fromMap,
  bool isLegacy = false,
}) {
  return Taper(
    toData: (value) => MapTapeData(toMap(value)),
    fromData: (data) {
      if (data is! MapTapeData) {
        panic('Expected MapTapeData, got ${data.runtimeType}.');
      }
      return fromMap(data.map);
    },
    isLegacy: isLegacy,
  );
}
