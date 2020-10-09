import 'package:chest/chunky/chunky.dart';
import 'package:chest/layout/layout.dart';

import '../utils.dart';
import 'chunks.dart';

extension ChunkManager on Transaction {
  TransactionChunk reserve() {
    final main = mainChunk;

    if (main.firstFreeChunk == 0) {
      return add();
    } else {
      final freeChunk = this[main.firstFreeChunk];
      main.firstFreeChunk = freeChunk.apply(FreeChunk()).next;
      return freeChunk..clear();
    }
  }

  void free(int index) {
    final main = mainChunk;
    this[index].apply(FreeChunk()).next = main.firstFreeChunk;
    main.firstFreeChunk = index;
  }
}
