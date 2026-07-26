/// Data shapes backing the generated table in `hanzi_strokes.dart`.
///
/// Everything here is `const`-constructible so the whole table lives in the
/// binary with no parsing or asset loading at startup.
library;

import 'dart:ui' show Offset;

/// How two strokes meet.
///
/// Lives here rather than in `lib/geometry/` because the generated table stores
/// it: the junctions are extracted from the SVG at build time, not measured at
/// runtime.
enum JunctionKind {
  /// They never come near each other.
  none,

  /// They meet at an end of both.
  touch,

  /// An end of one lands in the middle of the other — 人's 捺 on its 丿, 丁, 上.
  tee,

  /// They meet in the middle of both — 十, 九, 中.
  cross,
}

/// Where two strokes of a glyph meet, taken from the source SVG.
///
/// Exact rather than estimated. makemeahanzi and animCJK cut each stroke's
/// filled outline where another crosses it and reuse the identical
/// coordinates, so the shared vertices *are* the junction — four corners bound
/// a crossing, two a stroke ending against another. KanjiVG stores centrelines
/// instead, which simply intersect.
class Junction {
  const Junction({
    required this.a,
    required this.b,
    required this.kind,
    required this.x,
    required this.y,
  });

  /// Indices of the two strokes, `a < b`.
  final int a;
  final int b;

  final JunctionKind kind;

  /// Where they meet, in the source's own raw coordinates — the same space as
  /// [CharGlyph.medians], so the same transform applies.
  final double x;
  final double y;

  Offset get point => Offset(x, y);

  bool involves(int stroke) => a == stroke || b == stroke;
}

/// The three languages that share the Han characters — the C, J and K of "CJK".
///
/// Korean coverage is thin by nature: animCJK carries 535 hanja against
/// thousands of Chinese and Japanese characters, so a missing Korean column is
/// normal and is shown rather than hidden.
enum Lang {
  zh(label: '中', name: 'Chinese', source: 'makemeahanzi'),
  ja(label: '日', name: 'Japanese', source: 'KanjiVG'),
  ko(label: '한', name: 'Korean', source: 'animCJK');

  const Lang({required this.label, required this.name, required this.source});

  final String label;
  final String name;
  final String source;
}

/// Where a glyph's geometry came from. The sources agree on almost no
/// convention, so the renderer has to know which it is holding.
enum GlyphSource {
  /// makemeahanzi (via hanzi-writer-data): 1024-unit box, **y-up** (upper-left
  /// is `(0, 900)`), paths are filled outlines, medians supplied separately.
  makemeahanzi(viewBox: 1024, flipY: true, filled: true),

  /// KanjiVG: 109-unit box, ordinary y-down, paths are centrelines meant to be
  /// stroked. Medians are sampled from those same paths at build time.
  kanjivg(viewBox: 109, flipY: false, filled: false),

  /// animCJK: 1024-unit box, ordinary y-down, filled outlines with medians as
  /// separate polylines. The only source needing no transform at all.
  animcjk(viewBox: 1024, flipY: false, filled: true);

  const GlyphSource({
    required this.viewBox,
    required this.flipY,
    required this.filled,
  });

  /// Side of the square the source draws in, in its own units.
  final double viewBox;

  /// Whether y must be flipped to reach screen coordinates.
  final bool flipY;

  /// Whether paths are filled outlines (true) or centrelines to stroke (false).
  final bool filled;
}

/// One character's geometry from one source.
///
/// [outlines], [medians] and [types] are parallel: entry *i* of each describes
/// stroke *i*, in that source's writing order — which is the whole point of
/// [OrderComparison], since the sources do not always agree on it.
class CharGlyph {
  const CharGlyph({
    required this.char,
    required this.source,
    required this.outlines,
    required this.medians,
    required this.types,
    this.junctions = const [],
  });

  final String char;
  final GlyphSource source;

  /// SVG path data per stroke, in [source]'s own coordinates.
  final List<String> outlines;

  /// Centreline per stroke, flattened to `[x0, y0, x1, y1, ...]`.
  ///
  /// The first point is where the stroke *starts* and the last is where it
  /// *ends*, in the direction it is written.
  final List<List<double>> medians;

  /// Unicode CJK Strokes codepoint per stroke, or null where no source could
  /// say. KanjiVG labels these natively; Chinese is mapped from cnchar's names
  /// and Korean is transferred from KanjiVG by geometric matching.
  final List<String?> types;

