import 'dart:async';

import 'package:chest/src/storage/debug/storage.dart';

import 'blocks.dart';
import 'content.dart';
import 'storage/storage.dart';
import 'storage/web/storage.dart'
    if (dart.library.io) 'storage/vm/storage.dart';
import 'tapers.dart';

/// The [Backend] for chests that already supports saving and updating a value,
/// but does not yet offer saving and maintaining `References` or saving which
/// tapers are used.
class Backend<T> {
  Backend(this._value, this._storage) {
    _storage.updates.listen((update) {
      _value.update(update.path, update.value, createImplicitly: true);
      _onValueChangedController.add(Path.root());
    });
  }

  final UpdatableBlock _value;
  final Storage _storage;
  final _onValueChangedController = StreamController<Path<Block>>.broadcast();

  Type get _type => T;
  Stream<Path<Block>> get _onValueChanged => _onValueChangedController.stream;

  static Future<Backend<T>> open<T>(
    String name,
    FutureOr<T> Function() ifNew,
  ) async {
    // Get the existing [Content] from the chest.
    final storage = await openStorage(name);
    var updatableContent = await storage.getValue();

    // Set default content if none exists.
    if (updatableContent == null) {
      final content = Content(
        typeCodes: TypeCodes(registry.nonLegacyTypeCodes),
        value: await ifNew(),
      ).toBlock();
      storage.setValue(Path.root(), content);
      updatableContent = UpdatableBlock(content);
    }

    // Migrate tapers if necessary.
    final typeCodesBlock = updatableContent.getAt(pathToTypeCodes.serialize());
    if (typeCodesBlock == null) {
      throw CorruptedChestException('Chest content has no type codes.');
    }
    final typeCodes = typeCodesBlock.toObject();
    if (typeCodes is! TypeCodes) {
      throw CorruptedChestException(
          "Chest content's type codes are not of type TypeCodes.");
    }
    // Migrate if the registered tapers changed since the last time the chest
    // was opened.
    if (typeCodes != TypeCodes(registry.nonLegacyTypeCodes)) {
      updatableContent = await storage.migrate();
    }

    // Ensure that the content is of the right type.
    final value = updatableContent.getAt(pathToValue.serialize());
    if (value == null) {
      throw CorruptedChestException('Chest content has no value.');
    }
    final taper = registry.typeCodeToTaper(value.typeCode);
    if (taper == null) {
      throw NoTaperForTypeCodeError(value.typeCode);
    }
    if (taper is! Taper<T>) {
      throw ChestDoesNotMatchTypeError(
        name: name,
        expectedType: T,
        actualType: taper.type,
      );
    }

    return Backend<T>(updatableContent, storage);
  }

  static Backend<T> mock<T>(String name, T value) {
    final content = Content(
      typeCodes: TypeCodes(registry.nonLegacyTypeCodes),
      value: value,
    );
    final updatableContent = UpdatableBlock(content.toBlock());
    return Backend<T>(updatableContent, DebugStorage(updatableContent));
  }

  Future<void> flush() => _storage.flush();
  Future<void> compact() => _storage.compact();
  Future<void> close() async {
    // Let the actual value be garbage collected by replacing it with a small
    // one.
    _value.update(Path.root(), MapBlock(0, {}), createImplicitly: false);
    _onValueChangedController.close();
    await _storage.close();
  }

  bool existsAt(Path<Object?> path) {
    final actualPath = pathToValue.followedBy(path).serialize();
    return _value.getAt(actualPath) != null;
  }

  void setAt(Path<Object?> path, Object? value, bool createImplicitly) {
    final actualPath = pathToValue.followedBy(path).serialize();
    final blockValue = value.toBlock();
    _value.update(actualPath, blockValue, createImplicitly: createImplicitly);
    _onValueChangedController.add(actualPath);
    _storage.setValue(actualPath, blockValue);
  }

  R? getAt<R>(Path<Object?> path) {
    final actualPath = pathToValue.followedBy(path).serialize();
    return _value.getAt(actualPath)?.toObject() as R;
  }

  Stream<R?> watchAt<R>(Path<Object?> path) {
    final blockPath = pathToValue.followedBy(path).serialize();
    return _onValueChanged
        .where((changedPath) {
          // Only deserialize on those events that could have changed the value.
          return changedPath.startsWith(blockPath) ||
              blockPath.startsWith(changedPath);
        })
        .map((_) => getAt<R>(blockPath))
        .distinct();
  }

  Backend<R> cast<R>(String name) {
    if (this is! Backend<R>) {
      throw ChestDoesNotMatchTypeError(
        name: name,
        expectedType: R,
        actualType: _type,
      );
    }
    return this as Backend<R>;
  }
}

class ChestDoesNotMatchTypeError extends ChestError {
  ChestDoesNotMatchTypeError({
    required this.name,
    required this.expectedType,
    required this.actualType,
  });

  final String name;
  final Type expectedType;
  final Type actualType;

  String toString() => 'You tried to open Chest "$name" of type '
      "$expectedType, but it's actually of type $actualType.";
}

extension on Path<Object?> {
  Path<Block> serialize() {
    return Path(keys.map((it) => it.toBlock()).toList());
  }
}
