import 'dart:convert';

import 'chest.dart';

class TaperForInt extends ConcreteTaper<int> {
  @override
  int fromData(TapeData data) {
    // TODO: implement fromData
    throw UnimplementedError();
  }

  @override
  TapeData toData(int value) {
    // TODO: implement toData
    throw UnimplementedError();
  }
}

class TaperForList extends GenericTaper<List<dynamic>> {
  @override
  Taper<List<A>> enrich<A>(Taper<A> a) {
    print('Enriching $this with $a, which tapes $A.');
    return ConcreteTaperForList<A>(a);
  }

  ConcreteType get concreteType =>
      ConcreteType(registry.taperToTypeCode(this)!);
}

class ConcreteTaperForList<A> extends Taper<List<A>> {
  ConcreteTaperForList(this._a);

  final Taper<A> _a;

  ConcreteType get concreteType => ConcreteType(
      registry.taperToTypeCode(TaperForList())!, [_a.concreteType]);
}

void main() async {
  registry.register({
    0: TaperForInt(),
    // 1: TaperForString(),
    2: TaperForList(),
    // 3: TaperForMap(),
  });

  // registry.valueToTaper(2);
  registry.valueToTaper([
    [1]
  ]);

  // tape.register({
  //   ...tapers.forDartCore,
  //   ...tapers.forDartMath,
  //   ...tapers.forDartTypedData,
  //   0: taper.forUser.v1 >> taper.forUser,
  //   1: taper.forPet,
  //   2: taper.forUser,
  // });

  /// Chests are a storage for global, persisted variables.
  // print('Opening foo chest');
  // final foo = await Chest.open<User>(
  //   '🌮',
  //   ifNew: () => User('Marcel', Pet('0')),
  // );
  // foo.pet.watch().forEach((it) => print('Pet is now $it.'));
  // while (true) {
  //   await Future.delayed(Duration(seconds: 5));
  //   // Increase Pet's name
  //   final petName = foo.pet.name.value;
  //   foo.pet.name.value = '${int.parse(petName) + 1}';
  // }
  // await foo.close();
}

// @tape
// class User {
//   User(this.name, this.pet);

//   final String name;
//   final Pet pet;

//   String toString() => 'User($name, $pet)';
// }

// @tape
// class Pet {
//   Pet(this.name);

//   final String name;

//   String toString() => 'Pet($name)';
// }

// ================================= generated =================================

// User

// extension TaperForUser on TaperApi {
//   Taper<User> forUser() => _TaperForUser();
// }

// class _TaperForUser extends ClassTaper<User> {
//   Map<String, Object> toFields(User value) {
//     return {'name': value.name, 'pet': value.pet};
//   }

//   User fromFields(Map<String, Object?> fields) {
//     return User(fields['name'] as String, fields['pet'] as Pet);
//   }
// }

// extension ChildrenOfUser on Ref<User> {
//   Ref<String> get name => child('name');
//   Ref<int> get age => child('age');
//   Ref<Pet> get pet => child('pet');
// }

// // Pet

// extension TaperForPet on TaperApi {
//   Taper<Pet> forPet() => _TaperForPet();
// }

// class _TaperForPet extends ClassTaper<Pet> {
//   Map<String, Object> toFields(Pet value) {
//     return {'name': value.name};
//   }

//   Pet fromFields(Map<String, Object?> fields) {
//     return Pet(fields['name'] as String);
//   }
// }

// extension ChildrenOfPet on Ref<Pet> {
//   Ref<String> get name => child('name');
// }