  /// Where the strokes meet, read out of the source SVG at build time. Only
  /// meeting pairs appear; anything absent is [JunctionKind.none].
  final List<Junction> junctions;

  /// The junction between strokes [a] and [b], or [JunctionKind.none].
  JunctionKind junctionBetweenStrokes(int a, int b) {
    final lo = a < b ? a : b;
    final hi = a < b ? b : a;
    for (final j in junctions) {
      if (j.a == lo && j.b == hi) return j.kind;
    }
    return JunctionKind.none;
  }
}

/// One language's demonstration of a stroke type.
class StrokeExample {
  const StrokeExample({
    required this.glyphKey,
    required this.strokeIndex,
    required this.directions,
  });

  /// Key into `strokeGlyphs`.
  final String glyphKey;
  final int strokeIndex;

  /// Compass headings derived from this stroke's median geometry, e.g.
  /// `['E', 'S']`. Derived, not read off the name.
  final List<String> directions;
}

/// One of the 38 assigned Unicode CJK Strokes (U+31C0–U+31E5).
///
/// This block is the public, language-neutral taxonomy — KanjiVG tags Japanese
/// kanji with exactly these codepoints, which is why it can key every column.
class StrokeType {
  const StrokeType({
    required this.codePoint,
    required this.letter,
    required this.zh,
    required this.gloss,
    required this.examples,
  });

  /// The stroke character itself, e.g. `㇕`. Drawn from vector data rather than
  /// rendered as text — U+31C0–U+31E5 is not reliably present in web fonts.
  final String codePoint;

  /// Unicode's abbreviation, the initials of the Chinese name: `HZG` for 横折钩.
  final String letter;

  /// Chinese name, e.g. `横折`.
  final String zh;

  /// Plain-English gloss, e.g. `horizontal + turn`.
  final String gloss;

  /// Per language, a character demonstrating this stroke. A language is absent
  /// when no example was found — which for six of the 38 means every language.
  final Map<Lang, StrokeExample> examples;

  bool has(Lang lang) => examples.containsKey(lang);
  Iterable<Lang> get languages => examples.keys;

  /// `U+31D5` for display; the glyph itself usually will not render.
  String get hex =>
      'U+${codePoint.runes.first.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  /// The direction sequence, taken from whichever language has an example.
  /// They agree — that is the finding this app exists to show.
  List<String> get directions =>
      examples.values.firstOrNull?.directions ?? const [];
}

/// A character at least one language writes in a different **order**.
///
/// Chinese is the reference. For every language present, [toReference] maps that
/// language's stroke *i* onto the Chinese stroke it physically is — established
/// by matching the glyphs geometrically, since the sources share no identifiers.
/// A language whose permutation is the identity writes it the Chinese way.
class OrderComparison {
  const OrderComparison({
    required this.char,
    required this.glyphs,
    required this.toReference,
    required this.types,
    required this.firstDivergence,
  });

  final String char;

  /// Language to key into `strokeGlyphs`. Always contains [Lang.zh].
  final Map<Lang, String> glyphs;

  /// Language to permutation into Chinese stroke order. Chinese maps to itself.
  final Map<Lang, List<int>> toReference;

  /// Language to its per-stroke CJK Strokes codepoints, in its own order.
  final Map<Lang, List<String?>> types;

  /// Language to the first stroke position where it parts from Chinese, or -1
  /// if it agrees. At least one language here is non-negative.
  final Map<Lang, int> firstDivergence;

  int get strokeCount => toReference[Lang.zh]?.length ?? 0;

  Iterable<Lang> get languages => glyphs.keys;

  /// Languages that actually differ from Chinese here.
  Iterable<Lang> get divergent =>
      firstDivergence.entries.where((e) => e.value >= 0).map((e) => e.key);
}

/// A single stroke that two languages write in a different **direction**.
///
/// animCJK's README claims these exist ("many Japanese and Korean characters
/// … have a different stroke direction"), though its changelog only ever
/// records order changes. This type carries whatever the data actually shows;
/// an empty list is a real answer, not a missing feature.
class DirectionDivergence {
  const DirectionDivergence({
    required this.char,
    required this.referenceStroke,
    required this.directions,
    required this.glyphs,
  });

  final String char;

  /// Which Chinese stroke this is, by index.
  final int referenceStroke;

  /// Language to the compass headings that language writes this stroke in.
  final Map<Lang, List<String>> directions;

  /// Language to key into `strokeGlyphs`, so the disagreement can be drawn.
  final Map<Lang, String> glyphs;
}
