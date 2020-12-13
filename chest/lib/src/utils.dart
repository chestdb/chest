import 'dart:typed_data';

extension IterableX<T> on Iterable<T> {
  T? get firstOrNull {
    return isEmpty ? null : cast<T?>().firstWhere((_) => true, orElse: null);
  }
}

extension ListX<T> on List<T> {
  bool deeplyEquals(List<T> other) {
    final length = this.length;
    if (length != other.length) return false;
    for (var i = 0; i < length; i++) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }
}

extension StreamWhereType<T> on Stream<T> {
  Stream<R> whereType<R>() => where((it) => it is R).cast<R>();
}

extension WhereKeyValue<K, V> on Iterable<MapEntry<K, V>> {
  Iterable<MapEntry<K, V>> whereKeyValue(bool Function(K key, V value) check) {
    return where((entry) => check(entry.key, entry.value));
  }

  Iterable<T> mapKeyValue<T>(T Function(K key, V value) mapper) {
    return map((entry) => mapper(entry.key, entry.value));
  }

  Map<K, V> toMap() => Map.fromEntries(this);
}

bool get inDebugMode {
  var test = false;
  assert(() {
    test = true;
    return true;
  }());
  return test;
}

abstract class ChestException implements Exception {}

abstract class ChestError extends Error {}

class _InternalChestError extends ChestError {
  _InternalChestError(this.message);

  final String message;

  String toString() => 'Internal Chest Error: $message';
}

Never panic(String message) => throw _InternalChestError(message);
