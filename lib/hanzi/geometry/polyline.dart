/// Arc-length traversal of a median polyline.
///
/// Medians are not uniformly sampled — makemeahanzi puts vertices where the
/// stroke bends (and where a Kai-style entry serif curls), so stepping by index
/// makes the animated dot lurch. Everything here steps by *distance* instead,
/// which is what makes the sweep read as a pen moving at a constant speed.
library;

import 'dart:ui';

/// A polyline with its cumulative arc lengths precomputed.
class Polyline {
  Polyline(this.points)
      : _cumulative = _measure(points),
        assert(points.length >= 2, 'a stroke median needs at least two points');

  final List<Offset> points;
  final List<double> _cumulative;

  static List<double> _measure(List<Offset> pts) {
    final out = <double>[0];
    var total = 0.0;
    for (var i = 0; i + 1 < pts.length; i++) {
      total += (pts[i + 1] - pts[i]).distance;
      out.add(total);
    }
    return out;
  }

  /// Total length along the polyline.
  double get length => _cumulative.last;

  /// Where the stroke starts — the pen-down point.
  Offset get start => points.first;

  /// Where the stroke ends — the pen-up point.
  Offset get end => points.last;

  /// The point [t] of the way along, `t` in 0..1 by arc length.
  Offset pointAt(double t) {
    final target = t.clamp(0.0, 1.0) * length;
    final i = _segmentAt(target);
    return _lerpInSegment(i, target);
  }

  /// Direction of travel [t] of the way along, as an angle in radians.
  ///
  /// Uses the segment the point falls in, so it tracks the stroke around
  /// corners rather than reporting one average heading.
  double headingAt(double t) {
    final target = t.clamp(0.0, 1.0) * length;
    final i = _segmentAt(target);
    final delta = points[i + 1] - points[i];
    return delta.direction;
  }

  /// The polyline truncated at [t] — the part of the stroke drawn so far.
  ///
  /// Always at least two points, so the result is safe to stroke as a path.
  List<Offset> upTo(double t) {
    final target = t.clamp(0.0, 1.0) * length;
    final i = _segmentAt(target);
    return [
      ...points.take(i + 1),
      _lerpInSegment(i, target),
    ];
  }

  /// Index of the segment containing [distance] along the polyline.
  int _segmentAt(double distance) {
    for (var i = 0; i + 1 < _cumulative.length; i++) {
      if (distance <= _cumulative[i + 1]) return i;
    }
    return points.length - 2;
  }

  Offset _lerpInSegment(int i, double distance) {
    final span = _cumulative[i + 1] - _cumulative[i];
    if (span <= 0) return points[i];
    final f = ((distance - _cumulative[i]) / span).clamp(0.0, 1.0);
    return Offset.lerp(points[i], points[i + 1], f)!;
  }
}
