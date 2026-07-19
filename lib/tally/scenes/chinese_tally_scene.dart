import 'package:flutter/material.dart';

import '../engine/scene.dart';
import 'writing_scene.dart' show PaperLayer;

enum _StrokeType { horizontal, vertical }

class _Stroke {
  _Stroke(this.points);
  final List<Offset> points;
  Offset get start => points.first;
  Offset get end => points.last;
  Offset get center => Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
}

bool _below(_Stroke earlier, _Stroke later) => later.center.dy > earlier.center.dy;

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

/// The 5 strokes of 正 (zhèng), in order — the East Asian tally system (one
/// stroke per count, a full character = five). Each entry is the stroke's
/// shape plus a check against already-accepted strokes ([accepted], in
/// stroke order) that the candidate ([candidate]) must satisfy:
///
/// 1. horizontal — no constraint (first stroke).
/// 2. vertical — below stroke 1; intersects stroke 1.
/// 3. horizontal — right of stroke 2, below stroke 1; intersects stroke 2.
/// 4. vertical — left of stroke 2, below every stroke so far; intersects
///    none of the first 3 strokes.
/// 5. horizontal — below every stroke so far; intersects both stroke 2 and
///    stroke 4.
final _strokeSpecs = <(_StrokeType, bool Function(List<_Stroke> accepted, _Stroke candidate))>[
  (_StrokeType.horizontal, (accepted, s) => true),
  (
    _StrokeType.vertical,
    (accepted, s) => _below(accepted[0], s) && _intersects(s, accepted[0]),
  ),
  (
    _StrokeType.horizontal,
    (accepted, s) =>
        s.center.dx > accepted[1].center.dx &&
        _below(accepted[0], s) &&
        _intersects(s, accepted[1]),
  ),
  (
    _StrokeType.vertical,
    (accepted, s) =>
        s.center.dx < accepted[1].center.dx &&
        accepted.every((a) => _below(a, s)) &&
        accepted.every((a) => !_intersects(s, a)),
  ),
  (
    _StrokeType.horizontal,
    (accepted, s) =>
        accepted.every((a) => _below(a, s)) &&
        _intersects(s, accepted[1]) &&
        _intersects(s, accepted[3]),
  ),
];

/// Freehand 正-tally, same style as [TallyLayer]: strokes are rendered as
/// actually drawn. Each stroke must match the next entry in [_strokeSpecs]
/// (shape + relative position + crossing rule) or it's discarded.
/// Completing all 5 strokes finishes a character (+5) and starts a fresh one.
class ChineseTallyLayer extends Layer {
  static const double _minDragDistance = 8;

  final List<_Stroke> _strokes = []; // accepted strokes, current character
  int _completedCharacters = 0;
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

  bool _isHorizontal(_Stroke s) =>
      (s.end.dx - s.start.dx).abs() > (s.end.dy - s.start.dy).abs();

  bool _isVertical(_Stroke s) =>
      (s.end.dx - s.start.dx).abs() < (s.end.dy - s.start.dy).abs();

  void _commit(_Stroke stroke) {
    final (type, checkPosition) = _strokeSpecs[_strokes.length];
    final matchesType =
        type == _StrokeType.horizontal ? _isHorizontal(stroke) : _isVertical(stroke);
    if (!matchesType || !checkPosition(_strokes, stroke)) return;

    _strokes.add(stroke);
    if (_strokes.length == _strokeSpecs.length) {
      _completedCharacters++;
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

    final count = _completedCharacters * 5 + _strokes.length;
    final label = TextPainter(
      text: TextSpan(
        text: 'Count: $count  (draw 正 — each stroke must match the next '
            'shape, position, and crossing rule)',
        style: const TextStyle(color: Colors.black54, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

Scene buildChineseTallyScene() => Scene([PaperLayer(), ChineseTallyLayer()]);
