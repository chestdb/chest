import 'dart:convert';
import 'dart:developer';
import 'dart:isolate';

import 'package:chest/chunky/chunky.dart';
import 'package:tape/tape.dart';

import '../chest.dart';
import 'chunks.dart';

/// An implementation of [Chest] for the Dart VM.
///
/// Asynchronous I/O is slow in Dart and we want to be able to communicate with
/// our debugging tooling without huge performance impacts. That's why the
/// [VmChest] spawns another [Isolate] ("the backend") where only synchronous
/// I/O is used. All the heavy lifting is done by the backend and the [VmChest]
/// is merely a thin client that communicates with it by sending messages
/// through ports.
///
/// # Communication
///
/// The first message from the backend is a [SendPort] to enable bidirectional
/// communication. All the other messages exchanged are valid json strings and
/// have a `type` field.
///
/// {'type': 'setup', 'name': '<name of the chest>'}
/// {'type': 'put', 'key': '<base64-encoded key>', 'value': '<base64-encoded value>'}
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
  Box<K, V> box<K, V>(String name) => VmBox._(this, null, name);
}

class VmBox<K, V> implements Box<K, V> {
  VmBox._(this._chest, this._doc, this._name);

  final VmChest _chest;
  final VmDoc _doc; // The parent doc. Is `null` if this is a root box.
  final String _name;

  List<dynamic> get _path => _doc == null ? [_name] : [..._doc._path, _name];

  @override
  Doc<V> doc(K key) => VmDoc._(_chest, this, key);

  @override
  QueryResult<V> rawQuery(Query<IndexedClass<V>> query) {
    print('TODO: Execute the query $query');
    throw UnimplementedError();
  }
}

class VmDoc<K, V> implements Doc<V> {
  VmDoc._(this._chest, this._box, this._key);

  final VmChest _chest;
  final VmBox _box;
  final K _key;

  List<dynamic> get _path => [..._box._path, _key];
  List<dynamic> get path => _path; // TODO: Remove.

  @override
  Box<K, W> box<K, W>(String name) => VmBox._(_chest, this, name);

  @override
  Future<bool> exists() {
    // TODO: implement exists
    throw UnimplementedError();
  }

  @override
  Future<V> get() {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future<void> remove() {
    // TODO: implement remove
    throw UnimplementedError();
  }

  @override
  Future<void> set(V value) {
    // TODO: implement set
    throw UnimplementedError();
  }

  @override
  Stream<V> watch() {
    // TODO: implement watch
    throw UnimplementedError();
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
  final _chunk = ChunkData();

  Future<void> run(SendPort sendPort, ReceivePort receivePort) async {
    _sendPort = sendPort;
    _receivePort = receivePort;

    receivePort.listen((message) {
      final data = json.decode(message) as Map<String, dynamic>;
      print('Message is $message');
      final handler = {
        'setup': setup,
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

  void setup(Map<String, dynamic> message) {
    _name = message['name'];
    _chunky = Chunky('$_name.chest');

    if (_chunky.numberOfChunks == 0) {
      _chunky.transaction((chunky) {
        if (chunky.numberOfChunks == 0) {
          chunky.addTyped(ChunkTypes.main);
        }
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
