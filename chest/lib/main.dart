import 'dart:math';

import 'package:tape/tape.dart';

import 'chunky/chunky.dart';
import 'vm_chest/chunks/chunks.dart';
import 'vm_chest/doc_storage.dart';
import 'vm_chest/vm_chest.dart';

void main() async {
  print(
      'Max children of internal node: ${IntMapInternalNodeChunk.maxChildren}');
  print('Max values of leaf node: ${IntMapLeafNodeChunk.maxValues}');

  final chunky = Chunky('🌮')
    ..clear()
    ..transaction((chunky) => chunky.addTyped(ChunkTypes.main));

  for (var i = 1; i <= 100; i++) {
    chunky.transaction((chunky) {
      print('> Adding $i');
      final docs = DocStorage(chunky);
      docs[i] = List.generate(i, (n) => n);
    });
  }
  return;

  // final chunk = Chunk();
  // final bucket = BucketChunk(chunk);
  // bucket.add(1, [17, 17, 17, 17]);
  // bucket.add(2, [34, 34, 34]);
  // bucket.add(3, [51, 51]);
  // bucket.add(4, [68, 68]);
  // print(bucket.chunk);
  // bucket.remove(1);
  // print(bucket.chunk);

  // return;

  // Tape.registerDartCoreAdapters();

  // print('Hello world.');
  // final chest = VmChest('👋🏻');
  // await Future.delayed(Duration(seconds: 2));

  // chest.put([1, 2, 3, 4, 5], generateObject());

  // while (true) {
  //   print('Adding object.');
  //   await Future.delayed(Duration(seconds: 2));
  // }

  return;
}

dynamic generateObject() {
  final generators = <dynamic Function()>[
    generateDuration,
    generateDouble,
    generateString,
    generateInt,
  ];
  return generators[Random().nextInt(generators.length)]();
}

Duration generateDuration() =>
    Duration(microseconds: Random().nextInt(1000000));

double generateDouble() => Random().nextDouble();

String generateString() {
  const fruits = ['apple', 'banana', 'kiwi', 'orange', 'passion fruit'];
  return fruits[Random().nextInt(fruits.length)];
}

int generateInt() => Random().nextInt(10);
