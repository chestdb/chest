import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:isolate';
import 'dart:math';

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
/// The backend acts like a server. All communication is initially started by
/// the clients. They use a `requestId` field to match responses to the original
/// requests.
/// The server might answer multiple messages to the same request. For example,
/// the result of a query is streamed to the client – sending every document in
/// its own message. Or a watch request causes the backend to send messages when
/// documents are changed.
/// Because you can access the same [Chest] from multiple [Isolate]s / clients
/// which connect to the same backend [Isolate], it may even seem like the
/// backend proactively sends messages if you watch docs.
///
/// ## Acknowledgement
///
/// The backend answers with this message to indicate an action is complete.
///
/// {'requestId': '<request id>', 'type': 'ack'}
///
/// ## Setup
///
/// This message contains information for setting up the chest.
/// The backend answers with an ack message.
///
/// {
///   'requestId': '<request id>',
///   'type': 'setup',
///   'name': '<name of the chest>'
/// }
///
/// ## Put
///
/// This message is used to put a document at a specific location, creating the
/// parent collection implicitly (if it doesn't already exist).
/// The backend answers with an ack message.
///
/// {
///   'requestId': '<request id>',
///   'type': 'put',
///   'path': ['string', '<base64-encoded key>'],
///   'value': '<base64-encoded value>'
/// }
class VmChest implements Chest {
  VmChest(this.name) {
    _spawnBackend();
  }

  final String name;

  final _initializer = Completer<void>();
  Isolate _isolate;
  SendPort _sendPort;
  Stream<Object> _incomingMessages;

  Future<void> _spawnBackend() async {
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _runBackend,
      receivePort.sendPort,
      debugName: 'chest.$name',
    );
    final _incomingMessages = receivePort.map((message) {
      print('Received message $message.');
      return message;
    }).asBroadcastStream();
    _sendPort = await _incomingMessages.first;
    await _sendRequest({'type': 'setup', 'name': name}).waitForAck();
    _initializer.complete();
  }

  @override
  Box<K, V> box<K, V>(String name) => VmBox._(this, null, name);

  @override
  Future<void> close() {
    throw UnimplementedError();
    _isolate.kill();
  }

  Stream<Map<String, dynamic>> _sendRequest(Map<String, dynamic> request) {
    final controller = StreamController<Map<String, dynamic>>();
    final random = Random();
    final requestId = base64.encode([
      for (var i = 0; i < 32; i++) random.nextInt(256),
    ]);
    request['requestId'] = requestId;

    scheduleMicrotask(() async {
      await _initializer.future;
      _sendPort.send(request);
      print('Sent request $request.');
      controller.addStream(_incomingMessages
          .cast<String>()
          .map(json.decode)
          .cast<Map<String, dynamic>>()
          .where((message) => message['requestId'] == requestId));
    });
    return controller.stream;
  }
}

extension on Stream<Map<String, dynamic>> {
  Future<void> waitForAck() =>
      firstWhere((message) => message['type'] == 'ack');
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
  Future<void> set(V value) async {
    await _chest._sendRequest({
      'type': 'put',
      'path': _path,
      'value': base64.encode(tape.encode(value)),
    }).waitForAck();
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
