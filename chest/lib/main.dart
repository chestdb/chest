import 'dart:math';

import 'package:chest/vm_chest/doc_tree.dart';
import 'package:tape/tape.dart';

import 'chunky/chunky.dart';
import 'vm_chest/chunks/chunks.dart';
import 'vm_chest/vm_chest.dart';

void main() async {
  final chunky = Chunky.named('🌮');
  try {
    chunky.transaction((chunky) {
      if (chunky.numberOfChunks == 0) {
        chunky.add(MainChunk(Chunk()));
      }
      final tree = DocTree(chunky);

      for (var i = 1; i <= 6; i++) {
        print('> Adding $i');
        tree.insert(i, i);
      }
      print('Done.');
      throw 'Do not complete transaction.';
    });
  } catch (e) {
    return;
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

  final tree = Tree<String>();
  print(tree);
  tree.insert(1, 'one');
  print(tree);
  tree.insert(2, 'two');
  print(tree);
  tree.insert(3, 'three');
  print(tree);
  tree.insert(4, 'four');
  print(tree);
  tree.delete(2);
  print(tree);
  tree.insert(5, 'five');
  print(tree);
  tree.insert(6, 'six');
  print(tree);
  tree.insert(7, 'seven');
  print(tree);
  print(tree.find(1));
  print(tree.find(2));
  print(tree.find(3));
  print(tree.find(4));
  print(tree.find(5));
  print(tree.find(6));
  return;

  Tape.registerDartCoreAdapters();

  print('Hello world.');
  final chest = VmChest('👋🏻');
  await Future.delayed(Duration(seconds: 2));

  chest.put([1, 2, 3, 4, 5], generateObject());

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
