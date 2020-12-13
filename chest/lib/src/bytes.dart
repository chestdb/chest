import 'dart:typed_data';

import 'blocks.dart';
import 'tapers.dart';
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
/// * The object's inner content come after the object itself, the encoding is
///   not recursive (although its implementation is). That means, you can access
///   an objects property without decoding the whole object.
///   In the example above, if we are interested only in the pet, we could
///   search through the keys, comparing our key ('pet') to the encoded ones
///   by following the pointers. As soon as we find the 'pet' key, we can follow
///   the value pointer and only decode the pet without ever touching the
///   `User`'s name.
/// * Because a map's keys are sorted by their content, they can be compared
///   in O(log n) using binary search.
/// * Encoding keys before values leads to better cache-locality when doing the
///   binary search.

const blockKindMap = 0;
const blockKindBytes = 1;

extension BlockToBytes on Block {
  Uint8List toBytes() {
    // TODO: Don't hardcode the length.
    final data = _Data(ByteData(1024));

    // Map from fully serialized, deduplicated blocks to their offset. Used for
    // deduplication.
    final registry = <BlockView, int>{};

    /// Serializes a block and returns its offset.
    ///
    /// Quick reminder: The block layout looks like this:
    ///
    /// Map:    type code | 0 | length | key | value | key | value | ...
    /// Bytes:  type code | 1 | bytes
    int serialize(Block block) {
      final start = data.cursor;
      data.addTypeCode(block.typeCode);
      if (block is MapBlock) {
        // Layout: 0 | length | key | value | key | value | ...
        data.addBlockKind(blockKindMap);
        final entries = block.entries;
        data.addLength(entries.length);
        final entriesStart = data.cursor;

        // For the serialization of the content, we apply some serialization
        // magic: ✨
        //
        // 1. Move the cursor behind the block, leaving space for pointers.
        // 2. Serialize all the keys and fill in the pointers.
        // 3. Serialize all the values and fill in the pointers.
        // 4. Sort the entries by keys.
        data.cursor += 16 * entries.length;
        for (var i = 0; i < entries.length; i++) {
          final keyOffset = serialize(entries[i].key);
          data.setPointer(entriesStart + 2 * _pointerLength * i, keyOffset);
        }
        for (var i = 0; i < entries.length; i++) {
          final valueOffset = serialize(entries[i].value);
          data.setPointer(
            entriesStart + 2 * _pointerLength * i + _pointerLength,
            valueOffset,
          );
        }
        // Sort entries.
        final sortedMapEntries = BlockView.at(data, start)
            .cast<MapBlockView>()
            .entries
          ..sort((a, b) => a.key.compareTo(b.key));
        for (var i = 0; i < sortedMapEntries.length; i++) {
          final entry = sortedMapEntries[i];
          data
            ..setPointer(
              entriesStart + 2 * _pointerLength * i,
              entry.key.offset,
            )
            ..setPointer(
              entriesStart + 2 * _pointerLength * i + _pointerLength,
              entry.value.offset,
            );
        }
      } else if (block is BytesBlock) {
        // Bytes: type code | 1 | bytes
        data.addBlockKind(blockKindBytes);
        final bytes = block.bytes;
        data.addLength(bytes.length);
        bytes.forEach(data.addByte);
      } else {
        throw CorruptedDataException('Unknown block $block while serializing.');
      }

      // Deduplication. Check if we already serialized a block that's the same
      // as the one we jsut serialized. That sounds expensive, but because the
      // blocks are saved in a `Set`, where they are sorted into buckets based
      // on their hash code, they often aren't even compared. And even for those
      // that are compared explicitly, it's cheaper than you might think:
      //
      // * Map blocks can compare their pointers, not the actual values, as no
      //   two values that are equal exist because all child blocks are already
      //   deduplicated.
      // * Byte block comparisons are expensive – they are compared byte by
      //   byte.
      final thisBlock = BlockView.at(data, start);
      final sameBlockOffset = registry[thisBlock];
      if (sameBlockOffset != null) {
        // This block will be overwritten.
        data.cursor = start;
        return sameBlockOffset;
      }
      registry[thisBlock] = start;
      return start;
    }

    serialize(this);
    return Uint8List.view(data.data.buffer, 0, data.cursor);
  }
}

