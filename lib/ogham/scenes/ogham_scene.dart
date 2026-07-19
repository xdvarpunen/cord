import 'package:flutter/material.dart';

import '../engine/scene.dart';

/// Cream, dot-grid paper background (Moleskine-style notebook page). Copied
/// per-feature — the Ogham feature shares no code with the other scripts.
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

/// The result of recognizing the strokes currently on the canvas: the
/// letter's traditional name, its Latin transliteration (empty for the
/// space / feather marks), and its Ogham glyph (kept for reference — the
/// on-canvas readout renders text, not the glyph, since Flutter web has no
/// fallback font for the Ogham block).
@immutable
class OghamResult {
  const OghamResult(this.name, this.translit, this.char);

  final String name;
  final String translit;
  final String char;
}

/// Freehand recognition of Ogham letters, ported from the `shorthand`
/// project's `OghamProcessor` (git history) and self-contained under
/// `lib/ogham/` — it shares no engine/scene/data with the other script
/// features.
///
/// Letters are drawn relative to a central horizontal **stemline** with a
/// thin band around it (the *druim*). Every completed stroke is added to a
/// set, and the whole set is re-classified as a single letter, keyed on how
/// many strokes there are and where they sit:
///
/// - crossing the **upper** edge only → *hÚatha* consonants H D T C Q (1–5),
/// - crossing the **lower** edge only → *Beithe* consonants B L F S N (1–5),
/// - crossing **both** edges → *Muine* consonants M G NG Z R (1–5),
/// - sitting **on** the stem (notches / taps within the band) → vowels
///   A O U E I (1–5),
///
/// plus the irregular *forfeda* (Ea, Oi, Ui, P) and the feather / space
/// marks. Tap the stem for single-notch vowels; drag across it for
/// consonant strokes.
class OghamLayer extends Layer {
  /// Height of the band around the stemline (the gap between the upper and
  /// lower edges). Vowel notches must fall inside it; consonant strokes are
  /// classified by which edge(s) their chord crosses.
  static const double _thickness = 64;
  static const double _edgeWidth = 100000;

  final List<List<Offset>> _strokes = [];
  List<Offset>? _activePoints;
  OghamResult? _recognized;

  /// The most recently recognized result, or null if the strokes on the
  /// canvas didn't match anything — read by tests; the on-canvas readout
  /// gets the same information via [paint].
  OghamResult? get recognized => _recognized;

  void clear() {
    _strokes.clear();
    _activePoints = null;
    _recognized = null;
  }

  @override
  void handlePointerEvent(PointerEvent event, Size size) {
    if (event is PointerDownEvent) {
      _activePoints = [event.localPosition];
    } else if (event is PointerMoveEvent && _activePoints != null) {
      _activePoints!.add(event.localPosition);
    } else if (event is PointerUpEvent && _activePoints != null) {
      // Every stroke counts, including a single-point tap: an Ogham vowel is
      // a notch on the stem, so taps are meaningful (unlike the other
      // features, which drop taps as accidental).
      _strokes.add(_activePoints!);
      _activePoints = null;
      _recognized = _classify(size.height / 2, _thickness);
    }
  }

  // --- Classification (ported from OghamProcessor.process) ------------------

