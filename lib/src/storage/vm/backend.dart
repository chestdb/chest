import 'dart:async';

import '../storage.dart';
import 'file.dart';
import 'message.dart';
import 'transferable_block.dart';

/// The [VmBackend] is responsible for managing access to a `.chest` file.
///
/// Multiple [Storage]s of the same chest running on different [Isolate]s all
/// communicate with the same [VmBackend].
class VmBackend {
  /// The version of the file layout.
  static const currentVersion = 0;

  VmBackend({
    required String name,
    required Stream<ActionMessage> incomingMessages,
    required this.sendMessage,
    required this.dispose,
  }) : _file = ChestFile('${tape.rootPath}/$name.chest') {
    incomingMessages.listen(_handleMessage);
    _registerServiceMethods();
  }

  ChestFile _file;
  final void Function(EventMessage event) sendMessage;
  final void Function() dispose;

  Future<void> _handleMessage(ActionMessage message) async {
    Event event;
    try {
      event = await _handleAction(message.action);
    } catch (e, st) {
      event = ErrorEvent('$e', '$st');
    }
    sendMessage(EventMessage(uuid: message.uuid, event: event));
  }

  Future<Event> _handleAction(Action action) async {
    if (action is GetValueAction) {
      return ValueEvent(value: _getValue()?.transferable());
    }
    if (action is SetValueAction) {
      _setValue(action.path, action.value);
      return ValueSetEvent();
    }
    if (action is FlushAction) {
      _flush();
      return FlushedEvent();
    }
    if (action is CompactAction) {
      _compact();
      return CompactedEvent();
    }
    if (action is MigrateAction) {
      final migratedValue = _migrate(action.registry);
      return MigratedEvent(value: migratedValue);
    }
    if (action is CloseAction) {
      _close();
      return ClosedEvent();
    }
    panic('Backend: Unknown action $action.');
  }

  Iterable<ChestFileUpdate> _getUpdates() sync* {
    final header = _file.readHeader();
    if (header == null) return;
    if (header.version > currentVersion) {
      throw VersionTooBigException(header.version);
    }

    while (true) {
      final update = _file.readUpdate();
      if (update == null) break;
      yield update;
    }
  }

  UpdatableBlock? _getValue() {
    UpdatableBlock? value;
    for (final update in _getUpdates()) {
      if (value == null) {
        if (!update.path.isRoot) panic('First update was not for root.');
        value = UpdatableBlock(update.value);
      } else {
        value.update(update.path, update.value, createImplicitly: true);
      }
    }
    return value;
  }

  void _setValue(Path<Block> path, Block value) {
    if (path.isRoot) {
      _replaceRootValue(value);
      return;
    }
    _file.appendUpdate(ChestFileUpdate(path, value));

    if (_file.shouldBeCompacted) {
      _compact();
    }
  }

  // TODO: Use the `.chest.compacted` file if the normal one doesn't exist.
  void _compact() {
    final value = _getValue();
    if (value == null) panic('Attempted to compact, but value is null.');
    _replaceRootValue(value.getAtRoot());
  }

  void _replaceRootValue(Block newValue) {
    // This is expensive.
    final newFile = ChestFile('${_file.path}.compacted')
      ..writeHeader(ChestFileHeader(currentVersion))
      ..appendUpdate(ChestFileUpdate(Path.root(), newValue));

    // Replace the old file.
    final path = _file.path;
    _file.delete();
    newFile.renameTo(path);
    _file = newFile;
  }

  TransferableUpdatableBlock _migrate(Registry registry) {
    final value =
        _getValue() ?? panic('Attempted to migrate, but value is null.');
    // TODO: Make this more efficient by only migrating the parts that need migration.
    final migrated = value.getAtRoot().toObject(registry).toBlock(registry);
    _replaceRootValue(migrated);
    return UpdatableBlock(migrated).transferable();
  }

  void _flush() {
    _file.flush();
  }

  void _close() {
    _file.close();
    dispose();
  }

  void _registerServiceMethods() {
    // registerExtension('ext.chest.num_chunks', (method, parameters) async {
    //   print("Returning the number of chunks.");
    //   return ServiceExtensionResponse.result(json.encode({
    //     'type': 'size',
    //     'size': _chunky.numberOfChunks,
    //   }));
    // });
  }
}

class VersionTooBigException implements Exception {
  VersionTooBigException(this.version);

  final int version;

  String toString() =>
      'The chest you tried to open has version $version, but the Chest package '
      'used has the file layout version ${VmBackend.currentVersion}.\n'
      'You should update your Chest dependency.';
}
