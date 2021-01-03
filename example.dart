import 'package:chest/chest.dart';

void main() async {
  tape.register({
    ...tapers.forDartCore,
    ...tapers.forDartMath,
    ...tapers.forDartTypedData,
    0: taper.forUser(),
    1: taper.forPet(),
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

// User

extension TaperForUser on TaperNamespace {
  Taper<User> forUser() {
    return ClassTaper(
      toFields: (user) => {'name': user.name, 'pet': user.pet},
      fromFields: (fields) => User(
        fields['name'] as String,
        fields['pet'] as Pet,
      ),
    );
  }
}

extension ReferenceToUser on Reference<User> {
  Reference<String> get name => field('name');
  Reference<int> get age => field('age');
  Reference<Pet> get pet => field('pet');
}

// Pet

extension TaperForPet on TaperNamespace {
  Taper<Pet> forPet() {
    return ClassTaper(
      toFields: (pet) => {'name': pet.name},
      fromFields: (fields) => Pet(fields['name'] as String),
    );
  }
}

extension ReferenceToPet on Reference<Pet> {
  Reference<String> get name => child('name');
}
