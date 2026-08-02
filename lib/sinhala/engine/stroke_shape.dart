import 'dart:math' as math;
import 'dart:ui';

/// Which way a stroke bent at one point along its path.
enum TurnDirection { straight, left, right }

/// The signed angle change at one point of a stroke.
class AngleSegment {
  const AngleSegment({
    required this.index,
    required this.point,
    required this.degrees,
    required this.direction,
  });

  /// Index of this point in [StrokeShape.points].
  final int index;

  final Offset point;

  /// Signed angle change in degrees — **left is positive**, right negative,
  /// and a straight run is 0. Scaled so that summing [degrees] along the
  /// stroke gives the real total turn: a full loop adds up to ~360°.
  final double degrees;

  /// [degrees] bucketed, with anything under the tolerance called straight.
  final TurnDirection direction;

  double get magnitude => degrees.abs();
  bool get isLeft => direction == TurnDirection.left;
  bool get isRight => direction == TurnDirection.right;
  bool get isStraight => direction == TurnDirection.straight;
}

/// One stretch of a stroke that bends the same way throughout, as
/// [StrokeShape.turnRuns] cuts them.
///
/// [direction] and [degrees] are the segmentation's own findings, and are what
/// a rule should read — see the note on [StrokeShape.turnRuns] for why asking
/// [shape] instead gives a different, wrong answer.
class TurnRun {
  const TurnRun({
    required this.direction,
    required this.degrees,
    required this.shape,
  });

  /// Which way this run bends. Never [TurnDirection.straight] — a run exists
  /// only where the pen was turning.
  final TurnDirection direction;

  /// How far it comes round in total, in degrees. Around 90 is a corner, 180
  /// the pen doubling back on itself, 360 a closed loop.
  final double degrees;

  /// The stretch of stroke the run covers, measurable like any other.
  final StrokeShape shape;

  bool get isLeft => direction == TurnDirection.left;
  bool get isRight => direction == TurnDirection.right;

  @override
  String toString() => '${isLeft ? 'L' : 'R'}${degrees.round()}';
}

/// One stretch of a stroke travelling the same way up or down the page, as
/// [StrokeShape.verticalRuns] cuts them.
class VerticalRun {
  const VerticalRun({
    required this.goingUp,
    required this.rise,
    required this.shape,
  });

  /// Whether the pen was climbing. Screen y points down, so this is `dy < 0`.
  final bool goingUp;

  /// How far it climbed or fell in total, in logical pixels.
  final double rise;

  /// The stretch of stroke the run covers, measurable like any other.
  final StrokeShape shape;

  @override
  String toString() => '${goingUp ? 'U' : 'D'}${rise.round()}';
}

/// A place where a stroke crossed back over its own path.
class Crossing {
  const Crossing({
    required this.point,
    required this.fromIndex,
    required this.toIndex,
  });

  /// Where the two parts of the stroke meet.
  final Offset point;

  /// Index in [StrokeShape.points] of the earlier segment that was crossed.
  final int fromIndex;

  /// Index in [StrokeShape.points] of the later segment doing the crossing —
  /// the pen was here when it cut back over itself.
  final int toIndex;
}

/// Everything measured about one drawn stroke: where it bent and which way,
/// and where it crossed itself. This is the vocabulary the letter rules in
/// `scenes/sinhala_scene.dart` are written against.
///
/// The angle half is ported from the shorthand project's
/// `angle_inspector_final.dart` (its `LineAngle` / `AngleSegment` /
/// `LineDirection`), which measures the signed angle between successive
/// vectors with `atan2(cross, dot)` and buckets each into left / right /
/// straight. The sign convention is kept from there: **left is positive**.
/// Sinhala is distinguished far more by which way the pen keeps turning than
/// by any bounding box or stroke count.
///
/// Two deliberate departures from the shorthand original:
///
/// 1. The angle is measured between the *incoming and outgoing* vectors
///    (b-a then c-b), not between BA and BC as shorthand does. Shorthand's
///    formula returns the interior angle at B, which is 180° for a point on a
///    straight line — so its totals climb steadily on strokes that never turn
///    at all. Measuring the heading change instead makes a straight run 0°,
///    which is what [leftTotal] and [rightTotal] need to mean anything.
/// 2. Points are resampled to even spacing first (see [resampleSpacing]) and
///    each vector is measured over a short window, so the numbers don't depend
///    on how fast the letter was drawn — raw touch samples bunch up wherever
///    the pen slowed down, and a cluster of near-identical points produces
///    wild angles.
class StrokeShape {
  StrokeShape._({
    required this.points,
    required this.segments,
    required this.bounds,
  });

