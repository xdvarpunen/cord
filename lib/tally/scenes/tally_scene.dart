import 'package:flutter/material.dart';

import '../engine/scene.dart';
import 'writing_scene.dart' show PaperLayer;

/// A completed pointer drag: the full drawn path (for rendering) plus its
/// start/end points (for shape classification, same as the shorthand
/// project's line utilities, which only look at a line's endpoints).
class _Stroke {
  _Stroke(this.points);
  final List<Offset> points;
  Offset get start => points.first;
  Offset get end => points.last;
}

/// Freehand tally marks, built on the shape/intersection tests from the
/// shorthand project's `TallyMarksOneProcessorService`: a stroke is
/// "vertical" if drawn taller than wide, and crossing four vertical strokes
/// is what completes a bundle of five.
///
/// Enforced strictly: once 4 vertical strokes are pending, the next stroke
/// must cross all 4 or it's discarded — same rule every 5th stroke.
class TallyLayer extends Layer {
  static const double _minDragDistance = 8;

  final List<_Stroke> _strokes = []; // accepted strokes, for rendering
  final List<_Stroke> _pendingVerticals = []; // current bundle's verticals
  int _completedGroups = 0;
  List<Offset>? _activePoints;

  @override
  void handlePointerEvent(PointerEvent event, Size size) {
    if (event is PointerDownEvent) {
      _activePoints = [event.localPosition];
    } else if (event is PointerMoveEvent && _activePoints != null) {
      _activePoints!.add(event.localPosition);
    } else if (event is PointerUpEvent && _activePoints != null) {
      final points = _activePoints!;
      if (points.length >= 2 &&
          (points.last - points.first).distance >= _minDragDistance) {
        _commit(_Stroke(points));
      }
      _activePoints = null;
    }
  }

  void _commit(_Stroke stroke) {
    if (_pendingVerticals.length < 4) {
      // The first 4 strokes must each be vertical; anything else is
      // discarded rather than drawn.
      if (!_isVertical(stroke)) return;
      _strokes.add(stroke);
      _pendingVerticals.add(stroke);
      return;
    }
    // Bundle is full: this stroke must cross all 4 pending verticals,
    // otherwise it's discarded rather than added.
    final crossesAll =
        _pendingVerticals.every((v) => _segmentsIntersect(stroke, v));
    if (crossesAll) {
      _completedGroups++;
      _pendingVerticals.clear();
      // Clear the drawn bundle on the closing 5th stroke, same as the East
      // Asian 正 scene — the count ticks up and the canvas resets for the
      // next bundle rather than accumulating marks forever.
      _strokes.clear();
    }
  }

  bool _isVertical(_Stroke s) =>
      (s.end.dx - s.start.dx).abs() < (s.end.dy - s.start.dy).abs();

  // Signed area of triangle (a, b, c); sign gives which side c is on.
  double _direction(Offset a, Offset b, Offset c) =>
      (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);

  bool _onSegment(Offset a, Offset b, Offset c) =>
      (c.dx >= a.dx && c.dx <= b.dx || c.dx >= b.dx && c.dx <= a.dx) &&
      (c.dy >= a.dy && c.dy <= b.dy || c.dy >= b.dy && c.dy <= a.dy);

  bool _segmentsIntersect(_Stroke a, _Stroke b) {
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

  int get _count => _completedGroups * 5 + _pendingVerticals.length;

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

    final label = TextPainter(
      text: TextSpan(
        text: 'Count: $_count  (draw 4 vertical lines, then one crossing '
            'all 4 — anything else is rejected)',
        style: const TextStyle(color: Colors.black54, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

Scene buildTallyScene() => Scene([PaperLayer(), TallyLayer()]);
