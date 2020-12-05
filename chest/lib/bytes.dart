import 'dart:typed_data';

import 'blocks.dart';
import 'utils.dart';
import 'value.dart';

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
