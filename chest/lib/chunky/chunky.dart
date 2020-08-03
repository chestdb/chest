import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';

import 'chunk.dart';
import 'sync_file.dart';

export 'chunk.dart';

/// [Chunky] offers low-level primitives of loading parts of a file (so-called
/// "chunks") into memory, and writing in atomic batches. Those chunks all have
/// the same size [chunkSize].
///
/// [Chunky] actually manages two files:
/// - The chunk file holds the actual chunk data (that can be a lot of data).
/// - The transaction file holds all changes of the currently running
///   transaction as well as a byte indicating whether the transaction is
///   committed (aka ready to be applied to the chunk file).
class Chunky {
  Chunky.named(String name)
      : this(
          chunkFile: SyncFile(name),
          transactionFile: SyncFile('$name.transaction'),
        );

  Chunky({@required this.chunkFile, @required this.transactionFile}) {
    final length = chunkFile.length();
    assert(length % chunkSize == 0);
    _numberOfChunks = length ~/ chunkSize;

    ChunkyTransaction.restoreIfCommitted(transactionFile, chunkFile);
  }

  final SyncFile chunkFile;
  final SyncFile transactionFile;

  /// How many chunks the chunk file contains.
  int get numberOfChunks => _numberOfChunks;
  int _numberOfChunks;

  var _transactionFuture = Future<void>.value();
  var _transactionQueueLength = 0;
  bool get _isTransactionQueueEmpty => _transactionQueueLength == 0;

  /// Reads the chunk at the specified [index] into the provided [chunk].
  void readInto(int index, Chunk chunk) {
    chunkFile
      ..goToIndex(index)
      ..readChunkInto(chunk);
  }

  void _write(int index, Chunk chunk) {
    chunkFile
      ..goToIndex(index)
      ..writeChunk(chunk);
    _numberOfChunks = max(_numberOfChunks, index + 1);
  }

  void _flush() => chunkFile.flush();

  /// Runs a transaction, in which writes can happen.
  Future<T> transaction<T>(FutureOr<T> Function(ChunkyTransaction) callback) {
    final previousFuture = _transactionFuture;
    final completer = Completer<T>();
    _transactionFuture = completer.future;
    _transactionQueueLength++;

    return previousFuture.then((_) async {
      final transaction = ChunkyTransaction._(this);
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

  Future<void> close() async {
    while (!_isTransactionQueueEmpty) {
      await _transactionFuture;
    }
    chunkFile.close();
    transactionFile.close();
  }
}

/// Writes don't get applied to the chunk file directly, because the program may
/// be aborted while writing, causing changes to be partially written to the
/// file. That's why during a transaction, the changes are written to a separate
/// transaction file, which has the following format:
///
/// | commit byte | index | chunk data | index chunk data | ... |
///
/// The commit byte indicates whether the changes are ready to be applied to the
/// actual chunk file (it's 0 or 255). For each change, the chunk index and
/// chunk data are saved.
///
/// Initially, the commit byte is zero. During the transaction, the changes are
/// added to the transaction file. Once the transaction is done, the commit
/// byte is set to 255. Then, the changes are applied to the chunk file.
/// When chunky is started and the transaction file's commit byte is set to 255,
/// the changes are automatically applied to the chunk file.
///
/// So, why are the operations atomic?
/// - If the program gets aborted while a transaction is running (so, before
///   it's committed), the commit byte is not set, so the changes are not
///   applied on the next startup.
/// - If the program gets aborted while the changes are written to the chunk
///   file (after the transaction is committed), the commit bit is set, so the
///   changes are written to the chunk file on the next startup.
///
/// For more information, read
class ChunkyTransaction {
  ChunkyTransaction._(this._chunky) {
    // Prepare the file by setting the commit byte to 0 and removing the rest.
    _transactionFile
      ..clear()
      ..goTo(0)
      ..writeByte(0);
    _numberOfChunks = _chunky.numberOfChunks;
  }

  final Chunky _chunky;
  SyncFile get _transactionFile => _chunky.transactionFile;

  /// A map from chunk indizes to byte offsets in the transaction file.
  final _changedChunks = <int, int>{};
  bool _isCommitted = false;

  /// How many chunks the chunk file contains.
  int get numberOfChunks => _numberOfChunks;
  int _numberOfChunks;

  void readInto(int index, Chunk chunk) {
    assert(!_isCommitted);

    // Depending on whether the chunk was changed in this transaction, get the
    // changed one from the transaction file or the original one from the chunk
    // file.
    if (_changedChunks.containsKey(index)) {
      _transactionFile
        ..goTo(_changedChunks[index])
        ..readChunkInto(chunk);
    } else {
      _chunky.readInto(index, chunk);
    }
  }

  /// Do not use unless you're absolutely certain that this is what you want.
  /// This method is super inefficient.
  @Deprecated('This is really inefficient.')
  Chunk read(int index) {
    final chunk = Chunk();
    readInto(index, chunk);
    return chunk;
  }

  void write(int index, Chunk chunk) {
    assert(!_isCommitted);

    _transactionFile
      ..goToEnd()
      ..writeInt(index)
      ..writeChunk(chunk);
    _changedChunks[index] = _transactionFile.length() - chunkSize;
    // print('Transaction file length is now ${_transactionFile.length()}. '
    //     'Changed: $_changedChunks');
    _numberOfChunks = max(_numberOfChunks, index + 1);
  }

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

  static restoreIfCommitted(SyncFile transactionFile, SyncFile chunkFile) {
    transactionFile.goTo(0);
    if (transactionFile.length() == 0 || transactionFile.readByte() == 0) {
      // The file doesn't contain a committed transaction.
      return;
    }

    // Restore the committed transaction.
    final chunkBuffer = Chunk();
    final length = transactionFile.length();
    var position = 1;

    while (position < length) {
      final index = transactionFile.readInt();
      transactionFile.readChunkInto(chunkBuffer);
      chunkFile
        ..goToIndex(index)
        ..writeChunk(chunkBuffer);
      position += 8 + chunkSize;
    }
  }
}
