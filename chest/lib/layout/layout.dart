/// The layout layer offers a declarative API for defining memory layouts.
///
/// You can define memory layouts as a tree that internally operates on a byte
/// array (a chunk).
///
/// These are the tree passes done while applying the layout to obtain an
/// interactive layout instance:
/// - The binding pass binds each widget to its parent. This allows children to
///   defer operations that change bytes to their parents.
/// - The layout pass gives layout constraints down (min and max length) and
///   sets the length and offset of all widgets.
/// - The apply pass initializes memory, i.e. by filling it with zeros.
///
/// The layout pass is pretty similar to how the layout pass of Flutter Widgets
/// work, but instead of doing layout on a two-dimensional pixel grid, we do
/// layout on a one-dimensional list of bytes.
library layout;

import 'package:chest/chunky/chunky.dart';

export 'foundation.dart';
export 'utils.dart';
export 'widgets.dart';

import 'foundation.dart';
import 'widgets.dart';

void main() {
  final someChunk = TransactionChunk(1, ChunkData());
  final memory = someChunk.apply(Tuple2(
    first: Uint8(),
    second: Uint8(),
  ));
  memory.first;
}
