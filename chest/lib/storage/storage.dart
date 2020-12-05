import '../blocks.dart';
import '../value.dart';

export '../blocks.dart';
export '../value.dart';

abstract class Storage {
  /// A stream of updates.
  Stream<Update> get updates;

  /// Gets the value. Used at startup.
  Future<Value?> getValue();

  void setValue(Path path, Block value);

  Future<void> flush();
  Future<void> close();
}

class Update {
  Update(this.path, this.value);

  final Path<Block> path;
  final Block value;
}
