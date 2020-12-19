import 'dart:isolate';

import '../storage.dart';

/// A representation of a [Block] that doesn't offer direct access to its
/// content, but can be efficiently transferred between [Isolate]s.
///
/// This is how the efficient sending works:
///
/// 1.  When creating a `TransferableBlock`, the block is serialized into bytes
///     and those bytes are wrapped in a [TransferableTypedData]. That causes
///     Dart to copy the bytes to an external memory region outside of the Dart
///     heap. So, a [TransferableBlock]s are merely a pointer to that external
///     memory region.
/// 2.  When a [TransferableBlock] is transferred between isolates (by sending
///     it through a port), only the pointer is passed through, which is pretty
///     cheap.
/// 3.  When calling `transferredBlock.materialize()` on the receiving isolate,
///     the [TransferableTypeData.materialize] function is called, which marks
///     the external memory as being owned by the receiving isolate so nobody
///     else can grab it again. That also means, that you can only call
///     `materialize` once.
///
/// The cool thing is that the work on the receiving isolate is constant – all
/// the heavy serialization and copying of bytes can happen on the backend
/// isolate and the receiving isolate has instant access to the bytes.
class TransferableBlock {
  TransferableBlock(Block block)
      : _data = TransferableTypedData.fromList([block.toBytes()]);

  final TransferableTypedData _data;

  Block materialize() => BlockView.of(_data.materialize());
}

extension BlockToTransferable on Block {
  TransferableBlock transferable() => TransferableBlock(this);
}

class TransferableUpdatableBlock {
  TransferableUpdatableBlock(this.block, this.updates);

  final TransferableBlock block;
  final Map<TransferableBlock, TransferableUpdatableBlock?> updates;

  UpdatableBlock materialize() {
    return UpdatableBlock(
      block.materialize(),
      updates.map((path, block) {
        return MapEntry(path.materialize(), block?.materialize());
      }),
    );
  }
}

extension UpdatableBlockToTransferable on UpdatableBlock {
  TransferableUpdatableBlock transferable() => TransferableUpdatableBlock(
        block.transferable(),
        updates.map((path, block) {
          return MapEntry(path.transferable(), block?.transferable());
        }),
      );
}
