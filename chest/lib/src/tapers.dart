import 'blocks.dart';
import 'registry.dart';

/// A converter between [Object]s and [Block]s.
abstract class Taper<T> {
  const Taper();
  Type get type => T;

  void registerForTypeCode(int typeCode) =>
      registry.registerSingle(typeCode, this);

  /// Turns the [value] into [BlockData].
  BlockData toData(T value);

  /// Creates the [T] from [BlockData].
  T fromData(BlockData data);
}

abstract class BlockData {}

class MapBlockData extends BlockData {
  MapBlockData(this.map);
  final Map<Object?, Object?> map;
}

class BytesBlockData extends BlockData {
  BytesBlockData(this.bytes);
  final List<int> bytes;
}

/// A [Taper] that turns an object into bytes.
abstract class MapTaper<T> extends Taper<T> {
  const MapTaper();

  Map<Object?, Object?> toMap(T value);
  T fromMap(Map<Object?, Object?> fields);

  BlockData toData(T value) {
    return MapBlockData(toMap(value)
        .map((key, value) => MapEntry(key.toBlock(), value.toBlock())));
  }

  T fromData(BlockData data) {
    if (data is! MapBlockData) {
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

  BlockData toData(T value) => BytesBlockData(toBytes(value));
  T fromData(BlockData data) {
    if (data is! BytesBlockData) {
      throw 'Expected BytesBlockData, got ${data.runtimeType}';
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

  T fromBlock(Block block) {
    if (block is! MapBlock) {
      throw 'Expected MapBlock, got ${block.runtimeType}';
    }
    final fieldsAsBlocks = block.entries.toList();
    final fields = <String, Object>{};
    for (final field in fieldsAsBlocks) {
      final key = field.key.toObject();
      if (key is! String) {
        throw 'Key was not a String: $key';
      }
      fields[key] = field.value.toObject();
    }
    return fromFields(fields);
  }
}

/// Namespace for single, user-defined tapers.
const taper = TaperApi();

class TaperApi {
  const TaperApi();
}

/// Namespace for tapers for a package.
const tapers = TapersForPackageApi();

class TapersForPackageApi {
  const TapersForPackageApi();
}

/// Main API for the tape part.
const tape = TapeApi();

class TapeApi {
  const TapeApi();

  void register(Map<int, Taper<dynamic>> typeCodesToTapers) {
    registry.register(typeCodesToTapers);
  }

  bool get isInitialized => registry.hasTapers;
}
