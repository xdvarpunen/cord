/// Recognising a freehand stroke as one of the Unicode CJK Strokes.
///
/// The sibling projects hand-write a classifier per letter — `tifi` runs to
/// some 2,600 lines of bespoke geometry. Nothing like that is needed here,
/// because the generated table already contains a reference median for every
/// stroke type in every language that uses it. So this is template matching:
/// resample the drawn stroke, resample each reference the same way, and take
/// the nearest.
///
/// That also means recognition improves for free whenever the data is
/// regenerated, and a stroke type gains a template the moment it gains an
/// example.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../data/hanzi_strokes.dart';
import '../data/stroke_models.dart';
import '../geometry/polyline.dart';
import '../geometry/topology.dart';
import '../svg/path_parser.dart';

/// Points each stroke is resampled to before comparison. Enough to keep the
/// shape of a four-turn stroke like ㇡, cheap enough to compare against every
/// template on each pen-up.
const int kResampleCount = 32;

/// A drawn mark shorter than this fraction of the canvas is treated as a dot
/// rather than a drag. Dots are a legitimate stroke (㇔) but normalising one
/// blows it up into something indistinguishable from a full-length 捺, so the
/// two pools are compared separately.
const double kDotFraction = 0.10;

/// A reference stroke shorter than this fraction of the glyph box counts as a
/// dot. Measured, not guessed: across all 78 templates the 点 entries span
/// 202–265 units of 1024, and the next smallest stroke (提) is 318, so the
/// boundary sits comfortably in the gap between them.
const double kDotExtentFraction = 0.28;

/// One candidate reading of a drawn stroke.
class StrokeMatch {
  const StrokeMatch({
    required this.type,
    required this.lang,
    required this.distance,
  });

  final StrokeType type;

  /// Which language's example matched. The same type usually has two or three
  /// templates, drawn in different styles.
  final Lang lang;

  /// Mean distance per resampled point, in normalised units. Lower is better;
  /// roughly, below 0.10 is a confident match.
  final double distance;

  /// 0..1, for display. Not a probability — just a readable inverse of
  /// [distance].
  double get confidence => (1 - distance * 4).clamp(0.0, 1.0);
}

/// Cost of disagreeing with a template about whether the stroke loops over
/// itself.
///
/// A single stroke's only topology is self-intersection, and almost every CJK
/// stroke has none — so this is mostly a guard against a looped scribble
/// matching a simple stroke. Sized to matter without overriding shape, since
/// resampling can occasionally invent or lose a crossing on a tight hook.
const double kSelfIntersectionPenalty = 0.05;

/// A reference stroke, resampled and ready to compare against.
class StrokeTemplate {
  const StrokeTemplate(
      this.type, this.lang, this.points, this.isDot, this.loops);

  final StrokeType type;
  final Lang lang;

  /// Normalised, [kResampleCount] points long.
  final List<Offset> points;

  /// Whether the reference is a dot rather than a travelling stroke.
  final bool isDot;

  /// How many times the reference crosses its own path.
  final int loops;
}

List<StrokeTemplate>? _templates;

/// Every reference stroke, normalised and resampled. Built once, lazily.
///
/// A type with examples in all three languages contributes three templates —
/// the styles differ enough that treating them separately helps rather than
/// averaging them into a blur.
List<StrokeTemplate> get templates => _templates ??= [
      for (final type in strokeTypes)
        for (final entry in type.examples.entries)
          if (_medianOf(entry.value) case final median?)
            StrokeTemplate(
              type,
              entry.key,
              resample(median, kResampleCount),
              _isDotShaped(median),
              // Counted on the resampled form, so the drawn stroke — which is
              // resampled the same way — is judged on equal terms.
              selfIntersections(resample(median, kResampleCount)),
            ),
    ];

List<Offset>? _medianOf(StrokeExample example) {
  final glyph = strokeGlyphs[example.glyphKey];
  if (glyph == null || example.strokeIndex >= glyph.medians.length) return null;
  final pts = medianToScreen(glyph.source, glyph.medians[example.strokeIndex]);
  return pts.length >= 2 ? pts : null;
}

/// A reference stroke whose extent is small relative to the glyph box — 点 and
/// friends.
bool _isDotShaped(List<Offset> points) {
  final bounds = _bounds(points);
  return math.max(bounds.width, bounds.height) <
      kStrokeViewBox * kDotExtentFraction;
}

/// Recognises [drawn] against every template, best first.
///
/// [canvasSize] is only used to decide whether the input was a dot; the shape
/// comparison itself is scale-free.
///
/// Returns an empty list for input too short to be a stroke at all.
List<StrokeMatch> recognizeStroke(List<Offset> drawn, Size canvasSize) {
  if (drawn.length < 2) return const [];

  final extent = math.max(_bounds(drawn).width, _bounds(drawn).height);
  final canvasExtent = math.max(canvasSize.shortestSide, 1.0);
  final drawnIsDot = extent < canvasExtent * kDotFraction;

  final sample = resample(drawn, kResampleCount);

  // A dot compared against a long stroke is meaningless once both are scaled to
  // the same box — they would look alike. Compare like with like.
  var pool = templates.where((t) => t.isDot == drawnIsDot).toList();
  // ...but never answer "nothing" for a real stroke just because the pool came
  // out empty. If the data ever stops containing any dot-sized reference, fall
  // back to the whole set rather than silently returning no result at all.
  if (pool.isEmpty) pool = templates;

  // A stroke's own topology is whether it loops over itself — the one thing
  // point-by-point comparison cannot see, since a loop and a fold occupy much
  // the same positions.
  final loops = selfIntersections(sample);

  final matches = [
    for (final template in pool)
      StrokeMatch(
        type: template.type,
        lang: template.lang,
        distance: _meanDistance(sample, template.points) +
            kSelfIntersectionPenalty * (loops - template.loops).abs(),
      ),
  ];

  matches.sort((a, b) => a.distance.compareTo(b.distance));

  // Collapse to one entry per stroke type — the best-matching language for it.
  final seen = <String>{};
  return [
    for (final m in matches)
      if (seen.add(m.type.codePoint)) m,
  ];
}

/// Resamples to [count] points evenly spaced **by arc length**, then normalises
/// into a box centred on the origin.
///
/// Scaling is **uniform**, which matters: 横 is wide and flat, 竖 tall and
/// narrow, and squashing each into a square would erase exactly the difference
/// between them.
List<Offset> resample(List<Offset> points, int count) {
  final line = Polyline(points);
  final sampled = [
    for (var i = 0; i < count; i++) line.pointAt(i / (count - 1)),
  ];

  final bounds = _bounds(sampled);
  final scale = math.max(bounds.width, bounds.height);
  final centre = bounds.center;
  if (scale < 1e-6) {
    return [for (final _ in sampled) Offset.zero];
  }
  return [for (final p in sampled) (p - centre) / scale];
}

double _meanDistance(List<Offset> a, List<Offset> b) {
  var total = 0.0;
  for (var i = 0; i < a.length && i < b.length; i++) {
    total += (a[i] - b[i]).distance;
  }
  return total / a.length;
}

Rect _bounds(List<Offset> points) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in points) {
    minX = math.min(minX, p.dx);
    minY = math.min(minY, p.dy);
    maxX = math.max(maxX, p.dx);
    maxY = math.max(maxY, p.dy);
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}
