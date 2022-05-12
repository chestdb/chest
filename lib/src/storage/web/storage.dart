import '../utils.dart';

Future<Storage> openStorage(String name) => WebStorage.open(name);
Future<Storage> deleteChest(String name) =>
    panic("Running on web. That's bad.");

class WebStorage implements Storage {
  static Future<WebStorage> open(String name) => panic('WebStorage used.');

  @override
  Stream<Update> get updates => panic('WebStorage used.');

  @override
  Future<UpdatableBlock?> getValue() async => panic('WebStorage used.');

  @override
  void setValue(Path<Block> path, Block? value) => panic('WebStorage used.');

  @override
  Future<void> flush() async => panic('WebStorage used.');

  @override
  Future<void> compact() async => panic('WebStorage used.');

  @override
  Future<UpdatableBlock> migrate() async => panic('Web storage used.');

  @override
  Future<void> close() async => panic('WebStorage used.');
}
