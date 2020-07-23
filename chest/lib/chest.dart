import 'dart:convert';
import 'dart:developer';
import 'dart:isolate';

import 'package:tape/tape.dart';

import 'buckets.dart';
import 'chunky/chunk.dart';
import 'chunky/chunky.dart';
import 'main.dart';

abstract class Chest {
  Chest(String name);
  Future<void> add(Object object);
}

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
        _sendPort.send(name);
      } else {
        print('Warning: Unhandled message $message.');
      }
    });
  }

  @override
  Future<void> add(Object object) async {
    // TODO: wait for [_sendPort] to be initialized.
    final bytes = tape.encode(object);
    _sendPort.send(bytes);
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
  var _bucket = BucketChunk();
  int _index = 0;

  Future<void> run(SendPort sendPort, ReceivePort receivePort) async {
    _sendPort = sendPort;
    _receivePort = receivePort;

    receivePort.listen((message) {
      if (_name == null) {
        _name = message;
        _chunky = Chunky.named('$_name.chest');
        _chunky.transaction((chunky) {
          chunky.write(0, _bucket.chunk);
        });
        return;
      }

      try {
        _bucket.add(message);
      } catch (e) {
        print('_Bucket $_index full (${_bucket.numObjects}): ${_bucket.chunk}');
        _bucket = BucketChunk()..add(message);
        _index++;
        _chunky.transaction((chunky) => chunky.write(_index, _bucket.chunk));
      }
    });

    _registerServiceMethods();
  }

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

class BucketChunk {
  final chunk = Chunk.empty();

  int numObjects = 0;

  void add(List<int> object) {
    if (numObjects >= 256) {
      throw "Doesn't fit.";
    }
    final headerOffset = 1 + 2 * numObjects;
    final dataOffset =
        (headerOffset == 1 ? chunkSize : chunk.getUint16(headerOffset - 2)) -
            object.length;
    if (headerOffset + 2 > dataOffset) {
      throw "Doesn't fit.";
    }

    numObjects++;
    chunk.setUint16(headerOffset, dataOffset);
    for (var i = 0; i < object.length; i++) {
      chunk.setUint8(dataOffset + i, object[i]);
    }
  }
}
