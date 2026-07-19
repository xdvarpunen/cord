import 'package:flutter/material.dart';

import '../engine/scene.dart';

/// Cream, dot-grid paper background (Moleskine-style notebook page). Copied
/// per-feature — the Etruscan feature shares no code with the other scripts.
class PaperLayer extends Layer {
  static const _paperColor = Color(0xFFF3ECDC);
  static const _dotColor = Color(0x33000000);
  static const _spacing = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _paperColor);
    final dotPaint = Paint()..color = _dotColor;
    for (double y = _spacing; y < size.height; y += _spacing) {
      for (double x = _spacing; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }
}

/// Freehand Etruscan numeral recognition, ported from the `shorthand`
/// project's `EtruscanNumeralsLinesInterpreter` (git history) and
/// self-contained under `lib/etruscan/`.
///
/// Strokes are grouped by overlapping horizontal (x) range — one group per
/// numeral drawn side by side — and each group is classified:
///
/// - **1** — a single vertical stroke,
/// - **5** — two strokes forming a peak (∧: up then down) that do not cross,
/// - **10** — two crossing strokes (✕),
/// - **50** — a peak on top of a tall vertical stroke,
/// - **100** — a cross with a vertical stroke through its centre.
///
/// Groups are read left to right; the recognized numerals (and their additive
/// total) update live as you draw.
class EtruscanLayer extends Layer {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _activePoints;
  List<String> _numerals = [];

  static const _values = {'1': 1, '5': 5, '10': 10, '50': 50, '100': 100};

  /// The recognized numerals, in left-to-right order (`?` for an
  /// unrecognized group) — read by tests; the on-canvas readout gets the same
  /// information via [paint].
  List<String> get numerals => _numerals;

  /// The additive total of the recognized numerals (Etruscan numerals are
  /// additive), ignoring unrecognized groups.
  int get total =>
      _numerals.fold(0, (sum, n) => sum + (_values[n] ?? 0));

  void clear() {
    _strokes.clear();
    _activePoints = null;
    _numerals = [];
  }

  @override
  void handlePointerEvent(PointerEvent event, Size size) {
    if (event is PointerDownEvent) {
      _activePoints = [event.localPosition];
    } else if (event is PointerMoveEvent && _activePoints != null) {
      _activePoints!.add(event.localPosition);
    } else if (event is PointerUpEvent && _activePoints != null) {
      _strokes.add(_activePoints!);
      _activePoints = null;
      _recompute();
    }
  }

  void _recompute() {
    final groups = _groupByIntersectingXRange(_strokes)
      // Read left to right — the shorthand version left this as a TODO.
      ..sort((a, b) => _minX(a).compareTo(_minX(b)));
    _numerals = groups.map(_detect).toList(growable: false);
  }

  // --- Classification (ported from EtruscanNumeralsLinesInterpreter) --------

  String _detect(List<List<Offset>> g) {
    if (_isOne(g)) return '1';
    if (_isTen(g)) return '10';
    if (_isFive(g)) return '5';
    if (_isHundred(g)) return '100';
    if (_isFifty(g)) return '50';
    return '?';
  }

  bool _isOne(List<List<Offset>> g) => g.length == 1 && _vertical(g.first);

  bool _isFive(List<List<Offset>> g) =>
      g.length == 2 && _ascending(g.first) && _descending(g.last);

  bool _isTen(List<List<Offset>> g) {
    if (g.length != 2) return false;
    final ascending = g.where(_ascending).toList();
    final descending = g.where(_descending).toList();
    if (ascending.length != 1 || descending.length != 1) return false;
    return _linesIntersect(ascending.first, descending.first);
  }

  bool _isFifty(List<List<Offset>> g) {
    if (g.length != 3) return false;
    final vertical = _findTallVertical(g);
    if (vertical == null) return false;
    final centerY = _centerY(vertical);
    final others =
        g.where((l) => !identical(l, vertical)).toList(growable: false);
    if (others.length != 2) return false;
    // Both other strokes must sit above the vertical's centre (smaller y).
    for (final line in others) {
      if (line.first.dy > centerY || line.last.dy > centerY) return false;
    }
    final ascending = others.where(_ascending).length == 1;
    final descending = others.where(_descending).length == 1;
    return ascending && descending;
  }

  bool _isHundred(List<List<Offset>> g) {
    if (g.length != 3) return false;
    bool between(double v, double a, double b) =>
        (v > a && v < b) || (v > b && v < a);
    for (final middle in g) {
      final others =
          g.where((l) => !identical(l, middle)).toList(growable: false);
      if (others.length != 2) continue;
      final midTopX = middle.first.dx;
      final midBottomX = middle.last.dx;
      final o1 = others[0];
      final o2 = others[1];
      if (!between(midTopX, o1.first.dx, o2.first.dx)) continue;
      if (!between(midBottomX, o1.last.dx, o2.last.dx)) continue;
      if (!_linesIntersect(middle, o1)) continue;
      if (!_linesIntersect(middle, o2)) continue;
      if (!_linesIntersect(o1, o2)) continue;
      return true;
    }
    return false;
  }

