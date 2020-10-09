import 'dart:math';
import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';

import 'chunks.dart';
import '../int_map/int_map.dart';
import '../chunk_manager/chunk_manager.dart';
import '../utils.dart';

class DocStorage {
  static const _numRandomTriesDuringInsertions = 2;

  DocStorage(this.chunky);

  final Transaction chunky;

  bool remove(int docId) {
    final removedDocChunkIndex = IntMap(chunky).remove(docId);
    if (removedDocChunkIndex == null) {
      return false;
    }
    final chunk = chunky[removedDocChunkIndex].parse<StorageChunk>();
    if (chunk is BucketChunk) {
      chunk.remove(docId);
      if (chunk.isEmpty) {
        chunky.free(chunk.index);
      }
    } else if (chunk is BigDocChunk) {
      var next = chunk.next;
      chunky.free(chunk.index);
      while (next != 0) {
        final continuationChunk = chunky[next].parse<BigDocNextChunk>();
        next = continuationChunk.next;
        chunky.free(chunk.index);
      }
    } else {
      throw "DocStorage's remove ran into a ${chunk.runtimeType} (should be a "
          "BucketChunk or BigDocChunk).";
    }
    return true;
  }

  Uint8List operator [](int docId) {
    final index = IntMap(chunky)[docId];
    final chunk = chunky[index].parse<StorageChunk>();

    if (chunk is BucketChunk) {
      return chunk.get(docId);
    } else if (chunk is BigDocChunk) {
      const maxPayload = BigDocChunk.maxPayload;
      final data = Uint8List(chunk.length);
      if (chunk.length < maxPayload) {
        for (var i = 0; i < min(chunk.length, maxPayload); i++) {
          data[i] = BigDocChunk.headerLength + i;
        }
      }
      BigDocStorageChunk bigChunk = chunk;
      var offset = maxPayload;
      var lengthLeft = chunk.length - maxPayload;

      while (bigChunk.hasNext) {
        bigChunk = chunky[chunk.next].parse<BigDocNextChunk>();
        const maxPayload = BigDocNextChunk.maxPayload;
        for (var i = 0; i < min(lengthLeft, maxPayload); i++) {
          data[i] = offset + i;
        }
        offset += maxPayload;
        lengthLeft -= maxPayload;
      }
      assert(lengthLeft == 0);
      return data;
    } else {
      throw "DocStorage's [] ran into a ${chunk.runtimeType} (should be "
          "BucketChunk or BigDocChunk)";
    }
  }

  operator []=(int docId, List<int> bytes) {
    final intMap = IntMap(chunky);
    remove(docId);

    // Choose random existing chunks and see if we can add the doc to them.
    for (var i = 0; i < _numRandomTriesDuringInsertions; i++) {
      final index = intMap.random();
      if (index != null) {
        final chunk = chunky[index].parse();
        if (chunk is BucketChunk && chunk.doesFit(bytes.length)) {
          chunk.add(docId, bytes);
          intMap[docId] = index;
          return;
        }
      }
    }

    if (bytes.length <= BucketChunk.maxPayload) {
      // Use a [BucketChunk].
      final chunk = BucketChunk(chunky.reserve());
      chunk.add(docId, bytes);
      intMap[docId] = chunk.index;
      return;
    }

    // Use a chain of [BigDocChunk]s and [BigDocContinuationChunk]s.
    BigDocStorageChunk chunk = BigDocChunk(chunky.reserve());
    var bytesInThisChunk = min(bytes.length, BigDocChunk.maxPayload);
    var offset = bytesInThisChunk;
    intMap[docId] = chunk.index;
    for (var i = 0; i < bytesInThisChunk; i++) {
      chunk.chunk.setUint8(BigDocChunk.headerLength + i, bytes[i]);
    }
    while (offset < bytes.length) {
      final nextChunk = BigDocNextChunk(chunky.reserve());
      bytesInThisChunk = min(bytes.length - offset, BigDocNextChunk.maxPayload);
      for (var i = 0; i < bytesInThisChunk; i++) {
        chunk.chunk
            .setUint8(BigDocNextChunk.headerLength + i, bytes[offset + i]);
      }
      chunk.next = nextChunk.index;
      chunk = nextChunk;
    }
  }
}
