/*import 'dart:async';

import 'package:quiver/collection.dart';

import 'files.dart';
import 'chunky.dart';

class CachedChunkFile implements ChunkFile {
  CachedChunkFile(this._file, this._pool);

  final ChunkFile _file;
  ChunkFile get chunkFile => _file;
  SyncFile get file => _file.file;

  ChunkDataPool _pool;
  _LruMap<int, ChunkData> _cache;

  @override
  void readChunkInto(int index, ChunkData chunk) {
    _cache.putIfAbsent(index, () {
      final newChunk = _pool.reserve();

    });
    // TODO: implement readChunkInto
  }

  @override
  void writeChunk(int index, ChunkData chunk) {
    // TODO: implement writeChunk
  }
}

/// A linked list entry.
class _Linked<T> {
  T value;
  _Linked<T> previous;
  _Linked<T> next;
}

/// A very simple implementation of an LruMap.
class _LruMap<K, V> {
  final _entries = <K, _Linked<V>>{};
  _Linked<V> _head;
  _Linked<V> _tail;

  int _maximumLength;
  int get maximumLength => _maximumLength;
  set maximumLength(int value) {
    _maximumLength = value;
    _shorten();
  }

  operator [](K key) {
    final entry = _entries[key];
    if (entry == null) {
      return null;
    }
    _promote(entry);
    return entry;
  }

  operator []=(K key, V value) {
    var entry = _entries.putIfAbsent(key, () => _create(value));
    entry.value = value;
    _promote(entry);
    _shorten();
  }

  V remove(K key) {
    final entry = _entries.remove(key);
    _remove(entry);
    return entry.value;
  }

  void _shorten() {
    while (_entries.length > maximumLength) {
      _removeLru();
    }
  }

  void _removeLru() {
    if (_tail != null) {
      _remove(_tail);
    }
  }

  _Linked<V> _create(V value) {
    final entry = _Linked()
      ..value = value
      ..next = _head;
    _head?.previous = entry;
    _head = entry;
    _tail ??= entry;
    return entry;
  }

  void _remove(_Linked<V> entry) {
    entry
      ..previous?.next = entry.next
      ..next?.previous = entry.previous
      ..previous = null
      ..next = null;
  }

  void _promote(_Linked<V> entry) {
    _remove(entry);
    entry.next = _head;
    _head.previous = entry;
    _head = entry;
  }
}*/