  OghamResult? _classify(double loc, double thick) {
    final lines = _strokes;
    if (lines.isEmpty) return null;

    if (lines.length == 1) {
      if (_isUi(lines, loc, thick)) return const OghamResult('uilleann', 'ui', 'ᚗ');
      if (_isSpace(lines, loc, thick)) return const OghamResult('word space', '', ' ');
      if (_isOi(lines, loc, thick)) return const OghamResult('ór', 'oi', 'ᚖ');
      if (_isStart(lines, loc, thick)) {
        return const OghamResult('feather mark (start)', '', '᚛');
      }
      if (_isEnd(lines, loc, thick)) {
        return const OghamResult('feather mark (end)', '', '᚜');
      }
      if (_isM(lines, loc, thick)) return const OghamResult('muin', 'm', 'ᚋ');
      if (_isA(lines, loc, thick)) return const OghamResult('ailm', 'a', 'ᚐ');
      if (_isH(lines, loc, thick)) return const OghamResult('úath', 'h', 'ᚆ');
      if (_isB(lines, loc, thick)) return const OghamResult('beith', 'b', 'ᚁ');
      if (_isP(lines, loc, thick)) return const OghamResult('peith', 'p', 'ᚚ');
    } else if (lines.length == 2) {
      if (_isEa(lines, loc, thick)) return const OghamResult('éabhadh', 'ea', 'ᚕ');
      if (_isG(lines, loc, thick)) return const OghamResult('gort', 'g', 'ᚌ');
      if (_isD(lines, loc, thick)) return const OghamResult('dair', 'd', 'ᚇ');
      if (_isL(lines, loc, thick)) return const OghamResult('luis', 'l', 'ᚂ');
      if (_isO(lines, loc, thick)) return const OghamResult('onn', 'o', 'ᚑ');
    } else if (lines.length == 3) {
      if (_isNG(lines, loc, thick)) return const OghamResult('nGéadal', 'ng', 'ᚍ');
      if (_isT(lines, loc, thick)) return const OghamResult('tinne', 't', 'ᚈ');
      if (_isF(lines, loc, thick)) return const OghamResult('fearn', 'f', 'ᚃ');
      if (_isU(lines, loc, thick)) return const OghamResult('úr', 'u', 'ᚒ');
    } else if (lines.length == 4) {
      if (_isST(lines, loc, thick)) return const OghamResult('straif', 'z', 'ᚎ');
      if (_isC(lines, loc, thick)) return const OghamResult('coll', 'c', 'ᚉ');
      if (_isS(lines, loc, thick)) return const OghamResult('sail', 's', 'ᚄ');
      if (_isE(lines, loc, thick)) return const OghamResult('eadhadh', 'e', 'ᚓ');
    } else if (lines.length == 5) {
      if (_isR(lines, loc, thick)) return const OghamResult('ruis', 'r', 'ᚏ');
      if (_isQ(lines, loc, thick)) return const OghamResult('ceirt', 'q', 'ᚊ');
      if (_isN(lines, loc, thick)) return const OghamResult('nion', 'n', 'ᚅ');
      if (_isI(lines, loc, thick)) return const OghamResult('iodhadh', 'i', 'ᚔ');
    } else if (lines.length == 7) {
      if (_isAe(lines, loc, thick)) {
        return const OghamResult('eamhancholl', 'ae', 'ᚙ');
      }
    }
    return null;
  }

  double _upperEdge(double loc, double thick) => loc - thick / 2;
  double _lowerEdge(double loc, double thick) => loc + thick / 2;

  bool _between(Offset p, double loc, double thick) =>
      p.dy >= _upperEdge(loc, thick) && p.dy <= _lowerEdge(loc, thick);

  bool _crossUpper(List<Offset> line, double loc, double thick) =>
      _linesIntersect(line, [
        Offset(0, _upperEdge(loc, thick)),
        Offset(_edgeWidth, _upperEdge(loc, thick)),
      ]);

  bool _crossLower(List<Offset> line, double loc, double thick) =>
      _linesIntersect(line, [
        Offset(0, _lowerEdge(loc, thick)),
        Offset(_edgeWidth, _lowerEdge(loc, thick)),
      ]);

  // Consonants below the stem (Aicme Beithe): 1–5 strokes crossing the lower
  // edge.
  bool _isB(List<List<Offset>> l, double loc, double t) =>
      _crossLower(l.first, loc, t);
  bool _isL(List<List<Offset>> l, double loc, double t) =>
      _crossLower(l[0], loc, t) && _crossLower(l[1], loc, t);
  bool _isF(List<List<Offset>> l, double loc, double t) =>
      l.take(3).every((line) => _crossLower(line, loc, t));
  bool _isS(List<List<Offset>> l, double loc, double t) =>
      l.take(4).every((line) => _crossLower(line, loc, t));
  bool _isN(List<List<Offset>> l, double loc, double t) =>
      l.take(5).every((line) => _crossLower(line, loc, t));

