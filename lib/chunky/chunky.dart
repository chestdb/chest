import 'dart:typed_data';

import 'chunk.dart';
import 'file.dart';

part 'transaction.dart';

const translationsPerTranslationChunk = chunkSize ~/ 8;

/// The [ChunkManager] offers low-level primitives of loading parts of a file
/// into memory, virtualization from physical addresses, and atomic operations.
/// All operations are O(1).
///
/// To achieve that, the file is organized into multiple chunks of size
/// [chunkSize], which have virtualized addresses. This allows for more
/// flexibility, more on that later.
///
/// ## Terminology
///
/// - Chunk refers to one region in the file of [chunkSize].
/// - Offset refers to the actual byte offset in the file.
/// - The address of a chunk is its physical index in the file.
/// - The id of a chunk is its abstracted user-visible virtual index.
///
/// ## File layout
///
/// | header  | translation | ...        | translation | ...        | transaction |
/// | 1 chunk | 1 chunk     | 512 chunks | 1 chunk     | 512 chunks | rest        |
///
/// As you see, before every 512 user/free chunks there's a translation chunk
/// that saves translation information for 512 chunks (not necessarily the next
/// 512). If chunks get obsolete (freed), the file doesn't automatically shrink.
/// Instead, they are just marked as free and then reused when needed.
///
/// The user/free chunks are also sometimes called content chunks because they
/// represent space where actual content might go. The header/translation chunks
/// are also called scaffold chunks because they're the structure with metadata
/// about the rest.
///
/// Note that the transaction log at the end is not chunk-aligned.
///
/// ## Chunk types
///
/// ### User chunk
///
/// A chunk containing data for the layers above us ("user"). The data has no
/// layout or guarantees known to us.
///
/// ### Translation chunk
///
///  0       7 8      15 16     23 24     31 32     29
/// | address | address | address | address | address | ... |
///
/// A chunk containing mapping information from ids to physical addresses. The
/// first translation chunk contains the addresses for the ids 0 to 511, the
/// second one for the next 512 etc. The address information are just written
/// one after another.
///
/// ### Header chunk
///
/// The header chunk contains general information.
///
///  0       7 8          15 16         23 24      31 32
/// | version | user chunks | free chunks | 1st free | t |
///
/// version: The file format version.
/// user chunks: The number of user chunks.
/// free chunks: The number of free chunks.
/// 1st free: The address of the first free chunk.
/// t: Whether a transaction is running or not.
///
/// ### Free chunk
///
///  0        7 8   15
/// | previous | next | garbage |
///
/// Those are chunks that have been freed and contain garbage. To efficiently be
/// able to find new free chunks, they form a double linked list by pointing to
/// the next and previous free chunks using 8-bit integers.
///
/// ## Actions
///
/// ### Writing to a chunk
///
/// - Create a new chunk and write the modified data to it.
/// - In a transaction, do:
///   - Update the appropriate translation entry.
///   - Free the orginal chunk by setting the previous and next chunks' pointers
///     accordingly and adding pointers to them on the original chunk.
class ChunkManager {}

class ChunkManagerImpl implements ChunkManager {
  ChunkManagerImpl(String fileName) {
    // Open the file.
    _file = File.open(fileName);
    final length = _file.length();

    if (length < chunkSize) {
      // Leaving everything zero does exactly what we want.
      _file.writeChunkFrom(Chunk.empty());
    }

    _file.toOffset(0);
    _version = _file.readInt();
    _numberOfUserChunks = _file.readInt();
    _numberOfFreeChunks = _file.readInt();
    _firstFreeChunk = _file.readInt();
    _isTransactionRunning = _file.readByte() != 0;

    print('Version is $version');
    print('$numberOfUserChunks user chunks');
    print('$numberOfFreeChunks free chunks');
    print('first free chunk is at $firstFreeChunk');
    print('is transaction running? $isTransactionRunning');

    if (isTransactionRunning) {
      runExistingTransaction();
    }
  }

  File _file;

  int _version;
  int get version => _version;
  set version(int version) {
    _version = version;
    _file.toOffset(0).writeInt(version);
  }

  int _numberOfUserChunks;
  int get numberOfUserChunks => _numberOfUserChunks;
  set numberOfUserChunks(int numberOfUserChunks) {
    _numberOfUserChunks = numberOfUserChunks;
    _file.toOffset(8).writeInt(numberOfUserChunks);
  }

