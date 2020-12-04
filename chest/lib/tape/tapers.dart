import 'package:chest/tape/registry.dart';

import 'blocks.dart';

/// A converter between [Object]s and [Block]s.
abstract class Taper<T> {
  String get name;
  Type get type => T;

  void registerForTypeCode(int typeCode) =>
      registry.registerSingle(typeCode, this);

  Block toBlock(T value);
  T fromBlock(Block block);
}

/// A [Taper] that turns an object into a map. Especially useful for classes.
abstract class ClassTaper<T> extends Taper<T> {
  Map<String, Object> toFields(T value);
  T fromFields(Map<String, Object> fields);

  Block toBlock(T value) {
    final fields = toFields(value).entries.toList();
    final typeCode = registry.taperToTypeCode(this);
    if (typeCode == null) {
      throw 'This taper is not registered: $this';
    }
    return DefaultMapBlock(typeCode, {
      for (final field in fields) field.key.toBlock(): field.value.toBlock(),
    });
  }

  T fromBlock(Block block) {
    if (block is! MapBlock) {
      throw 'Expected MapBlock, got ${block.runtimeType}';
    }
    final fieldsAsBlocks = block.map.entries.toList();
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

/// A [Taper] that turns an object into bytes.
abstract class BytesTaper<T> extends Taper<T> {
  List<int> toBytes(T value);
  T fromBytes(List<int> bytes);

  Block toBlock(T value) {
    final typeCode = registry.taperToTypeCode(this);
    if (typeCode == null) {
      throw 'This taper is not registered: $this';
    }
    return DefaultBytesBlock(typeCode, toBytes(value));
  }

  T fromBlock(Block block) {
    if (block is! BytesBlock) {
      throw 'Expected BytesBlock, got ${block.runtimeType}';
    }
    return fromBytes(block.bytes);
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
}