  /// Even spacing, in logical pixels, that strokes are resampled to. Small
  /// enough to keep the letter's shape, large enough that hand tremor between
  /// raw samples doesn't read as a direction change.
  static const double resampleSpacing = 6;

  /// How many resampled points either side of a point its vectors are measured
  /// over. Larger = smoother, but blurs turns that sit close together.
  static const int window = 2;

  /// Angle change (degrees, at one point) below which the pen counts as going
  /// straight. Kept low on purpose: Sinhala is full of large, gentle curves,
  /// and a bend of 100px radius only turns a couple of degrees per sample — a
  /// coarser tolerance would make whole letters read as straight lines.
  static const double straightTolerance = 2;

  /// The stroke, resampled to [resampleSpacing].
  final List<Offset> points;

  /// The angle change at every point that has a full [window] either side, in
  /// drawing order.
  final List<AngleSegment> segments;

  final Rect bounds;

  /// Measures a stroke as drawn, resampling it to even spacing first.
  factory StrokeShape.fromPoints(List<Offset> raw) =>
      StrokeShape.fromResampled(_resample(raw, resampleSpacing));

  /// Measures a run of points that is *already* evenly spaced — used when
  /// cutting a stroke in two, so it isn't resampled twice.
  factory StrokeShape.fromResampled(List<Offset> points) {
    final segments = <AngleSegment>[];

    for (var i = window; i < points.length - window; i++) {
      final incoming = points[i] - points[i - window];
      final outgoing = points[i + window] - points[i];
      // The windows overlap, so a given bend is measured at `window` points in
      // a row. Divide it back out, otherwise the totals come out inflated by
      // that factor and a full loop reads ~720° instead of ~360°.
      final degrees = _signedAngleDegrees(incoming, outgoing) / window;
      segments.add(AngleSegment(
        index: i,
        point: points[i],
        degrees: degrees,
        direction: degrees.abs() < straightTolerance
            ? TurnDirection.straight
            : degrees > 0
                ? TurnDirection.left
                : TurnDirection.right,
      ));
    }

    return StrokeShape._(
      points: points,
      segments: segments,
      bounds: _boundsOf(points),
    );
  }

  Offset get start => points.first;
  Offset get end => points.last;

  // --- Angles -------------------------------------------------------------

  /// How far the stroke turned left in total, in degrees, ignoring any right
  /// turns. A full counter-clockwise loop is ~360.
  double get leftTotal => _totalFor(TurnDirection.left);

  /// How far the stroke turned right in total, in degrees.
  double get rightTotal => _totalFor(TurnDirection.right);

  /// Left minus right — where the stroke ended up pointing relative to where
  /// it set off, accumulated rather than measured end to end.
  double get netTurn => leftTotal - rightTotal;

  /// Every turn, both ways, added up — how much the stroke bends in total
  /// regardless of direction.
  double get totalTurn => leftTotal + rightTotal;

  double _totalFor(TurnDirection direction) => segments
      .where((s) => s.direction == direction)
      .fold(0.0, (sum, s) => sum + s.magnitude);

  /// Whether the stroke only ever bends left: it turns left by a real amount
  /// and any rightward bending is small enough to be hand wobble.
  ///
  /// [minimum] is how much left turning it takes to count as turning at all,
  /// and [tolerance] is the share of that which may go the other way.
  bool turnsLeftOnly({double minimum = 60, double tolerance = 0.15}) =>
      leftTotal >= minimum && rightTotal <= math.max(15, leftTotal * tolerance);

  /// The mirror of [turnsLeftOnly].
  bool turnsRightOnly({double minimum = 60, double tolerance = 0.15}) =>
      rightTotal >= minimum && leftTotal <= math.max(15, rightTotal * tolerance);

  /// How far a run of bending must add up to before it counts as the pen
  /// changing hand rather than wobbling.
  static const double minimumRunTurn = 25;

