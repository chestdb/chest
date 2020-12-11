/*import 'dart:typed_data';

import 'blocks.dart';
import 'utils.dart';

/// Blocks are encoded like this:
///
/// Map:   type code | 0 | length | key | value | key | value | ...
///        Note: The keys and values are pointers to other blocks.
///        The entries are sorted by keys (not by the pointers, but the values
///        they point to).
/// Bytes: type code | 1 | length | bytes
///
/// For example, the object `User(name: 'Marcel', pet: Pet(name: 'Blub'))` might
/// be encoded like this (note that for clarity, the block kind and length are
/// omitted and strings are used to represent their byte encoding):
///
///   +--->--->-+---<---<---<---<---<---<---<---<---+
///   |     +---|--->--->--->--->--->--->--->--->-+ |
///   |     |   V                                 V |
/// 0 k v k v | 1 'name' | 1 'pet' | 1 'Marcel' | 2 k v | 1 'Blub'
///     | |                ^         ^                |   ^
///     | +--->--->--->--->+         |                +---+
///     +--->--->--->--->--->--->--->+
///
/// Here are a few properties of this encoding:
///
/// * The object's inner things come after the object itself, the encoding is
///   not recursive (although its implementation is). That means, you can access
///   an objects property without decoding the whole object.
///   In the example above, if we are interested only in the pet, we could
///   search through the keys, comparing our key ('pet') to the encoded ones
///   by following the pointers. As soon as we find the 'pet' key, we can follow
///   the value pointer and only decode the pet without ever touching the
///   `User`'s name.
/// * Because a map's keys are sorted by their content, they can be compared
///   in O(log n) using binary search.
/// * Because keys are encoded before values because of cache-locality of the
///   binary search.

const blockKindMap = 0;
const blockKindBytes = 1;

extension BlockToBytes on Block {
  Uint8List toBytes() {
    // TODO: Don't hardcode the length.
    final data = Data(ByteData(1024));
    // TODO: Make this a set and use the contains method as soon as hashCode is overridden.
    final registry = <BlockView>[];

    /// Serializes a block and returns its offset.
    int serialize(Block block) {
      final start = data.cursor;
      data.addTypeCode(block.typeCode);
      if (block is MapBlock) {
        data.addBlockKind(blockKindMap);
        final entries = block.entries;
        data.addLength(entries.length);
        final entriesStart = data.cursor;
        data.cursor += 16 * entries.length;
        for (var i = 0; i < entries.length; i++) {
          final keyOffset = serialize(entries[i].key);
          data.setPointer(entriesStart + 16 * i, keyOffset);
        }
        for (var i = 0; i < entries.length; i++) {
          final valueOffset = serialize(entries[i].value);
          data.setPointer(entriesStart + 16 * i + 8, valueOffset);
        }
        // Sort entries.
        final sortedMapEntries = BlockView.at(data, start)
            .cast<MapBlockView>()
            .entries
          ..sort((a, b) => a.key.compareTo(b.key));
        for (var i = 0; i < sortedMapEntries.length; i++) {
          final entry = sortedMapEntries[i];
          data
            ..setPointer(start + 8 + 1 + 8 + 16 * i, entry.key.offset)
            ..setPointer(start + 8 + 1 + 8 + 16 * i + 8, entry.value.offset);
        }
      } else if (block is BytesBlock) {
        data.addBlockKind(blockKindBytes);
        final bytes = block.bytes;
        data.addLength(bytes.length);
        bytes.forEach(data.addByte);
      } else {
        throw 'Unknown block $block.';
      }
      final thisBlock = BlockView.at(data, start);
      for (final otherBlock in registry) {
        if (thisBlock == otherBlock) {
          data.cursor = start;
          return otherBlock.offset;
        }
      }
      registry.add(thisBlock);
      return start;
    }

    serialize(this);
    return Uint8List.view(data.data.buffer, 0, data.cursor);
  }
}

extension BytesToBlock on Uint8List {
  Block toBlock() {
    final data = Data(ByteData.view(buffer));
    return BlockView.at(data, 0);
  }
}

// Lazy block implementations that looks up data in a [_Data].

// Block views.

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
*/
