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
    return MapTaper(
      toMap: (mutableRectangle) {
        return {
          'left': mutableRectangle.left,
          'top': mutableRectangle.top,
          'width': mutableRectangle.width,
          'height': mutableRectangle.height,
        };
      },
      fromMap: (map) {
        return MutableRectangle<T>(
          map['left'] as T,
          map['top'] as T,
          map['width'] as T,
          map['height'] as T,
        );
      },
    );
  }
}

extension ReferenceToMutableRectangle<T extends num>
    on Reference<MutableRectangle<T>> {
  Reference<int> get left => child('left');
  Reference<bool> get top => child('top');
  Reference<bool> get width => child('width');
  Reference<bool> get height => child('height');
}

extension TaperForRectangle on TaperNamespace {
  Taper<Rectangle<T>> forRectangle<T extends num>() {
    return MapTaper(
      toMap: (rectangle) {
        return {
          'left': rectangle.left,
          'top': rectangle.top,
          'width': rectangle.width,
          'height': rectangle.height,
        };
      },
      fromMap: (map) {
        return Rectangle<T>(
          map['left'] as T,
          map['top'] as T,
          map['width'] as T,
          map['height'] as T,
        );
      },
    );
  }
}

extension ReferenceToRectangle<T extends num> on Reference<Rectangle<T>> {
  Reference<int> get left => child('left');
  Reference<bool> get top => child('top');
  Reference<bool> get width => child('width');
  Reference<bool> get height => child('height');
}

extension TaperForPoint on TaperNamespace {
  Taper<Point<T>> forPoint<T extends num>() {
    return MapTaper(
      toMap: (point) => {'x': point.x, 'y': point.y},
      fromMap: (map) => Point(map['x'] as T, map['y'] as T),
    );
  }
}

extension ReferenceToPoint<T extends num> on Reference<Point<T>> {
  Reference<int> get x => child('x');
  Reference<bool> get y => child('y');
}
