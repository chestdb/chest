import 'dart:io';
import 'dart:math';

import 'package:tape/tape.dart';

import 'chunky/chunk.dart';
import 'chunky/chunky.dart';

void main() async {
  Tape.registerDartCoreAdapters();

  print('Hello world.');

  final chunky = await Chunky.named('sample');
  var index = 0;
  var bucket = BucketChunk();
  chunky.transaction((chunky) {
    chunky.write(0, bucket.chunk);
  });

  while (true) {
    var object = generateObject();
    try {
      bucket.add(object);
    } catch (e) {
      print('Bucket $index full (${bucket.objects.length}): ${bucket.chunk}');
      bucket = BucketChunk()..add(object);
      index++;
      chunky.transaction((chunky) => chunky.write(index, bucket.chunk));
    }
    await Future.delayed(Duration(seconds: 1));
  }
}

class BucketChunk {
  final chunk = Chunk.empty();
  final objects = <Object, List<int>>{};

  int get usedBytes =>
      1 +
      objects.values.fold(0, (sum, bytes) => sum + bytes.length) +
      objects.length * 2;
  int get freeBytes => chunkSize - usedBytes;

  void add(Object obj) {
    final bytes = tape.encode(obj);
    if (objects.length >= 256 || bytes.length > freeBytes) {
      throw "Doesn't fit.";
    }
    objects[obj] = bytes;
    chunk.setUint8(0, objects.length);

    var pointerCursor = 1;
    var objectCursor = chunkSize;

    for (final bytes in objects.values) {
      objectCursor -= bytes.length;
      chunk.setUint16(pointerCursor, objectCursor);
      chunk.setBytes(objectCursor, bytes);
      pointerCursor += 2;
    }
  }
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
