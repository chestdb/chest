import 'dart:typed_data';

extension IterableX<T> on Iterable<T> {
  T? get firstOrNull {
    return isEmpty ? null : cast<T?>().firstWhere((_) => true, orElse: null);
  }
}

extension ListX<T> on List<T> {
  bool deeplyEquals(List<T> other) {
    final length = this.length;
    if (length != other.length) return false;
    for (var i = 0; i < length; i++) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }
}

extension StreamWhereType<T> on Stream<T> {
  Stream<R> whereType<R>() => where((it) => it is R).cast<R>();
}

extension WhereKeyValue<K, V> on Iterable<MapEntry<K, V>> {
  Iterable<MapEntry<K, V>> whereKeyValue(bool Function(K key, V value) check) {
    return where((entry) => check(entry.key, entry.value));
  }

  Iterable<T> mapKeyValue<T>(T Function(K key, V value) mapper) {
    return map((entry) => mapper(entry.key, entry.value));
  }

  Map<K, V> toMap() => Map.fromEntries(this);
}

bool get inDebugMode {
  var test = false;
  assert(() {
    test = true;
    return true;
  }());
  return test;
}

abstract class ChestException implements Exception {}

abstract class ChestError extends Error {}

class _InternalChestError extends ChestError {
  _InternalChestError(this.message);

  final String message;

  String toString() => 'Internal Chest Error: $message';
}

Never panic(String message) => throw _InternalChestError(message);

// On Path:
// Path<Block> serialize() {
//   return Path(keys.map((it) => it.toBlock()).toList());
// }

/// A wrapper around [ByteData] that only offers useful methods for encoding
/// [Block]s.
class Data {
  Data(this.data);

  ByteData data;
  int cursor = 0;

  void setTypeCode(int offset, int code) => data.setUint64(offset, code);
  int getTypeCode(int offset) => data.getUint64(offset);
  void addTypeCode(int code) {
    setTypeCode(cursor, code);
    cursor += 8;
  }

  void setBlockKind(int offset, int kind) => data.setUint8(offset, kind);
  int getBlockKind(int offset) => data.getUint8(offset);
  void addBlockKind(int kind) {
    setBlockKind(cursor, kind);
    cursor += 1;
  }

  void setLength(int offset, int length) => data.setUint64(offset, length);
  int getLength(int offset) => data.getUint64(offset);
  void addLength(int length) {
    setLength(cursor, length);
    cursor += 8;
  }

  void setPointer(int offset, int pointer) => data.setUint64(offset, pointer);
  int getPointer(int offset) => data.getUint64(offset);
  void addPointer(int pointer) {
    setPointer(cursor, pointer);
    cursor += 8;
  }

  void setByte(int offset, int byte) => data.setUint8(offset, byte);
  int getByte(int offset) => data.getUint8(offset);
  void addByte(int byte) {
    setByte(cursor, byte);
    cursor += 1;
  }
}
