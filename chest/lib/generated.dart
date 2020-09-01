part of 'main.dart';

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
