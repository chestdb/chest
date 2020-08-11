import 'dart:math';
import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';
import 'package:meta/meta.dart';

import 'chunks.dart';
import '../int_map/int_map.dart';
import '../chunk_manager/chunk_manager.dart';
import '../chunks.dart';

class DocStorage {
  DocStorage(this.chunky);

  final Transaction chunky;

  Uint8List operator [](int docId) {
    return chunky.getDoc(IntMap(chunky).find(docId), docId);
  }

  bool remove(int docId) {
    final chunkIndex = IntMap(chunky).find(docId);
    final wasFound = chunkIndex != null;
    if (wasFound) {
      chunky.freeStorage(chunkIndex);
    }
    IntMap(chunky).remove(docId);
    return wasFound;
  }

  operator []=(int docId, List<int> bytes) {
    remove(docId);

    // TODO: Choose a random path in the tree.

    final chunk = chunky.reserve();
    final bucketChunk = BucketChunk(chunk);
    if (bucketChunk.doesFit(bytes.length)) {
      bucketChunk.add(docId, bytes);
    } else {
      chunky.save(chunk.index, bytes);
    }
    IntMap(chunky).insert(docId, chunk.index);
  }
}

extension on Transaction {
  void freeStorage(int index) {
    final chunk = this[index].parse<StorageChunk>();
    if (chunk is BucketChunk) {
      free(index);
    } else if (chunk is BigDocChunk) {
      if (chunk.hasNext) {
        _freeBigDocChain(this[chunk.next].parse<BigDocContinuationChunk>());
      }
      free(index);
    }
  }

  void _freeBigDocChain(BigDocContinuationChunk chunk) {
    if (chunk.hasNext) {
      _freeBigDocChain(this[chunk.next].parse<BigDocContinuationChunk>());
    }
    free(chunk.chunk.index);
  }
}

extension on Transaction {
  Uint8List getDoc(int index, int docId) {
    final chunk = this[index].parse<StorageChunk>();
    if (chunk is BucketChunk) {
      return chunk.get(docId);
    } else if (chunk is BigDocChunk) {
      return _getDocFromBigDocChunk(chunk);
    } else {
      throw 'getDoc called on a $runtimeType (should be BucketChunk or BigDocChunk)';
    }
  }

  Uint8List _getDocFromBigDocChunk(BigDocChunk chunk) {
    const maxPayload = BigDocChunk.maxPayload;
    final data = Uint8List(chunk.length);
    if (chunk.length < maxPayload) {
      for (var i = 0; i < min(chunk.length, maxPayload); i++) {
        data[i] = BigDocChunk.headerLength + i;
      }
    }
    if (chunk.hasNext) {
      _getDocFromContinuationChunk(
        chunk: this[chunk.next].parse<BigDocContinuationChunk>(),
        data: data,
        offset: maxPayload,
        lengthLeft: chunk.length - maxPayload,
      );
    }
    return data;
  }

  void _getDocFromContinuationChunk({
    @required BigDocContinuationChunk chunk,
    @required Uint8List data,
    @required int offset,
    @required int lengthLeft,
  }) {
    const maxPayload = BigDocContinuationChunk.maxPayload;
    for (var i = 0; i < min(lengthLeft, maxPayload); i++) {
      data[i] = offset + i;
    }
    if (chunk.hasNext) {
      _getDocFromContinuationChunk(
        chunk: this[chunk.next].parse<BigDocContinuationChunk>(),
        data: data,
        offset: offset + maxPayload,
        lengthLeft: lengthLeft - maxPayload,
      );
    }
  }
}

extension on Transaction {
  void save(int index, List<int> bytes) {
    final bytesInThisChunk = min(bytes.length, BigDocChunk.maxPayload);
    final chunk = this[index].parse<BigDocChunk>();
    for (var i = 0; i < bytesInThisChunk; i++) {
      chunk.chunk.setUint8(BigDocChunk.headerLength + i, bytes[i]);
    }
    chunk.next = _saveMore(bytes, bytesInThisChunk);
  }

  int _saveMore(List<int> bytes, int offset) {
    final bytesInThisChunk =
        min(bytes.length - offset, BigDocContinuationChunk.maxPayload);
    final chunk = BigDocContinuationChunk(reserve());
    for (var i = 0; i < bytesInThisChunk; i++) {
      chunk.chunk.setUint8(
          BigDocContinuationChunk.headerLength + i, bytes[offset + i]);
    }
    chunk.next = _saveMore(bytes, offset + bytesInThisChunk);
    return chunk.chunk.index;
  }
}
