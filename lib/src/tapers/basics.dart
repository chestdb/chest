import '../tapers.dart';
import '../utils.dart';

export '../api.dart';
export '../chest.dart';
export '../tapers.dart';

class _InlineTaper<T> extends Taper<T> {
  const _InlineTaper({
    required TapeData Function(T value) toData,
    required T Function(TapeData data) fromData,
    this.isLegacy = false,
  })  : _toData = toData,
        _fromData = fromData;

  final TapeData Function(T value) _toData;
  final T Function(TapeData data) _fromData;
  final bool isLegacy;

  @override
  TapeData toData(T value) => _toData(value);

  @override
  T fromData(TapeData data) => _fromData(data);
}

/// A [Taper] that turns a value into bytes.
abstract class BytesTaper<T> extends Taper<T> {
  const BytesTaper();

  List<int> toBytes(T value);
  T fromBytes(List<int> bytes);

  @override
  BytesTapeData toData(T value) => BytesTapeData(toBytes(value));

  @override
  T fromData(TapeData data) {
    if (data is! BytesTapeData) {
      panic('Expected BytesTapeData, got ${data.runtimeType}.');
    }
    return fromBytes(data.bytes);
  }
}

/// A [Taper] that turns a value into a `Map<Object?, Object?>`.
abstract class MapTaper<T> extends Taper<T> {
  const MapTaper();

  Map<Object?, Object?> toMap(T value);
  T fromMap(Map<Object?, Object?> map);

  @override
  MapTapeData toData(T value) => MapTapeData(toMap(value));

  @override
  T fromData(TapeData data) {
    if (data is! MapTapeData) {
      panic('Expected MapTapeData, got ${data.runtimeType}.');
    }
    return fromMap(data.map);
  }
}
