import '../storage.dart';

Future<Storage> openStorage(String name) => WebStorage.open(name);

class WebStorage implements Storage {
  static Future<WebStorage> open(String name) => panic('WebStorage used.');

  @override
  Stream<Update> get updates => panic('WebStorage used.');

  Future<UpdatableBlock?> getValue() async => panic('WebStorage used.');

  @override
  void setValue(Path<Block> path, Block value) => panic('WebStorage used.');

  @override
  Future<void> flush() async => panic('WebStorage used.');

  @override
  Future<void> compact() async => panic('WebStorage used.');

  @override
  Future<UpdatableBlock> migrate() async => panic('Web storage used.');

  @override
  Future<void> close() async => panic('WebStorage used.');
}
