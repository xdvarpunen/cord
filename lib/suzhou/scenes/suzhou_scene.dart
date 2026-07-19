import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/scene.dart';

/// Cream, dot-grid paper background (Moleskine-style notebook page) — a plain,
/// script-agnostic backdrop for the drawing surface.
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

/// One freehand pen stroke: the polyline of points from pointer-down to
/// pointer-up.
class _Stroke {
  _Stroke(this.points);
  final List<Offset> points;
  Offset get start => points.first;
  Offset get end => points.last;

  /// Straight-line displacement from first point to last.
  Offset get chord => end - start;

  Rect get bounds {
    var left = points.first.dx, right = points.first.dx;
    var top = points.first.dy, bottom = points.first.dy;
    for (final p in points) {
      left = math.min(left, p.dx);
      right = math.max(right, p.dx);
      top = math.min(top, p.dy);
      bottom = math.max(bottom, p.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

/// Which way a bar runs, or which axis a set of strokes is lined up along.
enum _Axis { vertical, horizontal }

/// A Suzhou numeral the recognizer can read.
///
/// Only digits with a built classifier live here; the full set of ten (for the
/// reference table) is in `data/suzhou_numerals.dart`. Digits are added one at
/// a time as their gesture is pinned down.
enum _SuzhouDigit {
  /// 〇 — a single stroke that crosses itself: a loop closed by carrying the
  /// pen past its own start. See [SuzhouLayer._classifyLooped].
  zero('〇', 0, 'a single stroke that crosses itself'),

  /// 〡 — a single vertical stroke that does not intersect itself.
  one('〡', 1, 'a single vertical stroke'),

  /// 〢 — two vertical strokes side by side, over the same y range.
  two('〢', 2, 'two vertical strokes side by side'),

  /// 〣 — three vertical strokes side by side, over the same y range.
  three('〣', 3, 'three vertical strokes side by side'),

  /// 〤 — an ascending and a descending stroke that cross: an `✕`.
  /// See [SuzhouLayer._classifyFour].
  four('〤', 4, 'an ascending and a descending stroke that cross (✕)'),

  /// 〥 — a 〇 with an arm either side of the loop, running in opposite
  /// horizontal directions. See [SuzhouLayer._classifyLooped].
  five('〥', 5, 'a loop with opposed sideways arms'),

  /// 〦 — a horizontal stroke crossing a vertical one.
  /// See [SuzhouLayer._classifyCrossed].
  six('〦', 6, 'a horizontal stroke crossing a vertical one'),

  /// 〧 — 〦 with one further horizontal stroke below it.
  seven('〧', 7, '〦 with one horizontal stroke below'),

  /// 〨 — 〦 with two further horizontal strokes below it.
  eight('〨', 8, '〦 with two horizontal strokes below'),

  /// 〩 — 〦 with a 〤 (an `✕`) below it.
  /// See [SuzhouLayer._classifyNine].
  nine('〩', 9, '〦 with a 〤 below it');

  const _SuzhouDigit(this.glyph, this.value, this.description);

  final String glyph;
  final int value;
  final String description;
}

/// Freehand recognition of Suzhou numerals, drawn on a [GameCanvas].
///
/// Classification runs over **every stroke on the page**, not just the last
/// one — the bar digits are distinguished purely by stroke count (〡 is one
/// vertical bar, 〢 two, 〣 three), so a per-stroke classifier could never tell
/// them apart. Each completed stroke re-runs the classifiers against the whole
/// set, so the readout updates live and drawing a second bar next to a 〡
/// re-reads the page as 〢 once that classifier exists.
///
/// Digits so far:
///
/// - **〇** (0) — one stroke that crosses itself (a loop), and **〥** (5) —
///   the same with an arm either side of the loop running in opposite
///   horizontal directions. One classifier decides both: see
///   [_classifyLooped].
/// - **〡〢〣** (1–3) — that many straight vertical bars, side by side over a
///   shared y range. See [_classifyBars].
/// - **〤** (4) — two crossing strokes, one ascending and one descending.
///   See [_classifyFour].
/// - **〦〧〨** (6–8) — a horizontal stroke crossing a vertical one, plus that
///   many further horizontals stacked below. See [_classifyCrossed].
/// - **〩** (9) — the same crossed figure with a 〤 below it.
///   See [_classifyNine].
///
/// All ten digits are covered.
class SuzhouLayer extends Layer {
  /// Below this pointer-travel distance a gesture is a tap, not a drag — no
  /// tap-based digits exist yet, so taps are ignored.
  static const double _dotThreshold = 5;

  /// A drag must travel at least this far to be committed as a stroke, so a
  /// near-stationary jitter isn't mistaken for a line.
  static const double _minDragDistance = 8;

  /// How far a stroke may wander sideways off its own start→end line, as a
  /// fraction of that line's length, and still count as straight.
  static const double _straightTolerance = 0.18;

  /// How far a bar may lean off true vertical, as a ratio of horizontal to
  /// vertical displacement (0.40 ≈ 22°).
  static const double _leanTolerance = 0.40;

  /// How much of the shortest stroke's extent must fall inside the range they
  /// all share, for them to count as lined up along that axis.
  static const double _overlapFraction = 0.6;

  /// How far apart neighbouring bars' centres must sit, in logical pixels,
  /// to read as separate bars rather than one line drawn over twice.
  static const double _minBarSeparation = 12;

  /// How far a limb of 〤 must run horizontally before its slope is
  /// meaningful — below this a near-vertical stroke has no real direction.
  static const double _minDiagonalRun = 8;


  final List<_Stroke> _strokes = [];
  _SuzhouDigit? _recognized;
  List<Offset>? _activePoints;

  void clear() {
    _strokes.clear();
    _recognized = null;
  }

  @override
  void handlePointerEvent(PointerEvent event, Size size) {
    if (event is PointerDownEvent) {
      _activePoints = [event.localPosition];
    } else if (event is PointerMoveEvent && _activePoints != null) {
      _activePoints!.add(event.localPosition);
    } else if (event is PointerUpEvent && _activePoints != null) {
      final points = _activePoints!;
      final dragDistance = (points.last - points.first).distance;
      if (dragDistance >= _dotThreshold &&
          points.length >= 2 &&
          dragDistance >= _minDragDistance) {
        _commit(_Stroke(points));
      }
      _activePoints = null;
    }
  }

  void _commit(_Stroke stroke) {
    _strokes.add(stroke);
    _recognized = _firstValid([
      () => _classifyLooped(_strokes),
      () => _classifyFour(_strokes),
      () => _classifyNine(_strokes),
      () => _classifyCrossed(_strokes),
      () => _classifyBars(_strokes),
    ]);
  }

  /// Tries each classifier in order, returning the first non-null result.
  _SuzhouDigit? _firstValid(List<_SuzhouDigit? Function()> classifiers) {
    for (final classify in classifiers) {
      final result = classify();
      if (result != null) return result;
    }
    return null;
  }

  /// Whether the page holds a **looped digit** — 〇 (0) or 〥 (5).
  ///
  /// One stroke that crosses itself is a 〇. It becomes a 〥 when the loop has
  /// an arm hanging off each end that run in *opposite* horizontal directions
  /// — the arm before the crossing going one way, the arm after the loop the
  /// other. So 5 is decided as a refinement of 0, not as a rival to it, and
  /// there is no classifier ordering to get wrong.
  ///
  /// This can't collide with [_classifyBars] either: a bar is required *not*
  /// to self-cross, so the crossing separates them cleanly at one stroke.
  _SuzhouDigit? _classifyLooped(List<_Stroke> strokes) {
    if (strokes.length != 1) return null;
    final stroke = strokes.single;

    final crossings = _selfCrossings(stroke);
    if (crossings.isEmpty) return null;

    return _hasOpposedArms(stroke, crossings)
        ? _SuzhouDigit.five
        : _SuzhouDigit.zero;
  }

  /// Whether any of [crossings] leaves the stroke with two arms that run in
  /// opposite horizontal directions — what raises a 〇 to a 〥.
  ///
  /// A looped figure can cross itself more than once, and only one of those
  /// crossings is the one with the real arms on it — closing the loop makes
  /// another, whose "arms" are stubs. So every crossing is tried and any
  /// qualifying one is enough. Which arm goes left and which goes right
  /// doesn't matter, only that they oppose, so it reads the same drawn from
  /// either end.
  bool _hasOpposedArms(
      _Stroke stroke, List<({int entry, int exit})> crossings) {
    for (final crossing in crossings) {
      // The crossing brackets the loop; the arms are what hangs off each end.
      final before = stroke.points.sublist(0, crossing.entry + 1);
      final after = stroke.points.sublist(crossing.exit + 1);
      if (before.length < 2 || after.length < 2) continue;

      // Only the direction each arm travels matters — not how level it is, nor
      // how far it runs. An arm of a hand-drawn 〥 can descend further than it
      // reaches sideways and still be the arm.
      final leading = _Stroke(before).chord.dx.sign;
      final trailing = _Stroke(after).chord.dx.sign;
      if (leading == 0 || trailing == 0) continue;

      if (leading != trailing) return true;
    }
    return false;
  }

  /// Whether the page holds **〤** (4): two strokes that cross, one ascending
  /// and one descending — an `✕`.
  ///
  /// Slope is read left-to-right off the stroke's shape, not off the order the
  /// points were sampled, so it doesn't matter which end of each limb you
  /// start from — only that the finished figure has one rising and one falling
  /// limb. Both orderings of the two strokes are accepted.
  _SuzhouDigit? _classifyFour(List<_Stroke> strokes) {
    if (strokes.length != 2) return null;

    final first = _slopeDirection(strokes[0]);
    final second = _slopeDirection(strokes[1]);
    if (first == null || second == null) return null;

    // One up, one down — same-sloped pairs (`//`) are not a cross.
    if (first == second) return null;

    return _strokesCross(strokes[0], strokes[1]) ? _SuzhouDigit.four : null;
  }

  /// Whether [stroke] rises (`true`) or falls (`false`) as it goes left to
  /// right, or null if it runs too vertically for its slope to mean anything.
  ///
  /// Screen y grows downward, so a *rising* limb is one whose right-hand end
  /// has the smaller y.
  bool? _slopeDirection(_Stroke stroke) {
    final chord = stroke.chord;
    if (chord.dx.abs() < _minDiagonalRun) return null;

    // Re-read the chord left-to-right regardless of which way it was drawn.
    final rise = chord.dx > 0 ? -chord.dy : chord.dy;
    return rise > 0;
  }

  /// Whether any segment of [a] crosses any segment of [b] — the two limbs of
  /// an `✕` actually meeting, rather than two diagonals drawn apart.
  bool _strokesCross(_Stroke a, _Stroke b) {
    for (var i = 0; i < a.points.length - 1; i++) {
      for (var j = 0; j < b.points.length - 1; j++) {
        if (_segmentsIntersect(
            a.points[i], a.points[i + 1], b.points[j], b.points[j + 1])) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether the page holds **〦〧〨** (6–8): the crossed figure 〦 — a
  /// horizontal stroke crossing a vertical one — optionally with further
  /// horizontal strokes stacked below it, in the same x range. Each stroke
  /// added below counts one more: none is 6, one is 7, two is 8.
  ///
  /// (9 is 〦 over an `✕` rather than over more horizontals, so it has its own
  /// classifier — see [_classifyNine].)
  _SuzhouDigit? _classifyCrossed(List<_Stroke> strokes) {
    const byExtras = {
      0: _SuzhouDigit.six,
      1: _SuzhouDigit.seven,
      2: _SuzhouDigit.eight,
    };
    final digit = byExtras[strokes.length - 2];
    if (digit == null) return null;

    final crossed = _crossedFigure(strokes);
    if (crossed == null) return null;

    // Everything not part of the 〦 must be a horizontal stroke sitting below
    // its crossbar, lined up under it.
    final below = strokes.where((s) => s != crossed.bar && s != crossed.upright);
    if (!below.every(_isHorizontalBar)) return null;
    if (!below.every((s) => _isBelow(s, crossed.bar))) return null;
    if (!_shareRange([crossed.bar, ...below], _Axis.horizontal)) return null;

    return digit;
  }

  /// Whether the page holds **〩** (9): the crossed figure 〦 with a 〤 — an
  /// ascending and a descending stroke that cross — below it, in the same x
  /// range.
  _SuzhouDigit? _classifyNine(List<_Stroke> strokes) {
    if (strokes.length != 4) return null;

    final crossed = _crossedFigure(strokes);
    if (crossed == null) return null;

    final rest =
        strokes.where((s) => s != crossed.bar && s != crossed.upright).toList();
    if (rest.length != 2) return null;

    // The remaining pair must itself read as a 〤, and sit under the crossbar.
    if (_classifyFour(rest) != _SuzhouDigit.four) return null;
    if (!rest.every((s) => _isBelow(s, crossed.bar))) return null;
    if (!_shareRange([crossed.bar, ...rest], _Axis.horizontal)) return null;

    return _SuzhouDigit.nine;
  }

  /// Finds the 〦 inside [strokes]: the one vertical stroke, and the one
  /// horizontal stroke that crosses it. Null when the page doesn't hold
  /// exactly that — no upright, several uprights, or nothing crossing it.
  ///
  /// Shared by [_classifyCrossed] and [_classifyNine], which differ only in
  /// what sits below the figure.
  ({_Stroke upright, _Stroke bar})? _crossedFigure(List<_Stroke> strokes) {
    final uprights = strokes.where(_isVerticalBar).toList();
    if (uprights.length != 1) return null;
    final upright = uprights.single;

    final crossbars = strokes
        .where((s) => s != upright && _isHorizontalBar(s))
        .where((s) => _strokesCross(s, upright))
        .toList();
    if (crossbars.length != 1) return null;

    return (upright: upright, bar: crossbars.single);
  }

  /// Whether [stroke] sits below [reference] — its whole extent clear of the
  /// other's, so a stroke merely drawn at a slant doesn't count as stacked.
  bool _isBelow(_Stroke stroke, _Stroke reference) =>
      stroke.bounds.top > reference.bounds.bottom;

  /// Whether the page holds a **bar digit** — 〡 (1), 〢 (2) or 〣 (3).
  ///
  /// These differ only in how many bars there are, so one classifier covers
  /// all three: every stroke must be a vertical bar, the bars must span the
  /// same y range (they sit side by side, not stacked), and they must be far
  /// enough apart to read as separate bars rather than one retraced line.
  /// The digit is then just the count.
  ///
  /// Stops at three — 4 is 〤, a cross, not four bars.
  _SuzhouDigit? _classifyBars(List<_Stroke> strokes) {
    const byCount = {
      1: _SuzhouDigit.one,
      2: _SuzhouDigit.two,
      3: _SuzhouDigit.three,
    };
    final digit = byCount[strokes.length];
    if (digit == null) return null;
    if (!strokes.every(_isVerticalBar)) return null;
    if (!_shareRange(strokes, _Axis.vertical)) return null;
    if (!_sideBySide(strokes)) return null;
    return digit;
  }

  /// Whether every stroke covers substantially the same band along [axis] —
  /// the span they all share must be at least [_overlapFraction] of the
  /// shortest one's extent.
  ///
  /// On the vertical axis this is what stops two bars drawn one *above* the
  /// other from reading as 〢: both are vertical bars, but with no common y
  /// range. On the horizontal axis it's the "same x range" that keeps the
  /// stacked strokes of 〧 and 〨 lined up under the crossbar.
  bool _shareRange(List<_Stroke> strokes, _Axis axis) {
    if (strokes.length < 2) return true;

    final vertical = axis == _Axis.vertical;
    var lastStart = double.negativeInfinity;
    var firstEnd = double.infinity;
    var shortest = double.infinity;
    for (final stroke in strokes) {
      final bounds = stroke.bounds;
      final start = vertical ? bounds.top : bounds.left;
      final end = vertical ? bounds.bottom : bounds.right;
      lastStart = math.max(lastStart, start);
      firstEnd = math.min(firstEnd, end);
      shortest = math.min(shortest, end - start);
    }

    return (firstEnd - lastStart) >= shortest * _overlapFraction;
  }

  /// Whether the bars are spread across x rather than piled on one another —
  /// neighbouring bars' centres must sit at least [_minBarSeparation] apart,
  /// so tracing over an existing bar doesn't silently bump 〡 to 〢.
  bool _sideBySide(List<_Stroke> strokes) {
    if (strokes.length < 2) return true;
    final centres = strokes.map((s) => s.bounds.center.dx).toList()..sort();
    for (var i = 1; i < centres.length; i++) {
      if (centres[i] - centres[i - 1] < _minBarSeparation) return false;
    }
    return true;
  }

  /// Whether [stroke] reads as a single vertical bar. See [_isBar].
  ///
  /// Shared by every bar digit — 〢 and 〣 are just two and three of these — so
  /// it takes one stroke rather than baking in a count.
  bool _isVerticalBar(_Stroke stroke) => _isBar(stroke, _Axis.vertical);

  /// Whether [stroke] reads as a single horizontal bar. See [_isBar].
  bool _isHorizontalBar(_Stroke stroke) => _isBar(stroke, _Axis.horizontal);

  /// Whether [stroke] is a straight bar running along [axis]: no self-crossing,
  /// much longer along the axis than across it, near-true to the axis, and
  /// straight enough that a curve or a hook doesn't pass as a bar.
  ///
  /// One predicate covers both orientations because the tests are identical
  /// once "along" and "across" are read off the right axis — the bars of 〡〢〣
  /// are vertical, the crossbar of 〦 horizontal.
  bool _isBar(_Stroke stroke, _Axis axis) {
    if (_selfIntersections(stroke) != 0) return false;

    final chord = stroke.chord;
    final length = chord.distance;
    if (length < _minDragDistance) return false;

    final vertical = axis == _Axis.vertical;

    // True to the axis: drift across it must stay small next to the run along.
    final along = vertical ? chord.dy : chord.dx;
    final across = vertical ? chord.dx : chord.dy;
    if (across.abs() > along.abs() * _leanTolerance) return false;

    // A bar's bounding box is long, not fat — catches a stroke that doubles
    // back across the axis yet happens to start and end in line.
    final bounds = stroke.bounds;
    final boundsAlong = vertical ? bounds.height : bounds.width;
    final boundsAcross = vertical ? bounds.width : bounds.height;
    if (boundsAcross > boundsAlong * _leanTolerance) return false;

    return _maxDeviationFromChord(stroke) <= length * _straightTolerance;
  }

  /// The greatest perpendicular distance from any of [stroke]'s points to the
  /// straight line joining its endpoints — how far the stroke bows.
  double _maxDeviationFromChord(_Stroke stroke) {
    final chord = stroke.chord;
    final length = chord.distance;
    if (length == 0) return 0;

    var worst = 0.0;
    for (final p in stroke.points) {
      final rel = p - stroke.start;
      // |cross product| / |chord| is the point's distance from the line.
      final distance = (rel.dx * chord.dy - rel.dy * chord.dx).abs() / length;
      worst = math.max(worst, distance);
    }
    return worst;
  }

  /// How many times [stroke] crosses its own path — non-adjacent segments
  /// (index gap of at least two) that intersect, deduplicated so one real
  /// loop sampled across nearby points still counts once.
  int _selfIntersections(_Stroke stroke) {
    final points = stroke.points;
    var count = 0;
    var lastCrossing = -10;
    for (var i = 0; i < points.length - 1; i++) {
      for (var j = i + 2; j < points.length - 1; j++) {
        if (_segmentsIntersect(
            points[i], points[i + 1], points[j], points[j + 1])) {
          if (j - lastCrossing > 2) count++;
          lastCrossing = j;
        }
      }
    }
    return count;
  }

  /// Every place [stroke] crosses its own path: [entry] is the segment running
  /// *into* the crossing, [exit] the one running back *out* of it.
  ///
  /// Each pair brackets a loop, so what lies before [entry] and after [exit]
  /// are that loop's two free arms — which is what distinguishes 〥 from a
  /// plain 〇. A figure can cross itself more than once (closing a loop *and*
  /// cutting back through an earlier line), so all of them are returned and
  /// [_classifyFive] can ask about each in turn.
  ///
  /// Uses the same non-adjacency rule as [_selfIntersections]: segments must
  /// be at least two apart to count, so consecutive samples never "cross".
  List<({int entry, int exit})> _selfCrossings(_Stroke stroke) {
    final points = stroke.points;
    final crossings = <({int entry, int exit})>[];
    for (var i = 0; i < points.length - 1; i++) {
      for (var j = i + 2; j < points.length - 1; j++) {
        if (_segmentsIntersect(
            points[i], points[i + 1], points[j], points[j + 1])) {
          crossings.add((entry: i, exit: j));
        }
      }
    }
    return crossings;
  }

  bool _segmentsIntersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    double cross(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);

    final d1 = cross(p3, p4, p1);
    final d2 = cross(p3, p4, p2);
    final d3 = cross(p1, p2, p3);
    final d4 = cross(p1, p2, p4);

    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }

  void _drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3A1E12)
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

    final recognized = _recognized;
    final label = TextPainter(
      text: recognized != null
          ? TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              children: [
                const TextSpan(text: 'Recognized: '),
                TextSpan(
                  text: recognized.glyph,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                TextSpan(text: '  (${recognized.value})'),
              ],
            )
          : const TextSpan(
              text: 'Draw a numeral below to see it recognized',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

/// Builds the scene plus a direct reference to its [SuzhouLayer], so the
/// hosting page can call [SuzhouLayer.clear] from the Clear button.
(Scene, SuzhouLayer) buildSuzhouScene() {
  final layer = SuzhouLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
