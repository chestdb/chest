import 'dart:typed_data';

extension IterableX<T> on Iterable<T> {
  T? get firstOrNull {
    return isEmpty ? null : cast<T?>().firstWhere((_) => true, orElse: null);
  }
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
