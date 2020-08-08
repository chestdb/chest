import 'dart:math';

import 'package:chest/vm_chest/doc_tree.dart';
import 'package:tape/tape.dart';

import 'chunky/chunky.dart';
import 'vm_chest/chunks/chunks.dart';
import 'vm_chest/doc_tree.dart';
import 'vm_chest/vm_chest.dart';

void main() async {
  // final chunky = Chunky('🌮');

  // // Transactions are great because of two reasons:
  // // - They guarantee consistency between all operations.
  // // - They allow the reuse of in-memory buffers, which are quite expensive to
  // //   create in Dart.

  // // You can only access chunks inside transactions. Here's a transaction that
  // // increases a counter atomically.
  // await chunky.transaction((chunky) {
  //   // The `chunky` object passed to this lambda is more powerful than the one on
  //   // the outside – you can access chunks.

  //   final chunk = chunky[0];
  //   final counter = chunk.getUint8(0);
  //   chunk.setUint8(0, counter + 1);
  // });

  // // Here's a transaction that calculates something based on data from chunks.
  // // Note that the in-memory buffer representing the chunk will be re-used in
  // // later transactions.
  // var sum = await chunky.transaction((chunky) {
  //   return chunky[0].getUint8(0) + chunky[1].getUint8(0);
  // });
  // print(sum);

  // This means that you can't re-use chunks outside of transactions lifespans:
  // Chunk fromTransaction;
  // chunky.transaction((chunky) {
  //   fromTransaction = chunky[0];
  // });
  // final firstByte = fromTransaction.getUint8(0); // Throws an error.

// If you really need the whole data of the chunk outside of the transaction,
// you need to copy it (save a snapshot of the live chunk):
  // var snapshot = chunky.transaction((chunky) => chunky[0].snapshot());

// The exception is for debug use cases.
  // final snapshot = chunky.debugRead(0);
  // chunky.debugReadInto(1, snapshot); // More efficient (no hidden allocation).

  final chunky = Chunky('🌮');
  try {
    chunky.clear();
    chunky.transaction((chunky) {
      if (chunky.numberOfChunks == 0) {
        // MainChunk(Chunk());
        chunky.addTyped(ChunkTypes.main);
      }
    });

    for (var i = 1; i <= 10; i++) {
      chunky.transaction((chunky) {
        print('> Adding $i');
        IntMap(chunky).insert(i, 42 * i);
      });
      if (i % 3 == 0) {
        chunky.transaction((chunky) {
          print('> Removing $i');
          IntMap(chunky).delete(i);
        });
      }
    }
    print('Done.');
    throw 'Do not complete transaction.';
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

  // final tree = Tree<int>();
  // for (var i = 1; i <= 7; i++) {
  //   print('> Adding $i');
  //   tree.insert(i, i);
  //   print(tree);
  //   if (i % 3 == 0) {
  //     print('> Removing $i');
  //     tree.delete(i);
  //     print(tree);
  //   }
  // }
  // print('Done.');
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
