import 'dart:async';
import 'dart:typed_data';

import 'package:chest/utils.dart';
import 'package:convert/convert.dart';
import 'package:meta/meta.dart';

import 'files.dart';
import 'constants.dart';

export 'constants.dart';

part 'chunk.dart';

// Assumptions:
// - Transactions concern few chunks. All the accessed chunks fit into memory.

typedef TransactionCallback<T> = FutureOr<T> Function(Transaction);

/// [Chunky] offers low-level primitives of loading parts of a file (so-called
/// "chunks") into memory, and writing in atomic batches. Those chunks all have
/// the same size: [chunkLength].
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
        .whereKeyValue((index, chunk) =>
            !_originalChunks.containsKey(index) || chunk.isDirty)
        .whereKeyValue((index, chunk) => chunk._data != _originalChunks[index])
        .toList();
    print('Changed chunks:');
    for (final chunk in differentChunks) {
      print('${chunk.key}: ${chunk.value}');
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

  ChunkData reserve() => _data.isEmpty ? ChunkData() : _data.removeAt(0);
  void free(ChunkData chunk) => _data.add(chunk);
}
