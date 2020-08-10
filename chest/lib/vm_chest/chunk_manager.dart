import 'package:chest/chunky/chunky.dart';

import 'chunks/chunks.dart';

extension ChunkManager on Transaction {
  TransactionChunk reserve() {
    final main = mainChunk;

    if (main.firstFreeChunk == 0) {
      return add();
    } else {
      final freeChunk = this[main.firstFreeChunk];
      main.firstFreeChunk = FreeChunk(freeChunk).next;
      return freeChunk..clear();
    }
  }

  void free(int index) {
    final main = mainChunk;
    FreeChunk(this[index]).next = main.firstFreeChunk;
    main.firstFreeChunk = index;
  }
}
