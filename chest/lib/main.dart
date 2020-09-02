import 'dart:math';

import 'package:tape/tape.dart';

import 'chest.dart';
import 'chunky/chunky.dart';
import 'vm_chest/chunks.dart';
import 'vm_chest/doc_storage/doc_storage.dart';
import 'vm_chest/int_map/chunks.dart';
import 'vm_chest/vm_chest.dart';

part 'generated.dart';

void main() async {
  Tape
    ..registerDartCoreAdapters()
    ..registerAdapters({
      0: AdapterForUser(),
      1: AdapterForPet(),
    });

  final chest = Chest('🌮');
  final users = chest.box<String, User>('users');
  final myPet = users.doc('marcel').box('pets').doc(Duration.zero);
  print((myPet as VmDoc).path);

  print('Adding user.');
  await users.doc('marcel').set(User('Marcel', Pet('hippo')));
  print('Added user.');

  // print(users.doc('marcel').get());
  // await chest.close();

  // final user = IndexedUser<User>([], identityFunction);
  // final property = user.pet.animal;
  // print('Property has path ${property.path}');
  // final userInstance = User('Marcel', Pet('hippo'));
  // print('user.pet.animal property of instance is '
  //     '${property.fromRoot(userInstance)}');
  // Box<Object, User> someBox;
  // someBox.query((user) {
  //   return user.name.equals('Marcel') & user.pet.animal.startsWith('h');
  // });
}

class Pet {
  Pet(this.animal);

  final String animal;

  String toString() => 'Pet($animal)';
}

class User {
  User(this.name, this.pet);

  final String name;
  final Pet pet;

  String toString() => 'User($name)';
}
