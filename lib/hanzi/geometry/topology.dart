/// How strokes meet each other.
///
/// Template matching compares where strokes *are*; this compares how they are
/// *connected*. Position alone cannot separate 人 from 九 — near-identical
/// placement, but 九's second stroke crosses the first while 人's only meets it
/// at the apex — nor 田 from 由, where the vertical either stops at the box or
/// passes through it.
///
/// The primitives mirror the sibling projects (`tifi`'s `_segmentsIntersect`,
/// `_selfIntersections`, `_crossings`), which treat topology as the first thing
/// a classifier checks. They are public here because both recognisers use them.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../data/stroke_models.dart' show JunctionKind;

export '../data/stroke_models.dart' show JunctionKind;

/// Fraction of the glyph's size within which two strokes count as meeting even
/// if they never truly cross.
///
/// Hand-drawn strokes miss. A 十 whose bar stops a hair short of the stem is
/// still a 十 to any reader, and demanding a true intersection would fail it.
const double kJunctionTolerance = 0.055;

/// How much of a stroke, measured along its arc length from either end, counts
/// as "the end" rather than "the middle".
///
/// This is what separates a cross from a tee, so it is set from the data rather
/// than by feel. Measuring where the junction actually falls in the reference
/// glyphs:
///
/// | glyph | along stroke 2 |          |
/// |-------|---------------:|----------|
/// | 人    |          0.000 | a true endpoint — the 捺 begins on the 丿 |
/// | 九    |          0.187 | a real crossing |
/// | 十    |          0.290 | a real crossing |
/// | 又    |          0.377 | a real crossing |
///
/// An earlier value of 0.22 sat *above* 九's 0.187, so 九's crossing was read as
/// an endpoint and it became indistinguishable from 人 — the exact confusion
/// this module exists to fix. 0.12 clears 九 with margin while leaving 人, whose
/// stroke starts exactly at the junction, firmly an endpoint.
const double kEndZone = 0.12;

/// Closest approach, as a fraction of the glyph's size, below which two strokes
/// are treated as genuinely touching rather than merely near.
///
/// Much tighter than [kJunctionTolerance]: this is not about sloppy drawing but
/// about the exact-contact case the strict crossing test declines to report.
const double kGrazingTolerance = 0.005;

