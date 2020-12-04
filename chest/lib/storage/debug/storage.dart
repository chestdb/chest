import 'dart:async';

import '../storage.dart';

class DebugStorage implements Storage {
  DebugStorage() : eventsController = StreamController<Event>.broadcast() {
    _sendEvents();
  }

  final StreamController<Event> eventsController;

  @override
  Stream<Event> get events => eventsController.stream;

  Future<void> _sendEvents() async {
    await Future.delayed(Duration(milliseconds: 100));
    eventsController.add(ValueUpdateEvent([1]));
    await Future.delayed(Duration(milliseconds: 100));
    eventsController.add(ValueUpdateEvent([2]));
    await Future.delayed(Duration(milliseconds: 100));
    eventsController.add(ValueUpdateEvent([3]));
  }

  @override
  void run(Action action) {
    if (action is SetValueAction) {
      print('Setting value to ${action.value}.');
      eventsController.add(ValueUpdateEvent([action.value as int]));
    } else {
      print('Running $action.');
    }
  }
}
