import 'tapers.dart';

import '../utils.dart';

void debugPrint(Object object) {
  // ignore: avoid_print
  //if (isDebugMode)
  print(object);
}

/// The [registry] contains all registered [Taper]s. It makes these tasks
/// possible:
///
/// * Given a [Taper], get its type code in O(1).
/// * Given a type code, get a [Taper] in O(1).
/// * Given an [Object], get a [Taper].
///   * If the static type of the object equals its runtime type, in O(1).
///   * If it doesn't, in somewhere between O(log n) and O(n), depending on the
///     type hierarachy.
///
/// To do that efficiently, it contains several data structures.
final registry = Registry();

class Registry {
  Registry();

  /// Whether the [register] method has been called.
  var _isInitialized = false;

  final _tapersToTypeCodes = <Taper<dynamic>, int>{};
  final _typeCodesToTapers = <int, Taper<dynamic>>{};

  /// A tree recreating Dart's type system. Given an object, we can walk down
  /// the tree at those nodes where the object matches the type. When we reach a
  /// leaf, we found the most specialized type that we know about.
  final _typeTree = _Type<Object?>.withoutTaper();

  /// Shortcuts into the tree.
  final _shortcutsIntoTheTree = <Type, _Type<dynamic>>{};

  /// Registers a [_Type] without an associated [Taper].
  void registerTypeWithoutTaper<T>() {
    final typeNode = _Type<T>.withoutTaper();

    _shortcutsIntoTheTree[T] ??= typeNode;
    _typeTree.insert(typeNode);
  }

  void registerSingle<T>(int typeCode, Taper<T> taper) {
    var isDebug = false;
    assert(isDebug = true);
    if (isDebug) {
      final previousTypeCode = taperToTypeCode(taper);
      if (previousTypeCode != null) {
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

    final type = _Type<T>.withTaper(taper);
    _shortcutsIntoTheTree[taper.type] ??= type;
    _typeTree.insert(type);
  }

  /// Register multiple adapters.
  void register(Map<int, Taper<dynamic>> typeCodesToTapers) {
    assert(!_isInitialized, 'Only call register once with all needed tapers.');
    _isInitialized = true;

    // We don't call [registerSingle] directly, but rather let the [Taper] call
    // that method, because otherwise we would lose type information (the static
    // type of the adapters inside the map is `TypeAdapter<dynamic>`).
    typeCodesToTapers.forEach((typeCode, taper) {
      taper.registerForTypeCode(typeCode);
    });
  }

  int? taperToTypeCode(Taper<dynamic> taper) => _tapersToTypeCodes[taper];
  Taper<dynamic>? typeCodeToTaper(int typeCode) => _typeCodesToTapers[typeCode];

  /// Finds an adapter for serializing the [object].
  Taper<T?>? valueToTaper<T>(T object) {
    // Find the best matching adapter in the type tree.
    final searchStartNode =
        _shortcutsIntoTheTree[object.runtimeType] ?? _typeTree;
    final matchingTypeNode = searchStartNode.findTypeByValue(object);
    final matchingType = matchingTypeNode.type;
    final actualType = object.runtimeType;

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

    return matchingTypeNode.taper;
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
///
/// * An adapter might be able to encode a `SampleClass` and all its
///   subclasses, so there don't need to be adapters for the subclasses.
/// * Some types cannot be known statically. For example, `<int>[].runtimeType`
///   is not the same `List<int>` as a static `List<int>`. At runtime, it's
///   either a (different) `List<int>` or a `JSArray` (if running on the web).
///
/// That being said, there exist shortcuts into the tree based on the runtime
/// type that are preferred over traversing the tree.
class _Type<T> {
  _Type.withTaper(this.taper);
  _Type.withoutTaper() : taper = null;

  Type get type => T;
  bool matches(dynamic value) => value is T;
  bool isSupertypeOf(_Type<dynamic> node) => node is _Type<T>;

  final Taper<T>? taper;
  bool get hasTaper => taper != null;

  final subtypes = <_Type<T>>{};

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

  _Type<R?> findTypeByValue<R>(R value) {
    final matchingSubType =
        subtypes.where((it) => it.matches(value)).firstOrNull;
    return matchingSubType?.findTypeByValue<R>(value) ?? (this as _Type<R?>);
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
      if (!hasTaper)
        '${isLast ? '└─' : '├─'} virtual node for $type'
      else
        '${isLast ? '└─' : '├─'} ${taper.runtimeType}',
      '\n',
      for (final child in children)
        child._debugToString(
            '$prefix${isLast ? '   ' : '│  '}', child == children.last),
    ].join();
  }
}
