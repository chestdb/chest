import '../storage.dart';
import 'transferable_block.dart';

/// [Action]s are sent from the user's isolate to the chest backend isolate.
abstract class Action {}

class GetValueAction extends Action {}

class SetValueAction extends Action {
  SetValueAction({required this.path, required this.value});

  final Path<Block> path;
  final Block value;
}

class FlushAction extends Action {
  FlushAction(this.uuid);

  final String uuid;
}

class CloseAction extends Action {}

/// [Event]s are sent from the chest backend isolate the the user's isolate.
abstract class Event {}

class WholeValueEvent extends Event {
  WholeValueEvent(this.value);

  final TransferableUpdatableBlock? value;
}

class FlushedEvent extends Event {
  FlushedEvent(this.uuid);

  final String uuid;
}
