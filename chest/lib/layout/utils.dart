import 'package:chest/chunky/chunky.dart';

import 'foundation.dart';

extension CheckedLayout on Widget {
  /// Layout, but with additional checks.
  void checkedLayout(Constraints constraints) {
    assert(
        constraints != null, 'Attempted to do layout with null constraints.');
    layout(constraints);
    assert(length != null, 'The length is null after layout.');
    assert(constraints.wouldFit(length),
        "After layout, the length is $length, which doesn't fit the given constraints $constraints.");
  }
}

/// A widget with a single child.
///
/// The widget itself is still responsible for setting its length and the offset
/// of the child. If the widget only consists of its child with no additional
/// information saved, consider using a [HigherOrderWidget], which also assumes
/// the length of its child and sets the child's offset to 0.
abstract class SingleChildWidget<W extends Widget> extends Widget {
  SingleChildWidget(this.child);

  final W child;

  @override
  void bind(Chunk context) {
    super.bind(context);
    child.bind(this);
  }

  @override
  void apply() => child.apply();
}

/// A widget with multiple children.
abstract class MultiChildWidget extends Widget {
  MultiChildWidget(this.children);

  final List<Widget> children;
  int get lengthOfChildren {
    return children.map((child) => child.length).reduce((a, b) {
      if (a == null || b == null) {
        return null;
      } else {
        return a + b;
      }
    });
  }

  @override
  void bind(Chunk context) {
    super.bind(context);
    for (final child in children) {
      child.bind(this);
    }
  }

  @override
  void apply() {
    for (final child in children) {
      child.apply();
    }
  }
}

/// A semantically transparent widget that is composed of smaller widgets.
abstract class HigherLevelWidget<W extends Widget> extends Widget {
  HigherLevelWidget(this.widget) {
    length = widget.length;
  }

  W widget;

  @override
  void bind(Chunk context) {
    super.bind(context);
    widget.bind(this);
  }

  @override
  void layout(Constraints constraints) {
    widget.checkedLayout(constraints);
    length = widget.length;
    widget.offset = 0;
  }

  @override
  void apply() => widget.apply();
}

/// A leaf widget without a child and a fixed length.
abstract class FixedLengthLeafWidget extends Widget {
  FixedLengthLeafWidget(int fixedLength) {
    length = fixedLength;
  }

  @override
  void layout(Constraints _) {
    // No-op since we already set the length in the constructor.
  }
}
