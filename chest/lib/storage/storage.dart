import '../blocks.dart';
import '../value.dart';

export '../blocks.dart';
export '../value.dart';

abstract class Storage {
  /// A stream of updates.
  Stream<Delta> get updates;

  /// Gets the value. Used at startup.
  Future<Block?> getValue();

  void setValue(Path path, Block value);

  Future<void> flush();
  Future<void> close();
}
