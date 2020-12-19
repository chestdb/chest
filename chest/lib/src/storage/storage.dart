import '../blocks.dart';

export '../blocks.dart';
export '../bytes.dart';
export '../utils.dart';

abstract class Storage {
  /// A stream of updates.
  Stream<Update> get updates;

  /// Gets the value. Used at startup.
  Future<UpdatableBlock?> getValue();

  void setValue(Path<Block> path, Block value);

  Future<void> flush();
  Future<void> close();
}

class Update {
  Update(this.path, this.value);

  final Path<Block> path;
  final Block value;
}
