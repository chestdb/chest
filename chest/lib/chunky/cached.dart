import 'dart:async';

import 'package:chest/chunky/sync_file.dart';
import 'package:quiver/collection.dart';

import 'chunky.dart';
import 'live_chunk.dart';

class CachedChunky implements Chunky {
  CachedChunky(this.chunky, {int readCacheSize = 16}) {
    _cache = LruMap<int, Chunk>(maximumSize: readCacheSize);
  }

  final Chunky chunky;
  LruMap<int, Chunk> _cache;

  @override
  SyncFile get chunkFile => chunky.chunkFile;

  @override
  SyncFile get transactionFile => chunky.transactionFile;

  @override
  int get numberOfChunks => chunky.numberOfChunks;

  @override
  void readInto(int index, Chunk chunk) {
    _cache.putIfAbsent(index, () {
      final chunk = Chunk();
      return Chunk.copyOf(chunk);
    }).copyTo(chunk);
  }

  @override
  Future<T> transaction<T>(FutureOr<T> Function(ChunkyTransaction) callback) {
    return chunky.transaction((chunky) {
      return callback(chunky);
    });
  }

  @override
  Future<void> close() => chunky.close();
}

class CachedChunkyTransaction implements ChunkyTransaction {
  CachedChunkyTransaction(this._chunky, {int cacheSize = 16}) {
    _cache = LruMap<int, Chunk>();
    _numberOfChunks = _chunky.numberOfChunks;
  }

  final ChunkyTransaction _chunky;
  LruMap<int, Chunk> _cache;

  int get numberOfChunks => _numberOfChunks;
  int _numberOfChunks;

  void readInto(int index, Chunk chunk) {
    _cache.putIfAbsent(index, () {
      final chunk = Chunk();
      return Chunk.copyOf(chunk);
    }).copyTo(chunk);
  }

  LiveChunk readIntoLive(int index, Chunk chunk) {
    readInto(index, chunk);
    return LiveChunk(chunky: this, index: index, chunk: chunk);
  }

  @Deprecated('This is really inefficient.')
  Chunk read(int index) {
    final chunk = Chunk();
    readInto(index, chunk);
    return chunk;
  }

  @Deprecated('This is really inefficient.')
  LiveChunk readLive(int index) =>
      LiveChunk(chunky: this, index: index, chunk: read(index));

  void write(int index, Chunk chunk) {
    if (_cache.containsKey(index)) {
      _cache[index].copyFrom(chunk);
    } else {
      // final nextEvicted = _cache.nextEvicted;
      // _chunky.write(nextEvicted.key, nextEvicted.value);
      _cache[index] = Chunk()..copyFrom(chunk);
    }
    // TODO(marcelgarus): Don't always write the chunk directly, but only when necessary (pseudo-code above).
    _chunky.write(index, chunk);
  }

  int add(Chunk chunk) {
    final index = numberOfChunks;
    write(index, chunk);
    return index;
  }

  LiveChunk addLive(Chunk chunk) {
    final index = add(chunk);
    return LiveChunk(chunky: this, index: index, chunk: chunk);
  }
}
