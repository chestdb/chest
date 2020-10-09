extension WhereKeyValue<K, V> on Iterable<MapEntry<K, V>> {
  Iterable<MapEntry<K, V>> whereKeyValue(
          bool Function(K key, V value) callback) =>
      where((entry) => callback(entry.key, entry.value));
}
