import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import '../../bytes.dart';
import '../../utils.dart';
import '../storage.dart';
import 'file.dart';
import 'message.dart';
import 'storage.dart';

/// The [VmBackend] is responsible for managing access to a `.chest` file.
///
/// Multiple [Storage]s of the same chest running on different [Isolate]s all
/// communicate with the same [VmBackend].
///
/// ## File layout
///
/// TODO: Support versioning.
/// TODO: Support delta updates.
/// TODO: Compress bytes.
/// | value |
class VmBackend {
  VmBackend({
    required String name,
    required Stream<Action> incomingActions,
    required this.sendEvent,
  }) : _file = SyncFile('$name.chest') {
    incomingActions.listen(_handleAction);
    _registerServiceMethods();
  }

  final SyncFile _file;
  final void Function(Event event) sendEvent;

  Future<void> _handleAction(Action action) async {
    print('Handling action $action.');
    if (action is GetValueAction) {
      Value? value;

      if (_file.length() == 0) {
        value = null;
      } else {
        final bytes = Uint8List(_file.length());
        _file.readBytesInto(bytes);
        print('Read bytes: $bytes');
        print('As blocks: ${BlockView.of(bytes.buffer)}');
        value = Value(BlockView.of(bytes.buffer));
      }
      sendEvent(WholeValueEvent(value));
    } else if (action is SetValueAction) {
      final bytes = action.value.toBytes();
      _file
        ..clear()
        ..writeBytes(bytes);
      // TODO: Broadcast the value.
    } else if (action is FlushAction) {
      _file.flush();
      sendEvent(FlushedEvent(action.uuid));
    }
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
