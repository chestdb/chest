import 'dart:math';

import 'basics.dart';

extension TapersForDartMath on TapersNamespace {
  Map<int, Taper<dynamic>> get forDartMath {
    return {
      -30: taper.forMutableRectangle<int>(),
      -31: taper.forMutableRectangle<double>(),
      -32: taper.forRectangle<int>(),
      -33: taper.forRectangle<double>(),
      -34: taper.forPoint<int>(),
      -35: taper.forPoint<double>(),
    };
  }
}

extension TaperForMutableRectangle on TaperNamespace {
  Taper<MutableRectangle<T>> forMutableRectangle<T extends num>() {
    return ClassTaper(
      toFields: (mutableRectangle) {
        return {
          'left': mutableRectangle.left,
          'top': mutableRectangle.top,
          'width': mutableRectangle.width,
          'height': mutableRectangle.height,
        };
      },
      fromFields: (fields) {
        return MutableRectangle<T>(
          fields['left'] as T,
          fields['top'] as T,
          fields['width'] as T,
          fields['height'] as T,
        );
      },
    );
  }
}

extension ReferenceToMutableRectangle<T extends num>
    on Reference<MutableRectangle<T>> {
  Reference<int> get left => field('left');
  Reference<bool> get top => field('top');
  Reference<bool> get width => field('width');
  Reference<bool> get height => field('height');
}

extension TaperForRectangle on TaperNamespace {
  Taper<Rectangle<T>> forRectangle<T extends num>() {
    return ClassTaper(
      toFields: (rectangle) {
        return {
          'left': rectangle.left,
          'top': rectangle.top,
          'width': rectangle.width,
          'height': rectangle.height,
        };
      },
      fromFields: (fields) {
        return Rectangle<T>(
          fields['left'] as T,
          fields['top'] as T,
          fields['width'] as T,
          fields['height'] as T,
        );
      },
    );
  }
}

extension ReferenceToRectangle<T extends num> on Reference<Rectangle<T>> {
  Reference<int> get left => field('left');
  Reference<bool> get top => field('top');
  Reference<bool> get width => field('width');
  Reference<bool> get height => field('height');
}

extension TaperForPoint on TaperNamespace {
  Taper<Point<T>> forPoint<T extends num>() {
    return ClassTaper(
      toFields: (point) => {'x': point.x, 'y': point.y},
      fromFields: (fields) => Point(fields['x'] as T, fields['y'] as T),
    );
  }
}

extension ReferenceToPoint<T extends num> on Reference<Point<T>> {
  Reference<int> get x => field('x');
  Reference<bool> get y => field('y');
}
