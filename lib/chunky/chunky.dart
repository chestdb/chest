import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'chunk.dart';
import 'sync_file.dart';

/// The [ChunkManager] offers low-level primitives of loading parts of a file
/// (so-called "chunks") into memory, and writing in atomic batches. Those
/// chunks all have the same size [chunkSize].
///
/// One [ChunkManager] actually manages two files:
/// - The chunk file (`sample.cassette`) holds the actual chunk data (and that
///   can be a lot of data).
/// - The transaction file (`sample.transaction.cassette`) holds all changes of
///   the currently running transaction as well as a bit indicating whether the
///   transaction got committed. During a transaction, the changes are only
///   written to this file. Once the transaction is complete (it is "committed"),
///   the commit bit is set to true and the changes are actually applied to the
///   chunk file one after another.
///   If the program gets aborted while a transaction is running (so, before
///   it's committed), the commit bit is not set, so the changes are not
///   applied on next startup.
///   If the program gets aborted while the changes are written to the chunk
///   file (after the transaction is committed), the commit bit is set, so the
///   changes are written to the chunk file on the next startup.
class ChunkManager {
  ChunkManager(String baseName) {
    _chunkFile = SyncFile('$baseName.cassette');
    _transactionFile = SyncFile('$baseName.transaction.cassette');

    final length = _chunkFile.length();
    assert(length % chunkSize == 0);
    _numberOfChunks = length ~/ chunkSize;

    var transactionWasRunning = false;
    if (_transactionFile.length() > 0) {
      _transactionFile.goTo(0);
      transactionWasRunning = _transactionFile.readByte() != 0;
    }
    if (transactionWasRunning) {
      _restoreTransaction();
    } else {
      _clearTransaction();
    }
  }

  SyncFile _chunkFile;
  SyncFile _transactionFile;

  int _numberOfChunks;
  int get numberOfChunks => _numberOfChunks;
  Future<void> _transaction = Future.value();
  int _numScheduledTransactions = 0;
  bool get isTransactionRunning => _numScheduledTransactions > 0;

  final _transactionChunks = <int, int>{};

  final _chunkBuffer = Chunk.empty();

  void readInto(int index, Chunk chunk) {
    print('Reading the chunk at index $index into...');
    if (_transactionChunks.containsKey(index)) {
      // The chunk has been changed in this transaction, so we return the
      // updated value.
      _transactionFile
        ..goTo(_transactionChunks[index])
        ..readChunkInto(chunk);
    } else {
      // The chunk hasn't been changed in this transaction, so we can get it
      // from the original file.
      _chunkFile
        ..goToIndex(index)
        ..readChunkInto(chunk);
    }
  }

  Chunk read(int index) {
    print('Reading the chunk at index $index...');
    final chunk = Chunk.empty();
    readInto(index, chunk);
    return chunk;
  }

  void _clearTransaction() {
    print('Clearing the transaction...');
    _transactionFile
      ..clear()
      ..goTo(0)
      ..writeByte(0)
      ..flush();
  }

  Future<T> transaction<T>(Future<T> Function() callback) {
    print('Starting a transaction...');
    _numScheduledTransactions++;

    final previousTransaction = _transaction;
    final completer = Completer<T>();
    _transaction = completer.future;

    return previousTransaction.then((_) async {
      final result = await callback();

      _transactionFile
        ..flush()
        ..goTo(0)
        ..writeByte(255)
        ..flush();
      for (final entry in _transactionChunks.entries) {
        final index = entry.key;
        final offset = entry.value;

        _transactionFile
          ..goTo(offset)
          ..readChunkInto(_chunkBuffer);
        _chunkFile
          ..goTo(index)
          ..writeChunk(_chunkBuffer);
      }
      _clearTransaction();

      _numScheduledTransactions--;
      completer.complete(result);
      return result;
    });
  }

  void write(int index, Chunk chunk) {
    assert(isTransactionRunning);
    print('Writing chunk to index $index...');
    _transactionFile
      ..goToEnd()
      ..writeInt(index)
      ..writeChunk(chunk);
  }

  int add(Chunk chunk) {
    assert(isTransactionRunning);
    print('Adding chunk...');
    final index = _numberOfChunks;
    write(index, chunk);
    _numberOfChunks++;
    return index;
  }

  void _restoreTransaction() {
    print('Restoring the transaction...');
    final length = _transactionFile.length();

    _transactionFile..goTo(1);
    var position = 1;

    while (position < length) {
      final index = _transactionFile.readInt();
      _transactionFile.readChunkInto(_chunkBuffer);
      _chunkFile
        ..goToIndex(index)
        ..writeChunk(_chunkBuffer);
      position += 8 + chunkSize;
    }

    _clearTransaction();
  }

  Future<void> close() async {
    print('Closing...');
    while (isTransactionRunning) {
      await _transaction;
    }
    _transactionFile.close();
    _chunkFile.close();
  }
}
