import 'dart:math';

import 'chest.dart';
import 'chunky/chunky.dart';
import 'vm_chest/chunks.dart';
import 'vm_chest/doc_storage/doc_storage.dart';
import 'vm_chest/int_map/chunks.dart';
import 'vm_chest/vm_chest.dart';

part 'generated.dart';

void main() async {
  final chest = Chest('🌮');
  final users = chest.box<String, User>('users');
  final myPet = users.doc('marcelgarus').box('pets').doc(Duration.zero);
  print((myPet as VmDoc).path);
  await chest.close();

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
