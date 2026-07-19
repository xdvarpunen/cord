import 'package:flutter/material.dart';

import '../engine/scene.dart';
import 'writing_scene.dart' show PaperLayer;

enum _Role { topLeft, topRight, bottomLeft, bottomRight }

/// Dot-dash tally marks: a bundle of ten built in three strict stages.
///
/// 1. Four dots — a stroke under 5px counts as a dot; a longer stroke is
///    discarded until 4 dots exist. The 4 dots are classified into the
///    corners of a square (top-left/top-right/bottom-left/bottom-right)
///    relative to their centroid.
/// 2. Four side lines — each must visit exactly 2 *adjacent* corner dots'
///    circles, in any order (top-left+top-right, top-right+bottom-right,
///    bottom-right+bottom-left, bottom-left+top-left); anything else is
///    discarded.
/// 3. Two diagonal lines — each must visit exactly 2 *opposite* corner dots
///    (top-left+bottom-right, top-right+bottom-left); anything else is
///    discarded.
///
/// "Visits" means some point along the drawn stroke falls within a dot's
/// circle — the stroke doesn't need to start/end exactly on the dot.
///
/// Once all ten marks land, a new bundle starts fresh on the next dot.
class DotDashLayer extends Layer {
  static const double _dotThreshold = 5;
  static const double _dotRadius = 15;

  static final _sideKeys = {
    _key(_Role.topLeft, _Role.topRight),
    _key(_Role.topRight, _Role.bottomRight),
    _key(_Role.bottomRight, _Role.bottomLeft),
    _key(_Role.bottomLeft, _Role.topLeft),
  };
  static final _diagonalKeys = {
    _key(_Role.topLeft, _Role.bottomRight),
    _key(_Role.topRight, _Role.bottomLeft),
  };

  final List<Offset> _dots = [];
  Map<_Role, Offset> _roles = {};
  final Set<String> _connectionsDone = {};
  final List<List<Offset>> _lines = [];
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
      _commit(points, (points.last - points.first).distance);
      _activePoints = null;
    }
  }

  void _commit(List<Offset> points, double dragDistance) {
    final isDot = dragDistance < _dotThreshold;

    if (_dots.length < 4) {
      if (isDot) {
        _dots.add(points.first);
        if (_dots.length == 4) _roles = _classifyDots(_dots);
      }
      return; // a line drawn before 4 dots exist is discarded
    }
    if (isDot) return; // dots are no longer accepted once dots are complete

    final visited = _visitedRoles(points);
    if (visited.length != 2) return;
    final key = _key(visited.first, visited.last);

    final needSides = _connectionsDone.length < 4;
    final validKey =
        needSides ? _sideKeys.contains(key) : _diagonalKeys.contains(key);
    if (!validKey || _connectionsDone.contains(key)) return;

    _connectionsDone.add(key);
    _lines.add(points);

    if (_connectionsDone.length == 6) {
      _completedGroups++;
      _dots.clear();
      _roles = {};
      _connectionsDone.clear();
      _lines.clear();
    }
  }

  Map<_Role, Offset> _classifyDots(List<Offset> dots) {
    final cx = dots.map((d) => d.dx).reduce((a, b) => a + b) / dots.length;
    final cy = dots.map((d) => d.dy).reduce((a, b) => a + b) / dots.length;
    final roles = <_Role, Offset>{};
    for (final dot in dots) {
      final role = dot.dy < cy
          ? (dot.dx < cx ? _Role.topLeft : _Role.topRight)
          : (dot.dx < cx ? _Role.bottomLeft : _Role.bottomRight);
      roles[role] = dot;
    }
    return roles;
  }

  /// Every role whose dot circle is touched by some point along [points].
  List<_Role> _visitedRoles(List<Offset> points) {
    final visited = <_Role>{};
    for (final p in points) {
      for (final entry in _roles.entries) {
        if ((entry.value - p).distance <= _dotRadius) visited.add(entry.key);
      }
    }
    return visited.toList();
  }

  static String _key(_Role a, _Role b) {
    final names = [a.name, b.name]..sort();
    return names.join('-');
  }

  void _drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF1B2A4A)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = Colors.black;

    for (final dot in _dots) {
      canvas.drawCircle(dot, _dotRadius, dotPaint);
    }
    for (final line in _lines) {
      _drawPath(canvas, line, linePaint);
    }
    if (_activePoints != null) {
      final previewPaint = Paint()
        ..color = linePaint.color.withValues(alpha: 0.5)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      _drawPath(canvas, _activePoints!, previewPaint);
    }

    final count = _completedGroups * 10 + _dots.length + _connectionsDone.length;
    final label = TextPainter(
      text: TextSpan(
        text: 'Count: $count  (click 4 dots, then 4 side lines, then '
            '2 diagonals)',
        style: const TextStyle(color: Colors.black54, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

Scene buildDotDashScene() => Scene([PaperLayer(), DotDashLayer()]);