/// Orientation test: do segments a1→a2 and b1→b2 **properly** cross?
///
/// Proper means each segment has the other's endpoints strictly on opposite
/// sides. Merely meeting at a shared endpoint does not count, and neither does
/// lying collinear.
///
/// That strictness is load-bearing. The looser form — comparing signs while
/// letting one be zero — reports a crossing wherever two segments touch
/// end-to-end, which made every corner of an L-shaped stroke read as a
/// self-intersection. Endpoint contact is real information, but it is
/// [junctionBetween]'s job to classify, not this predicate's.
bool segmentsIntersect(Offset a1, Offset a2, Offset b1, Offset b2) {
  int side(Offset p, Offset q, Offset r) {
    final v = (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
    return v == 0 ? 0 : (v > 0 ? 1 : -1);
  }

  final d1 = side(a1, a2, b1);
  final d2 = side(a1, a2, b2);
  final d3 = side(b1, b2, a1);
  final d4 = side(b1, b2, a2);
  if (d1 == 0 || d2 == 0 || d3 == 0 || d4 == 0) return false;
  return d1 != d2 && d3 != d4;
}

/// Where a1→a2 meets b1→b2, or null if they are parallel.
Offset? intersectionPoint(Offset a1, Offset a2, Offset b1, Offset b2) {
  final d = (a2.dx - a1.dx) * (b2.dy - b1.dy) - (a2.dy - a1.dy) * (b2.dx - b1.dx);
  if (d.abs() < 1e-9) return null;
  final t =
      ((b1.dx - a1.dx) * (b2.dy - b1.dy) - (b1.dy - a1.dy) * (b2.dx - b1.dx)) / d;
  return Offset(a1.dx + (a2.dx - a1.dx) * t, a1.dy + (a2.dy - a1.dy) * t);
}

/// Places [stroke] crosses its own path.
///
/// Only non-adjacent segments count — neighbours share a point by construction.
/// Crossings closer together than a couple of segments are treated as one, so a
/// single real loop sampled densely does not read as several.
int selfIntersections(List<Offset> stroke) {
  var found = 0;
  var lastCrossing = -10;
  for (var i = 0; i + 1 < stroke.length; i++) {
    for (var j = i + 2; j + 1 < stroke.length; j++) {
      if (!segmentsIntersect(stroke[i], stroke[i + 1], stroke[j], stroke[j + 1])) {
        continue;
      }
      if (j - lastCrossing > 2) found++;
      lastCrossing = j;
    }
  }
  return found;
}

/// How strokes [a] and [b] meet, at the given [scale] (the size of the whole
/// character, which the tolerance is relative to).
///
/// [junctionTolerance] and [endZone] default to the calibrated constants and
/// exist so the calibration itself can be run — see the sweep in
/// `test/junction_data_test.dart`, which fits them against the junctions read
/// out of the source SVG.
JunctionKind junctionBetween(
  List<Offset> a,
  List<Offset> b,
  double scale, {
  double junctionTolerance = kJunctionTolerance,
  double endZone = kEndZone,
}) {
  if (a.length < 2 || b.length < 2) return JunctionKind.none;
  final tolerance = scale * junctionTolerance;

  // A true crossing is the strongest evidence, so look for one first and note
  // where along each stroke it happened.
  for (var i = 0; i + 1 < a.length; i++) {
    for (var j = 0; j + 1 < b.length; j++) {
      if (!segmentsIntersect(a[i], a[i + 1], b[j], b[j + 1])) continue;
      final at = intersectionPoint(a[i], a[i + 1], b[j], b[j + 1]);
      if (at == null) continue;
      return _classify(_positionAlong(a, at), _positionAlong(b, at), endZone);
    }
  }

  // Otherwise they may still meet, in the way a hand actually draws: close
  // enough that a reader sees them touching.
  var best = double.infinity;
  var bestOnA = Offset.zero;
  var bestOnB = Offset.zero;
  for (var i = 0; i + 1 < a.length; i++) {
    for (var j = 0; j + 1 < b.length; j++) {
      final (d, pa, pb) = _segmentDistance(a[i], a[i + 1], b[j], b[j + 1]);
      if (d < best) {
        best = d;
        bestOnA = pa;
        bestOnB = pb;
      }
    }
  }
  if (best > tolerance) return JunctionKind.none;

  final kind =
      _classify(_positionAlong(a, bestOnA), _positionAlong(b, bestOnB), endZone);

  // A near miss is not a full crossing — neither stroke got past the other — so
  // it can only be a tee or a touch. But *touching* is different from missing:
  // when a sampled vertex of one stroke lands exactly on the other, they really
  // do intersect, the strict test in [segmentsIntersect] just declines to say
  // so. Without this the middle of a 十 would read as a tee whenever the
  // resampling happened to place a point on the crossing.
  if (kind == JunctionKind.cross && best > scale * kGrazingTolerance) {
    return JunctionKind.tee;
  }
  return kind;
}

JunctionKind _classify(double alongA, double alongB, double endZone) {
  final endA = alongA < endZone || alongA > 1 - endZone;
  final endB = alongB < endZone || alongB > 1 - endZone;
  if (endA && endB) return JunctionKind.touch;
  if (endA || endB) return JunctionKind.tee;
  return JunctionKind.cross;
}

/// Where [at] falls along [stroke], as a fraction of its arc length.
double _positionAlong(List<Offset> stroke, Offset at) {
  var total = 0.0;
  var best = double.infinity;
  var bestLength = 0.0;
  for (var i = 0; i + 1 < stroke.length; i++) {
    final segment = stroke[i + 1] - stroke[i];
    final length = segment.distance;
    final t = length < 1e-9
        ? 0.0
        : (((at - stroke[i]).dx * segment.dx + (at - stroke[i]).dy * segment.dy) /
                (length * length))
            .clamp(0.0, 1.0);
    final closest = stroke[i] + segment * t;
    final d = (at - closest).distance;
    if (d < best) {
      best = d;
      bestLength = total + length * t;
    }
    total += length;
  }
  return total < 1e-9 ? 0.0 : (bestLength / total).clamp(0.0, 1.0);
}

/// Closest approach between two segments, with the points that achieved it.
(double, Offset, Offset) _segmentDistance(
    Offset a1, Offset a2, Offset b1, Offset b2) {
  var best = double.infinity;
  var pa = a1;
  var pb = b1;

  void consider(Offset from, Offset to, Offset point, {required bool onA}) {
    final segment = to - from;
    final length = segment.distance;
    final t = length < 1e-9
        ? 0.0
        : (((point - from).dx * segment.dx + (point - from).dy * segment.dy) /
                (length * length))
            .clamp(0.0, 1.0);
    final closest = from + segment * t;
    final d = (point - closest).distance;
    if (d < best) {
      best = d;
      pa = onA ? closest : point;
      pb = onA ? point : closest;
    }
  }

  consider(a1, a2, b1, onA: true);
  consider(a1, a2, b2, onA: true);
  consider(b1, b2, a1, onA: false);
  consider(b1, b2, a2, onA: false);
  return (best, pa, pb);
}

/// The junction between every pair of strokes.
///
/// Symmetric; `[i][j]` and `[j][i]` hold the same value, and the diagonal is
/// [JunctionKind.none].
List<List<JunctionKind>> topologyOf(
  List<List<Offset>> strokes, {
  double junctionTolerance = kJunctionTolerance,
  double endZone = kEndZone,
}) {
  final scale = _scaleOf(strokes);
  final n = strokes.length;
  final matrix = List.generate(
      n, (_) => List.filled(n, JunctionKind.none), growable: false);
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      final kind = junctionBetween(strokes[i], strokes[j], scale,
          junctionTolerance: junctionTolerance, endZone: endZone);
      matrix[i][j] = kind;
      matrix[j][i] = kind;
    }
  }
  return matrix;
}

