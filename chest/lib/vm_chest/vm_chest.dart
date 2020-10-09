import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:isolate';
import 'dart:math';

import 'package:chest/chunky/chunky.dart';
import 'package:meta/meta.dart';
import 'package:tape/tape.dart';

import '../chest.dart';
import 'backend.dart';
import 'utils.dart';

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

  /// Completes as soon as bidirectional communication channels [_sendPort] and
  /// [_incomingMessages] are established.
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
    _incomingMessages = receivePort.asBroadcastStream();
    _sendPort = await _incomingMessages.first;
    _initializer.complete();
    await _sendRequest(SetupRequest(name)).waitForAck();
  }

  @override
  Box<K, V> box<K, V>(String name) => VmBox._(this, null, name);

  @override
  Future<void> close() {
    throw UnimplementedError();
    // _isolate.kill(); // TODO: implement
  }

  /// Sends the given [request] and answers with a [Stream] of [Response]s to
  /// that request.
  Stream<Response> _sendRequest(Request request) {
    final controller = StreamController<Response>();

    scheduleMicrotask(() async {
      await _initializer.future;
      _sendPort.send(request);
      print('-> $request.');
      controller.addStream(_incomingMessages
          .cast<Response>()
          .where((response) => response.requestId == request.id));
    });
    return controller.stream;
  }
}

extension on Stream<Response> {
  Future<void> waitForAck() =>
      firstWhere((response) => response is AckResponse);
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
  Future<bool> exists() async {
    throw UnimplementedError();
    await _chest._sendRequest(ExistsRequest(_path));
  }

  @override
  Future<V> get() async {
    throw UnimplementedError();
    await _chest._sendRequest(GetRequest(_path));
  }

  @override
  Future<void> remove() async {
    await _chest._sendRequest(RemoveRequest(_path)).waitForAck();
  }

  @override
  Future<void> set(V value) async {
    await _chest
        ._sendRequest(SetRequest(_path, tape.encode(value)))
        .waitForAck();
  }

  @override
  Stream<V> watch() {
    // TODO: implement watch
    throw UnimplementedError();
  }
}

/// This is the entrypoint for the backend isolate.
Future<void> _runBackend(SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  print('Not running backend.');
  // VmBackend().run(sendPort, receivePort);
}

@sealed
class Request {
  Request(this.id);

  Request.withRandomId() {
    final random = Random();
    id = base64.encode([
      for (var i = 0; i < 32; i++) random.nextInt(256),
    ]);
  }

  String id;
}

class SetupRequest extends Request {
  SetupRequest(this.name) : super.withRandomId();

  final String name;

  @override
  String toString() => 'SetupRequest@$id($name)';
}

class ExistsRequest extends Request {
  ExistsRequest(this.path) : super.withRandomId();

  final List<Object> path;

  @override
  String toString() => 'ExistsRequest@$id($path)';
}

class SetRequest extends Request {
  SetRequest(this.path, this.value) : super.withRandomId();

  final List<Object> path;
  final Object value;

  @override
  String toString() => 'SetRequest@$id($path: $value)';
}

class GetRequest extends Request {
  GetRequest(this.path) : super.withRandomId();

  final List<Object> path;

  @override
  String toString() => 'GetRequest@$id($path)';
}

class RemoveRequest extends Request {
  RemoveRequest(this.path) : super.withRandomId();

  final List<Object> path;

  @override
  String toString() => 'RemoveRequest@$id($path)';
}

class WatchRequest extends Request {
  WatchRequest(this.path) : super.withRandomId();

  final List<Object> path;

  @override
  String toString() => 'WatchRequest@$id($path)';
}

class QueryRequest extends Request {
  QueryRequest(this.path, this.query) : super.withRandomId();

  final List<Object> path;
  final Query<dynamic> query;

  @override
  String toString() => 'QueryRequest@$id($path, $query)';
}

@sealed
class Response {
  Response(Request request) : requestId = request.id;

  final String requestId;
}

class AckResponse extends Response {
  AckResponse(Request request) : super(request);

  @override
  String toString() => 'AckResponse@$requestId';
}

class ValueResponse extends Response {
  ValueResponse(Request request, this.value) : super(request);

  final dynamic value;

  @override
  String toString() => 'ValueResponse@$requestId($value)';
}
