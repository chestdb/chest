import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:chest/chunky/chunky.dart';
import 'package:meta/meta.dart';
import 'package:tape/tape.dart';

import 'utils.dart';
import 'vm_chest.dart';

class VmBackend {
  /// Completes as soon as [_chunky] is initialized.
  final _initializer = Completer<void>();
  SendPort _sendPort;
  Chunky _chunky;

  Future<void> run(SendPort sendPort, ReceivePort receivePort) async {
    _sendPort = sendPort;
    receivePort.listen((message) {
      final request = message as Request;
      final action = {
        SetupRequest: () => setup(request),
        SetRequest: () => set(request),
      }[request.runtimeType];

      if (action == null) {
        print('Backend: Unhandled request type: ${request.runtimeType}');
      } else {
        action();
      }
    });

    _registerServiceMethods();
  }

  void send(Response response) {
    print('<- $response.');
    _sendPort.send(response);
  }

  Future<void> setup(SetupRequest request) async {
    print('Backend: Setting up.');
    _chunky = Chunky('${request.name}.chest');

    if (_chunky.numberOfChunks == 0) {
      await _chunky.transaction((chunky) => chunky.addTyped(ChunkTypes.main));
    }

    _initializer.complete();
    send(AckResponse(request));
  }

  /// Returns the position of the [BoxChunk] at the given [path].
  Future<int> _box(Transaction chunky, List<Object> path) async {
    assert(path.isNotEmpty);
    final name = path.removeLast();
    final boxes = path.isEmpty
        ? (await chunky[0]).parse<MainChunk>().boxes
        : _doc(chunky, path).resolve().boxes;
    return boxes.find(name);
  }

  /// Returns the doc id of the document at the given [path].
  Future<int> _doc(Transaction chunky, List<Object> path) async {
    assert(path.isNotEmpty);
    final key = path.removeLast();
    final box = await _box(chunky, path);
    final tree = (await chunky[box]).parse() as PayloadToIntTree;
    return tree.find(key);
  }

  Future<void> set(SetRequest request) async {
    await _initializer.future;
    final path = request.path;
    final value = request.value;
    print('Backend: Adding $path: $value');
    print(zlib.encode(request.value));
    send(AckResponse(request));
  }

  void _registerServiceMethods() {
    registerExtension('ext.chest.num_chunks', (method, parameters) async {
      print("Returning the number of chunks.");
      return ServiceExtensionResponse.result(json.encode({
        'type': 'size',
        'size': _chunky.numberOfChunks,
      }));
    });
  }
}
