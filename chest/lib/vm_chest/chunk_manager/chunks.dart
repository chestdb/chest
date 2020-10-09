import 'package:chest/layout/layout.dart';

/// A chunk that contains no functional data and is free to re-use.
class FreeChunk extends HigherLevelWidget<Tuple2<ChunkId, Padding>> {
  FreeChunk() : super(Tuple2(first: ChunkId(), second: Padding()));

  /// Points to the next free chunk. All free chunks form a linked list.
  int get next => widget.first.value;
  set next(int id) => widget.first.value = id;

  String toString() => 'FreeChunk(next: $next)';
}