  // Consonants above the stem (Aicme hÚatha): 1–5 strokes crossing the upper
  // edge.
  bool _isH(List<List<Offset>> l, double loc, double t) =>
      _crossUpper(l.first, loc, t);
  bool _isD(List<List<Offset>> l, double loc, double t) =>
      _crossUpper(l[0], loc, t) && _crossUpper(l[1], loc, t);
  bool _isT(List<List<Offset>> l, double loc, double t) =>
      l.take(3).every((line) => _crossUpper(line, loc, t));
  bool _isC(List<List<Offset>> l, double loc, double t) =>
      l.take(4).every((line) => _crossUpper(line, loc, t));
  bool _isQ(List<List<Offset>> l, double loc, double t) =>
      l.take(5).every((line) => _crossUpper(line, loc, t));

  // Consonants across the stem (Aicme Muine): 1–5 strokes crossing both edges.
  bool _crossBoth(List<Offset> line, double loc, double t) =>
      _crossUpper(line, loc, t) && _crossLower(line, loc, t);
  bool _isM(List<List<Offset>> l, double loc, double t) =>
      _crossBoth(l.first, loc, t);
  bool _isG(List<List<Offset>> l, double loc, double t) =>
      _crossBoth(l[0], loc, t) && _crossBoth(l[1], loc, t);
  bool _isNG(List<List<Offset>> l, double loc, double t) =>
      l.take(3).every((line) => _crossBoth(line, loc, t));
  bool _isST(List<List<Offset>> l, double loc, double t) =>
      l.take(4).every((line) => _crossBoth(line, loc, t));
  bool _isR(List<List<Offset>> l, double loc, double t) =>
      l.take(5).every((line) => _crossBoth(line, loc, t));

  // Vowels (Aicme Ailme): 1–5 notches whose first point sits on the stem.
  bool _onStem(Offset p, double loc, double t) =>
      p.dy > _upperEdge(loc, t) && p.dy < _lowerEdge(loc, t);
  bool _isA(List<List<Offset>> l, double loc, double t) =>
      l.first.length == 1 && _onStem(l.first.first, loc, t);
  bool _isO(List<List<Offset>> l, double loc, double t) =>
      _onStem(l[0].first, loc, t) && _onStem(l[1].first, loc, t);
  bool _isU(List<List<Offset>> l, double loc, double t) =>
      l.take(3).every((line) => _onStem(line.first, loc, t));
  bool _isE(List<List<Offset>> l, double loc, double t) =>
      l.take(4).every((line) => _onStem(line.first, loc, t));
  bool _isI(List<List<Offset>> l, double loc, double t) =>
      l.take(5).every((line) => _onStem(line.first, loc, t));

  // Peith (forfeda P): a single stroke lying entirely below the lower edge.
  bool _isP(List<List<Offset>> l, double loc, double t) {
    final line = l.first;
    if (line.length < 2) return false;
    return line.every((p) => p.dy > _lowerEdge(loc, t));
  }

  // A word space: a single stroke running along the stem, wholly within the
  // band.
  bool _isSpace(List<List<Offset>> l, double loc, double t) {
    final line = l.first;
    if (line.length < 2) return false;
    return line.every((p) => _between(p, loc, t));
  }

  // Éabhadh (forfeda Ea): two strokes forming an X — they cross each other,
  // and each crosses both stem edges.
  bool _isEa(List<List<Offset>> l, double loc, double t) {
    if (l.length > 2) return false;
    final groups = _groupByIntersectingSegments(l);
    if (groups.isEmpty) return false;
    final group = groups[0];

    final upRight = group.where((s) =>
        (_isDirectionRight(s) && _isDirectionUp(s)) ||
        (_isDirectionLeft(s) && _isDirectionDown(s)));
    final upLeft = group.where((s) =>
        (_isDirectionLeft(s) && _isDirectionUp(s)) ||
        (_isDirectionRight(s) && _isDirectionDown(s)));

    final linesCross = upRight.length == 1 && upLeft.length == 1;
    if (!linesCross) return false;

    return _crossBoth(l[0], loc, t) && _crossBoth(l[1], loc, t);
  }

