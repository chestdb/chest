import 'dart:async';
import 'dart:typed_data';

import '../../bytes.dart';
import '../storage.dart';
import 'file.dart';
import 'message.dart';

/// The [VmBackend] is responsible for managing access to a `.chest` file.
///
/// Multiple [Storage]s of the same chest running on different [Isolate]s all
/// communicate with the same [VmBackend].
///
/// ## File layout
///
/// TODO: Compress bytes.
/// | version | updates |
/// | 8 B     | ...     |
///
/// All updates have the following layout:
///
/// | validity | path                         | data          |
/// |          | num segments | segments      | length | data |
/// |          |              | length | data |        |      |
/// | 1 B      | 8 B          | 8 B    | 8 B  | 8 B    | 8 B  |
///
/// The first udpate always has an empty path.
class VmBackend {
  VmBackend({
    required String name,
    required Stream<Action> incomingActions,
    required this.sendEvent,
    required this.dispose,
  }) : _file = SyncFile('$name.chest') {
    incomingActions.listen(_handleAction);
    _registerServiceMethods();
  }

  SyncFile _file;
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
    if (_file.length() == 0) {
      return null;
    }
    _file.goToStart();
    final version = _file.readInt();
    if (version > 0) throw 'Version too big: $version.';

    UpdatableBlock? value;

    while (_file.position() < _file.length()) {
      final validity = _file.readByte();
      if (validity == 0) {
        _file.truncate(_file.position() - 1);
        break;
      }

      final pathLength = _file.readInt();
      final segments = <Block>[];
      for (var i = 0; i < pathLength; i++) {
        final segmentLength = _file.readInt();
        final segmentBytes = Uint8List(segmentLength);
        _file.readBytesInto(segmentBytes);
        segments.add(BlockView.of(segmentBytes.buffer));
      }
      final path = Path(segments);

      final valueLength = _file.readInt();
      final valueBytes = Uint8List(valueLength);
      _file.readBytesInto(valueBytes);
      final valueBlock = BlockView.of(valueBytes.buffer);

      if (value == null) {
        if (!path.isRoot) throw 'First update was not for root.';
        value = UpdatableBlock(valueBlock);
      } else {
        value.update(path, valueBlock, createImplicitly: true);
      }
    }
    return value;
  }

  void _setValue(Path<Block> path, Block value) {
    if (path.isRoot) {
      _replaceRootValue(value);
      return;
    }
    final start = _file.length();
    _file
      ..goToEnd()
      ..writeByte(0) // validity byte
      ..flush()
      ..writeInt(path.length);
    for (final key in path.keys) {
      final bytes = key.toBytes();
      _file
        ..writeInt(bytes.length)
        ..writeBytes(bytes);
    }
    final bytes = value.toBytes();
    _file
      ..writeInt(bytes.length)
      ..writeBytes(bytes)
      ..flush()
      ..goTo(start)
      ..writeByte(1) // make transaction valid
      ..flush();
    // TODO: Broadcast the value.

    // Decide whether to compact.
    _file.goTo(8 /*version*/ + 1 /*validity*/ + 8 /*path length (0)*/);
    final baseValueSize = _file.readInt();
    if (_file.length() / baseValueSize > 1.4) {
      _compact();
    }
  }

  void _compact() {
    print('Compacting...');
    final value = _getValue();
    if (value == null) panic('Attempted to compact, but value is null.');
    _replaceRootValue(value.getAtRoot());
  }

  void _replaceRootValue(Block newValue) {
    final name = _file.path;
    // This is expensive.
    final bytes = newValue.toBytes();
    final newFile = SyncFile('$name.compacted')
      ..clear()
      ..writeInt(0) // version
      ..writeByte(1) // validity bit
      ..writeInt(0) // path has length zero (this is the root object)
      ..writeInt(bytes.length)
      ..writeBytes(bytes)
      ..flush();

    // Replace the old file.
    _file.delete();
    newFile.renameTo(name);
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
