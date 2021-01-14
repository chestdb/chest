import 'package:chest/chest.dart';

void main() async {
  tape.register({
    ...tapers.forDartCore,
    ...tapers.forDartMath,
    ...tapers.forDartTypedData,
    0: taper.forUser().v0,
    // 1: taper.forUser().v1,
    2: taper.forPet().v0,
    // 2: legacyTaper.forUser().v1,
  });

  /// Chests are a storage for global, persisted variables.
  print('Opening foo chest');
  final foo = Chest<User>('🌮', ifNew: () => User('Marcel', Pet('0')));
  await foo.open();
  // foo.pet.watch().handleError((error) {
  //   print('Error. Value is ${foo.value}.');
  // }).forEach((it) => print('Pet is now $it.'));
  while (true) {
    await Future.delayed(Duration(seconds: 10));
    // Increase Pet's name.
    final petName = foo.pet.name.value;
    final newName = (int.parse(petName) + 1).toString();
    print('Renaming pet from $petName to $newName');
    foo.pet.name.value = newName;
    print(foo.value);
  }
  await foo.close();
}

@tape({
  v0: {#name, #pet},
  // v1: {#age, #name, #pet},
})
class User {
  User(this.name, this.pet);

  final String name;
  final Pet pet;
  // final double age;

  String toString() => 'User($name, $pet)';
}

@tape({
  v0: {#name},
})
class Pet {
  Pet(this.name);

  final String name;

  String toString() => 'Pet($name)';
}

// ================================= generated =================================

// User

extension TaperForUserExtension on TaperNamespace {
  VersionedTapersForUser forUser() => VersionedTapersForUser();
}

class VersionedTapersForUser {
  Taper<User> get v0 => TaperForUserV0();
}

class TaperForUserV0 extends MapTaper<User> {
  const TaperForUserV0();

  @override
  Map<Object?, Object?> toMap(User user) =>
      {'name': user.name, 'pet': user.pet};

  @override
  User fromMap(Map<Object?, Object?> map) =>
      User(map['name'] as String, map['pet'] as Pet);
}

extension ReferenceToUser on Reference<User> {
  Reference<String> get name => child('name');
  Reference<int> get age => child('age');
  Reference<Pet> get pet => child('pet');
}

// Pet

extension TaperForPetExtension on TaperNamespace {
  VersionedTapersForPet forPet() => VersionedTapersForPet();
}

class VersionedTapersForPet {
  Taper<Pet> get v0 => TaperForPetV0();
}

class TaperForPetV0 extends MapTaper<Pet> {
  const TaperForPetV0();

  @override
  Map<Object?, Object?> toMap(Pet pet) => {'name': pet.name};

  @override
  Pet fromMap(Map<Object?, Object?> map) => Pet(map['name'] as String);
}

extension ReferenceToPet on Reference<Pet> {
  Reference<String> get name => child('name');
}