  // Ór (forfeda Oi): a single stroke reaching above and below the band while
  // entering/leaving through it — a spiral-like mark spanning the stem.
  bool _isOi(List<List<Offset>> l, double loc, double t) {
    final line = l.first;
    if (line.length < 2) return false;
    final left = _mostLeftX(line);
    final right = _mostRightX(line);
    final top = _mostTopY(line);
    final bottom = _mostBottomY(line);
    return _onStem(left, loc, t) &&
        _onStem(right, loc, t) &&
        top.dy < _upperEdge(loc, t) &&
        bottom.dy > _lowerEdge(loc, t);
  }

  // Uilleann (forfeda Ui): a single stroke crossing the lower edge that turns
  // through every direction (a hook / loop).
  bool _isUi(List<List<Offset>> l, double loc, double t) {
    final line = l.first;
    if (line.length < 2) return false;
    if (!_crossLower(line, loc, t)) return false;
    return _hasAllDirections(line);
  }

  // The feather mark ᚛ that opens an inscription: a single stroke whose
  // rightmost point sits on the stem and which reverses right-then-left.
  bool _isStart(List<List<Offset>> l, double loc, double t) {
    final line = l.first;
    if (line.length < 2) return false;
    final segments = _cutByHorizontalDirectionChange(line);
    if (segments.length < 2) return false;
    if (!_isDirectionRight(segments[0])) return false;
    if (!_isDirectionLeft(segments[1])) return false;
    final right = _mostRightX(line);
    return right.dy > _upperEdge(loc, t) && right.dy <= _lowerEdge(loc, t);
  }

  // The feather mark ᚜ that closes an inscription: the mirror of [_isStart].
  bool _isEnd(List<List<Offset>> l, double loc, double t) {
    final line = l.first;
    if (line.length < 2) return false;
    final segments = _cutByHorizontalDirectionChange(line);
    if (segments.length < 2) return false;
    if (!_isDirectionLeft(segments[0])) return false;
    if (!_isDirectionRight(segments[1])) return false;
    final left = _mostLeftX(line);
    return left.dy > _upperEdge(loc, t) && left.dy <= _lowerEdge(loc, t);
  }

  // Eamhancholl (forfeda Ae): a lattice — four strokes crossing the upper
  // edge, plus three more each intersecting all four.
  bool _isAe(List<List<Offset>> l, double loc, double t) {
    if (l.length < 7) return false;
    for (var i = 0; i < 4; i++) {
      if (!_crossUpper(l[i], loc, t)) return false;
    }
    for (var i = 4; i < 7; i++) {
      for (var j = 0; j < 4; j++) {
        if (!_linesIntersect(l[i], l[j])) return false;
      }
    }
    return true;
  }

  // --- Geometry helpers (ported from the shorthand toolbox) -----------------

  static bool _linesIntersect(List<Offset> line1, List<Offset> line2) {
    final p1 = line1.first;
    final p2 = line1.last;
    final p3 = line2.first;
    final p4 = line2.last;

    final d1 = _direction(p3, p4, p1);
    final d2 = _direction(p3, p4, p2);
    final d3 = _direction(p1, p2, p3);
    final d4 = _direction(p1, p2, p4);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    if (d1 == 0 && _onSegment(p3, p4, p1)) return true;
    if (d2 == 0 && _onSegment(p3, p4, p2)) return true;
    if (d3 == 0 && _onSegment(p1, p2, p3)) return true;
    if (d4 == 0 && _onSegment(p1, p2, p4)) return true;
    return false;
  }

  static double _direction(Offset a, Offset b, Offset c) =>
      (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);

  static bool _onSegment(Offset a, Offset b, Offset c) =>
      (c.dx >= a.dx && c.dx <= b.dx || c.dx >= b.dx && c.dx <= a.dx) &&
      (c.dy >= a.dy && c.dy <= b.dy || c.dy >= b.dy && c.dy <= a.dy);

  static bool _isDirectionUp(List<Offset> s) =>
      s.length >= 2 && s.last.dy < s.first.dy;
  static bool _isDirectionDown(List<Offset> s) =>
      s.length >= 2 && s.last.dy > s.first.dy;
  static bool _isDirectionLeft(List<Offset> s) =>
      s.length >= 2 && s.last.dx < s.first.dx;
  static bool _isDirectionRight(List<Offset> s) =>
      s.length >= 2 && s.last.dx > s.first.dx;

