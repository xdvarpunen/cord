/// Recognising a whole hand-drawn character.
///
/// Same idea as [recognizeStroke], one level up: the generated table holds
/// every stroke of every glyph, so a drawn character is compared against each
/// candidate stroke by stroke.
///
/// The interesting part is that it scores twice. Once **in order**, pairing the
/// drawn stroke *i* with the reference stroke *i*, and once **ignoring order**,
/// matching each drawn stroke to whichever reference stroke it best fits. The
/// gap between the two separates "you drew the wrong character" from "you drew
/// the right character in a different order" — and since the same character is
/// stored under `ZH:`, `JA:` and `KO:` keys with each tradition's own order,
/// that also answers *whose* order you used.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../data/hanzi_strokes.dart';
import '../data/stroke_models.dart';
import '../geometry/topology.dart';
import '../svg/path_parser.dart';
import 'stroke_recognizer.dart';

/// Points per stroke. Lower than [kResampleCount] because a character compares
/// many strokes at once and only the gross shape of each one matters here.
const int kCharacterResampleCount = 16;

/// Below this mean distance a reading is worth showing at all.
const double kCharacterCutoff = 0.28;

/// How heavily a disagreement about how strokes meet counts against a match.
///
/// Chosen by sweeping against the measurement that exposed the problem — the
/// number of confusable characters whose nearest match disagreed about how many
/// strokes cross — and taking the smallest value that drives it to zero. The
/// sweep lives in `test/topology_metric_test.dart`, and ran
/// 0.0 → 10, 0.2 → 9, 0.3 → 6, 0.4 → 2, 0.58 → 1, **0.60 → 0**.
///
/// Shape distances between genuinely different characters sit around 0.12–0.16,
/// so a weight of this size lets a wholly wrong topology outrank a small
/// difference in shape — precisely the 田/由 case, where placement is nearly
/// identical and only the crossing differs.
const double kTopologyWeight = 0.6;

/// How one glyph variant scored against what was drawn.
class CharacterMatch {
  const CharacterMatch({
    required this.char,
    required this.lang,
    required this.glyphKey,
    required this.orderedDistance,
    required this.unorderedDistance,
    required this.assignment,
    required this.shapeDistance,
    required this.topologyPenalty,
  });

  final String char;
  final Lang lang;
  final String glyphKey;

  /// Cost pairing drawn stroke *i* with reference stroke *i*. Sensitive to the
  /// order strokes were written in.
  final double orderedDistance;

  /// Cost allowing any pairing. Insensitive to order, so it measures whether
  /// the right marks are on the page at all.
  final double unorderedDistance;

  /// Which reference stroke each drawn stroke was matched to, ignoring order.
  final List<int> assignment;

  /// The two halves of [unorderedDistance], before weighting:
  /// `unorderedDistance == shapeDistance + kTopologyWeight * topologyPenalty`.
  ///
  /// Exposed so the weighting can be measured and tuned against real data
  /// rather than guessed at — see the sweep in `test/topology_metric_test.dart`.
  final double shapeDistance;

  /// 0..1. How much the drawn strokes disagree with this glyph about *how they
  /// meet* — crossing, T-junction, touching at the ends, or not at all.
  final double topologyPenalty;

  /// Whether the strokes were written in this variant's order.
  bool get orderMatches {
    for (var i = 0; i < assignment.length; i++) {
      if (assignment[i] != i) return false;
    }
    return true;
  }

  /// First stroke written out of this variant's order, or -1.
  int get firstOutOfOrder {
    for (var i = 0; i < assignment.length; i++) {
      if (assignment[i] != i) return i;
    }
    return -1;
  }

  /// The score used for ranking: shape first, since a character drawn in an
  /// unusual order is still that character.
  double get score => unorderedDistance;

  /// 0..1, for display. Not a probability.
  double get confidence => (1 - unorderedDistance * 3.2).clamp(0.0, 1.0);
}