  /// The stroke cut wherever the bending changes hand: a piece that bends left
  /// throughout, then one that bends right throughout, and so on. Straight
  /// stretches belong to whichever bend they sit between, and the pieces are
  /// contiguous, so together they cover the whole stroke.
  ///
  /// This is the turn-direction counterpart of shorthand's
  /// `cutByVerticalDirectionChange` / `cutByHorizontalDirectionChange`, and it
  /// is what lets a rule talk about a letter in parts — "an arch, and then a
  /// hook the other way" — without hunting for corners.
  ///
  /// Each run carries the direction and the amount the segmentation found, and
  /// those are what a rule should read. Re-deriving the direction from the
  /// piece itself gives a different answer: a piece runs from the middle of the
  /// gap before it to the middle of the gap after, so it takes in the tail ends
  /// of its neighbours' bends and can measure the opposite way round. That put
  /// three right-hand runs in a row on a stroke whose bending changed hand
  /// three times.
  List<TurnRun> get turnRuns {
    final runs = <_Run>[];
    for (final segment in segments) {
      if (segment.isStraight) continue;
      if (runs.isNotEmpty && runs.last.direction == segment.direction) {
        runs.last.add(segment);
      } else {
        runs.add(_Run(segment));
      }
    }

    // A brief wobble the other way is not the pen changing hand. Drop the runs
    // that never amount to anything, then rejoin any neighbours left facing
    // the same way.
    final merged = <_Run>[];
    for (final run in runs.where((r) => r.total >= minimumRunTurn)) {
      if (merged.isNotEmpty && merged.last.direction == run.direction) {
        merged.last.absorb(run);
      } else {
        merged.add(run);
      }
    }
    if (merged.isEmpty) return const [];

    // Cut halfway across the straight stretch separating each pair of runs, so
    // no part of the stroke falls between the pieces.
    final cuts = <int>[0];
    for (var i = 1; i < merged.length; i++) {
      cuts.add((merged[i - 1].lastIndex + merged[i].firstIndex) ~/ 2);
    }
    cuts.add(points.length - 1);

    return [
      for (var i = 0; i < merged.length; i++)
        TurnRun(
          direction: merged[i].direction,
          degrees: merged[i].total,
          shape:
              StrokeShape.fromResampled(points.sublist(cuts[i], cuts[i + 1] + 1)),
        ),
    ];
  }

  /// How far a stretch must climb or fall before it counts as the pen changing
  /// vertical direction rather than wavering.
  static const double minimumRise = 10;

  /// The stroke cut wherever it changes vertical direction — where the pen
  /// stops climbing and starts descending, or the reverse.
  ///
  /// This is shorthand's `cutByVerticalDirectionChange`, which the angle work
  /// left unported. Counting these counts the humps in a zigzag, and a hump is
  /// a thing a hand keeps steady even when the bending and the crossings move
  /// about: one shape can put its extra turn in any run and cross itself any
  /// number of times, and still have the same number of humps.
  List<VerticalRun> get verticalRuns {
    final runs = <_VerticalRun>[];
    for (var i = 1; i < points.length; i++) {
      final drop = points[i].dy - points[i - 1].dy;
      if (drop == 0) continue;

      final up = drop < 0;
      if (runs.isNotEmpty && runs.last.up == up) {
        runs.last.add(i, drop.abs());
      } else {
        runs.add(_VerticalRun(up, i - 1, i, drop.abs()));
      }
    }

    // As with turnRuns: drop what never amounts to anything, then rejoin the
    // neighbours left going the same way.
    final merged = <_VerticalRun>[];
    for (final run in runs.where((r) => r.rise >= minimumRise)) {
      if (merged.isNotEmpty && merged.last.up == run.up) {
        merged.last.absorb(run);
      } else {
        merged.add(run);
      }
    }
    if (merged.isEmpty) return const [];

    // Contiguous pieces, cut halfway across whatever separates each pair.
    final cuts = <int>[0];
    for (var i = 1; i < merged.length; i++) {
      cuts.add((merged[i - 1].lastIndex + merged[i].firstIndex) ~/ 2);
    }
    cuts.add(points.length - 1);

    return [
      for (var i = 0; i < merged.length; i++)
        VerticalRun(
          goingUp: merged[i].up,
          rise: merged[i].rise,
          shape: StrokeShape.fromResampled(
              points.sublist(cuts[i], cuts[i + 1] + 1)),
        ),
    ];
  }

  // --- Self-intersection --------------------------------------------------

