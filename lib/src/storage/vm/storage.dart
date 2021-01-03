import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import '../../utils.dart';
import '../storage.dart';
import 'backend.dart';
import 'message.dart';

Future<Storage> openStorage(String name) => VmStorage.open(name);

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
    final receivePort = ReceivePort();
    // TODO: Try to find existing isolate.
    await Isolate.spawn(
      _runBackend,
      SetupInfo(name, receivePort.sendPort),
      debugName: 'chest.$name',
    );
    final incoming = receivePort.asBroadcastStream();
    final answer = await incoming.first as SetupAnswer;
    return VmStorage._(
      name,
      events: incoming.cast<Event>(),
      sendAction: answer.sendPort.send,
      dispose: () {
        answer.sendPort.send(CloseAction());
        receivePort.close();
      },
    );
  }

  VmStorage._(
    this.name, {
    required this.events,
    required this.sendAction,
    required this.dispose,
  });

  final String name;

  @override
  Stream<Update> get updates => _updatesController.stream;
  final _updatesController = StreamController<Update>.broadcast();

  final Stream<Event> events;
  final void Function(Action action) sendAction;
  final void Function() dispose;

  @override
  Future<UpdatableBlock?> getValue() async {
    sendAction(GetValueAction());
    final event = await events.waitFor<ValueEvent>();
    return event.value?.materialize();
  }

  @override
  void setValue(Path<Block> path, Block value) {
    sendAction(SetValueAction(path: path, value: value));
  }

  @override
  Future<void> flush() async {
    final uuid = _randomUuid();
    sendAction(FlushAction(uuid));
    await events.waitFor<FlushedEvent>(withUuid(uuid));
  }

  @override
  Future<UpdatableBlock> migrate() async {
    final uuid = _randomUuid();
    sendAction(MigrateAction(uuid, registry));
    final event = await events.waitFor<MigratedEvent>(withUuid(uuid));
    return event.value.materialize();
  }

  @override
  Future<void> compact() async {
    final uuid = _randomUuid();
    sendAction(CompactAction(uuid));
    await events.waitFor<CompactedEvent>(withUuid(uuid));
  }

  @override
  Future<void> close() async {
    dispose();
  }
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

  // In its constructor, the [VmBackend] automatically listens for incoming
  // actions.
  VmBackend(
    name: info.name,
    incomingActions: receivePort.cast<Action>(),
    sendEvent: info.sendPort.send,
    dispose: () {
      receivePort.close();
    },
  );
}

extension WaitableStream<T> on Stream<T> {
  Future<R> waitFor<R>([bool Function(R value)? checker]) {
    checker ??= (_) => true;
    return whereType<R>().where(checker).first;
  }
}

String _randomUuid() {
  final buffer = StringBuffer();
  final random = Random();
  final chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  for (var i = 0; i < 10; i++) {
    buffer.write(chars[random.nextInt(chars.length)]);
  }
  return buffer.toString();
}

bool Function(EventWithUuid event) withUuid(String uuid) =>
    (EventWithUuid event) => event.uuid == uuid;
