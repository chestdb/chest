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
  static const currentFileLayoutVersion = 0;

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
      sendEvent(WholeValueEvent(_getValue()));
    } else if (action is SetValueAction) {
      _setValue(action.path, action.value);
    } else if (action is FlushAction) {
      _flush();
      sendEvent(FlushedEvent(action.uuid));
    } else if (action is CloseAction) {
      _close();
    } else {
      throw UnimplementedError('Backend: Unknown action $action.');
    }
  }

  UpdatableBlock? _getValue() {
    final header = _file.readHeader();
    if (header == null) return null;

    if (header.version > currentFileLayoutVersion) {
      // TODO: Better error.
      throw 'Version too big: ${header.version}.';
    }

    UpdatableBlock? value;
    while (true) {
      final update = _file.readUpdate();
      if (update == null) break;

      if (value == null) {
        // TODO: Better error.
        if (!update.path.isRoot) throw 'First update was not for root.';
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
    // TODO: Broadcast the value.

    if (_file.shouldBeCompacted) {
      _compact();
    }
  }

  void _compact() {
    print('Compacting...');
    _replaceRootValue(
      _getValue()?.getAtRoot() ??
          panic('Attempted to compact, but value is null.'),
    );
  }

  void _replaceRootValue(Block newValue) {
    // This is expensive.
    final newFile = ChestFile('${_file.path}.compacted')
      ..writeHeader(ChestFileHeader(currentFileLayoutVersion))
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
