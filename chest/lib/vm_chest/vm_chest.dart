import 'dart:convert';
import 'dart:developer';
import 'dart:isolate';

import 'package:chest/chunky/chunk.dart';
import 'package:chest/chunky/chunky.dart';
import 'package:tape/tape.dart';

import '../chest.dart';
import 'chunks/chunks.dart';

class VmChest implements Chest {
  VmChest(this.name) {
    _spawnBackend();
  }

  final String name;
  Isolate _isolate;
  ReceivePort _receivePort;
  SendPort _sendPort;

  Future<void> _spawnBackend() async {
    final _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _runBackend,
      _receivePort.sendPort,
      debugName: 'chest.$name',
    );
    _receivePort.listen((message) {
      if (_sendPort == null) {
        /// The first message is a [SendPort].
        _sendPort = message;
        _sendPort.send(json.encode({
          'type': 'setup',
          'name': name,
        }));
      } else {
        print('Warning: Unhandled message $message.');
      }
    });
  }

  @override
  Future<void> put(List<int> key, Object value) async {
    // TODO: wait for [_sendPort] to be initialized.
    _sendPort.send(json.encode({
      'type': 'put',
      'key': base64.encode(key),
      'value': base64.encode(tape.encode(value)),
    }));
  }
}

Future<void> _runBackend(SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  _ChestVmBackend().run(sendPort, receivePort);
}

class _ChestVmBackend {
  SendPort _sendPort;
  ReceivePort _receivePort;
  String _name;
  Chunky _chunky;
  int _index = 0;
  final _chunk = Chunk();

  Future<void> run(SendPort sendPort, ReceivePort receivePort) async {
    _sendPort = sendPort;
    _receivePort = receivePort;

    receivePort.listen((message) {
      final data = json.decode(message) as Map<String, dynamic>;
      print('Message is $message');
      final handler = {
        'setup': initialize,
        'put': put,
      }[data['type']];
      if (handler == null) {
        print('Unhandled message type: ${data['type']}');
      } else {
        handler(data);
      }
    });

    _registerServiceMethods();
  }

  void initialize(Map<String, dynamic> message) {
    _name = message['name'];
    _chunky = Chunky.named('$_name.chest');

    if (_chunky.numberOfChunks == 0) {
      _chunky.transaction((chunky) {
        // MainChunk(_chunk).apply();
        chunky.write(0, _chunk);

        // DocTreeChunk(_chunk).apply();
        chunky.write(1, _chunk);
      });
    }
  }

  void put(Map<String, dynamic> message) {
    final key = base64.decode(message['key'] as String);
    final value = base64.decode(message['value'] as String);
    print('Adding $key: $value');
  }

  void _put(List<int> key, List<int> value) {}

  void _registerServiceMethods() {
    registerExtension('ext.chest.num_chunks', (method, parameters) async {
      print("Returning the number of chunks.");
      return ServiceExtensionResponse.result(json.encode({
        'type': 'size',
        'size': _index,
      }));
    });
  }
}
