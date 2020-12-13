import 'package:more/more.dart';

import 'utils.dart';

export 'tapers/core.dart';
export 'tapers/math.dart';
export 'tapers/typed_data.dart';

/// An intermediary representation of data. [Taper]s produce this when they
/// serialize [Object]s.
abstract class TapeData {}

class MapTapeData extends TapeData {
  MapTapeData(this.map);
  final Map<Object?, Object?> map;
}

class BytesTapeData extends TapeData {
  BytesTapeData(this.bytes);
  final List<int> bytes;
}

/// A converter between [Object]s and [TapeData].
///
/// [Taper]s are usually added as extension methods on the [TaperApi], so
/// instead of writing `TaperForUser()`, you can write `taper.forUser()` and you
/// don't clutter the global namespace.
///
/// [Taper]s are also usually registerd at the [registry] like this:
///
/// ```
/// tape.register({
///   ...tapers.forDartCore, // This unpacks to many tapers.
///   0: taper.forUser(), // A taper for a specific type.
///   2: legacyTaper.forUser().v1, // This is a migration.
///   1: taper.forPet(),
/// });
/// ```
abstract class Taper<T> {
  const Taper();

  Type get type => T;
  bool matches(Object? value) => value is T;
  bool get isLegacy => false;
  void _registerForTypeCode(int typeCode) =>
      registry._registerSingle(typeCode, this);

  /// Turns the [value] into [TapeData].
  TapeData toData(T value);

  /// Turns [TapeData] back into a value of type [T].
  T fromData(TapeData data);

  @override
  operator ==(Object other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          other is Taper<T> &&
          type == other.type;

  @override
  int get hashCode => hash2(runtimeType, type);
}

/// The [registry] contains all registered [Taper]s. It makes these
/// tasks possible:
///
/// * Given a [TaperOrSemiTaper], get its type code in O(1).
/// * Given a type code, get a [TaperOrSemiTaper] in O(1).
/// * Given an [Object], get a [Taper].
///   * If the static type of the object equals its runtime type, in O(1).
///   * If it doesn't, in somewhere between O(log n) and O(n), depending on the
///     type hierarachy.
///
/// To do that efficiently, it contains several data structures.
final registry = _Registry();

class _AnyTaper extends Taper<Object?> {
  @override
  Object? fromData(TapeData data) =>
      panic("_AnyTaper.fromData should never be called.");

  @override
  TapeData toData(Object? value) => throw NoTaperForValueError(value);
}

class _Registry {
  _Registry();

  /// Whether the [register] method has been called.
  var _isInitialized = false;

  final _tapersToTypeCodes = <Taper<dynamic>, int>{};
  final _typeCodesToTapers = <int, Taper<dynamic>>{};
  bool get hasTapers => _tapersToTypeCodes.isNotEmpty;

  /// A tree recreating Dart's type system. Given an object, we can walk down
  /// the tree at those nodes where the object matches the type. When we reach a
  /// leaf, we found the most specialized type that we know about.
  final _typeTree = _Type<Object?>(_AnyTaper());

  /// Shortcuts into the tree.
  final _shortcutsIntoTheTree = <Type, _Type<dynamic>>{};

  /// Registers the [taper] for the [typeCode].
  void _registerSingle<T>(int typeCode, Taper<T> taper) {
    _tapersToTypeCodes[taper] = typeCode;
    _typeCodesToTapers[typeCode] = taper;

    // Legacy tapers are not inserted into the type tree because they are only
    // used for deserialization, never serialization of values. So, we also
    // never have to find them based on a value.
    if (taper.isLegacy) return;

    if (inDebugMode) {
      final previousTypeCode = taperToTypeCode(taper);
      if (previousTypeCode != null) {
        throw TaperRegisteredTwiceError(taper, previousTypeCode, typeCode);
      }
    }

    final type = _Type<T>(taper);
    _shortcutsIntoTheTree[T] ??= type;
    _typeTree.insert(type);
  }

  /// Registers multiple adapters.
  void register(Map<int, Taper<dynamic>> typeCodesToTapers) {
    if (!_isInitialized) throw RegisterCalledTwiceError();
    _isInitialized = true;

    /// We don't call [_registerSingle] directly, but rather let the [Taper]
    /// call that method, because otherwise we would lose type information (the
    /// static type of the tapers inside the map is `Taper<dynamic>`).
    typeCodesToTapers.forEach((typeCode, taper) {
      taper._registerForTypeCode(typeCode);
    });
  }

  int? taperToTypeCode(Taper<dynamic> taper) => _tapersToTypeCodes[taper];
  Taper<dynamic>? typeCodeToTaper(int typeCode) => _typeCodesToTapers[typeCode];

