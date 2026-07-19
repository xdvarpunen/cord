import 'package:flutter/material.dart';

import '../engine/scene.dart';
import 'writing_scene.dart' show PaperLayer;

enum _ShapeType { horizontal, vertical, diagonal }

class _Stroke {
  _Stroke(this.points);
  final List<Offset> points;
  Offset get start => points.first;
  Offset get end => points.last;
  Offset get center => Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
}

double _aspectRatio(_Stroke s) {
  final w = (s.end.dx - s.start.dx).abs();
  final h = (s.end.dy - s.start.dy).abs();
  if (w == 0 || h == 0) return 0;
  return w < h ? w / h : h / w;
}

// Below 0.5 the stroke leans clearly toward one axis; at/above it, neither
// axis dominates, so it reads as a diagonal.
bool _isHorizontal(_Stroke s) =>
    (s.end.dx - s.start.dx).abs() > (s.end.dy - s.start.dy).abs() &&
    _aspectRatio(s) < 0.5;
bool _isVertical(_Stroke s) =>
    (s.end.dy - s.start.dy).abs() > (s.end.dx - s.start.dx).abs() &&
    _aspectRatio(s) < 0.5;
bool _isDiagonal(_Stroke s) => _aspectRatio(s) >= 0.5;

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

/// True if [center] falls within the bounding box of [others] — i.e. it
/// sits in the middle of them, not off to one side.
bool _isMiddleOf(Offset center, List<Offset> others) {
  final minX = others.map((o) => o.dx).reduce((a, b) => a < b ? a : b);
  final maxX = others.map((o) => o.dx).reduce((a, b) => a > b ? a : b);
  final minY = others.map((o) => o.dy).reduce((a, b) => a < b ? a : b);
  final maxY = others.map((o) => o.dy).reduce((a, b) => a > b ? a : b);
  return center.dx >= minX && center.dx <= maxX && center.dy >= minY && center.dy <= maxY;
}

/// Card-game tally marks, same freehand style as [TallyLayer]. Each of the 5
/// strokes has its own shape + position + crossing rule, checked against
/// already-accepted strokes in the current bundle:
///
/// 1. vertical — no constraint (first stroke).
/// 2. horizontal — above stroke 1's center; intersects stroke 1.
/// 3. vertical — right of stroke 2's center; intersects stroke 2.
/// 4. horizontal — below every center so far; intersects stroke 3.
/// 5. diagonal — its center sits in the middle of the other 4 centers'
///    bounding box; intersects at least 2 of the 4 lines (any of them).
final _strokeSpecs = <(_ShapeType, bool Function(List<_Stroke> accepted, _Stroke candidate))>[
  (_ShapeType.vertical, (accepted, s) => true),
  (
    _ShapeType.horizontal,
    (accepted, s) => s.center.dy < accepted[0].center.dy && _intersects(s, accepted[0]),
  ),
  (
    _ShapeType.vertical,
    (accepted, s) => s.center.dx > accepted[1].center.dx && _intersects(s, accepted[1]),
  ),
  (
    _ShapeType.horizontal,
    (accepted, s) =>
        accepted.every((a) => s.center.dy > a.center.dy) && _intersects(s, accepted[2]),
  ),
  (
    _ShapeType.diagonal,
    (accepted, s) =>
        _isMiddleOf(s.center, accepted.map((a) => a.center).toList()) &&
        accepted.where((a) => _intersects(s, a)).length >= 2,
  ),
];

class CardTallyLayer extends Layer {
  static const double _minDragDistance = 8;

  final List<_Stroke> _strokes = []; // accepted strokes, current bundle
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
    final matchesType = switch (type) {
      _ShapeType.horizontal => _isHorizontal(stroke),
      _ShapeType.vertical => _isVertical(stroke),
      _ShapeType.diagonal => _isDiagonal(stroke),
    };
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
        text: 'Count: $count  (draw each stroke matching its shape, '
            'position, and crossing rule)',
        style: const TextStyle(color: Colors.black54, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

Scene buildCardTallyScene() => Scene([PaperLayer(), CardTallyLayer()]);
