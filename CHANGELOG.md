## 0.0.5-0

* Make root path configurable.
* Improve error messages by decoding paths and always printing the chest name.
* Add `update` and `mutate` methods to `Reference`.
* Add `valueOr` and `valueOrNull` on `Reference`.
* Make `Uint8`'s `toString` nicer.

## 0.0.4-0

* Separate creating `Chest`s and opening them.
* Rename `Ref` to `Reference`.
* Make defining tapers more concise.
* Support migration of tapers.
* Chest files now have magic bytes at the beginning.
* Prepare for code generation.
* Better error handling in the isolate.

## 0.0.3-0

* Develop brand, including color palette, font, and logo.
* Use more efficient `TransferableTypedData` for sending bytes between isolates.
* Support manually compacting chests.
* Revise readme, adding documentation on tapers.

## 0.0.2-0

* Refactor the whole code architecture.
* Support updating parts of chests.
* Support watching parts of chests.
* Implement compaction.
* Develop new syntax for stringified blocks.
* Add basic error handling.
* Write tapers for some types.
* Revise readme.

## 0.0.1-0

* Initial release supporting reading and writing to chests.
