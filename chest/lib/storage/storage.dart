import '../chest.dart';

abstract class Storage {
  Stream<Event> get events;
  void run(Action action);
}

// Events.

class Event {}

class ValueUpdateEvent extends Event {
  ValueUpdateEvent(this.value);

  final List<int> value;
}

// Actions.

class Action {}

typedef ActionSender = void Function(Action action);

class SetValueAction extends Action {
  SetValueAction(this.path, this.value);

  final Path path;
  final List<int> value;
}

class FlushAction extends Action {}

class CloseAction extends Action {}
