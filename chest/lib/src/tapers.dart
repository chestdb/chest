import 'package:more/more.dart';

import 'utils.dart';

export 'tapers/core.dart';
export 'tapers/math.dart';
export 'tapers/typed_data.dart';

/// The format that [Taper]s produce.
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
///   0: taper.forUser(),
///   1: taper.forPet(),
///   2: taper.forUserV1() >> taper.forUser(), // This is a migration.
/// });
/// ```
abstract class Taper<T> {
  const Taper();

  Type get type => T;
  bool matches(Object? value) => value is T;

  bool get isMigrating => false;

  void _registerForTypeCode(int typeCode) =>
      registry._registerSingle(typeCode, this);

  @override
  operator ==(Object other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          other is Taper<T> &&
          type == other.type;

  @override
  int get hashCode => hash2(runtimeType, type);

  ConcreteType get concreteType;
  // operator >>(Taper<T> other);
}

abstract class ConcreteTaper<T> extends Taper<T> {
  const ConcreteTaper();

  /// Turns the [value] into [TapeData].
  TapeData toData(T value);

  /// Turns [TapeData] back into a value of type [T].
  T fromData(TapeData data);

  /// Creates a new [Taper] that [isMigrating] and uses this taper for decoding
  /// and the [other] one for encoding.
  // operator >>(Taper<T> other) => _MigratingTaper(this, other);

  ConcreteType get concreteType =>
      ConcreteType(registry.taperToTypeCode(this)!);
}

class _MigratingTaper<T> extends ConcreteTaper<T> {
  _MigratingTaper(this.from, this.to);

  bool get isMigrating => true;

  final ConcreteTaper<T> from;
  final ConcreteTaper<T> to;

  TapeData toData(T value) => to.toData(value);
  T fromData(TapeData data) => from.fromData(data);
}

/// A class that's not a fully fledged [Taper] just yet. Used for generic types.
///
/// Example: [SemiTaperForList] is a `SemiTaper<List<dynamic>>` that can't be
/// used for serializing concrete `List? s yet. Instead, this semi-taper should
/// be enriched with concrete types for the generics, e.g. turned into a
/// `Taper<List<String>>`.
///
/// This indirection is necessary so we can construct i.e. `List<String>`s
/// without ever specifying the `List<String>` type in our code, only a
/// `SemiTaperForList` and a `TaperForString`. So, this solves the combinatorial
/// explosion of generics.
abstract class GenericTaper<T> extends Taper<T> {
  /// There are more concrete [SemiTaper]s that each have an [enrich] method
  /// with a different number of type arguments.

  // operator >>(Taper<T> other) => _MigratingTaper(this, other);
  Taper<T> enrich<A>(Taper<A> type);
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
  ConcreteType get concreteType => throw 'Any shouldnt be concrete.';
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

  void _registerSingle<T>(int typeCode, Taper<T> taper) {
    var isDebug = false;
    assert(isDebug = true);
    if (isDebug) {
      final previousTypeCode = taperToTypeCode(taper);
      if (previousTypeCode != null) {
        // TODO: Better error.
        throw 'Taper registered for multiple type codes.';
        /*TaperRegisteredForMultipleTypeCodes(
          taper: taper,
          firstTypeCode: taperToTypeCode(taper),
          secondTypeCode: typeCode,
        );*/
      }
    }

    _tapersToTypeCodes[taper] = typeCode;
    _typeCodesToTapers[typeCode] = taper;

    final type = _Type<T>(taper);
    _shortcutsIntoTheTree[taper.type] ??= type;
    _typeTree.insert(type);
  }

  /// Register multiple adapters.
  void register(Map<int, Taper<dynamic>> typeCodesToTapers) {
    assert(!_isInitialized, 'Only call register once with all needed tapers.');
    _isInitialized = true;

    /// We don't call [registerSingle] directly, but rather let the [Taper] call
    /// that method, because otherwise we would lose type information (the
    /// static type of the adapters inside the map is `TypeAdapter<dynamic>`).
    typeCodesToTapers.forEach((typeCode, taper) {
      taper._registerForTypeCode(typeCode);
    });

    print(treeAsDebugString());
  }

