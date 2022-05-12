import '../blocks.dart';
import 'web/storage.dart' if (dart.library.io) 'vm/storage.dart';

abstract class Storage {
  static Future<Storage> open(String name) => openStorage(name);
  static Future<void> delete(String name) => deleteChest(name);

  /// A stream of updates.
  Stream<Update> get updates;

  Future<UpdatableBlock?> getValue(); // For now, only used on startup.
  void setValue(Path<Block> path, Block? value);

  Future<void> flush();
  Future<UpdatableBlock> migrate();
  Future<void> compact();
  Future<void> close();
}

class Update {
  Update(this.path, this.value);

  final Path<Block> path;
  final Block? value;
}
