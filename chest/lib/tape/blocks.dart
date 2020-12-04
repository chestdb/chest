import 'registry.dart';

/// An intermediary format that is well-understood, has value semantics, and is
/// guaranteed to be transferrable between [Isolate]s.
abstract class Block implements Comparable<Block> {
  const Block();

  int get typeCode;

  A cast<A>() {
    if (this is A) {
      return this as A;
    } else {
      throw 'Block type not expected';
    }
  }

  @override
  String toString([int indentation]);
}

/// A block that can contain a map from blocks to other blocks.
abstract class MapBlock extends Block {
  const MapBlock();

  Map<Block, Block> get map;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MapBlock) return false;
    if (typeCode != other.typeCode) return false;
    final entries = map.entries.toList();
    final otherEntries = other.map.entries.toList();
    if (entries.length != otherEntries.length) return false;
    for (var i = 0; i < map.length; i++) {
      if (entries[i] != otherEntries[i]) return false;
    }
    return true;
  }

  // TODO: Override hashCode

  @override
  int compareTo(Block other) {
    if (identical(this, other)) return 0;

    var result = typeCode.compareTo(other.typeCode);
    if (result != 0) return result;

    if (other is! MapBlock) return -1;

    final entries = map.entries.toList();
    final otherEntries = other.map.entries.toList();

    result = map.length.compareTo(otherEntries.length);
    if (result != 0) return result;

    for (var i = 0; i < map.length; i++) {
      final entry = entries[i];
      final otherEntry = otherEntries[i];

      result = entry.key.compareTo(otherEntry.key);
      if (result != 0) return result;

      result = entry.value.compareTo(otherEntry.value);
      if (result != 0) return result;
    }

    return 0;
  }

  @override
  String toString([int indentation = 0]) {
    final buffer = StringBuffer()..writeln('MapBlock($typeCode, {');
    for (final entry in map.entries) {
      buffer
        ..write(' ' * (indentation + 1))
        ..write(entry.key.toString(indentation + 1))
        ..write(': ')
        ..write(entry.value.toString(indentation + 1))
        ..writeln(',');
    }
    buffer..write(' ' * indentation)..write('})');
    return buffer.toString();
  }
}

/// A block that contains some bytes.
abstract class BytesBlock extends Block {
  const BytesBlock();

  List<int> get bytes;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BytesBlock) return false;
    if (typeCode != other.typeCode) return false;
    final bytes = this.bytes;
    final otherBytes = other.bytes;
    if (bytes.length != otherBytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != otherBytes[i]) return false;
    }
    return true;
  }

  // TODO: Override hashCode

  @override
  int compareTo(Block other) {
    if (identical(this, other)) return 0;

    var result = typeCode.compareTo(other.typeCode);
    if (result != 0) return result;

    if (other is! BytesBlock) return -1;

    final bytes = this.bytes;
    final otherBytes = other.bytes;

    result = bytes.length.compareTo(otherBytes.length);
    if (result != 0) return result;

    for (var i = 0; i < bytes.length; i++) {
      result = bytes[i].compareTo(otherBytes[i]);
      if (result != 0) return result;
    }

    return 0;
  }

  String toString([int indentation = 0]) {
    return 'BytesBlock($typeCode, ${bytes.map((byte) => byte.toRadixString(16)).join(' ')})';
  }
}

// Default, straight-forward block implementations that keep everything in
// memory as Dart objects.

class DefaultMapBlock extends MapBlock {
  DefaultMapBlock(this.typeCode, this.map);

  final int typeCode;
  final Map<Block, Block> map;
}

class DefaultBytesBlock extends BytesBlock {
  DefaultBytesBlock(this.typeCode, this.bytes);

  final int typeCode;
  final List<int> bytes;
}

// Conversion methods between objects and [Block]s.

extension ObjectToBlock on Object? {
  Block toBlock() {
    final taper = registry.valueToTaper(this);
    if (taper == null) {
      throw 'No taper found for type $runtimeType.';
    }
    return taper.toBlock(this);
  }
}

extension BlockToObject on Block {
  Object toObject() {
    final taper = registry.typeCodeToTaper(typeCode);
    if (taper == null) {
      throw 'No taper found for type code $typeCode.';
    }
    return taper.fromBlock(this);
  }
}
