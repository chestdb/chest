import 'dart:typed_data';

import 'blocks.dart';

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

const _blockKindMap = 0;
const _blockKindBytes = 1;

abstract class BlockView implements Block {
  int get offset;

  static BlockView at(_Data data, int offset) {
    final blockKind = data.getBlockKind(offset + 8);
    if (blockKind == _blockKindMap) {
      return MapBlockView(data, offset);
    } else if (blockKind == _blockKindBytes) {
      return BytesBlockView(data, offset);
    } else {
      throw 'Unknown block kind $blockKind.';
    }
  }
}

class MapBlockView extends MapBlock implements BlockView {
  MapBlockView(this.data, this.offset);

  final _Data data;
  final int offset;

  @override
  int get typeCode => data.getTypeCode(offset);

  int get length => data.getLength(offset + 8 + 1);

  @override
  Map<BlockView, BlockView> get map {
    final length = this.length;
    return <BlockView, BlockView>{
      for (var i = 0; i < length; i++)
        BlockView.at(data, data.getPointer(offset + 8 + 1 + 8 + 16 * i)):
            BlockView.at(
                data, data.getPointer(offset + 8 + 1 + 8 + 16 * i + 8)),
    };
  }
}

class BytesBlockView extends BytesBlock implements BlockView {
  BytesBlockView(this.data, this.offset);

  final _Data data;
  final int offset;

  @override
  int get typeCode => data.getTypeCode(offset);

  @override
  List<int> get bytes {
    final length = data.getLength(offset + 8 + 1);
    return Uint8List.view(data.data.buffer, offset + 8 + 1 + 8, length);
  }
}

extension BlockToBytes on Block {
  Uint8List toBytes() {
    final data = _Data(ByteData(1024));
    // TODO: Make this a set and use the contains method as soon as hashCode is overridden.
    final registry = <BlockView>[];

    /// Serializes a block and returns its offset.
    int serialize(Block block) {
      final start = data.cursor;
      data.addTypeCode(block.typeCode);
      if (block is MapBlock) {
        data.addBlockKind(_blockKindMap);
        final entries = block.map.entries.toList();
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
            .map
            .entries
            .toList()
              ..sort((a, b) => a.key.compareTo(b.key));
        for (var i = 0; i < sortedMapEntries.length; i++) {
          final entry = sortedMapEntries[i];
          data
            ..setPointer(start + 8 + 1 + 8 + 16 * i, entry.key.offset)
            ..setPointer(start + 8 + 1 + 8 + 16 * i + 8, entry.value.offset);
        }
      } else if (block is BytesBlock) {
        data.addBlockKind(_blockKindBytes);
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
    final data = _Data(ByteData.view(buffer));
    return BlockView.at(data, 0);
  }
}

/// A wrapper around [ByteData] that only offers useful methods for encoding
/// [Block]s.
class _Data {
  _Data(this.data);

  ByteData data;
  int cursor = 0;

  void setTypeCode(int offset, int code) => data.setUint64(offset, code);
  int getTypeCode(int offset) => data.getUint64(offset);
  void addTypeCode(int code) {
    setTypeCode(cursor, code);
    cursor += 8;
  }

  void setBlockKind(int offset, int kind) => data.setUint8(offset, kind);
  int getBlockKind(int offset) => data.getUint8(offset);
  void addBlockKind(int kind) {
    setBlockKind(cursor, kind);
    cursor += 1;
  }

  void setLength(int offset, int length) => data.setUint64(offset, length);
  int getLength(int offset) => data.getUint64(offset);
  void addLength(int length) {
    setLength(cursor, length);
    cursor += 8;
  }

  void setPointer(int offset, int pointer) => data.setUint64(offset, pointer);
  int getPointer(int offset) => data.getUint64(offset);
  void addPointer(int pointer) {
    setPointer(cursor, pointer);
    cursor += 8;
  }

  void setByte(int offset, int byte) => data.setUint8(offset, byte);
  int getByte(int offset) => data.getUint8(offset);
  void addByte(int byte) {
    setByte(cursor, byte);
    cursor += 1;
  }
}
