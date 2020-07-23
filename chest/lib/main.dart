import 'dart:convert';
import 'dart:developer';
import 'dart:isolate';
import 'dart:math';

import 'package:tape/tape.dart';

import 'buckets.dart';
import 'chest.dart';
import 'chunky/chunk.dart';
import 'chunky/chunky.dart';

void main() async {
  Tape.registerDartCoreAdapters();

  print('Hello world.');
  final chest = VmChest('👋🏻');
  await Future.delayed(Duration(seconds: 2));

  while (true) {
    print('Adding object.');
    chest.add(generateObject());
    await Future.delayed(Duration(seconds: 2));
  }

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
