import '../storage.dart';
import 'transferable_block.dart';

/// [ActionMessage]s are sent from the user's isolate to the chest backend
/// isolate.
class ActionMessage {
  ActionMessage({required this.uuid, required this.action});

  final String uuid;
  final Action action;
}

/// [EventMessage]s are sent from the chest backend isolate to the user's
/// isolate in response to [ActionMessage]s. They are matched to the
/// corresponding [ActionMessage] using the [uuid].

class EventMessage {
  EventMessage({required this.uuid, required this.event});

  final String uuid;
  final Event event;
}

/// The payload of an [ActionMessage].
abstract class Action {}

class GetValueAction extends Action {}

class SetValueAction extends Action {
  SetValueAction({required this.path, required this.value});

  final Path<Block> path;
  final Block? value;
}

class FlushAction extends Action {}

class MigrateAction extends Action {
  MigrateAction({required this.registry});

  final Registry registry;
}

class CompactAction extends Action {}

class CloseAction extends Action {}

/// The payload of an [EventMessage].
abstract class Event {}

class ErrorEvent extends Event {
  ErrorEvent(this.error, this.stackTrace);

  final String error;
  final String stackTrace;

  @override
  String toString() => '$error\n$stackTrace';
}

class ValueEvent extends Event {
  ValueEvent({required this.value});

  final TransferableUpdatableBlock? value;
}

class ValueSetEvent extends Event {}

class FlushedEvent extends Event {}

class MigratedEvent extends Event {
  MigratedEvent({required this.value});

  final TransferableUpdatableBlock value;
}

class CompactedEvent extends Event {}

class ClosedEvent extends Event {}