  /// How close two crossings must be before they are taken to be the same one
  /// found twice — which happens where a stroke cuts back over itself at a
  /// shallow angle and several segment pairs all overlap.
  static const double _sameCrossingDistance = resampleSpacing * 2;

  /// Every place the pen cut back over a part of the stroke it had already
  /// drawn, in drawing order.
  ///
  /// Searched once and cached: it is O(n²) in the number of points, which is
  /// cheap at ~130 points per letter but not worth repeating for every rule.
  List<Crossing> get crossings => _crossings ??= _findCrossings();
  List<Crossing>? _crossings;

  /// The first place, in drawing order, where the stroke crossed itself — or
  /// null if it never does.
  Crossing? get firstCrossing =>
      crossings.isEmpty ? null : crossings.first;

  List<Crossing> _findCrossings() {
    final found = <Crossing>[];
    // Outer loop over the *later* segment, so the crossings come out in the
    // order the pen made them. Segments that touch (or are one apart) always
    // "intersect" at their shared end, so they are skipped.
    for (var to = 2; to < points.length - 1; to++) {
      for (var from = 0; from < to - 1; from++) {
        final point = _segmentIntersection(
          points[from],
          points[from + 1],
          points[to],
          points[to + 1],
        );
        if (point == null) continue;
        if (found.any((c) =>
            (c.point - point).distance < _sameCrossingDistance)) {
          continue;
        }
        found.add(Crossing(point: point, fromIndex: from, toIndex: to));
      }
    }
    return found;
  }

  /// The stroke from its start up to where it first crossed itself — the loop
  /// the pen closed. Null if it never crosses itself.
  StrokeShape? get loopToCrossing {
    final crossing = firstCrossing;
    if (crossing == null) return null;
    return _sub([...points.sublist(0, crossing.toIndex + 1), crossing.point]);
  }

  /// How far along the stroke the pen had come when it first cut back over
  /// itself: 0 at the start, 1 at the end. Null if it never crosses.
  double? get crossingPosition {
    final crossing = firstCrossing;
    if (crossing == null || points.length < 2) return null;
    return crossing.toIndex / (points.length - 1);
  }

  /// The loop a crossing actually encloses: the run of stroke between the two
  /// places it met itself, taken from the crossing point round and back to it.
  ///
  /// Distinct from [loopToCrossing], which is everything up to the crossing
  /// including whatever led into it. This is the closed circle alone, so it is
  /// what to measure when the question is how big the loop is rather than how
  /// far the pen came before making it.
  StrokeShape? get closedLoop {
    final crossing = firstCrossing;
    if (crossing == null) return null;
    return _sub([
      crossing.point,
      ...points.sublist(crossing.fromIndex + 1, crossing.toIndex + 1),
      crossing.point,
    ]);
  }

  /// The stroke from where it first crossed itself through to the end — the
  /// tail hanging off the loop. Null if it never crosses itself.
  StrokeShape? get tailFromCrossing {
    final crossing = firstCrossing;
    if (crossing == null) return null;
    return _sub([crossing.point, ...points.sublist(crossing.toIndex + 1)]);
  }

  /// A sub-stroke, or null if there is not even a line's worth of it.
  ///
  /// A piece shorter than [window] either side of a point has no measurable
  /// angles, and gets no [segments] — but it still has a start, an end and
  /// bounds, which is all a rule needs when it only asks where the piece went.
  /// The turn totals of such a piece are 0, so [turnsLeftOnly] and
  /// [turnsRightOnly] both refuse it rather than claiming a direction that was
  /// never measured.
  static StrokeShape? _sub(List<Offset> points) =>
      points.length < 2 ? null : StrokeShape.fromResampled(points);

  // --- Position -----------------------------------------------------------

  /// Whether the pen finished higher up the page than it started, by a margin
  /// scaled to the stroke's own height (so it means the same whether the
  /// letter was drawn big or small). Screen y points down, hence the `<`.
  bool get endsAboveStart => end.dy < start.dy - bounds.height * 0.15;

  /// Whether the pen finished lower down the page than it started.
  bool get endsBelowStart => end.dy > start.dy + bounds.height * 0.15;

  /// Whether the pen finished in the right-hand half of the stroke's own
  /// bounding box.
  bool get endsInRightHalf => end.dx > bounds.center.dx;

