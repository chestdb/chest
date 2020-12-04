extension IterableX<T> on Iterable<T> {
  T? get firstOrNull {
    return isEmpty ? null : cast<T?>().firstWhere((_) => true, orElse: null);
  }
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
