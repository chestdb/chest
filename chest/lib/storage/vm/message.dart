import '../storage.dart';

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

abstract class Event {}

class WholeValueEvent extends Event {
  WholeValueEvent(this.value);

  final Value? value;
}

class FlushedEvent extends Event {
  FlushedEvent(this.uuid);

  final String uuid;
}