  /// Whether the pen set off from the left-hand half of the stroke's own
  /// bounding box.
  bool get startsInLeftHalf => start.dx < bounds.center.dx;

  /// Whether the pen finished in the left-hand half of the stroke's own
  /// bounding box.
  ///
  /// Both ends being over there is what makes a curve open leftward: a Ɔ keeps
  /// its tips on the left, a C on the right.
  bool get endsInLeftHalf => end.dx < bounds.center.dx;

  /// Whether the stroke set off from its own lowest point — drawn from the
  /// bottom up.
  bool get startsAtBottom => start.dy > bounds.bottom - bounds.height * 0.15;

  /// Whether the stroke finished at its own highest point — the pen carried up
  /// past everything else it had drawn.
  bool get endsAtTop => end.dy < bounds.top + bounds.height * 0.15;

  /// Whether the stroke finished at its own lowest point — the pen carried
  /// down past everything else it had drawn.
  ///
  /// The mirror of [startsAtBottom]. Nothing reads it yet; it is here for 𑇤,
  /// whose description turns on the stroke finishing below the rest of itself.
  bool get endsAtBottom => end.dy > bounds.bottom - bounds.height * 0.15;

  /// Whether the stroke goes both above and below the height it set off from.
  ///
  /// Only that it happens, not how often: the margin either side is a jitter
  /// floor, not a demand that the stroke travel any distance up or down.
  bool get passesAboveAndBelowStart =>
      bounds.top < start.dy - bounds.height * 0.05 &&
      bounds.bottom > start.dy + bounds.height * 0.05;

  /// Whether the pen finished below and to the right of [point], by more than
  /// hand jitter.
  ///
  /// Useful against a [Crossing], where the question is not where the stroke
  /// started but which way it left the loop it had just closed.
  bool endsBelowRightOf(Offset point) =>
      end.dy > point.dy + bounds.height * 0.05 &&
      end.dx > point.dx + bounds.width * 0.05;

  /// Whether the stroke climbs to a high point somewhere in its middle and
  /// then comes back down — an arch, rather than a stroke that only rises or
  /// only falls. Both ends have to sit clearly below the top, by a margin
  /// scaled to the stroke's own height.
  bool get risesThenDescends {
    var top = points.first;
    for (final point in points) {
      if (point.dy < top.dy) top = point;
    }
    final margin = bounds.height * 0.15;
    return top.dy < start.dy - margin && top.dy < end.dy - margin;
  }

  /// Which side [point] lies on, judged against the straight line from the
  /// stroke's start to its end — left and right meaning as the pen faced while
  /// drawing it, the same sense as the turn directions.
  ///
  /// Anything within [minimumDistance] of that line is [TurnDirection.straight]
  /// rather than being forced to one side.
  TurnDirection sideOf(Offset point, {double minimumDistance = 2}) {
    final along = end - start;
    if (along.distance == 0) return TurnDirection.straight;

    final toPoint = point - start;
    // Screen y points down, so the cross product is flipped to keep "left" the
    // same way round as it is for the angles.
    final cross = along.dy * toPoint.dx - along.dx * toPoint.dy;
    final distance = cross / along.distance;

    if (distance.abs() < minimumDistance) return TurnDirection.straight;
    return distance > 0 ? TurnDirection.left : TurnDirection.right;
  }

  double get aspect => bounds.height == 0 ? 999 : bounds.width / bounds.height;

  /// The direction the pen was travelling as it finished.
  ///
  /// Measured back over the last short stretch rather than from the final pair
  /// of samples, so a wobble as the pen lifts doesn't decide it.
  Offset get endDirection {
    final back = math.min(window * 2, points.length - 1);
    return end - points[points.length - 1 - back];
  }

  /// The shallowest a rise can be and still count as the stroke pointing up:
  /// the climb must be at least this share of the sideways run, which puts the
  /// limit at about 27° off the horizontal.
  ///
  /// A tail flicked up and away at 45° is pointing up by any reading, so this
  /// is not "more up than sideways" — that would turn away half the diagonals.
  /// It only rules out a stroke running off sideways with a slight lift.
  static const double _upwardSlope = 0.5;

