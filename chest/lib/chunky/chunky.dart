import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:meta/meta.dart';

import 'package:chest/vm_chest/chunks/chunks.dart';

import 'files.dart';

part 'chunk.dart';

// Assumptions:
// - Transactions concern few chunks. All the accessed chunks fit into memory.

typedef TransactionCallback<T> = FutureOr<T> Function(Transaction);

/// [Chunky] offers low-level primitives of loading parts of a file (so-called
/// "chunks") into memory, and writing in atomic batches. Those chunks all have
/// the same size: [chunkSize].
///
/// [Chunky] actually manages two files:
/// - The chunk file holds the actual chunk data (this can be a lot of data).
/// - The transaction file holds all changes of the currently applied
///   transaction.
class Chunky {
  Chunky._(this._chunkFile, this._transactionFile);

  Chunky.fromFiles({
    @required SyncFile chunkFile,
    @required SyncFile transactionFile,
  }) : this._(ChunkFile(chunkFile), TransactionFile(transactionFile));

  Chunky(String name)
      : this.fromFiles(
          chunkFile: SyncFile(name),
          transactionFile: SyncFile('$name.transaction'),
        );

  final ChunkFile _chunkFile;
  final TransactionFile _transactionFile;
  final _chunkDataPool = ChunkDataPool();

  var _transactionFuture = Future<void>.value();
  var _transactionQueueLength = 0;
  bool get _isTransactionQueueEmpty => _transactionQueueLength == 0;

  int get numberOfChunks => _chunkFile.numberOfChunks;

  Future<T> transaction<T>(TransactionCallback callback) {
    final previousFuture = _transactionFuture;
    final completer = Completer<T>();
    _transactionFuture = completer.future;
    _transactionQueueLength++;

    return previousFuture.then((_) async {
      final transaction =
          Transaction._(_chunkFile, _transactionFile, _chunkDataPool);
      T result;
      try {
        result = await callback(transaction);
      } finally {
        _transactionQueueLength--;
      }
      transaction._commit();
      completer.complete(result);
      return result;
    });
  }

  Future<void> clear() async {
    _chunkFile.file.clear();
  }

  // TODO(marcelgarus): What exactly does it mean to close chunky?
  Future<void> close() async {
    while (!_isTransactionQueueEmpty) {
      await _transactionFuture;
    }
    _chunkFile.file.close();
    _transactionFile.file.close();
  }
}

class Transaction {
  Transaction._(this._chunkFile, this._transactionFile, this._pool) {
    _numberOfChunks = _chunkFile.numberOfChunks;
  }

  final ChunkFile _chunkFile;
  final TransactionFile _transactionFile;
  final _pool;

  final _originalChunks = <int, ChunkData>{};
  final _newChunks = <int, TransactionChunk>{};

  /// How many chunks the chunk file contains.
  int get numberOfChunks => _numberOfChunks;
  int _numberOfChunks;

  TransactionChunk add() {
    final index = _numberOfChunks;
    final chunk = TransactionChunk(index, _pool.reserve());
    _newChunks[index] = chunk;
    _numberOfChunks++;
    return chunk;
  }

  Chunk operator [](int index) {
    if (_newChunks.containsKey(index)) {
      return _newChunks[index];
    }
    final originalChunk = _pool.reserve();
    final newChunk = _pool.reserve();

    _chunkFile.readChunkInto(index, originalChunk);
    _originalChunks[index] = originalChunk;

    newChunk.copyFrom(originalChunk);
    final chunk = TransactionChunk(index, newChunk);
    _newChunks[index] = chunk;

    return chunk;
  }

  void _commit() {
    final differentChunks = _newChunks.entries
        .where((entry) =>
            !_originalChunks.containsKey(entry.key) || entry.value.isDirty)
        .where((entry) => entry.value._data != _originalChunks[entry.key])
        .toList();
    print('Changed chunks:');
    for (final chunk in differentChunks) {
      print('${chunk.key}: ${chunk.value.parse()}');
    }
    if (differentChunks.isEmpty) {
      return; // Nothing changed.
    }
    _transactionFile.start();
    for (final entry in differentChunks) {
      _transactionFile.addChange(entry.key, entry.value._data);
    }
    _transactionFile.commit();
    for (final entry in differentChunks) {
      _chunkFile.writeChunk(entry.key, entry.value._data);
    }
    _chunkFile.file.flush();
    _transactionFile.start();
  }

  static restoreIfCommitted(
    ChunkFile _chunkFile,
    TransactionFile _transactionFile,
  ) {
    if (!_transactionFile.isCommitted) {
      return;
    }

    final chunk = ChunkData();
    final reader = _transactionFile.reader;
    while (!reader.isAtEnd) {
      final index = reader.next(chunk);
      _chunkFile.writeChunk(index, chunk);
    }
  }
}

class ChunkDataPool {
  final _data = <ChunkData>[];

  ChunkData reserve() {
    return _data.isEmpty ? ChunkData() : _data.removeAt(0);
  }

  void free(ChunkData chunk) {
    _data.add(chunk);
  }
}

/*
class Chunky {
  /// How many chunks the chunk file contains.
  int get numberOfChunks => _numberOfChunks;
  int _numberOfChunks;
}

class ChunkyTransaction {
  /// How many chunks the chunk file contains.
  int get numberOfChunks => _numberOfChunks;
  int _numberOfChunks;

  int add(Chunk chunk) {
    assert(!_isCommitted);

    final index = _numberOfChunks;
    write(index, chunk);
    return index;
  }

  void _commit() {
    final chunkBuffer = Chunk();
    _transactionFile
      ..flush()
      ..goTo(0)
      ..writeByte(255)
      ..flush();

    // Rather than going through the transaction file and applying the changes
    // one by one, we combine multiple changes to the same chunk into one change
    // by only applying all [changedChunks] once.
    for (final entry in _changedChunks.entries) {
      final index = entry.key;
      final offset = entry.value;
      _transactionFile
        ..goTo(offset)
        ..readChunkInto(chunkBuffer);
      _chunky._write(index, chunkBuffer);
    }

    _chunky._flush();
    _transactionFile
      ..goTo(0)
      ..writeByte(0)
      ..flush();
  }

  static restoreIfCommitted(SyncFile _transactionFile, SyncFile _chunkFile) {
    _transactionFile.goTo(0);
    if (_transactionFile.length() == 0 || _transactionFile.readByte() == 0) {
      // The file doesn't contain a committed transaction.
      return;
    }

    // Restore the committed transaction.
    final chunkBuffer = Chunk();
    final length = _transactionFile.length();
    var position = 1;

    while (position < length) {
      final index = _transactionFile.readInt();
      _transactionFile.readChunkInto(chunkBuffer);
      _chunkFile
        ..goToIndex(index)
        ..writeChunk(chunkBuffer);
      position += 8 + chunkSize;
    }
  }
}*/