/// How many pairs of strokes properly cross. Used by the diagnostics that
/// exposed this gap in the first place.
int crossingCount(List<List<Offset>> strokes) {
  final topology = topologyOf(strokes);
  var count = 0;
  for (var i = 0; i < topology.length; i++) {
    for (var j = i + 1; j < topology.length; j++) {
      if (topology[i][j] == JunctionKind.cross) count++;
    }
  }
  return count;
}

/// Disagreement between two junction matrices, as a fraction of stroke pairs.
///
/// [assignment] maps each stroke of [drawn] onto a stroke of [reference], so
/// the comparison follows the pairing the shape matcher already established
/// rather than assuming both were drawn in the same order.
double topologyMismatch(
  List<List<JunctionKind>> drawn,
  List<List<JunctionKind>> reference,
  List<int> assignment,
) {
  final n = drawn.length;
  if (n < 2 || reference.length != n) return 0;

  var mismatches = 0.0;
  var pairs = 0;
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      final ri = assignment[i];
      final rj = assignment[j];
      if (ri < 0 || rj < 0 || ri >= n || rj >= n) continue;
      pairs++;
      mismatches += _penalty(drawn[i][j], reference[ri][rj]);
    }
  }
  return pairs == 0 ? 0 : mismatches / pairs;
}

/// Cost of reading one junction as another.
///
/// Not all confusions are equal: mistaking a cross for "not touching at all" is
/// a bigger error than mistaking it for a tee, and tee-versus-touch is the sort
/// of thing sloppy handwriting produces legitimately.
double _penalty(JunctionKind a, JunctionKind b) {
  if (a == b) return 0;
  const rank = {
    JunctionKind.none: 0,
    JunctionKind.touch: 1,
    JunctionKind.tee: 2,
    JunctionKind.cross: 3,
  };
  return (rank[a]! - rank[b]!).abs() / 3;
}

double _scaleOf(List<List<Offset>> strokes) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final stroke in strokes) {
    for (final p in stroke) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
  }
  final scale = math.max(maxX - minX, maxY - minY);
  return scale.isFinite && scale > 0 ? scale : 1;
}
