import 'dart:io';

import 'chunky/chunk.dart';
import 'chunky/chunky.dart';

void main() async {
  print('Hello world.');

  final chunky = await ChunkManager('sample');

  final firstChunk = await chunky.read(0);

  // Writes on chunks only change the data in memory. To actually write them to
  // disk, `chunky.write` has to be used inside a transaction.
  firstChunk.setUint8(24, 42);

  await chunky.transaction(() async {
    await chunky.write(0, firstChunk);
  });

  final newChunk = Chunk.empty();
  newChunk.setUint8(1, firstChunk.getUint8(2));

// Inside transactions, multiple chunks can be written to.
  await chunky.transaction(() async {
    final chunkId = await chunky.add(newChunk);
    firstChunk.setUint8(123, chunkId);
    await chunky.write(0, firstChunk);
  });

  await chunky.transaction(() async {
    int id = chunky.add(Chunk.empty());
    print('Reserved chunk and got id $id.');
    print('There are ${chunky.numberOfChunks} chunks.');
  });

  // final firstChunk = await chunky.read(0);
  // final newChunk = ChunkData();

  // firstChunk.writeUint8(24, 42);
  // newChunk.writeUint8(1, firstChunk.readUint8(2));

  // final id = chunk.add(newChunk);
  // newChunk.writeUint8(123, 12);

  // await chunky.writeAll({
  //   0: firstChunk,
  //   id: newChunk,
  // });
}
