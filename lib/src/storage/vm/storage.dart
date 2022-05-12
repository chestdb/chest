import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import '../utils.dart';
import 'backend.dart';
import 'file.dart';
import 'message.dart';

Future<Storage> openStorage(String name) => VmStorage.open(name);
Future<void> deleteChest(String name) => VmStorage.delete(name);

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
      _SetupInfo(
        rootPath: tape.rootPath,
        name: name,
        sendPort: receivePort.sendPort,
      ),
      debugName: 'chest.$name',
    );
    final incoming = receivePort.asBroadcastStream();
    final answer = await incoming.first as _SetupAnswer;
    return VmStorage._(
      name,
      incomingMessages: incoming.cast<EventMessage>(),
      sendMessage: answer.sendPort.send,
      dispose: () => receivePort.close(),
    );
  }

  static Future<void> delete(String name) async {
    SyncFile('${tape.rootPath}/$name.chest').delete();
  }

  VmStorage._(
    this.name, {
    required this.incomingMessages,
    required this.sendMessage,
    required this.dispose,
  });

  final String name;

  @override
  Stream<Update> get updates => _updatesController.stream;
  final _updatesController = StreamController<Update>.broadcast();

  final Stream<EventMessage> incomingMessages;
  final void Function(ActionMessage action) sendMessage;
  final void Function() dispose;

  Future<E> _send<E extends Event>(Action action) async {
    final uuid = _randomUuid();
    sendMessage(ActionMessage(uuid: uuid, action: action));
    final answer =
        await incomingMessages.firstWhere((message) => message.uuid == uuid);
    final event = answer.event;
    if (event is ErrorEvent) {
      throw event.error;
    }
    if (event is! E) {
      panic("Cast of received event failed. Expected $E, but was "
          "${event.runtimeType}");
    }
    return event;
  }

  @override
  Future<UpdatableBlock?> getValue() async {
    print('Sending GetValueAction');
    final event = await _send<ValueEvent>(GetValueAction());
    return event.value?.materialize();
  }

  @override
  Future<void> setValue(Path<Block> path, Block? value) async {
    await _send<ValueSetEvent>(SetValueAction(path: path, value: value));
  }

  @override
  Future<void> flush() async => await _send<FlushedEvent>(FlushAction());

  @override
  Future<UpdatableBlock> migrate() async {
    final event = await _send<MigratedEvent>(MigrateAction(registry: registry));
    return event.value.materialize();
  }

  @override
  Future<void> compact() async => await _send<CompactedEvent>(CompactAction());

  @override
  Future<void> close() async {
    await _send<ClosedEvent>(CloseAction());
    dispose();
  }
}

class _SetupInfo {
  _SetupInfo(
      {required this.rootPath, required this.name, required this.sendPort});

  final String rootPath;
  final String name;
  final SendPort sendPort;
}

class _SetupAnswer {
  _SetupAnswer({required this.sendPort});

  final SendPort sendPort;
}

/// This is the entrypoint for the backend isolate.
Future<void> _runBackend(_SetupInfo info) async {
  final receivePort = ReceivePort();
  tape.rootPath = info.rootPath;
  info.sendPort.send(_SetupAnswer(sendPort: receivePort.sendPort));

  // In its constructor, the [VmBackend] automatically listens for incoming
  // actions.
  VmBackend(
    name: info.name,
    incomingMessages: receivePort.cast<ActionMessage>(),
    sendMessage: info.sendPort.send,
    dispose: () => receivePort.close(),
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
