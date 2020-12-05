import 'dart:async';
import 'dart:isolate';

import '../storage.dart';

/// An implementation of [Chest] for the Dart VM.
///
/// Asynchronous I/O is slow in Dart and we want to be able to communicate with
/// our debugging tooling without huge performance impacts. That's why the
/// [VmStorage] spawns another [Isolate] ("the backend") where only synchronous
/// I/O is used. All the heavy lifting is done by the backend and the [VmStorage]
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
class VmStorage implements Storage {
  static Future<VmStorage> open(String name) async {
    // final receivePort = ReceivePort();
    // final isolate = await Isolate.spawn(
    //   _runBackend,
    //   SetupInfo(name, receivePort.sendPort),
    //   debugName: 'chest.$name',
    // );
    // final incoming = receivePort.asBroadcastStream();
    // final answer = await incoming.first as SetupAnswer;
    return VmStorage._(
      name,
      // events: incoming.cast<Event>(),
      // sendAction: answer.sendPort.send,
    );
  }

  VmStorage._(this.name);

  final String name;

  final _updatesController = StreamController<Delta>.broadcast();
  Stream<Delta> get updates => _updatesController.stream;

  Future<Block?> getValue() async {
    throw UnimplementedError();
  }

  void setValue(Path path, Block value) {}

  @override
  Future<void> flush() {
    throw UnimplementedError();
  }

  @override
  Future<void> close() {
    throw UnimplementedError();
    // _isolate.kill(); // TODO: implement
  }
}

// extension on Stream<Response> {
//   Future<void> waitForAck() =>
//       firstWhere((response) => response is AckResponse);
// }

// class SetupInfo {
//   SetupInfo(this.name, this.sendPort);

//   final String name;
//   final SendPort sendPort;
// }

// class SetupAnswer {
//   SetupAnswer(this.sendPort);

//   final SendPort sendPort;
// }

/// This is the entrypoint for the backend isolate.
// Future<void> _runBackend(SetupInfo info) async {
//   final receivePort = ReceivePort();
//   info.sendPort.send(SetupAnswer(receivePort.sendPort));

//   print('Not running backend.');
//   // VmBackend().run(sendPort, receivePort);
// }