/// Recognises [strokes] — one entry per stroke, in the order they were drawn.
///
/// Only characters present in the bundled table can be found; it is a stroke
/// reference, not a dictionary. Returns at most one entry per character, best
/// first, using whichever language variant fits best.
///
/// [orderSensitive] decides whether the sequence counts. Off — the default —
/// ranking uses [CharacterMatch.score], so a character written in an unusual
/// order is still that character; that is what the free-drawing tab wants. On,
/// ranking uses [CharacterMatch.orderedDistance], so writing the right shape in
/// the wrong sequence drops the match. Practice pages want that, and it is why
/// the flag exists rather than one behaviour being imposed on both.
///
/// [where] narrows the field to the glyphs it accepts. **This parameter is
/// cord's one addition to this file, which is otherwise upstream `hanzi`'s
/// verbatim** — that project recognises against everything it carries, having
/// no script selector. Additive and defaulted to null, so the behaviour with
/// it omitted is exactly upstream's; see `lib/hanzi/data/hanzi_scripts.dart`
/// for what passes it. Filtering here rather than over the results matters:
/// the returned list holds one row per *character*, already collapsed to
/// whichever variant fitted best, so filtering afterwards would report the
/// wrong variant's score — or drop a character whose best fit happened to be
/// a tradition you had not selected.
List<CharacterMatch> recognizeCharacter(
  List<List<Offset>> strokes, {
  bool orderSensitive = false,
  bool Function(String glyphKey, CharGlyph glyph)? where,
}) {
  final usable = strokes.where((s) => s.length >= 2).toList();
  if (usable.isEmpty) return const [];

  final drawn = _normalizeStrokes(usable);
  final drawnTopology = topologyOf(drawn);

  final matches = <CharacterMatch>[];
  for (final entry in strokeGlyphs.entries) {
    final glyph = entry.value;
    // Stroke count is a hard gate: it is the cheapest and most reliable signal,
    // and comparing a 4-stroke attempt against a 12-stroke glyph is noise.
    if (glyph.medians.length != drawn.length) continue;
    if (where != null && !where(entry.key, glyph)) continue;

    final match = _score(entry.key, glyph, drawn, drawnTopology);
    if (match != null) matches.add(match);
  }

  double rank(CharacterMatch m) =>
      orderSensitive ? m.orderedDistance : m.score;
  matches.sort((a, b) => rank(a).compareTo(rank(b)));

  // One row per character: the language variant it fitted best.
  final seen = <String>{};
  return [
    for (final m in matches)
      if (rank(m) <= kCharacterCutoff && seen.add(m.char)) m,
  ];
}

/// Every language variant of [char] that the table holds, best fit first.
///
/// This is what answers "whose stroke order did I use?" — the same character
/// under each tradition, scored separately.
List<CharacterMatch> variantsFor(List<List<Offset>> strokes, String char) {
  final usable = strokes.where((s) => s.length >= 2).toList();
  if (usable.isEmpty) return const [];
  final drawn = _normalizeStrokes(usable);
  final drawnTopology = topologyOf(drawn);

  final out = <CharacterMatch>[];
  for (final entry in strokeGlyphs.entries) {
    final glyph = entry.value;
    if (glyph.char != char || glyph.medians.length != drawn.length) continue;
    final match = _score(entry.key, glyph, drawn, drawnTopology);
    if (match != null) out.add(match);
  }
  out.sort((a, b) => a.orderedDistance.compareTo(b.orderedDistance));
  return out;
}

Lang _langOf(String glyphKey) => switch (glyphKey.split(':').first) {
      'JA' => Lang.ja,
      'KO' => Lang.ko,
      _ => Lang.zh,
    };

/// Scores one stored glyph against what was drawn, on shape *and* topology.
///
/// Both distances get the topology penalty, each against its own pairing:
/// [CharacterMatch.orderedDistance] assumes stroke *i* is stroke *i*, while
/// [CharacterMatch.unorderedDistance] uses the best assignment. Scoring them
/// consistently keeps `orderMatches` meaningful.
CharacterMatch? _score(
  String glyphKey,
  CharGlyph glyph,
  List<List<Offset>> drawn,
  List<List<JunctionKind>> drawnTopology,
) {
  final reference = _referenceStrokes(glyphKey, glyph);
  if (reference.length != drawn.length) return null;

  final assigned = _bestAssignmentCost(drawn, reference);
  final referenceTopology = _referenceTopology(glyphKey, glyph, reference);
  final identity = [for (var i = 0; i < drawn.length; i++) i];

  final topology =
      topologyMismatch(drawnTopology, referenceTopology, assigned.assignment);
  final orderedTopology =
      topologyMismatch(drawnTopology, referenceTopology, identity);

  return CharacterMatch(
    char: glyph.char,
    lang: _langOf(glyphKey),
    glyphKey: glyphKey,
    orderedDistance:
        _orderedCost(drawn, reference) + kTopologyWeight * orderedTopology,
    unorderedDistance: assigned.cost + kTopologyWeight * topology,
    assignment: assigned.assignment,
    shapeDistance: assigned.cost,
    topologyPenalty: topology,
  );
}

/// Normalised reference strokes, cached: every pen-up would otherwise redo this
/// for each of the 231 stored glyphs.
final Map<String, List<List<Offset>>> _referenceCache = {};

List<List<Offset>> _referenceStrokes(String glyphKey, CharGlyph glyph) =>
    _referenceCache[glyphKey] ??= _normalizeStrokes([
      for (var i = 0; i < glyph.medians.length; i++)
        medianToScreen(glyph.source, glyph.medians[i]),
    ]);

