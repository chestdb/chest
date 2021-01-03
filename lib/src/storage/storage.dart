import '../blocks.dart';

export '../blocks.dart';
export '../bytes.dart';
export '../tapers.dart';
export '../utils.dart';

abstract class Storage {
  /// A stream of updates.
  Stream<Update> get updates;

  Future<UpdatableBlock?> getValue(); // For now, only used on startup.
  void setValue(Path<Block> path, Block value);

  Future<void> flush();
  Future<UpdatableBlock> migrate();
  Future<void> compact();
  Future<void> close();
}

class Update {
  Update(this.path, this.value);

  final Path<Block> path;
  final Block value;
}
