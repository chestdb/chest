part of 'main.dart';

class AdapterForUser extends TapeClassAdapter<User> {
  const AdapterForUser();

  @override
  User fromFields(Fields fields) {
    return User(
      fields.get<String>(0, orDefault: ''),
      fields.get<Pet>(1, orDefault: null),
    );
  }

  @override
  Fields toFields(User object) {
    return Fields({
      0: object.name,
      1: object.pet,
    });
  }
}

class AdapterForPet extends TapeClassAdapter<Pet> {
  const AdapterForPet();

  @override
  Pet fromFields(Fields fields) {
    return Pet(
      fields.get<String>(0, orDefault: ''),
    );
  }

  @override
  Fields toFields(Pet object) {
    return Fields({
      0: object.animal,
    });
  }
}

class IndexedPet<Root> implements IndexedClass<Root> {
  IndexedPet(List<int> path, Pet Function(Root) rootToClass)
      : animal = IndexedValue([...path, 0], (root) => rootToClass(root).animal);

  final IndexedValue<Root, String> animal;

  List<IndexedValue<Root, dynamic>> get values => [animal];
}

class IndexedUser<Root> implements IndexedClass<Root> {
  IndexedUser(List<int> path, User Function(Root) rootToClass)
      : name = IndexedValue([...path, 0], (root) => rootToClass(root).name),
        pet = IndexedPet([...path, 1], (root) => rootToClass(root).pet);

  final IndexedValue<Root, String> name;
  final IndexedPet<Root> pet;

  List<IndexedValue<Root, dynamic>> get values => [name, ...pet.values];
}

extension QueryableBoxOfPets on Box<Object, Pet> {
  QueryResult<Pet> query(
    Query<IndexedPet<Pet>> Function(IndexedPet<Pet> pet) queryBuilder,
  ) =>
      rawQuery(queryBuilder(IndexedPet<Pet>([], identityFunction)));
}

extension QueryableBoxOfUsers on Box<Object, User> {
  QueryResult<User> query(
    Query<IndexedUser<User>> Function(IndexedUser<User> user) queryBuilder,
  ) =>
      rawQuery(queryBuilder(IndexedUser<User>([], identityFunction)));
}
