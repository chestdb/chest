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
  Iterable<MapEntry<K, V>> whereKeyValue(bool Function(K key, V value) check) =>
      where((entry) => check(entry.key, entry.value));

  Iterable<T> mapKeyValue<T>(T Function(K key, V value) mapper) =>
      map((entry) => mapper(entry.key, entry.value));

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

const repoUrl = 'https://github.com/chestdb/chest';
String newIssueUrl(String title, String body, [List<String> tags = const []]) {
  return '$repoUrl/issues/new?title=${Uri.encodeComponent(title)}&'
      'body=${Uri.encodeComponent(body)}&'
      'tags=${tags.map(Uri.encodeComponent).join(',')}';
}

class _InternalChestError extends ChestError {
  _InternalChestError(this.message);

  final String message;

  String toString() {
    return 'An internal Chest Error occurred:\n$message\n\n'
            'This is not supposed to happen and either indicates that there is '
            'an error in the Chest package itself or that the error message '
            'should be substantially improved. Either way, please open a new '
            'issue at ' +
        newIssueUrl(
          'Internal error: $message',
          "Hi, I'm experiencing the following error:\n$message\n"
              '<details>\n<summary>Stack trace</summary>\n\n$stackTrace\n</details>',
        );
  }
}

Never panic(String message) => throw _InternalChestError(message);
