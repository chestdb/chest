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
import 'messages.dart';
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
/// The chest sends request to the backend, which is a server. `requestId`s are
/// used to match responses to requests.
/// The backend might also proactively send messages: If the same [Chest] is
/// opened in multiple [Isolate]s, all are connected to the same backend. So, it
/// one [Isolate] sets the value, the backend sends the updated value to all
/// others.
///
/// ## Acknowledgement
///
/// The backend answers with this message to indicate an action is complete.
class VmChest<T> implements Chest<T> {
  static Future<VmChest> open(String name) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _runBackend,
      SetupInfo(name, receivePort.sendPort),
      debugName: 'chest.$name',
    );
    final incoming = receivePort.asBroadcastStream();
    final answer = await incoming.first as SetupAnswer;
    return VmChest._(
      name: name,
      events: incoming.cast<Event>(),
      sendAction: answer.sendPort.send,
    );
  }

  VmChest._({
    @required this.name,
    @required this.events,
    @required this.sendAction,
  });

  final String name;
  final Stream<Event> events;
  final ActionSender sendAction;

  @override
  Future<void> flush() {
    throw UnimplementedError();
  }

  @override
  Future<void> close() {
    throw UnimplementedError();
    // _isolate.kill(); // TODO: implement
  }

  bool get isEmpty => (throw UnimplementedError());

  set value(T newValue) {
    sendAction(SetRequest(Path([]), tape.encode(value))).waitForAck();
  }

  T get value {}
}

class FieldRef<T> implements Ref<T> {
  FieldRef(this._box, this._fieldIds);

  final Box<dynamic> _box;
  final List<int> _fieldIds;
  Path get path => Path(_box.name, _fieldIds);

  Ref<R> field<R>(int fieldId) => FieldRef<R>(_box, [..._fieldIds, fieldId]);
  T get() => _box._chest._backend.get(path);
}

extension on Stream<Response> {
  Future<void> waitForAck() =>
      firstWhere((response) => response is AckResponse);
}

class SetupInfo {
  SetupInfo(this.name, this.sendPort);

  final String name;
  final SendPort sendPort;
}

class SetupAnswer {
  SetupAnswer(this.sendPort);

  final SendPort sendPort;
}

/// This is the entrypoint for the backend isolate.
Future<void> _runBackend(SetupInfo info) async {
  final receivePort = ReceivePort();
  info.sendPort.send(SetupAnswer(receivePort.sendPort));

  print('Not running backend.');
  // VmBackend().run(sendPort, receivePort);
}