  /// Finds an adapter for serializing the [value].
  Taper<Object?> valueToTaper<T>(T value) {
    // Start at the root node of the type tree or a shortcut, if available.
    // Then, repeatedly follow the first subtype that matches the tapers value.
    var type = _shortcutsIntoTheTree[value.runtimeType] ?? _typeTree;
    while (true) {
      final matchingSubtype =
          type.subtypes.where((it) => it.matches(value)).firstOrNull;
      if (matchingSubtype == null) break;
      type = matchingSubtype;
    }
    final taper = type.taper;
    if (!type.matches(value)) {
      panic("Shortcut into the tree for ${value.runtimeType} is to a taper "
          "that's not for ${value.runtimeType}, but for ${type.type}.");
    }
    if (!_debugIsSameType(value.runtimeType, type.type)) {
      print('Warning from Chest: We use a taper for type ${type.type} to '
          'encode a value of type ${value.runtimeType}. The value is $value.');
    }

    // Make lookup faster for the next time.
    _shortcutsIntoTheTree[value.runtimeType] = type;
    return taper;
  }

  static bool _debugIsSameType(Type runtimeType, Type staticType) {
    return staticType.toString() ==
        runtimeType
            .toString()
            .replaceAll('JSArray', 'List')
            .replaceAll('_CompactLinkedHashSet', 'Set')
            .replaceAll('_InternalLinkedHashMap', 'Map');
  }

  String treeAsDebugString() => _typeTree.asDebugString();
}

/// We maintain a tree of `_AdapterNode`s for cases where resolving adapter's by
/// an object's runtime type doesn't work.
/// This can happen because some types cannot be known statically. For example,
/// `<int>[].runtimeType` is not the same `List<int>` as a static `List<int>`.
/// At runtime, it's either a (different) `List<int>` or a `JSArray` (if running
/// on the web).
///
/// That being said, there exist shortcuts into the tree based on the runtime
/// type that are preferred over traversing the tree.
class _Type<T> {
  _Type(this.taper);

  final Taper<T> taper;
  final subtypes = <_Type<T>>{};

  Type get type => T;
  bool matches(Object? value) => value is T;
  bool isSupertypeOf(_Type<Object?> node) => node is _Type<T>;
  A run<A>(A Function<T>() callback) => callback();

  /// Inserts a new value.
  ///
  /// If the new type is a supertype of any of our subtypes, we insert it
  /// between us and those types. This is good because it decreases the number
  /// of direct subtypes we have, so the tree breadth decreases and lookups are
  /// faster.
  /// If that's not possible, then we insert the new type into those of our
  /// subtypes that it's a subtype of, or otherwise, we add it as our own.
  void insert(_Type<T> newType) {
    if (newType.runtimeType == runtimeType) {
      throw TwoTapersForTheSameTypeRegisteredError();
    }

    final newTypeSubtypes =
        subtypes.where((it) => newType.isSupertypeOf(it)).toList();
    final newTypeSupertypes =
        subtypes.where((it) => it.isSupertypeOf(newType)).toList();
    if (newTypeSubtypes.isNotEmpty) {
      subtypes.removeAll(newTypeSubtypes);
      newType.subtypes.addAll(newTypeSubtypes);
      subtypes.add(newType);
    } else if (newTypeSupertypes.isNotEmpty) {
      for (final supertype in newTypeSupertypes) {
        supertype.insert(newType);
      }
    } else {
      subtypes.add(newType);
    }
  }

  String asDebugString() {
    final buffer = StringBuffer()
      ..writeln('root node for objects to serialize');
    final children = subtypes;

    for (final child in children) {
      buffer.write(child._debugToString('', child == children.last));
    }
    return buffer.toString();
  }

  String _debugToString(String prefix, bool isLast) {
    final children = subtypes.toList();
    return [
      prefix,
      '${isLast ? '└─' : '├─'} ${taper.runtimeType}',
      '\n',
      for (final child in children)
        child._debugToString(
            '$prefix${isLast ? '   ' : '│  '}', child == children.last),
    ].join();
  }
}

// Errors.

class RegisterCalledTwiceError extends ChestError {
  String toString() =>
      'You called tape.register twice. Only call it once with all needed tapers.';
}

class TwoTapersForTheSameTypeRegisteredError extends ChestError {
  String toString() => 'Your registered two tapers for the same type.';
}

class TaperRegisteredTwiceError extends ChestError {
  TaperRegisteredTwiceError(this.taper, this.typeCode1, this.typeCode2);

  final Taper<Object?> taper;
  final int typeCode1;
  final int typeCode2;

  String toString() =>
      'Taper $taper registered for two type codes ($typeCode1, $typeCode2).';
}

class NoTaperForValueError extends ChestError {
  NoTaperForValueError(this.value);

  final Object? value;

  String toString() =>
      'There is no taper registered for serializing the value $value of type '
      '${value.runtimeType}.';
}
