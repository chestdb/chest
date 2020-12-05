import 'dart:convert';

import 'chest.dart';

void main() async {
  tape.register({
    ...tapers.forDartCore(),
    0: taper.forUser(),
    1: taper.forPet(),
  });

  // print(User('Marcel', Pet('Katzi')).toBlock().toBytes().compress());

  /// Chests are a storage for global, persisted variables.
  print('Main: Opening foo chest');
  final foo = await Chest.open<User>(
    '🌮',
    ifNew: () => User('Marcel', Pet('0')),
  );
  print('Main: foo is ${foo.value}');
  for (var i = 0; i < 2; i++) {
    await Future.delayed(Duration(seconds: 2));
    // Increase Pet's name
    final petName = foo.pet.name.get();
    print('Main: pet name is $petName');
    foo.pet.name.set('${int.parse(petName) + 1}');
    print('Main: pet name updated to ${foo.pet.name.get()}');
  }
  await foo.close();
}

@tape
class User {
  User(this.name, this.pet);

  final String name;
  final Pet pet;

  String toString() => 'User($name, $pet)';
}

@tape
class Pet {
  Pet(this.name);

  final String name;

  String toString() => 'Pet($name)';
}

// ================================= generated =================================

extension TapersForDartCore on TapersForPackageApi {
  Map<int, Taper<dynamic>> forDartCore() {
    return {
      -1: taper.forString(),
    };
  }
}

// String

extension TaperForString on TaperApi {
  Taper<String> forString() => _TaperForString();
}

class _TaperForString extends BytesTaper<String> {
  String get name => 'String';

  List<int> toBytes(String value) => utf8.encode(value);
  String fromBytes(List<int> bytes) => utf8.decode(bytes);
}

// User

extension TaperForUser on TaperApi {
  Taper<User> forUser() => _TaperForUser();
}

class _TaperForUser extends ClassTaper<User> {
  String get name => 'User';

  Map<String, Object> toFields(User value) {
    return {
      'name': value.name,
      'pet': value.pet,
    };
  }

  User fromFields(Map<String, Object> fields) {
    return User(
      fields['name'] as String,
      fields['pet'] as Pet,
    );
  }
}

extension UserRefs on Ref<User> {
  Ref<String> get name => child('name');
  Ref<int> get age => child('age');
  Ref<Pet> get pet => child('pet');
}

// Pet

extension TaperForPet on TaperApi {
  Taper<Pet> forPet() => _TaperForPet();
}

class _TaperForPet extends ClassTaper<Pet> {
  String get name => 'Pet';

  Map<String, Object> toFields(Pet value) {
    return {
      'name': value.name,
    };
  }

  Pet fromFields(Map<String, Object> fields) {
    return Pet(
      fields['name'] as String,
    );
  }
}

extension PetRefs on Ref<Pet> {
  Ref<String> get name => child('name');
}