  /// Whether the stroke finishes climbing more steeply than it runs sideways —
  /// a vertical line rather than a flick away on the diagonal. Says nothing
  /// about how long that line is.
  ///
  /// Stricter than [endsPointingUp], which takes anything past about 27° so
  /// that ෪'s diagonal tail counts. "A vertical line" is a different claim and
  /// gets a different measurement.
  bool get endsVertically {
    final direction = endDirection;
    return direction.dy < 0 && direction.dy.abs() > direction.dx.abs();
  }

  /// Whether the stroke finishes travelling upward, at more than a shallow
  /// angle — a tail that rises rather than one trailing off to a side.
  bool get endsPointingUp {
    final direction = endDirection;
    return direction.dy < 0 &&
        direction.dy.abs() > direction.dx.abs() * _upwardSlope;
  }

  @override
  String toString() => 'StrokeShape(left: ${leftTotal.round()}°, '
      'right: ${rightTotal.round()}°, net: ${netTurn.round()}°, '
      'endsAbove: $endsAboveStart, '
      'crossings: ${crossings.length}, '
      'points: ${points.length})';
}

/// A run of one vertical direction being accumulated by
/// [StrokeShape.verticalRuns].
class _VerticalRun {
  _VerticalRun(this.up, this.firstIndex, this.lastIndex, this.rise);

  final bool up;
  final int firstIndex;
  int lastIndex;
  double rise;

  void add(int index, double drop) {
    lastIndex = index;
    rise += drop;
  }

  void absorb(_VerticalRun other) {
    lastIndex = other.lastIndex;
    rise += other.rise;
  }
}

/// A run of same-handed bending being accumulated by [StrokeShape.turnRuns].
class _Run {
  _Run(AngleSegment first)
      : direction = first.direction,
        firstIndex = first.index,
        lastIndex = first.index,
        total = first.magnitude;

  final TurnDirection direction;
  final int firstIndex;
  int lastIndex;
  double total;

  void add(AngleSegment segment) {
    lastIndex = segment.index;
    total += segment.magnitude;
  }

  void absorb(_Run other) {
    lastIndex = other.lastIndex;
    total += other.total;
  }
}

/// The turn from vector [incoming] to vector [outgoing], in degrees,
/// normalized to (-180, 180]. **Left is positive.**
///
/// This is shorthand's `atan2(cross, dot)`, with the cross product's sign
/// flipped because screen y points down: without the flip a left turn as drawn
/// would come out negative.
double _signedAngleDegrees(Offset incoming, Offset outgoing) {
  if (incoming.distance == 0 || outgoing.distance == 0) return 0;
  final dot = incoming.dx * outgoing.dx + incoming.dy * outgoing.dy;
  final cross = incoming.dy * outgoing.dx - incoming.dx * outgoing.dy;
  return math.atan2(cross, dot) * 180 / math.pi;
}

/// Where segments p1→p2 and p3→p4 cross, or null if they don't (or run
/// parallel). Standard parametric line-line intersection, with both parameters
/// required to land inside their own segment.
Offset? _segmentIntersection(Offset p1, Offset p2, Offset p3, Offset p4) {
  final r = p2 - p1;
  final s = p4 - p3;
  final denominator = r.dx * s.dy - r.dy * s.dx;
  if (denominator == 0) return null;

  final gap = p3 - p1;
  final t = (gap.dx * s.dy - gap.dy * s.dx) / denominator;
  final u = (gap.dx * r.dy - gap.dy * r.dx) / denominator;
  if (t < 0 || t > 1 || u < 0 || u > 1) return null;

  return p1 + r * t;
}

/// Redraws [points] with a constant [spacing] between them.
List<Offset> _resample(List<Offset> points, double spacing) {
  final result = <Offset>[points.first];
  var previous = points.first;
  var carried = 0.0;

  for (var i = 1; i < points.length; i++) {
    final segment = points[i] - previous;
    final length = segment.distance;
    if (length == 0) continue;

    if (carried + length < spacing) {
      carried += length;
      previous = points[i];
      continue;
    }

    // Walk along this segment dropping a point every [spacing].
    var travelled = spacing - carried;
    while (travelled <= length) {
      result.add(previous + segment * (travelled / length));
      travelled += spacing;
    }
    carried = length - (travelled - spacing);
    previous = points[i];
  }

  if (result.last != points.last) result.add(points.last);
  return result;
}

Rect _boundsOf(List<Offset> points) {
  var minX = points.first.dx, maxX = points.first.dx;
  var minY = points.first.dy, maxY = points.first.dy;
  for (final p in points) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}
