// Some integer literals are so large that they would be rounded in JS. Gladly,
// these tests are only intended to be run on the Dart VM, so that's fine.
// ignore_for_file: avoid_js_rounded_ints

import 'package:chest/chunky/chunky.dart';
import 'package:chest/chunky/files.dart';
import 'package:test/test.dart';

class MockChunkFile implements ChunkFile {
  @override
  // TODO: implement file
  SyncFile get file => throw UnimplementedError();

  @override
  void readChunkInto(int index, ChunkData chunk) {
    // TODO: implement readChunkInto
  }

  @override
  void writeChunk(int index, ChunkData chunk) {
    // TODO: implement writeChunk
  }

  @override
  // TODO: implement numberOfChunks
  int get numberOfChunks => throw UnimplementedError();
}

void main() {
  group('ChunkData', () {
    test('equality', () {
      // TODO
    });
  });
}
