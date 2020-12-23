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
    required Stream<Action> incomingActions,
    required this.sendEvent,
    required this.dispose,
  }) : _file = ChestFile('$name.chest') {
    incomingActions.listen(_handleAction);
    _registerServiceMethods();
  }

  ChestFile _file;
  final void Function(Event event) sendEvent;
  final void Function() dispose;

  Future<void> _handleAction(Action action) async {
    if (action is GetValueAction) {
      sendEvent(ValueEvent(_getValue()?.transferable()));
    } else if (action is SetValueAction) {
      _setValue(action.path, action.value);
    } else if (action is FlushAction) {
      _flush();
      sendEvent(FlushedEvent(action.uuid));
    } else if (action is CompactAction) {
      _compact();
      sendEvent(CompactedEvent(action.uuid));
    } else if (action is CloseAction) {
      _close();
    } else {
      throw panic('Backend: Unknown action $action.');
    }
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
    // TODO: As soon as a backend is used by multiple frontends, broadcast the value.

    if (_file.shouldBeCompacted) {
      _compact();
    }
  }

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
    _file.delete();
    newFile.renameTo(_file.path);
    _file = newFile;
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
