import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';
import 'package:meta/meta.dart';

/// High-level description of a particular memory layout.
/// Similar to Flutter's Widgets.
abstract class Widget implements Chunk {
  /// Is set during bind. Will be the parent.
  Chunk context;

  /// Is set during bind for widgets with a fixed length.
  /// Is set during layout for widgets with a dynamic length.
  int length;
  bool get hasLength => length != null;

  /// Is set by the parent during bind or layout.
  int offset;

  /// Binds this widget to its parent. Used to forward actions like actually
  /// setting and reading bytes to the parent using the offset.
  @mustCallSuper
  void bind(Chunk context) => this.context = context;

  /// Sets the length and offset of all children and the length of this widget
  /// itself.
  void layout(Constraints constraints);

  /// Applies data to the memory, for example setting all bytes to zero.
  void apply() {}

  // Chunk operations.

  Chunk get _safeContext {
    assert(context != null,
        'Cannot execute operations, because the context has not been set.');
    return context;
  }

  int get _safeOffset {
    assert(offset != null,
        'Cannot execute operations, because offset has not been set.');
    return offset;
  }

  void setUint8(int offset, int value) {
    print(
        '${runtimeType}: setting Uint8 at $offset to $value (offset=$_safeOffset)');
    _safeContext.setUint8(_safeOffset + offset, value);
  }

  int getUint8(int offset) => _safeContext.getUint8(_safeOffset + offset);

  void setUint16(int offset, int value) =>
      _safeContext.setUint16(_safeOffset + offset, value);
  int getUint16(int offset) => _safeContext.getUint16(_safeOffset + offset);

  void setUint32(int offset, int value) =>
      _safeContext.setUint32(_safeOffset + offset, value);
  int getUint32(int offset) => _safeContext.getUint32(_safeOffset + offset);

  void setInt64(int offset, int value) =>
      _safeContext.setInt64(_safeOffset + offset, value);
  int getInt64(int offset) => _safeContext.getInt64(_safeOffset + offset);

  void setBytes(int offset, List<int> bytes) =>
      _safeContext.setBytes(_safeOffset + offset, bytes);
  Uint8List getBytes(int offset, int length) =>
      _safeContext.getBytes(_safeOffset + offset, length);

  void copyFrom(Chunk other) =>
      throw UnsupportedError("Can't call copyFrom on a memory layout widget.");
  void copyTo(Chunk other) =>
      throw UnsupportedError("Can't call copyTo on a memory layout widget.");
}

/// Memory constraints given to widgets during the layout phase.
///
/// Simply contains a minimum and maximum length.
class Constraints {
  Constraints(this.minLength, this.maxLength);
  Constraints.tight(int length) : this(length, length);
  Constraints.loose() : this(0, null);

  final int minLength;
  final int maxLength; // May be null to indicate no preferred upper bound.

  bool get isInfinite => maxLength == null;
  bool get isFinite => maxLength != null;
  bool get isTight => minLength == maxLength;

  bool wouldFit(int length) =>
      minLength <= length && (isInfinite || maxLength >= length);

  String toString() => "Constraints($minLength, $maxLength)";
}

typedef WidgetBuilder<W extends Widget> = W Function();

extension WidgetOnChunk on Chunk {
  W apply<W extends Widget>(W widget) {
    widget.bind(this);
    widget.layout(Constraints.tight(chunkLength));
    widget.offset = 0;
    // widget.apply();
    return widget;
  }
}