  List<Offset>? _findTallVertical(List<List<Offset>> g) {
    final verticals = g.where(_vertical).toList();
    if (verticals.isEmpty) return null;
    verticals.sort((a, b) => _ySpan(b).compareTo(_ySpan(a)));
    return verticals.first;
  }

  // --- Geometry helpers (first→last chord, same as the shorthand toolbox) ---

  bool _vertical(List<Offset> p) {
    if (p.length < 2) return false;
    final dx = (p.last.dx - p.first.dx).abs();
    final dy = (p.last.dy - p.first.dy).abs();
    return dx < dy;
  }

  bool _ascending(List<Offset> p) => p.length >= 2 && p.first.dy > p.last.dy;
  bool _descending(List<Offset> p) => p.length >= 2 && p.first.dy < p.last.dy;

  double _ySpan(List<Offset> line) {
    var mn = line.first.dy, mx = line.first.dy;
    for (final p in line) {
      if (p.dy < mn) mn = p.dy;
      if (p.dy > mx) mx = p.dy;
    }
    return mx - mn;
  }

  double _centerY(List<Offset> line) {
    var mn = line.first.dy, mx = line.first.dy;
    for (final p in line) {
      if (p.dy < mn) mn = p.dy;
      if (p.dy > mx) mx = p.dy;
    }
    return (mn + mx) / 2;
  }

  double _minX(List<List<Offset>> group) {
    var mn = group.first.first.dx;
    for (final line in group) {
      for (final p in line) {
        if (p.dx < mn) mn = p.dx;
      }
    }
    return mn;
  }

  static bool _linesIntersect(List<Offset> line1, List<Offset> line2) {
    if (line1.length < 2 || line2.length < 2) return false;
    final p1 = line1.first;
    final p2 = line1.last;
    final p3 = line2.first;
    final p4 = line2.last;

    double dir(Offset a, Offset b, Offset c) =>
        (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
    bool onSeg(Offset a, Offset b, Offset c) =>
        (c.dx >= a.dx && c.dx <= b.dx || c.dx >= b.dx && c.dx <= a.dx) &&
        (c.dy >= a.dy && c.dy <= b.dy || c.dy >= b.dy && c.dy <= a.dy);

    final d1 = dir(p3, p4, p1);
    final d2 = dir(p3, p4, p2);
    final d3 = dir(p1, p2, p3);
    final d4 = dir(p1, p2, p4);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    if (d1 == 0 && onSeg(p3, p4, p1)) return true;
    if (d2 == 0 && onSeg(p3, p4, p2)) return true;
    if (d3 == 0 && onSeg(p1, p2, p3)) return true;
    if (d4 == 0 && onSeg(p1, p2, p4)) return true;
    return false;
  }

  /// Groups strokes whose x-ranges overlap (transitively) — one numeral per
  /// group when they're drawn side by side.
  static List<List<List<Offset>>> _groupByIntersectingXRange(
    List<List<Offset>> strokes,
  ) {
    if (strokes.isEmpty) return [];
    final groups = <List<List<Offset>>>[];
    final visited = <List<Offset>>{};

    for (final stroke in strokes) {
      if (visited.contains(stroke)) continue;
      final group = <List<Offset>>[stroke];
      visited.add(stroke);
      bool changed;
      do {
        changed = false;
        for (final other in strokes) {
          if (visited.contains(other)) continue;
          if (group.any((g) => _intersectsByXRange(g, other))) {
            group.add(other);
            visited.add(other);
            changed = true;
          }
        }
      } while (changed);
      groups.add(group);
    }
    return groups;
  }

  static bool _intersectsByXRange(List<Offset> a, List<Offset> b) {
    var aMin = a.first.dx, aMax = a.first.dx;
    for (final p in a) {
      if (p.dx < aMin) aMin = p.dx;
      if (p.dx > aMax) aMax = p.dx;
    }
    var bMin = b.first.dx, bMax = b.first.dx;
    for (final p in b) {
      if (p.dx < bMin) bMin = p.dx;
      if (p.dx > bMax) bMax = p.dx;
    }
    return aMax >= bMin && aMin <= bMax;
  }

  // --- Painting -------------------------------------------------------------

  void _drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length == 1) {
      canvas.drawCircle(points.first, paint.strokeWidth / 2, paint);
      return;
    }
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0xFF1B2A4A)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final stroke in _strokes) {
      _drawPath(canvas, stroke, strokePaint);
    }
    final active = _activePoints;
    if (active != null) {
      _drawPath(
        canvas,
        active,
        Paint()
          ..color = strokePaint.color.withValues(alpha: 0.5)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    final label = TextPainter(
      text: _numerals.isEmpty
          ? const TextSpan(
              text: 'Draw a numeral: │ = 1, ∧ = 5, ✕ = 10',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            )
          : TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              children: [
                const TextSpan(text: 'Recognized: '),
                TextSpan(
                  text: _numerals.join('  '),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_numerals.any((n) => n != '?'))
                  TextSpan(text: '   (total $total)'),
              ],
            ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

/// Builds the scene plus a direct reference to its [EtruscanLayer], so the
/// hosting page can call [EtruscanLayer.clear] from the Clear button.
(Scene, EtruscanLayer) buildEtruscanScene() {
  final layer = EtruscanLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
