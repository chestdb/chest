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

class TypeCodes {
  TypeCodes(List<int> typeCodes)
      : this.typeCodes = List.from(typeCodes)..sort();

  final List<int> typeCodes;

  bool operator ==(Object other) =>
      other is TypeCodes && typeCodes.deeplyEquals(other.typeCodes);
}

// Because the [Content] should be serializable even if `dart:core` tapers are
// not registered, it doesn't expose types from `dart:core` to tape.

extension TapersForChest on TapersNamespace {
  Map<int, Taper<Object?>> get forChest {
    return {
      -1: taper.forContent(),
      -2: taper.forUint8(),
      -3: taper.forTypeCodes(),
    };
  }
}

class Uint8 {
  Uint8(this.value)
      : assert(0 <= value),
        assert(value < 256);

  final int value;

  bool operator ==(Object other) => other is Uint8 && value == other.value;
}

extension TaperForContentExtension on TaperNamespace {
  Taper<Content> forContent() => const TaperForContent();
}

class TaperForContent extends MapTaper<Content> {
  const TaperForContent();

  @override
  Map<Object?, Object?> toMap(Content content) {
    return {Uint8(0): content.value, Uint8(1): content.typeCodes};
  }

  @override
  Content fromMap(Map<Object?, Object?> map) {
    return Content(value: map[Uint8(0)], typeCodes: map[Uint8(1)] as TypeCodes);
  }
}

final pathToValue = Path<Object?>([Uint8(0)]);
final pathToTypeCodes = Path<Object?>([Uint8(1)]);

extension TaperForUint8Extension on TaperNamespace {
  Taper<Uint8> forUint8() => const TaperForUint8();
}

class TaperForUint8 extends BytesTaper<Uint8> {
  const TaperForUint8();

  @override
  List<int> toBytes(Uint8 uint8) => [uint8.value];

  @override
  Uint8 fromBytes(List<int> bytes) => Uint8(bytes.first);
}

extension TaperForTypeCodesExtension on TaperNamespace {
  Taper<TypeCodes> forTypeCodes() => const TaperForTypeCodes();
}

class TaperForTypeCodes extends BytesTaper<TypeCodes> {
  const TaperForTypeCodes();

  @override
  List<int> toBytes(TypeCodes typeCodes) =>
      Uint64List.fromList(typeCodes.typeCodes).buffer.asUint8List();

  @override
  TypeCodes fromBytes(List<int> bytes) =>
      TypeCodes(Uint8List.fromList(bytes).buffer.asUint64List());
}
