import 'dart:typed_data';

import 'blocks.dart';
import 'tapers.dart';
import 'utils.dart';

/// [Content] is the top-level object inside a [Chest] that wraps the actual
/// value and holds metadata.
///
/// That makes it possible to migrate [Taper]s and maintain [Reference]s without
/// parsing the whole value.
class Content {
  Content({
    required this.value,
    required this.typeCodes,
    // required this.references,
  });

  // The actual value of the chest.
  final Object? value;

  /// The type codes of all registered, non-legacy tapers.
  ///
  /// The registered tapers don't change that often. If they do, we compact the
  /// chest so that tapers get migrated.
  final TypeCodes typeCodes;

  // Maps paths to number of references.
  // final Map<Path<Block>, int> references;
}

// Because the [Content] should be serializable even if `dart:core` tapers are
// not registered, it doesn't expose types from `dart:core` to tape.

class TaperForContent extends MapTaper<Content> {
  @override
  Map<Uint8, Object?> toMap(Content content) {
    return {
      Uint8(0): content.value,
      Uint8(2): content.typeCodes,
      // Uint8(3): content.references,
    };
  }

  @override
  Content fromMap(Map<Object?, Object?> fields) {
    return Content(
      value: fields[Uint8(0)],
      typeCodes: fields[Uint8(2)] as TypeCodes,
      // references: fields['references'] as Map<Path<Block>, int>,
    );
  }
}

final pathToValue = Path<Object?>([Uint8(0)]);

class Uint8 {
  Uint8(this.value)
      : assert(0 <= value),
        assert(value < 256);

  final int value;

  bool operator ==(Object other) => other is Uint8 && value == other.value;
}

class TypeCodes {
  TypeCodes(List<int> typeCodes)
      : this.typeCodes = List.from(typeCodes)..sort();

  final List<int> typeCodes;

  bool operator ==(Object other) =>
      other is TypeCodes && typeCodes.deeplyEquals(other.typeCodes);
}

class TaperForUint8 extends BytesTaper<Uint8> {
  @override
  List<int> toBytes(Uint8 key) => [key.value];

  @override
  Uint8 fromBytes(List<int> bytes) => Uint8(bytes.first);
}

class TaperForTypeCodes extends BytesTaper<TypeCodes> {
  @override
  List<int> toBytes(TypeCodes typeCodes) =>
      Uint64List.fromList(typeCodes.typeCodes);

  @override
  TypeCodes fromBytes(List<int> bytes) =>
      TypeCodes(Uint64List.view(Uint8List.fromList(bytes).buffer));
}
