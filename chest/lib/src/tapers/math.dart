import 'dart:math';

import 'basics.dart';

extension TapersPackageForDartMath on TapersForPackageApi {
  Map<int, Taper<dynamic>> forDartMath() {
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

extension TapersForForDartMath on TaperApi {
  Taper<MutableRectangle<T>> forMutableRectangle<T extends num>() =>
      _TaperForMutableRectangle<T>();
  Taper<Rectangle<T>> forRectangle<T extends num>() => _TaperForRectangle<T>();
  Taper<Point<T>> forPoint<T extends num>() => _TaperForPoint<T>();
}

class _TaperForMutableRectangle<T extends num>
    extends ClassTaper<MutableRectangle<T>> {
  const _TaperForMutableRectangle();

  @override
  Map<String, Object?> toFields(MutableRectangle<T> rect) {
    return {
      'left': rect.left,
      'top': rect.top,
      'width': rect.width,
      'height': rect.height,
    };
  }

  @override
  MutableRectangle<T> fromFields(Map<String, Object?> fields) {
    return MutableRectangle<T>(
      fields['left'] as T,
      fields['top'] as T,
      fields['width'] as T,
      fields['height'] as T,
    );
  }
}

class _TaperForRectangle<T extends num> extends ClassTaper<Rectangle<T>> {
  const _TaperForRectangle();

  @override
  Map<String, Object?> toFields(Rectangle<T> rect) {
    return {
      'left': rect.left,
      'top': rect.top,
      'width': rect.width,
      'height': rect.height,
    };
  }

  @override
  Rectangle<T> fromFields(Map<String, Object?> fields) {
    return Rectangle<T>(
      fields['left'] as T,
      fields['top'] as T,
      fields['width'] as T,
      fields['height'] as T,
    );
  }
}

class _TaperForPoint<T extends num> extends ClassTaper<Point<T>> {
  const _TaperForPoint();

  @override
  Map<String, Object?> toFields(Point<T> point) {
    return {'x': point.x, 'y': point.y};
  }

  @override
  Point<T> fromFields(Map<String, Object?> fields) {
    return Point(fields['x'] as T, fields['y'] as T);
  }
}
