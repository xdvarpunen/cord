import 'package:flutter/material.dart';

import '../engine/scene.dart';
import 'writing_scene.dart' show PaperLayer;

enum _ShapeType { horizontal, vertical }

class _Stroke {
  _Stroke(this.points);
  final List<Offset> points;
  Offset get start => points.first;
  Offset get end => points.last;
  Offset get center => Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
}

bool _isHorizontal(_Stroke s) =>
    (s.end.dx - s.start.dx).abs() > (s.end.dy - s.start.dy).abs();
bool _isVertical(_Stroke s) =>
    (s.end.dx - s.start.dx).abs() < (s.end.dy - s.start.dy).abs();

// Same orientation-based segment intersection test as TallyLayer.
double _direction(Offset a, Offset b, Offset c) =>
    (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);

bool _onSegment(Offset a, Offset b, Offset c) =>
    (c.dx >= a.dx && c.dx <= b.dx || c.dx >= b.dx && c.dx <= a.dx) &&
    (c.dy >= a.dy && c.dy <= b.dy || c.dy >= b.dy && c.dy <= a.dy);

bool _intersects(_Stroke a, _Stroke b) {
  final d1 = _direction(b.start, b.end, a.start);
  final d2 = _direction(b.start, b.end, a.end);
  final d3 = _direction(a.start, a.end, b.start);
  final d4 = _direction(a.start, a.end, b.end);

  if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
    return true;
  }
  if (d1 == 0 && _onSegment(b.start, b.end, a.start)) return true;
  if (d2 == 0 && _onSegment(b.start, b.end, a.end)) return true;
  if (d3 == 0 && _onSegment(a.start, a.end, b.start)) return true;
  if (d4 == 0 && _onSegment(a.start, a.end, b.end)) return true;
  return false;
}

/// The 5 strokes of the Hindu-Arabic numeral "5", seven-segment style: top
/// bar, upper-left vertical, middle bar, lower-right vertical, bottom bar.
/// Completing all 5 finishes a "5" — worth five, matching the other tally
/// systems in this app.
///
/// 1. horizontal — no constraint (first stroke).
/// 2. vertical — left of stroke 1's center; intersects stroke 1.
/// 3. horizontal — below stroke 2's center; intersects stroke 2.
/// 4. vertical — right of and below stroke 3's center; intersects stroke 3.
/// 5. horizontal — below stroke 4's center; intersects stroke 4.
final _strokeSpecs = <(_ShapeType, bool Function(List<_Stroke> accepted, _Stroke candidate))>[
  (_ShapeType.horizontal, (accepted, s) => true),
  (
    _ShapeType.vertical,
    (accepted, s) => s.center.dx < accepted[0].center.dx && _intersects(s, accepted[0]),
  ),
  (
    _ShapeType.horizontal,
    (accepted, s) => s.center.dy > accepted[1].center.dy && _intersects(s, accepted[1]),
  ),
  (
    _ShapeType.vertical,
    (accepted, s) =>
        s.center.dx > accepted[2].center.dx &&
        s.center.dy > accepted[2].center.dy &&
        _intersects(s, accepted[2]),
  ),
  (
    _ShapeType.horizontal,
    (accepted, s) => s.center.dy > accepted[3].center.dy && _intersects(s, accepted[3]),
  ),
];

/// Freehand Hindu-Arabic "5" tally, same style as [TallyLayer]: strokes are
/// rendered as actually drawn. Each stroke must match the next entry in
/// [_strokeSpecs] (shape + relative position) or it's discarded. Completing
/// all 5 strokes finishes a "5" (+5) and starts a fresh one.
class HinduArabicFiveLayer extends Layer {
  static const double _minDragDistance = 8;

  final List<_Stroke> _strokes = []; // accepted strokes, current numeral
  int _completedGroups = 0;
  List<Offset>? _activePoints;

  @override
  void handlePointerEvent(PointerEvent event, Size size) {
    if (event is PointerDownEvent) {
      _activePoints = [event.localPosition];
    } else if (event is PointerMoveEvent && _activePoints != null) {
      _activePoints!.add(event.localPosition);
    } else if (event is PointerUpEvent && _activePoints != null) {
      final points = _activePoints!..add(event.localPosition);
      if (points.length >= 2 &&
          (points.last - points.first).distance >= _minDragDistance) {
        _commit(_Stroke(points));
      }
      _activePoints = null;
    }
  }

  void _commit(_Stroke stroke) {
    final (type, checkPosition) = _strokeSpecs[_strokes.length];
    final matchesType =
        type == _ShapeType.horizontal ? _isHorizontal(stroke) : _isVertical(stroke);
    if (!matchesType || !checkPosition(_strokes, stroke)) return;

    _strokes.add(stroke);
    if (_strokes.length == _strokeSpecs.length) {
      _completedGroups++;
      _strokes.clear();
    }
  }

  void _drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1B2A4A)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (final stroke in _strokes) {
      _drawPath(canvas, stroke.points, paint);
    }
    if (_activePoints != null) {
      final previewPaint = Paint()
        ..color = paint.color.withValues(alpha: 0.5)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      _drawPath(canvas, _activePoints!, previewPaint);
    }

    final count = _completedGroups * 5 + _strokes.length;
    final label = TextPainter(
      text: TextSpan(
        text: 'Count: $count  (draw "5": top bar, upper-left vertical, '
            'middle bar, lower-right vertical, bottom bar)',
        style: const TextStyle(color: Colors.black54, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

Scene buildHinduArabicFiveScene() => Scene([PaperLayer(), HinduArabicFiveLayer()]);