  int? taperToTypeCode(Taper<dynamic> taper) => _tapersToTypeCodes[taper];
  Taper<dynamic>? typeCodeToTaper(int typeCode) => _typeCodesToTapers[typeCode];

  /// Finds an adapter for serializing the [value].
  Taper<T> valueToTaper<T>(T value) {
    // Find the best matching adapter in the type tree.
    final type = _shortcutsIntoTheTree[value.runtimeType] ?? _typeTree;
    var concreteType = type._concreteTypeWhere(value);
    print('Concrete type is $concreteType');
    // return concreteType.taper as Taper<T>;
    throw 'valueToTaper end';

    // final subtype = type.subtypes.where((it) => it.matches(value)).firstOrNull;
    // final matchingTypeNode =
    //     matchingSubType?.findTypeByValue<R>(value) ?? (this as _Type<R?>);

    // final matchingTypeNode = searchStartType.findTypeByValue(object);
    // final matchingType = matchingTypeNode.type;
    // final actualType = object.runtimeType;

    // TODO: Move this to the conversion methods.
    /*assert(() {
      if (matchingTypeNode.taper == null) {
        throw Exception('No adapter for the type $actualType found. Consider '
            'adding an adapter for that type by calling '
            '${taperSuggestion(actualType)}.');
      }

      if (!_debugIsSameType(actualType, matchingType)) {
        debugPrint("No adapter for the exact type $actualType found, so we're "
            'encoding it as a ${matchingTypeNode.type}. For better performance '
            'and truly type-safe serializing, consider adding an adapter for '
            'that type by calling ${taperSuggestion(actualType)}.');
      }
      return true;
    }());*/
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

  void insert(_Type<T> newType) {
    assert(newType.runtimeType != runtimeType,
        'The same type was inserted into the tree twice: $runtimeType');

    // If the new type is a supertype of any of our subtypes, we insert it
    // between us and those types. This is good because it decreases the number
    // of direct subtypes we have, so the tree breadth decreases and lookups are
    // faster.
    // If that's not possible, then we insert the new type into those of our
    // subtypes that it's a subtype of, or otherwise, we add it as our own.
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

  /// Enriches the given type with our type.
  Taper<T> enrich<A>(_Type<A> type) {
    final taper = this.taper;
    if (taper is GenericTaper<T>) {
      return taper.enrich(taper);
    }
    throw 'Tried to enrich, but this is not a generic type.';
  }

  ConcreteType _concreteTypeWhere<T>(
    dynamic value, [
    GenericTaper<T>? generic,
  ]) {
    if (generic == null) {
      final bestFittingTaper = subtypes
              .map((it) => it.taper)
              .where((it) => it.matches(value))
              .firstOrNull ??
          taper;
      if (bestFittingTaper is GenericTaper<T>) {
        return registry._typeTree
            ._concreteTypeWhere(value, bestFittingTaper as GenericTaper<T>);
      } else {
        // return _ConcreteType(type);
        throw "In the else. Best fitting taper is $bestFittingTaper.";
      }
    } else {
      print('Finding concrete type starting from $this. Generic: $generic.');
      final bestFittingTaper = subtypes
              .map((it) => it.taper)
              .where((it) => generic.enrich(it).matches(value))
              .firstOrNull ??
          taper;
      print(
          'Continuing at type $bestFittingTaper because ${generic.enrich(bestFittingTaper)} matches $value.');
      print('Enriched generic is ${generic.enrich(bestFittingTaper)}.');
      print(
          'Concrete type is ${generic.enrich(bestFittingTaper).concreteType}.');
      // final enriched = taper.enrich(fittingSubtype);
    }
    throw 'Reached the end.';
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

class ConcreteType {
  ConcreteType(this.typeCode, [this.generics = const []]);

  final int typeCode;
  final List<ConcreteType> generics;

  String toString() => '$typeCode<${generics.join(', ')}>';
}