/// Junction matrices for the stored glyphs, cached for the same reason —
/// building one is quadratic in strokes and in points.
final Map<String, List<List<JunctionKind>>> _topologyCache = {};

/// The stored glyph's junction matrix, **measured the same way the drawn input
/// is** rather than read from [CharGlyph.junctions].
///
/// That looks like the wrong choice — the stored junctions are exact, taken
/// from the source SVG, while this re-measures from simplified medians. It was
/// tried the other way and reverted on the evidence:
///
/// Handwriting has no SVG, so the drawn side can only ever be estimated. Making
/// the reference exact while the input stays estimated means the two disagree
/// wherever the estimator is imperfect — and although it agrees with the SVG on
/// 98% of individual stroke pairs, a single disagreeing pair taints a whole
/// character. Tracing each stored glyph *exactly* then produced a topology
/// penalty on **53% of them**, up to 0.33. A perfectly drawn character being
/// marked down is a worse failure than the imprecision this was meant to fix.
///
/// Comparing like with like keeps the bias on both sides where it cancels. The
/// exact junctions are still worth having: they are what the estimator was
/// calibrated against, and what the detail pages draw.
List<List<JunctionKind>> _referenceTopology(
  String glyphKey,
  CharGlyph glyph,
  List<List<Offset>> reference,
) =>
    _topologyCache[glyphKey] ??= topologyOf(reference);

/// Drops both caches. For tests that change the weighting and want a clean run.
void clearRecognitionCaches() {
  _referenceCache.clear();
  _topologyCache.clear();
}

/// Resamples every stroke and normalises them **together**, against the bounding
/// box of the whole character.
///
/// Normalising each stroke on its own would throw away where it sits and how
/// big it is relative to the others — which is most of what distinguishes one
/// character from another.
List<List<Offset>> _normalizeStrokes(List<List<Offset>> strokes) {
  final sampled = [
    for (final s in strokes)
      if (s.length >= 2) _resamplePlain(s, kCharacterResampleCount),
  ];
  if (sampled.isEmpty) return const [];

  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final s in sampled) {
    for (final p in s) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
  }
  final scale = math.max(maxX - minX, maxY - minY);
  if (scale < 1e-6) return sampled;
  final centre = Offset((minX + maxX) / 2, (minY + maxY) / 2);

  return [
    for (final s in sampled) [for (final p in s) (p - centre) / scale],
  ];
}

/// Arc-length resample without the per-stroke normalisation that
/// [resample] applies — normalisation happens across the whole character.
List<Offset> _resamplePlain(List<Offset> points, int count) {
  final lengths = <double>[0];
  var total = 0.0;
  for (var i = 0; i + 1 < points.length; i++) {
    total += (points[i + 1] - points[i]).distance;
    lengths.add(total);
  }
  if (total < 1e-9) return [for (var i = 0; i < count; i++) points.first];

  final out = <Offset>[];
  for (var k = 0; k < count; k++) {
    final target = total * k / (count - 1);
    var i = 0;
    while (i + 2 < lengths.length && lengths[i + 1] < target) {
      i++;
    }
    final span = lengths[i + 1] - lengths[i];
    final f = span <= 0 ? 0.0 : ((target - lengths[i]) / span).clamp(0.0, 1.0);
    out.add(Offset.lerp(points[i], points[i + 1], f)!);
  }
  return out;
}

double _strokeCost(List<Offset> a, List<Offset> b) {
  var total = 0.0;
  for (var i = 0; i < a.length && i < b.length; i++) {
    total += (a[i] - b[i]).distance;
  }
  return total / a.length;
}

double _orderedCost(List<List<Offset>> drawn, List<List<Offset>> reference) {
  var total = 0.0;
  for (var i = 0; i < drawn.length; i++) {
    total += _strokeCost(drawn[i], reference[i]);
  }
  return total / drawn.length;
}

/// Greedy best pairing of drawn strokes to reference strokes, ignoring order.
({double cost, List<int> assignment}) _bestAssignmentCost(
  List<List<Offset>> drawn,
  List<List<Offset>> reference,
) {
  final pairs = <({int d, int r, double cost})>[];
  for (var d = 0; d < drawn.length; d++) {
    for (var r = 0; r < reference.length; r++) {
      pairs.add((d: d, r: r, cost: _strokeCost(drawn[d], reference[r])));
    }
  }
  pairs.sort((a, b) => a.cost.compareTo(b.cost));

  final assignment = List.filled(drawn.length, -1);
  final used = <int>{};
  var total = 0.0;
  for (final p in pairs) {
    if (assignment[p.d] != -1 || used.contains(p.r)) continue;
    assignment[p.d] = p.r;
    used.add(p.r);
    total += p.cost;
  }
  return (cost: total / drawn.length, assignment: assignment);
}