  int _numberOfFreeChunks;
  int get numberOfFreeChunks => _numberOfFreeChunks;
  set numberOfFreeChunks(int numberOfFreeChunks) {
    _numberOfFreeChunks = numberOfFreeChunks;
    _file.toOffset(16).writeInt(numberOfFreeChunks);
  }

  int _firstFreeChunk;
  int get firstFreeChunk => _firstFreeChunk;
  void set firstFreeChunk(int address) {
    _firstFreeChunk = address;
    _file.toOffset(24).writeInt(address);
  }

  bool _isTransactionRunning;
  bool get isTransactionRunning => _isTransactionRunning;
  set isTransactionRunning(bool isTransactionRunning) {
    _isTransactionRunning = isTransactionRunning;
    _file.toOffset(32).writeByte(isTransactionRunning ? 255 : 0);
  }

  /// The size of the file.
  int get fileSize => _file.length();

  int get numberOfContentChunks => numberOfUserChunks + numberOfFreeChunks;
  int get numberOfScaffoldChunks =>
      2 + numberOfContentChunks ~/ translationsPerTranslationChunk;
  int get totalNumberOfChunks => numberOfContentChunks + numberOfScaffoldChunks;
  int get endOffset => totalNumberOfChunks * chunkSize;

  /// Reserves a new chunk.
  int reserve() {
    final id = numberOfUserChunks;

    if (firstFreeChunk != 0) {
      // There are free chunks, so we use the first one.
      _file.toChunk(firstFreeChunk);
      final current = firstFreeChunk;
      final previous = _file.readInt();
      final next = _file.readInt();
      assert(previous == 0);

      _file.toChunk(next).writeInt(0);
      runTransaction([
        SetChunkIdToAddress(id, current),
        SetNumberOfFreeChunks(numberOfFreeChunks - 1),
        SetNumberOfUserChunks(numberOfUserChunks + 1),
        // Update the linked list.
        SetFirstFreeChunk(next),
        SetPreviousFreeChunk(next, 0),
      ]);
    } else {
      // There are no free chunks, so we have to allocate a new one.
      var address = totalNumberOfChunks;

      if (numberOfContentChunks % translationsPerTranslationChunk == 0) {
        // We also need to allocate a new translation chunk.
        _file.toChunk(address).writeChunkFrom(Chunk.empty());
        address++;
      }
      _file.writeChunkFrom(Chunk.empty());

      runTransaction([
        SetChunkIdToAddress(id, address),
        SetNumberOfUserChunks(numberOfUserChunks + 1),
      ]);
    }

    return id;
  }

// * When asked to (atomically) write to a chunk, it'll create a completely new
//   chunk, put the content in there, write transaction data into a chunk and
//   flush everything. Only then will attempt to execute the transaction by
//   updating the addresses in the translation table from
//

  /// Reads the chunk with the given [id] into the [chunk].
  void readInto(int id, Chunk chunk) {
    final address = _file.toOffset(offsetForIdLookup(id)).readInt();
    _file.toChunk(address).readChunkInto(chunk);
  }

  void writeFrom(int id, Chunk chunk) {
    if (firstFreeChunk != 0) {
      // There are free chunks, so we use the first one.
      _file.toChunk(firstFreeChunk);
      final current = firstFreeChunk;
      final previous = _file.readInt();
      final next = _file.readInt();
      assert(previous == 0);

      _file.toChunk(next).writeInt(0);
      runTransaction([
        SetChunkIdToAddress(id, current),
        SetNumberOfFreeChunks(numberOfFreeChunks - 1),
        SetNumberOfUserChunks(numberOfUserChunks + 1),
        // Update the linked list.
        SetFirstFreeChunk(next),
        SetPreviousFreeChunk(next, 0),
      ]);
    } else {
      // There are no free chunks, so we have to allocate a new one.
      var address = totalNumberOfChunks;

      if (numberOfContentChunks % translationsPerTranslationChunk == 0) {
        // We also need to allocate a new translation chunk.
        _file.toChunk(address).writeChunkFrom(Chunk.empty());
        address++;
      }
      _file.writeChunkFrom(Chunk.empty());

      runTransaction([
        SetChunkIdToAddress(id, address),
        SetNumberOfUserChunks(numberOfUserChunks + 1),
      ]);
    }
  }
}

int translationChunkAddressForId(int id) {
  final translationChunkIndex = id ~/ translationsPerTranslationChunk;
  return 1 + translationChunkIndex * (translationsPerTranslationChunk + 1);
}

int offsetForIdLookup(int id) {
  return translationChunkAddressForId(id) * chunkSize +
      id % translationsPerTranslationChunk;
}
