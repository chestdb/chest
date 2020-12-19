import '../storage.dart';
import 'transferable_block.dart';

/// [Action]s are sent from the user's isolate to the chest backend isolate.
abstract class Action {}

abstract class ActionWithUuid extends Action {
  ActionWithUuid(this.uuid);
  final String uuid;
}

class GetValueAction extends Action {}

class SetValueAction extends Action {
  SetValueAction({required this.path, required this.value});

  final Path<Block> path;
  final Block value;
}

class FlushAction extends ActionWithUuid {
  FlushAction(String uuid) : super(uuid);
}

class CompactAction extends ActionWithUuid {
  CompactAction(String uuid) : super(uuid);
}

class CloseAction extends Action {}

/// [Event]s are sent from the chest backend isolate the the user's isolate.
abstract class Event {}

abstract class EventWithUuid extends Event {
  EventWithUuid(this.uuid);
  final String uuid;
}

class ValueEvent extends Event {
  ValueEvent(this.value);

  final TransferableUpdatableBlock? value;
}

class FlushedEvent extends EventWithUuid {
  FlushedEvent(String uuid) : super(uuid);
}

class CompactedEvent extends EventWithUuid {
  CompactedEvent(String uuid) : super(uuid);
}
