import 'package:chest/src/blocks.dart';
import 'package:glados/glados.dart';

extension AnyBlock on Any {
  Generator<MapBlock> get mapBlock {
    return combine2<int, Map<Block, Block>, MapBlock>(
      any.int,
      any.map(any.block, any.block),
      (typeCode, map) => MapBlock(typeCode, map),
    );
  }

  Generator<BytesBlock> get bytesBlock {
    return combine2<int, List<int>, BytesBlock>(
      any.int,
      any.list(any.uint8),
      (typeCode, bytes) => BytesBlock(typeCode, bytes),
    );
  }

  Generator<Block> get block => either(any.mapBlock, any.bytesBlock);
}

void main() {
  group('UpdatableBlock', () {
    test('sample', () {
      final updatableBlock = UpdatableBlock(MapBlock(1, {
        BytesBlock(2, [1, 2, 3]): BytesBlock(3, [1, 2]),
        BytesBlock(2, [1, 2]): BytesBlock(2, [1]),
      }));
      updatableBlock.update(
        Path<Block>([
          BytesBlock(2, [1, 2])
        ]),
        BytesBlock(42, []),
        createImplicitly: false,
      );
      expect(
        updatableBlock.getAt(Path.root()),
        equals(MapBlock(1, {
          BytesBlock(2, [1, 2, 3]): BytesBlock(3, [1, 2]),
          BytesBlock(2, [1, 2]): BytesBlock(42, []),
        })),
      );
    });
  });
}
