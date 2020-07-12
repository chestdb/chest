part of 'chunky.dart';

/// A transaction works as follows:
/// - All transaction actions are appended to the end of the file (or overwrite
///   existing transaction actions).
/// - Then, the header's "transaction running" field is set to 255.
/// - Then, the transaction is executed step by step (the appropriate bytes are
///   overwritten).
/// - After that, the header's "transaction running" field is set back to 0.
///
/// If the transaction partially completed and then the program got killed, on
/// startup, the [ChunkManager] will see that the header's "transaction running"
/// field is set to not-null, and re-execute everything of the transaction.
/// This way, partially updated data will never occur.
extension TransactionRunner on ChunkManagerImpl {
  void runTransaction(List<Step> steps) {
    _file.toOffset(endOffset);
    steps.writeTo(_file);
    _file.flush();
    isTransactionRunning = true;
    _file.flush();
    steps.run(this);
    _file.flush();
    isTransactionRunning = false;
    _file.flush();
  }

  void runExistingTransaction() {
    final steps = Transaction.readFrom(_file.toOffset(endOffset));
    steps.run(this);
    _file.flush();
    isTransactionRunning = false;
    _file.flush();
  }
}

extension Transaction on List<Step> {
  static final _builders = <int, Step Function(File file)>{
    Step.typeSetNumUserChunks: (file) => SetNumberOfUserChunks.readFrom(file),
    Step.typeSetNumFreeChunks: (file) => SetNumberOfFreeChunks.readFrom(file),
    Step.typeSetFirstFreeChunkAddress: (file) =>
        SetFirstFreeChunk.readFrom(file),
    Step.typeSetChunkIdToAddress: (file) => SetChunkIdToAddress.readFrom(file),
    Step.typeSetPreviousFreeChunk: (file) =>
        SetPreviousFreeChunk.readFrom(file),
    Step.typeSetNextFreeChunk: (file) => SetNextFreeChunk.readFrom(file),
  };

  static List<Step> readFrom(File file) {
    final length = file.readInt();
    return <Step>[
      for (var i = 0; i < length; i++) _builders[file.readByte()](file),
    ];
  }

  void writeTo(File file) {
    file.writeInt(length);
    for (final step in this) {
      file.writeByte(step.type);
      step.writeTo(file);
    }
  }

  void run(ChunkManager manager) {
    for (final step in this) {
      step.run(manager);
    }
  }
}

/// Resembles a step of a transaction (modifying a non-content chunk).
abstract class Step {
  Step(this.type);

  final int type;
  static const typeSetNumUserChunks = 0;
  static const typeSetNumFreeChunks = 1;
  static const typeSetFirstFreeChunkAddress = 2;
  static const typeSetChunkIdToAddress = 3;
  static const typeSetPreviousFreeChunk = 4;
  static const typeSetNextFreeChunk = 5;

  void writeTo(File file);
  void run(ChunkManagerImpl manager);
}

class SetNumberOfUserChunks extends Step {
  SetNumberOfUserChunks(this.numUserChunks) : super(Step.typeSetNumUserChunks);
  SetNumberOfUserChunks.readFrom(File file) : this(file.readInt());

  final int numUserChunks;

  @override
  void writeTo(File file) => file.writeInt(numUserChunks);

  @override
  void run(ChunkManagerImpl manager) =>
      manager.numberOfUserChunks = numUserChunks;
}

class SetNumberOfFreeChunks extends Step {
  SetNumberOfFreeChunks(this.numFreeChunks) : super(Step.typeSetNumUserChunks);
  SetNumberOfFreeChunks.readFrom(File file) : this(file.readInt());

  final int numFreeChunks;

  @override
  void writeTo(File file) => file.writeInt(numFreeChunks);

  @override
  void run(ChunkManagerImpl manager) =>
      manager.numberOfFreeChunks = numFreeChunks;
}

class SetFirstFreeChunk extends Step {
  SetFirstFreeChunk(this.address) : super(Step.typeSetFirstFreeChunkAddress);
  SetFirstFreeChunk.readFrom(File file) : this(file.readInt());

  final int address;

  @override
  void writeTo(File file) => file.writeInt(address);

  @override
  void run(ChunkManagerImpl manager) => manager.firstFreeChunk = address;
}

class SetChunkIdToAddress extends Step {
  SetChunkIdToAddress(this.id, this.address)
      : super(Step.typeSetChunkIdToAddress);
  SetChunkIdToAddress.readFrom(File file)
      : this(file.readInt(), file.readInt());

  final int id;
  final int address;

  @override
  void writeTo(File file) => file..writeInt(id)..writeInt(address);

  @override
  void run(ChunkManagerImpl manager) {
    manager._file.toOffset(offsetForIdLookup(id)).writeInt(address);
  }
}

class SetPreviousFreeChunk extends Step {
  SetPreviousFreeChunk(this.current, this.previous)
      : super(Step.typeSetPreviousFreeChunk);
  SetPreviousFreeChunk.readFrom(File file)
      : this(file.readInt(), file.readInt());

  final int current;
  final int previous;

  @override
  void writeTo(File file) => file..writeInt(current)..writeInt(previous);

  @override
  void run(ChunkManagerImpl manager) {
    manager._file.toChunk(current).writeInt(previous);
  }
}

class SetNextFreeChunk extends Step {
  SetNextFreeChunk(this.current, this.next) : super(Step.typeSetNextFreeChunk);
  SetNextFreeChunk.readFrom(File file) : this(file.readInt(), file.readInt());

  final int current;
  final int next;

  @override
  void writeTo(File file) => file..writeInt(current)..writeInt(next);

  @override
  void run(ChunkManagerImpl manager) {
    manager._file.toChunkAndOffset(current, 8).writeInt(next);
  }
}
