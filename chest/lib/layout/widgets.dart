import 'dart:typed_data';

import 'package:chest/chunky/chunky.dart';
import 'package:meta/meta.dart';

import 'foundation.dart';
import 'utils.dart';

/// A widget that fills all the available space.
class Fill<W extends Widget> extends SingleChildWidget<W> {
  Fill(W child) : super(child);

  @override
  void layout(Constraints constraints) {
    assert(constraints.isFinite);
    length = constraints.maxLength;
  }
}

/// A widget that should be given tight constraints and assumes the given
/// length.
class _Tight extends Widget {
  @override
  void layout(Constraints constraints) {
    assert(constraints.isTight);
    length = constraints.maxLength;
  }
}

/// A widget that doesn't care about the bytes.
class Padding extends _Tight {}

/// A widget that sets all bytes to zero.
class Zeros extends _Tight {
  @override
  void apply() {
    for (var i = 0; i < length; i++) {
      setUint8(i, 0);
    }
  }
}

/// A widget that is a placeholder and sets all bytes to a pattern recognizable
/// in hex.
class Placeholder extends _Tight {
  Placeholder(this.type)
      : assert(type >= 0),
        assert(type < 16);

  final int type;

  @override
  void apply() {
    for (var i = 0; i < length; i++) {
      setUint8(i, type * 17);
    }
  }
}

/// A widget that lays out its children all after each other.
class ListWidget extends MultiChildWidget {
  ListWidget({@required List<Widget> children}) : super(children) {
    length = lengthOfChildren;
  }

  @override
  void layout(Constraints constraints) {
    var totalInflexibleLength = 0;

    for (final child in children.where((child) => child is! Flex)) {
      child.checkedLayout(Constraints.loose());
      totalInflexibleLength += child.length;
    }

    final flexes = children.whereType<Flex>().toList();
    if (flexes.length > 0) {
      assert(constraints.isFinite);
      final lengthLeft = constraints.maxLength - totalInflexibleLength;
      final lengthPerChild = lengthLeft ~/ flexes.length;
      var additionalBytes = lengthLeft - lengthPerChild * flexes.length;

      for (final flex in flexes) {
        var numBytes = lengthPerChild;
        if (additionalBytes > 0) {
          numBytes++;
          additionalBytes--;
        }
        flex.checkedLayout(Constraints.tight(numBytes));
      }
    }

    int offset = 0;
    for (final child in children) {
      child.offset = offset;
      offset += child.length;
    }

    length = offset;
  }
}

class Flex<W extends Widget> extends HigherLevelWidget<W> {
  Flex({@required W child}) : super(child);
}

// Tuple

class Tuple2<A extends Widget, B extends Widget>
    extends HigherLevelWidget<ListWidget> {
  Tuple2({@required A first, @required B second})
      : super(ListWidget(children: [first, second]));

  A get first => widget.children.first as A;
  B get second => widget.children[1] as B;
}

class Tuple3<A extends Widget, B extends Widget, C extends Widget>
    extends HigherLevelWidget<ListWidget> {
  Tuple3({@required A first, @required B second, @required C third})
      : super(ListWidget(children: [first, second, third]));

  A get first => widget.children.first as A;
  B get second => widget.children[1] as B;
  C get third => widget.children[2] as C;
}

// Primitives

class Uint8 extends FixedLengthLeafWidget {
  Uint8() : super(1);

  int get value => getUint8(0);
  set value(int val) => setUint8(0, val);
}

class Uint16 extends FixedLengthLeafWidget {
  Uint16() : super(2);

  int get value => getUint16(0);
  set value(int val) => setUint16(0, val);
}

// Chest-specific primitives

class ChunkId extends HigherLevelWidget<Uint16> {
  ChunkId() : super(Uint16());

  int get value => widget.value;
  set value(int val) => widget.value = val;
}

class DocId extends HigherLevelWidget<Uint16> {
  DocId() : super(Uint16());

  int get value => widget.value;
  set value(int val) => widget.value = val;
}
