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

extension TaperForMutableRectangleExtension on TaperNamespace {
  Taper<MutableRectangle<T>> forMutableRectangle<T extends num>() =>
      TaperForMutableRectangle<T>();
}

class TaperForMutableRectangle<T extends num>
    extends MapTaper<MutableRectangle<T>> {
  @override
  Map<Object?, Object?> toMap(MutableRectangle<T> mutableRectangle) {
    return {
      'left': mutableRectangle.left,
      'top': mutableRectangle.top,
      'width': mutableRectangle.width,
      'height': mutableRectangle.height,
    };
  }

  @override
  MutableRectangle<T> fromMap(Map<Object?, Object?> map) {
    return MutableRectangle<T>(
      map['left'] as T,
      map['top'] as T,
      map['width'] as T,
      map['height'] as T,
    );
  }
}

extension ReferenceToMutableRectangle<T extends num>
    on Reference<MutableRectangle<T>> {
  Reference<T> get left => child('left');
  Reference<T> get top => child('top');
  Reference<T> get width => child('width');
  Reference<T> get height => child('height');
}

extension TaperForRectangleExtension on TaperNamespace {
  Taper<Rectangle<T>> forRectangle<T extends num>() => TaperForRectangle<T>();
}

class TaperForRectangle<T extends num> extends MapTaper<Rectangle<T>> {
  @override
  Map<Object?, Object?> toMap(Rectangle<T> rectangle) {
    return {
      'left': rectangle.left,
      'top': rectangle.top,
      'width': rectangle.width,
      'height': rectangle.height,
    };
  }

  @override
  Rectangle<T> fromMap(Map<Object?, Object?> map) {
    return Rectangle<T>(
      map['left'] as T,
      map['top'] as T,
      map['width'] as T,
      map['height'] as T,
    );
  }
}

extension ReferenceToRectangle<T extends num> on Reference<Rectangle<T>> {
  Reference<T> get left => child('left');
  Reference<T> get top => child('top');
  Reference<T> get width => child('width');
  Reference<T> get height => child('height');
}

extension TaperForPointExtension on TaperNamespace {
  Taper<Point<T>> forPoint<T extends num>() => TaperForPoint<T>();
}

class TaperForPoint<T extends num> extends MapTaper<Point<T>> {
  @override
  Map<Object?, Object?> toMap(Point<T> point) => {'x': point.x, 'y': point.y};

  @override
  Point<T> fromMap(Map<Object?, Object?> map) =>
      Point(map['x'] as T, map['y'] as T);
}

extension ReferenceToPoint<T extends num> on Reference<Point<T>> {
  Reference<T> get x => child('x');
  Reference<T> get y => child('y');
}