  static List<List<Offset>> _cutByHorizontalDirectionChange(List<Offset> s) {
    final segments = <List<Offset>>[];
    if (s.length < 2) return segments;
    var current = <Offset>[s[0]];
    bool? goingRight;
    for (var i = 1; i < s.length; i++) {
      final prev = s[i - 1];
      final curr = s[i];
      final isRight = curr.dx > prev.dx;
      if (goingRight != null && isRight != goingRight) {
        segments.add(current);
        current = <Offset>[prev];
      }
      current.add(curr);
      goingRight = isRight;
    }
    segments.add(current);
    return segments;
  }

  static bool _hasAllDirections(List<Offset> line) {
    var up = false, down = false, left = false, right = false;
    for (var i = 0; i < line.length - 1; i++) {
      final dx = line[i + 1].dx - line[i].dx;
      final dy = line[i + 1].dy - line[i].dy;
      if (dy < 0) up = true;
      if (dy > 0) down = true;
      if (dx < 0) left = true;
      if (dx > 0) right = true;
      if (up && down && left && right) return true;
    }
    return up && down && left && right;
  }

  static Offset _mostLeftX(List<Offset> line) =>
      line.reduce((a, b) => b.dx < a.dx ? b : a);
  static Offset _mostRightX(List<Offset> line) =>
      line.reduce((a, b) => b.dx > a.dx ? b : a);
  static Offset _mostTopY(List<Offset> line) =>
      line.reduce((a, b) => b.dy < a.dy ? b : a);
  static Offset _mostBottomY(List<Offset> line) =>
      line.reduce((a, b) => b.dy > a.dy ? b : a);

  /// Groups strokes whose segments intersect (transitively).
  static List<List<List<Offset>>> _groupByIntersectingSegments(
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
          if (group.any((g) => _segmentsIntersect(g, other))) {
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

  static bool _segmentsIntersect(List<Offset> a, List<Offset> b) {
    for (var i = 0; i < a.length - 1; i++) {
      for (var j = 0; j < b.length - 1; j++) {
        if (_strictSegmentsIntersect(a[i], a[i + 1], b[j], b[j + 1])) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _strictSegmentsIntersect(
      Offset p1, Offset p2, Offset p3, Offset p4) {
    final d1 = _direction(p3, p4, p1);
    final d2 = _direction(p3, p4, p2);
    final d3 = _direction(p1, p2, p3);
    final d4 = _direction(p1, p2, p4);
    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
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
    final loc = size.height / 2;
    final upper = _upperEdge(loc, _thickness);
    final lower = _lowerEdge(loc, _thickness);

    // Band and stemline (the druim).
    canvas.drawRect(
      Rect.fromLTRB(0, upper, size.width, lower),
      Paint()..color = const Color(0x141B2A4A),
    );
    final edgePaint = Paint()
      ..color = const Color(0x331B2A4A)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, upper), Offset(size.width, upper), edgePaint);
    canvas.drawLine(Offset(0, lower), Offset(size.width, lower), edgePaint);
    canvas.drawLine(
      Offset(0, loc),
      Offset(size.width, loc),
      Paint()
        ..color = const Color(0xFF1B2A4A)
        ..strokeWidth = 2,
    );

    // Strokes.
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

    // Readout.
    final recognized = _recognized;
    final label = TextPainter(
      text: recognized != null
          ? TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              children: [
                const TextSpan(text: 'Recognized: '),
                TextSpan(
                  text: recognized.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (recognized.translit.isNotEmpty)
                  TextSpan(text: ' — "${recognized.translit}"'),
              ],
            )
          : const TextSpan(
              text: 'Draw a letter on the stemline to see it recognized',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

/// Builds the scene plus a direct reference to its [OghamLayer], so the
/// hosting page can call [OghamLayer.clear] from the Clear button.
(Scene, OghamLayer) buildOghamScene() {
  final layer = OghamLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
