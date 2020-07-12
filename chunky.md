# Consistency & Atomicity

One of the challenges of databases is consistency and atomicity. What is that?

If you make a change to a record and then your program crashes, you expect that it's either completely written to the database or not at all – having the first bytes of your change overwriting the previous state of the record is a no-go.

## The in-memory approach

In-memory databases can take an easy approach to solve that problem – they can just add all changes to the end of the file. Have a look at a sembast database file where record A got added, record B got added and then record A got removed:

```json
{"key":"a","store":"box","value":{"foo":1}}
{"key":"b","store":"box","value":{"foo":1}}
{"key":"a","store":"box","value":"deleted"}
```

The record still exists in the file, it's just not shown to the application any more.
Of course, if you change records a lot and remove records, the file gets very large.
To combat this, sembast (and also other in-memory databases, like Hive) introduce a "compaction" phase: They simply read all records into memory, create a new file (something like `database.compacted.json`), write the newest version of all existing records into that file, remove the old database and then remove the new version so that it becomes the de-facto database.

That approach is simple – just throw everything away and build it new – but it's effective.
It does have some disadvantages though:

* You need to choose the right time to do compaction. For example, something like "if 50 % of all records are either overwritten or deleted, compact everything". Every dataset differs, so while these heuristics fit most cases, there can always be some where it doesn't achieve optimal results.
* It doesn't scale. For large datasets, holding all values in memory isn't possible.
* Compaction takes time. This makes the database unpredictable – similar to how in most garbage-collected languages, the program is completely stopped for a moment to look for unused objects, compaction can also cause unpredictable spikes in resource exhausting. That's not as bad as garbage collection, because it doesn't stop everything (I/O is asynchronous, but it still takes more time to guarantee that a value has been written to disk).

## Cassette's approach

For big amounts of data, it's not viable to simply throw out everything and rebuild the database from scratch.
To be able to do incremental updates, chunks are introduced. They are contiguous slices of memory of a certain size.
Cassette's lowest layer – chunky – provides an abstraction from these chunks so you can atomically write to multiple chunks.

```dart
final chunky = await ChunkManager(File('sample.bin'));

final firstChunk = await chunky.read(0);
final newChunk = ChunkData();

firstChunk.writeUint8(24, 42);
newChunk.writeUint8(1, firstChunk.readUint8(2));

final id = chunk.add(newChunk);
newChunk.writeUint8(123, 12);

await chunky.writeAll({
  0: firstChunk,
  id: newChunk,
});
```

How do atomically writing to chunks work? By introducing a layer of indirection!
Chunks don't actually correspond to the place they are stored in the file. Intead, there's a translation table that maps virtual chunks to phyiscal ones.
