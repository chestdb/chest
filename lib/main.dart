import 'dart:io';

import 'chunky/chunky.dart';

void main() async {
  print('Hello world.');

  final chunky = ChunkManagerImpl('sample.bin');

  int id = chunky.reserve();
  print('Reserved chunk and got id $id.');
  print('There are ${chunky.totalNumberOfChunks} chunks.');

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
