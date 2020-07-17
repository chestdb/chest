import 'dart:io';

import 'chunky/chunk.dart';
import 'chunky/chunky.dart';

void main() async {
  print('Hello world.');

  final chunky = await Chunky.named('sample');
  print('Chunk file path is ${chunky.chunkFile.path}');
  final firstChunk = await chunky.read(0);

  // Writes on chunks only change the data in memory. To actually write them to
  // disk, `chunky.write` has to be used inside a transaction.
  firstChunk.setUint8(24, 42);

  await chunky.transaction((chunky) async {
    await chunky.write(0, firstChunk);
  });

  final newChunk = Chunk.empty();
  newChunk.setUint8(1, firstChunk.getUint8(2));

  // Inside transactions, multiple chunks can be written to.
  await chunky.transaction((chunky) async {
    final chunkId = await chunky.add(newChunk);
    firstChunk.setUint8(12, chunkId);
    await Future.delayed(Duration(seconds: 2));
    await chunky.write(0, firstChunk);
  });

  await chunky.transaction((chunky) async {
    int id = chunky.add(Chunk.empty());
    print('Reserved chunk and got id $id.');
  });
}