extension BytesToBlock on Uint8List {
  Block toBlock() => BlockView.of(buffer);
}

/// Lazy block implementations that looks up data in a [_Data].

// Block views.

abstract class BlockView implements Block {
  int get offset;

  static BlockView of(ByteBuffer buffer) {
    return at(_Data(ByteData.view(buffer)), 0);
  }

  static BlockView at(_Data data, int offset) {
    final blockKind = data.getBlockKind(offset + _typeCodeLength);
    if (blockKind == blockKindMap) {
      return MapBlockView(data, offset);
    } else if (blockKind == blockKindBytes) {
      return BytesBlockView(data, offset);
    } else {
      panic('Unknown block kind $blockKind.');
    }
  }
}

class MapBlockView extends MapBlock implements BlockView {
  MapBlockView(this.data, this.offset) : super.noop();

  final _Data data;
  final int offset;

  @override
  int get typeCode => data.getTypeCode(offset);

  int get length => data.getLength(offset + _typeCodeLength + _blockKindLength);

  Block? operator [](Block key) {
    final index = _getIndexOfKey(key);
    if (index == null) return null;
    return _getValueAt(index);
  }

  operator []=(Block key, Block value) =>
      panic("Can't assign to MapBlockView.");

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

  BlockView _getKeyAt(int index) {
    return BlockView.at(
      data,
      data.getPointer(
        offset +
            _typeCodeLength +
            _blockKindLength +
            _lengthLength +
            2 * _pointerLength * index,
      ),
    );
  }

  BlockView _getValueAt(int index) {
    return BlockView.at(
      data,
      data.getPointer(
        offset +
            _typeCodeLength +
            _blockKindLength +
            _lengthLength +
            2 * _pointerLength * index +
            _pointerLength,
      ),
    );
  }
}

class BytesBlockView extends BytesBlock implements BlockView {
  BytesBlockView(this.data, this.offset) : super.noop();

  final _Data data;
  final int offset;

  @override
  int get typeCode => data.getTypeCode(offset);

  @override
  List<int> get bytes {
    final length = data.getLength(offset + _typeCodeLength + _blockKindLength);
    return Uint8List.view(
      data.data.buffer,
      offset + _typeCodeLength + _blockKindLength + _lengthLength,
      length,
    );
  }
}

// Conversion methods between objects and [Block]s.

extension ObjectToBlock on Object? {
  Block toBlock() {
    final taper = registry.valueToTaper(this);
    final typeCode = registry.taperToTypeCode(taper)!;
    final data = taper.toData(this);
    if (data is MapTapeData) {
      return MapBlock(
        typeCode,
        data.map.map((key, value) => MapEntry(key.toBlock(), value.toBlock())),
      );
    } else if (data is BytesTapeData) {
      return BytesBlock(typeCode, data.bytes);
    } else {
      panic('A taper returned a ${data.runtimeType}: $data');
    }
  }
}

extension BlockToObject on Block {
  Object toObject() {
    final taper = registry.typeCodeToTaper(typeCode);
    if (taper == null) throw UnknownTypeCodeException(typeCode);

    TapeData data;
    Block this_ = this;
    if (this_ is MapBlock) {
      data = MapTapeData(this_.entries.toMap());
    } else if (this_ is BytesBlock) {
      data = BytesTapeData(this_.bytes);
    } else {
      panic('$runtimeType.toObject called');
    }
    return taper.fromData(data);
  }
}

// On Path:
// Path<Block> serialize() {
//   return Path(keys.map((it) => it.toBlock()).toList());
// }

int _typeCodeLength = 8;
int _blockKindLength = 1;
int _lengthLength = 8;
int _pointerLength = 8;

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

class CorruptedDataException implements Exception {
  CorruptedDataException(this.message);

  final String message;

  // TODO: Make this more beautiful and maybe put the URL in a variable.
  String toString() => "Your data seems to be corrupted. If you're "
      "absolutely sure that can't be the case, open an issue at "
      "github.com/marcelgarus/chest.\nFurther information: $message";
}

class UnknownTypeCodeException implements Exception {
  UnknownTypeCodeException(this.typeCode);

  final int typeCode;

  String toString() => 'Unknown type code $typeCode.';
}
