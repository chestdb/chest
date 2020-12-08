import 'dart:typed_data';

import 'bytes.dart';
import 'registry.dart';
import 'tapers.dart';
import 'utils.dart';

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

  Block? operator [](Block key);
  operator []=(Block key, Block value);
  List<MapEntry<Block, Block>> get entries;

  MapBlock copyWith(Map<Block, Block> changes) {
    final entries = this.entries.toMap();
    for (final entry in changes.entries) {
      entries[entry.key] = entry.value;
    }
    return DefaultMapBlock(typeCode, entries);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MapBlock) return false;
    if (typeCode != other.typeCode) return false;
    final entries = this.entries;
    final otherEntries = other.entries;
    if (entries.length != otherEntries.length) return false;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i] != otherEntries[i]) return false;
    }
    return true;
  }

  // TODO: Better hashCode.
  int get hashCode => 0;

  @override
  int compareTo(Block other) {
    if (identical(this, other)) return 0;

    var result = typeCode.compareTo(other.typeCode);
    if (result != 0) return result;

    if (other is! MapBlock) return -1;

    final entries = this.entries;
    final otherEntries = other.entries;

    result = entries.length.compareTo(otherEntries.length);
    if (result != 0) return result;

    for (var i = 0; i < entries.length; i++) {
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
    for (final entry in entries) {
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

  // TODO: Better hashCode.
  int get hashCode => 0;

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

  Block? operator [](Block key) => map[key];
  operator []=(Block key, Block value) => map[key] = value;
  List<MapEntry<Block, Block>> get entries => map.entries.toList();
}

class DefaultBytesBlock extends BytesBlock {
  DefaultBytesBlock(this.typeCode, this.bytes);

  final int typeCode;
  final List<int> bytes;
}

abstract class BlockView implements Block {
  int get offset;

  static BlockView of(ByteBuffer buffer) {
    return at(Data(ByteData.view(buffer)), 0);
  }

  static BlockView at(Data data, int offset) {
    final blockKind = data.getBlockKind(offset + 8);
    if (blockKind == blockKindMap) {
      return MapBlockView(data, offset);
    } else if (blockKind == blockKindBytes) {
      return BytesBlockView(data, offset);
    } else {
      throw 'Unknown block kind $blockKind.';
    }
  }
}

// Lazy block implementations that looks up data in a [_Data].

class MapBlockView extends MapBlock implements BlockView {
  MapBlockView(this.data, this.offset);

  final Data data;
  final int offset;

  @override
  int get typeCode => data.getTypeCode(offset);

  int get length => data.getLength(offset + 8 + 1);

  Block? operator [](Block key) {
    final index = _getIndexOfKey(key);
    if (index == null) return null;
    return _getValueAt(index);
  }

  operator []=(Block key, Block value) =>
      (throw "Can't assign to MapBlockView.");

  List<MapEntry<BlockView, BlockView>> get entries {
    final length = this.length;
    return <MapEntry<BlockView, BlockView>>[
      for (var i = 0; i < length; i++) MapEntry(_getKeyAt(i), _getValueAt(i)),
    ];
  }

  int? _getIndexOfKey(Block key) {
    var left = 0;
    var right = length;
    while (left < right) {
      final middleIndex = (left + right) ~/ 2;
      final middleBlock = _getKeyAt(middleIndex);
      final comparison = middleBlock.compareTo(key);
      if (comparison == 0) {
        return middleIndex;
      } else if (comparison < 0) {
        left = middleIndex + 1;
      } else {
        right = middleIndex;
      }
    }
    return null;
  }

  BlockView _getKeyAt(int index) =>
      BlockView.at(data, data.getPointer(offset + 8 + 1 + 8 + 16 * index));
  BlockView _getValueAt(int index) =>
      BlockView.at(data, data.getPointer(offset + 8 + 1 + 8 + 16 * index + 8));
}

class BytesBlockView extends BytesBlock implements BlockView {
  BytesBlockView(this.data, this.offset);

  final Data data;
  final int offset;

  @override
  int get typeCode => data.getTypeCode(offset);

  @override
  List<int> get bytes {
    final length = data.getLength(offset + 8 + 1);
    return Uint8List.view(data.data.buffer, offset + 8 + 1 + 8, length);
  }
}

// Conversion methods between objects and [Block]s.

extension ObjectToBlock on Object? {
  Block toBlock() {
    final taper = registry.valueToTaper(this);
    if (taper == null) {
      throw 'No taper found for type $runtimeType.';
    }
    final typeCode = registry.taperToTypeCode(taper)!;
    final data = taper.toData(this);
    if (data is MapBlockData) {
      return DefaultMapBlock(
        typeCode,
        data.map.map((key, value) => MapEntry(key.toBlock(), value.toBlock())),
      );
    } else if (data is BytesBlockData) {
      return DefaultBytesBlock(typeCode, data.bytes);
    } else {
      throw 'Tapers should always return either a MapBlockData or BytesBlockData';
    }
  }
}

extension BlockToObject on Block {
  Object toObject() {
    final taper = registry.typeCodeToTaper(typeCode);
    if (taper == null) {
      throw 'No taper found for type code $typeCode.';
    }
    BlockData data;
    Block this_ = this;
    if (this_ is MapBlock) {
      data = MapBlockData(this_.entries.toMap());
    } else if (this_ is BytesBlock) {
      data = BytesBlockData(this_.bytes);
    } else {
      throw 'Expected MapBlock or BytesBlock, but this is a $runtimeType.';
    }
    return taper.fromData(data);
  }
}
