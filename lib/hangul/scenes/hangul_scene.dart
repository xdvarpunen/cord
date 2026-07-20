import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/scene.dart';

/// Cream, dot-grid paper background (Moleskine-style notebook page).
class PaperLayer extends Layer {
  static const _paperColor = Color(0xFFF3ECDC);
  static const _dotColor = Color(0x33000000);
  static const _spacing = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _paperColor);
    final dotPaint = Paint()..color = _dotColor;
    for (var y = _spacing; y < size.height; y += _spacing) {
      for (var x = _spacing; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }
}

class _Stroke {
  _Stroke(this.points);

  final List<Offset> points;
  Offset get start => points.first;
  Offset get end => points.last;
}

/// Which side of a vowel's stem its ticks sit on (see
/// [HangulLayer._classifyStemAndTicks]). [left]/[right] go with a vertical
/// stem (ㅓ/ㅏ, ㅕ/ㅑ); [above]/[below] go with a horizontal one
/// (ㅗ/ㅜ, ㅛ/ㅠ) — the same shape turned on its side.
enum _TickSide {
  left,
  right,
  above,
  below;

  /// Whether ticks on this side hang off a vertical stem (as opposed to a
  /// horizontal one). Decides which orientation each of the recent strokes
  /// has to have to be the stem versus a tick.
  bool get stemIsVertical => this == left || this == right;
}

/// The jamo the recognizer can currently identify. Grows one entry at a
/// time as classifiers are built; [HangulLayer.recognizedSounds] is kept
/// in step with it so [HangulPage]'s legend only shows letters that can
/// actually be drawn.
enum _HangulJamo {
  i('ㅣ', 'i', 'i'),
  eu('ㅡ', 'eu', 'eu'),
  a('ㅏ', 'a', 'a'),
  ya('ㅑ', 'ya', 'ya'),
  eo('ㅓ', 'eo', 'eo'),
  yeo('ㅕ', 'yeo', 'yeo'),
  o('ㅗ', 'o', 'o'),
  yo('ㅛ', 'yo', 'yo'),
  u('ㅜ', 'u', 'u'),
  yu('ㅠ', 'yu', 'yu'),
  ieung('ㅇ', 'ieung', 'ng'),
  giyeok('ㄱ', 'giyeok', 'g/k'),
  nieun('ㄴ', 'nieun', 'n'),
  digeut('ㄷ', 'digeut', 'd/t'),
  hieut('ㅎ', 'hieut', 'h'),
  rieul('ㄹ', 'rieul', 'r/l'),
  mieum('ㅁ', 'mieum', 'm'),
  bieup('ㅂ', 'bieup', 'b/p'),
  tieut('ㅌ', 'tieut', 't'),
  siot('ㅅ', 'siot', 's'),
  kieuk('ㅋ', 'kieuk', 'k'),
  jieut('ㅈ', 'jieut', 'j'),
  chieut('ㅊ', 'chieut', 'ch'),
  pieup('ㅍ', 'pieup', 'p'),
  ssangGiyeok('ㄲ', 'ssanggiyeok', 'kk'),
  ssangDigeut('ㄸ', 'ssangdigeut', 'tt'),
  ssangBieup('ㅃ', 'ssangbieup', 'pp'),
  ssangSiot('ㅆ', 'ssangsiot', 'ss'),
  ssangJieut('ㅉ', 'ssangjieut', 'jj'),
  ae('ㅐ', 'ae', 'ae'),
  yae('ㅒ', 'yae', 'yae'),
  e('ㅔ', 'e', 'e'),
  ye('ㅖ', 'ye', 'ye'),
  ui('ㅢ', 'ui', 'ui'),
  wi('ㅟ', 'wi', 'wi'),
  oe('ㅚ', 'oe', 'oe'),
  wo('ㅝ', 'wo', 'wo'),
  we('ㅞ', 'we', 'we'),
  wa('ㅘ', 'wa', 'wa'),
  wae('ㅙ', 'wae', 'wae');

  const _HangulJamo(this.glyph, this.letterName, this.sound);

  final String glyph;
  final String letterName;
  final String sound;
}

/// Freehand recognition of Hangul jamo. Each letter is described purely
/// by the strokes it's made of, so the classifiers read the same way the
/// letters are taught:
///
/// - ㅣ (i) — a single straight vertical stroke, on its own (see
///   [HangulLayer._classifyI]).
/// - ㅡ (eu) — the same single straight stroke laid the other way: a
///   horizontal one (see [HangulLayer._classifyEu]). ㅣ and ㅡ are the two
///   halves of the same gesture, told apart purely by orientation, so
///   neither may accept the diagonal in between — hence the
///   [HangulLayer._verticalRatio] / [HangulLayer._horizontalRatio] margin
///   on both, which leaves a genuinely slanted line unrecognized rather
///   than guessing.
/// - ㅏ (a) — ㅣ's vertical stem plus one short horizontal tick touching
///   it, the tick sitting to the stem's right (see
///   [HangulLayer._classifyStemAndTicks]).
/// - ㅑ (ya) — the same, with two ticks on the right instead of one.
/// - ㅓ (eo) — ㅏ mirrored: the stem plus one tick on its left.
/// - ㅕ (yeo) — ㅓ with two ticks on the left.
/// - ㅗ (o) — the same stem-and-ticks shape turned on its side: a
///   horizontal bar with one short vertical tick standing above it.
/// - ㅛ (yo) — ㅗ with two ticks above.
/// - ㅜ (u) — ㅗ flipped: the bar with one tick hanging below it.
/// - ㅠ (yu) — ㅜ with two ticks below.
/// - ㅇ (ieung) — not straight strokes at all but a single closed loop,
///   recognized as a stroke that crosses back over itself exactly once
///   (see [HangulLayer._classifyIeung]).
/// - ㄱ (giyeok) — a single right-angle corner drawn top-left to
///   bottom-right, so its start→end chord is a descending diagonal, with
///   the elbow riding high at the top-right: the body sits above that
///   chord (see [HangulLayer._isCorner]).
/// - ㄴ (nieun) — the same descending-chord corner mirrored, the elbow
///   dropped low at the bottom-left so the body sits below the chord.
/// - ㄷ (digeut) — a ㄴ corner with a horizontal bar laid across its top,
///   closing the ㄴ's open top into ㄷ's square C (see
///   [HangulLayer._classifyDigeut]).
/// - ㅎ (hieut) — a ㅇ loop with two horizontal bars stacked above it in
///   the same x range, the lower one resting on the circle (see
///   [HangulLayer._classifyHieut]).
/// - ㄹ (rieul) — a ㄷ (a ㄴ corner capped by a horizontal bar) with a ㄱ
///   corner stacked on top, the ㄱ hooking onto that same bar (see
///   [HangulLayer._classifyRieul]).
/// - ㅁ (mieum) — a closed box: a vertical and a horizontal meeting at a
///   corner, with a ㄱ closing the top and right side, touching both (see
///   [HangulLayer._classifyMieum]).
/// - ㅂ (bieup) — four line strokes: two verticals rung together by two
///   horizontals, each horizontal crossing both verticals for four
///   intersections in all (see [HangulLayer._classifyBieup]).
/// - ㅌ (tieut) — a ㄴ corner crossed by two horizontal bars, which with
///   the ㄴ's own bottom bar make ㅌ's three rungs (see
///   [HangulLayer._classifyTieut]).
/// - ㅅ (siot) — 人: an ascending diagonal and a descending diagonal that
///   meet (see [HangulLayer._classifySiot]).
/// - ㅋ (kieuk) — a ㄱ corner crossed by a horizontal bar below its top —
///   ㄱ with a middle rung (see [HangulLayer._classifyKieuk]).
/// - ㅈ (jieut) — ㅋ's shape with a descending diagonal in place of the
///   horizontal: a ㄱ corner met by a descending diagonal (see
///   [HangulLayer._classifyJieut]).
/// - ㅊ (chieut) — a ㅈ with a horizontal bar added on top, over the same x
///   range (see [HangulLayer._classifyChieut]).
/// - ㅍ (pieup) — a horizontal bar crossed by two verticals (two
///   intersections) with a second horizontal floating above it, over the
///   same x range, crossing neither; told from ㅂ (both bars crossed, four
///   intersections) by the upper bar sitting clear (see
///   [HangulLayer._classifyPieup]).
/// - ㄲ/ㄸ/ㅃ/ㅆ/ㅉ (tense consonants) — not a shape of their own but a
///   composition: the same base consonant written twice, side by side and
///   in the same row, so the drawing splits into two untouching clusters
///   that each read as the same ㄱ/ㄷ/ㅂ/ㅅ/ㅈ (see
///   [HangulLayer._classifyComposition]).
/// - ㅔ/ㅖ (complex vowels) — a ㅓ/ㅕ with a trailing ㅣ; the tick points away
///   from the ㅣ, so they sit apart as two side-by-side clusters, the same
///   composition path as the tense consonants ([HangulLayer._classifyComposition]).
/// - ㅐ/ㅒ (complex vowels) — a ㅏ/ㅑ whose tick(s) reach and touch a trailing
///   ㅣ: two vertical stems bridged by one/two horizontal ticks that touch
///   both (see [HangulLayer._classifyAe], [HangulLayer._classifyYae]).
/// - ㅢ (complex vowel) — ㅡ and ㅣ that touch, both of comparable length,
///   neither the 2× stem-over-tick of ㅏ/ㅗ (see [HangulLayer._classifyUi]).
/// - ㅟ (complex vowel) — ㅜ (a bar with a tick hanging below) plus a
///   vertical ㅣ crossing the bar (see [HangulLayer._classifyWi]).
/// - ㅚ (complex vowel) — ㅗ (a bar with a tick standing above) plus a
///   vertical ㅣ crossing the bar — ㅟ mirrored (see
///   [HangulLayer._classifyOe]).
/// - ㅝ (complex vowel) — ㅜ whose bar is crossed by a ㅓ (a stem with a
///   left tick): bar + below-tick + crossing stem + left tick (see
///   [HangulLayer._classifyWo]).
/// - ㅞ (complex vowel) — ㅝ with a trailing ㅣ (ㅜ + ㅔ) (see
///   [HangulLayer._classifyWe]).
/// - ㅘ (complex vowel) — ㅝ mirrored: ㅗ (a bar with a tick standing above)
///   whose bar is crossed by a ㅏ (a stem with a right tick) (see
///   [HangulLayer._classifyWa]).
/// - ㅙ (complex vowel) — ㅘ with a trailing ㅣ (ㅗ + ㅐ) (see
///   [HangulLayer._classifyWae]).
///
/// Letters that share a shape are ordered most-strokes-first in
/// [HangulLayer._commit], so a finished ㅑ isn't reported as the ㅏ it
/// contains, and neither is reported as the bare ㅣ or ㅡ their individual
/// strokes would match on their own.
///
/// Everything else is still unrecognized — a drawing that matches nothing
/// leaves the label showing the prompt instead.
class HangulLayer extends Layer {
  /// A press-and-release shorter than this is a tap, not a drag. Hangul
  /// has no dot letters, so taps are simply ignored (unlike Tifinagh,
  /// where they're a whole letter family).
  static const double _tapThreshold = 5;

  /// Shortest drag that counts as a deliberate stroke rather than a
  /// slipped tap.
  static const double _minDragDistance = 8;

  /// How much taller than wide a stroke must be to read as vertical.
  /// A plain `|dy| > |dx|` would accept a 45°-ish diagonal, which is a
  /// different letter's stroke (and, later, ㅅ/ㅈ's own diagonals).
  static const double _verticalRatio = 2;

  /// The same margin the other way round, for [_classifyEu]. Deliberately
  /// equal to [_verticalRatio]: a line slanted enough to be ambiguous
  /// between ㅣ and ㅡ should match neither, rather than falling to
  /// whichever classifier happens to run first.
  static const double _horizontalRatio = 2;

  /// How far a stroke may bow off its own straight start-to-end chord and
  /// still read as a straight line: the larger of [_minStraightSlack] and
  /// this fraction of the chord's length. Without it, a curve or a hook
  /// that happens to start and end vertically apart (ㄱ drawn in one
  /// stroke, say) would pass for ㅣ.
  static const double _straightTolerance = 0.12;
  static const double _minStraightSlack = 6;

  /// How close two strokes must come to count as touching (see
  /// [_touches]). Hangul's ticks meet the stem in a T-junction rather than
  /// crossing it, so a strict segment-intersection test would turn on
  /// whether the hand happened to overshoot by a pixel — a tick that stops
  /// just short of the stem is the same letter to any reader.
  static const double _touchTolerance = 22;

  /// How far a tick's center must clear the stem to count as being on one
  /// side of it. A tick centered on the stem is a different letter's
  /// shape (a plus, not a ㅏ), so it should match nothing rather than fall
  /// to whichever side's classifier ran first.
  static const double _minSideOffset = 6;

  /// How far apart two ticks' vertical centers must be to read as two
  /// separate ticks (ㅑ) rather than one stroke drawn twice over itself.
  static const double _minTickSeparation = 12;

  /// How many times longer the stem must be than each of its ticks. The
  /// stem is the letter's spine (the tall line in ㅏ/ㅑ/ㅓ/ㅕ, the wide bar
  /// in ㅗ/ㅛ/ㅜ/ㅠ) and the ticks are short marks off it; without a length
  /// ratio a stem and a same-length crossbar could read as a stem-and-tick
  /// vowel when it's really a consonant stroke (ㅜ vs. ㅓ turned, say, or a
  /// future ㅌ/ㄷ bar). Two is the shape's own proportion, not a tuned
  /// fudge: a tick as long as half its stem already looks wrong.
  static const double _minStemTickRatio = 2;

  /// The least each axis of a corner's start→end chord may span for the
  /// chord to count as a descending diagonal (ㄱ/ㄴ are both drawn top-left
  /// to bottom-right). Below this the "corner" is really a near-horizontal
  /// or near-vertical bend, where "which side is the body on" is noise.
  static const double _minCornerChord = 15;

  /// How far, on average, a corner's body must lie off its chord to commit
  /// to a side — positive for ㄱ (elbow above the chord), negative for ㄴ
  /// (elbow below it). A clean corner clears roughly 40; this margin keeps
  /// a barely-bowed diagonal from being forced onto one side or the other.
  static const double _minCornerBulge = 12;

  /// Which sounds the recognizer supports so far, matched against
  /// [JamoRow.sound]. Kept in step with [_HangulJamo] — used by
  /// [HangulPage] to mute letters that can't be drawn yet rather than
  /// listing them as if they could.
  static const recognizedSounds = {
    'i', 'eu', 'a', 'ya', 'eo', 'yeo', 'o', 'yo', 'u', 'yu', 'ng',
    'g/k', 'n', 'd/t', 'h', 'r/l', 'm', 'b/p', 't', 's', 'k', 'j', 'ch', 'p',
    'kk', 'tt', 'pp', 'ss', 'jj',
    'ae', 'yae', 'e', 'ye', 'ui', 'wi', 'oe', 'wo', 'we', 'wa', 'wae',
  };

  final List<_Stroke> _strokes = [];
  _HangulJamo? _recognized;
  List<Offset>? _activePoints;

  /// The glyph currently being reported, or null if the drawing matches no
  /// letter. The letters themselves are private ([_HangulJamo]); this
  /// exposes just enough of the result for tests to assert on what a given
  /// sequence of strokes recognizes as.
  String? get recognizedGlyph => _recognized?.glyph;

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
      if (dragDistance >= _tapThreshold &&
          points.length >= 2 &&
          dragDistance >= _minDragDistance) {
        _commit(_Stroke(points));
      }
      _activePoints = null;
    }
  }

  void _commit(_Stroke stroke) {
    _strokes.add(stroke);
    // A two-part composition of side-by-side letters (a tense consonant or a
    // side-by-side complex vowel) is read from the whole drawing's two
    // clusters; failing that, the strokes are a single letter.
    _recognized = _classifyComposition() ?? _classifyBase();
  }

  /// Recognizes the current [_strokes] as one jamo, most-strokes-first so a
  /// finished letter isn't reported as the simpler shape it contains (the
  /// two-tick vowels contain the one-tick ones, and all contain a bare ㅣ/ㅡ).
  /// It reads whatever [_strokes] holds, so [_recognizeStrokes] can aim it at
  /// one cluster of a tense consonant as readily as at the whole drawing.
  _HangulJamo? _classifyBase() {
    if (_strokes.isEmpty) return null;
    return _firstMatch([
      () => _classifyPieup(),
      () => _classifyYae(),
      () => _classifyBieup(),
      () => _classifyHieut(),
      () => _classifyRieul(),
      () => _classifyMieum(),
      () => _classifyTieut(),
      () => _classifyChieut(),
      () => _classifyWe(),
      () => _classifyWae(),
      () => _classifyWo(),
      () => _classifyWa(),
      () => _classifyWi(),
      () => _classifyOe(),
      () => _classifyAe(),
      () => _classifyStemAndTicks(2, _TickSide.right, _HangulJamo.ya),
      () => _classifyStemAndTicks(2, _TickSide.left, _HangulJamo.yeo),
      () => _classifyStemAndTicks(2, _TickSide.above, _HangulJamo.yo),
      () => _classifyStemAndTicks(2, _TickSide.below, _HangulJamo.yu),
      () => _classifyStemAndTicks(1, _TickSide.right, _HangulJamo.a),
      () => _classifyStemAndTicks(1, _TickSide.left, _HangulJamo.eo),
      () => _classifyStemAndTicks(1, _TickSide.above, _HangulJamo.o),
      () => _classifyStemAndTicks(1, _TickSide.below, _HangulJamo.u),
      () => _classifyUi(),
      () => _classifyDigeut(),
      () => _classifySiot(),
      () => _classifyKieuk(),
      () => _classifyJieut(),
      () => _classifyI(),
      () => _classifyEu(),
      () => _classifyIeung(),
      () => _classifyGiyeok(),
      () => _classifyNieun(),
    ]);
  }

  /// The base consonants that double into a tense one, and the tense letter
  /// each yields. Only these five have a twin; any other letter written
  /// twice maps to nothing, so it stays two separate (unrecognized) copies.
  static const _tenseOf = {
    _HangulJamo.giyeok: _HangulJamo.ssangGiyeok,
    _HangulJamo.digeut: _HangulJamo.ssangDigeut,
    _HangulJamo.bieup: _HangulJamo.ssangBieup,
    _HangulJamo.siot: _HangulJamo.ssangSiot,
    _HangulJamo.jieut: _HangulJamo.ssangJieut,
  };

  /// Which vowel a stem vowel followed by a trailing ㅣ composes into — the
  /// side-by-side complex vowels. ㅓ/ㅕ's tick points away from the ㅣ so they
  /// sit apart (the natural side-by-side case); ㅏ/ㅑ are here too so a ㅐ/ㅒ
  /// drawn with a gap still resolves, with the touching form handled by
  /// [_classifyAe]/[_classifyYae].
  static const _complexWithI = {
    _HangulJamo.eo: _HangulJamo.e,
    _HangulJamo.yeo: _HangulJamo.ye,
    _HangulJamo.a: _HangulJamo.ae,
    _HangulJamo.ya: _HangulJamo.yae,
  };

  /// Whether the drawing is a two-part composition of side-by-side letters:
  /// a tense consonant — the same doubleable base twice ([_tenseOf]) — or a
  /// side-by-side complex vowel — a stem vowel then a trailing ㅣ
  /// ([_complexWithI]). Both read off [_sideBySidePair].
  _HangulJamo? _classifyComposition() {
    final pair = _sideBySidePair();
    if (pair == null) return null;
    final (left, right) = pair;
    if (left == null || right == null) return null;
    if (left == right) return _tenseOf[left];
    if (right == _HangulJamo.i) return _complexWithI[left];
    return null;
  }

  /// The drawing's two side-by-side clusters, each recognized on its own and
  /// returned left-to-right — or null unless it's exactly two clusters
  /// ([_connectedComponents]) with one clearly left of the other (a vertical
  /// gap) and overlapping in y (aligned in the same row, not stacked). One
  /// letter's strokes all touch, so two untouching letters come out as two
  /// clusters. Shared by the tense consonants and the side-by-side complex
  /// vowels ([_classifyComposition]).
  (_HangulJamo?, _HangulJamo?)? _sideBySidePair() {
    final components = _connectedComponents();
    if (components.length != 2) return null;
    final boundsA = _boundsOf([for (final s in components[0]) ...s.points]);
    final boundsB = _boundsOf([for (final s in components[1]) ...s.points]);
    final (left, leftBounds, right, rightBounds) =
        boundsA.center.dx <= boundsB.center.dx
            ? (components[0], boundsA, components[1], boundsB)
            : (components[1], boundsB, components[0], boundsA);
    // Side by side: a clean vertical gap, not overlapping or stacked.
    if (leftBounds.right >= rightBounds.left) return null;
    // In the same row: their y spans overlap by at least half the shorter.
    final yOverlap = math.min(leftBounds.bottom, rightBounds.bottom) -
        math.max(leftBounds.top, rightBounds.top);
    if (yOverlap < math.min(leftBounds.height, rightBounds.height) / 2) {
      return null;
    }
    return (_recognizeStrokes(left), _recognizeStrokes(right));
  }

  /// Groups [_strokes] into clusters that touch ([_touches]) — the drawing's
  /// separate letters. Strokes within one letter meet; two side-by-side
  /// letters don't, so each lands in its own cluster. Union-find over every
  /// stroke pair (touch tested both ways, since [_touches] isn't symmetric).
  List<List<_Stroke>> _connectedComponents() {
    final count = _strokes.length;
    final parent = List<int>.generate(count, (i) => i);
    int root(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    for (var i = 0; i < count; i++) {
      for (var j = i + 1; j < count; j++) {
        if (_touches(_strokes[i], _strokes[j]) ||
            _touches(_strokes[j], _strokes[i])) {
          parent[root(i)] = root(j);
        }
      }
    }
    final clusters = <int, List<_Stroke>>{};
    for (var i = 0; i < count; i++) {
      clusters.putIfAbsent(root(i), () => []).add(_strokes[i]);
    }
    return clusters.values.toList();
  }

  /// Recognizes an arbitrary [strokes] cluster as one jamo by pointing
  /// [_classifyBase] at it: the store is swapped out and restored so the
  /// classifiers, which read [_strokes], can grade a single cluster of a
  /// tense consonant on its own.
  _HangulJamo? _recognizeStrokes(List<_Stroke> strokes) {
    final saved = _strokes.toList();
    _strokes
      ..clear()
      ..addAll(strokes);
    try {
      return _classifyBase();
    } finally {
      _strokes
        ..clear()
        ..addAll(saved);
    }
  }

  /// Runs [classifiers] in order and returns the first letter one of them
  /// claims, or null if none does. Order matters as more letters land:
  /// the most specific (most strokes) shape goes first, so a completed
  /// letter isn't reported as the simpler shape it contains.
  _HangulJamo? _firstMatch(List<_HangulJamo? Function()> classifiers) {
    for (final classify in classifiers) {
      final result = classify();
      if (result != null) return result;
    }
    return null;
  }

  /// Whether [stroke] forms ㅣ: a straight vertical line drawn on its own.
  /// The "on its own" part ([_touchesAnotherStroke]) is what keeps it from
  /// firing on the vertical stem of a multi-stroke letter (ㅏ, ㅑ, and
  /// later ㅓ, ㅔ …): once a tick touches that stem the drawing is a whole
  /// vowel, not a bare ㅣ, so the stem alone must stop matching.
  _HangulJamo? _classifyI() {
    final stroke = _strokes.last;
    return _isVertical(stroke) &&
            _isStraight(stroke) &&
            !_touchesAnotherStroke(stroke)
        ? _HangulJamo.i
        : null;
  }

  /// Whether [stroke] forms ㅡ: ㅣ's gesture turned on its side — a
  /// straight horizontal line drawn on its own ([_touchesAnotherStroke]),
  /// the same guard as [_classifyI]. ㅗ, ㅜ, ㅛ, ㅠ and every consonant with
  /// a flat top or base contain this stroke, so a horizontal that touches
  /// something else is part of one of those, not a bare ㅡ.
  _HangulJamo? _classifyEu() {
    final stroke = _strokes.last;
    return _isHorizontal(stroke) &&
            _isStraight(stroke) &&
            !_touchesAnotherStroke(stroke)
        ? _HangulJamo.eu
        : null;
  }

  /// Whether [stroke] forms ㅇ (ieung): a single stroke that crosses back
  /// over itself exactly once — the loop of a circle drawn in one go, its
  /// tail passing over its own head as it closes. Exactly one crossing is
  /// what sets that closed loop apart from a straight line or open curve
  /// (zero) on one side and a scribble (several) on the other. Unlike the
  /// stem-and-ticks vowels ㅇ is a whole letter in one self-touching
  /// stroke, so it's classified straight off the just-committed stroke,
  /// the way ㅣ and ㅡ are.
  _HangulJamo? _classifyIeung() =>
      _selfCrossingCount(_strokes.last) == 1 ? _HangulJamo.ieung : null;

  /// How many times [stroke]'s own path crosses itself: the count of
  /// non-adjacent segment pairs that properly cross ([_segmentsCross]).
  /// Segments next to each other along the path share an endpoint by
  /// construction — they meet there, they don't cross — so they're skipped
  /// (the `j >= i + 2` gap), leaving a straight or gently curving stroke at
  /// zero and a clean single loop at one.
  int _selfCrossingCount(_Stroke stroke) {
    final points = stroke.points;
    var count = 0;
    for (var i = 1; i < points.length; i++) {
      for (var j = i + 2; j < points.length; j++) {
        if (_segmentsCross(
            points[i - 1], points[i], points[j - 1], points[j])) {
          count++;
        }
      }
    }
    return count;
  }

  /// Whether segments [a1]–[a2] and [b1]–[b2] cross transversally: each
  /// segment's endpoints straddle the other's line, tested by the sign of
  /// the four orientation cross-products. Strict signs mean a mere touch —
  /// an endpoint grazing the other segment, or the two running collinear —
  /// doesn't count, so a crossing is tallied once, by the single pair of
  /// segments that genuinely pass through each other.
  bool _segmentsCross(Offset a1, Offset a2, Offset b1, Offset b2) {
    double orientation(Offset p, Offset q, Offset r) =>
        (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
    final d1 = orientation(b1, b2, a1);
    final d2 = orientation(b1, b2, a2);
    final d3 = orientation(a1, a2, b1);
    final d4 = orientation(a1, a2, b2);
    return (d1 > 0) != (d2 > 0) && (d3 > 0) != (d4 > 0);
  }

  /// Whether the vertical stroke [vertical] passes clean through the
  /// horizontal [bar] — a true transversal crossing where the vertical reaches
  /// clearly above and below the bar's line and the bar clearly left and right
  /// of the vertical — as opposed to merely meeting it at an endpoint (a
  /// T-junction, where one stroke stops at the other).
  bool _crossesBar(_Stroke vertical, _Stroke bar) {
    final barY = _boundsOf(bar.points).center.dy;
    final verticalX = _boundsOf(vertical.points).center.dx;
    var above = false;
    var below = false;
    for (final point in vertical.points) {
      if (point.dy < barY - _minSideOffset) above = true;
      if (point.dy > barY + _minSideOffset) below = true;
    }
    if (!above || !below) return false;
    var left = false;
    var right = false;
    for (final point in bar.points) {
      if (point.dx < verticalX - _minSideOffset) left = true;
      if (point.dx > verticalX + _minSideOffset) right = true;
    }
    return left && right;
  }

  /// Whether [vertical] hangs below [bar] — touches it and stays under it (no
  /// part clearly above), the way ㅜ's tick sits under its bar. Distinct from a
  /// full ㅣ, which reaches above the bar and so isn't "below".
  bool _hangsBelow(_Stroke vertical, _Stroke bar) {
    if (!_touches(vertical, bar)) return false;
    final barY = _boundsOf(bar.points).center.dy;
    return _boundsOf(vertical.points).top >= barY - _minSideOffset;
  }

  /// Whether [vertical] stands above [bar] — touches it and stays over it (no
  /// part clearly below), the way ㅗ's tick rises off its bar. The mirror of
  /// [_hangsBelow].
  bool _standsAbove(_Stroke vertical, _Stroke bar) {
    if (!_touches(vertical, bar)) return false;
    final barY = _boundsOf(bar.points).center.dy;
    return _boundsOf(vertical.points).bottom <= barY + _minSideOffset;
  }

  /// Whether [stroke] forms ㄱ (giyeok): a single right-angle corner drawn
  /// top-left to bottom-right, its body riding above the descending chord
  /// from its start to its end (see [_isCorner]).
  _HangulJamo? _classifyGiyeok() =>
      _isCorner(_strokes.last, bodyAboveChord: true) ? _HangulJamo.giyeok : null;

  /// Whether [stroke] forms ㄴ (nieun): ㄱ's corner mirrored — the same
  /// descending chord, but the body sitting below it (see [_isCorner]).
  _HangulJamo? _classifyNieun() =>
      _isCorner(_strokes.last, bodyAboveChord: false)
          ? _HangulJamo.nieun
          : null;

  /// Whether the most recent two strokes form ㄷ (digeut): a ㄴ corner with
  /// a horizontal bar laid across its top, closing the ㄴ's open top into
  /// ㄷ's square C. Stroke order doesn't matter — the two recent strokes are
  /// sorted into corner and bar by shape. The bar has to touch the corner
  /// ([_touches]) and sit in its upper half, so a horizontal dropped low
  /// across a ㄴ (or its own bottom bar) isn't mistaken for the top of a ㄷ.
  _HangulJamo? _classifyDigeut() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes[_strokes.length - 1];
    final _Stroke corner;
    final _Stroke bar;
    if (_isCorner(a, bodyAboveChord: false) &&
        _isHorizontal(b) &&
        _isStraight(b)) {
      corner = a;
      bar = b;
    } else if (_isCorner(b, bodyAboveChord: false) &&
        _isHorizontal(a) &&
        _isStraight(a)) {
      corner = b;
      bar = a;
    } else {
      return null;
    }
    if (!_touches(bar, corner)) return null;
    // The bar is ㄷ's top: it rides in the upper half of the corner, not
    // down among the corner's own bottom bar.
    if (_boundsOf(bar.points).center.dy >= _boundsOf(corner.points).center.dy) {
      return null;
    }
    return _HangulJamo.digeut;
  }

  /// Whether the most recent two strokes form ㅅ (siot): 人, an ascending
  /// diagonal and a descending diagonal that meet. Both strokes have to be
  /// diagonals ([_isDiagonal]), one rising and one falling
  /// ([_isAscending]), and the two have to touch ([_touches]) — the apex
  /// where 人's legs join.
  _HangulJamo? _classifySiot() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes[_strokes.length - 1];
    if (!_isDiagonal(a) || !_isDiagonal(b)) return null;
    if (_isAscending(a) == _isAscending(b)) return null;
    if (!_touches(a, b)) return null;
    return _HangulJamo.siot;
  }

  /// Whether the just-drawn plus previous stroke pair a ㄱ corner with a
  /// [mark] stroke crossing its stem below the top bar — the shared shape of
  /// ㅋ (mark = a horizontal rung) and ㅈ (mark = a descending diagonal). The
  /// two recent strokes are sorted so stroke order doesn't matter; the mark
  /// has to touch the ㄱ and sit below its top bar (else it's a doubled top,
  /// not a rung). Returns the ㄱ and mark for the caller to finish, or null.
  (_Stroke, _Stroke)? _giyeokWithMark(bool Function(_Stroke) isMark) {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes[_strokes.length - 1];
    final _Stroke giyeok;
    final _Stroke mark;
    if (_isCorner(a, bodyAboveChord: true) && isMark(b)) {
      giyeok = a;
      mark = b;
    } else if (_isCorner(b, bodyAboveChord: true) && isMark(a)) {
      giyeok = b;
      mark = a;
    } else {
      return null;
    }
    if (!_touches(mark, giyeok)) return null;
    if (_boundsOf(mark.points).center.dy <=
        _boundsOf(giyeok.points).top + _minTickSeparation) {
      return null;
    }
    return (giyeok, mark);
  }

  /// Whether the most recent two strokes form ㅋ (kieuk): a ㄱ corner with a
  /// horizontal bar crossing its stem below the top bar — ㄱ's middle rung
  /// (see [_giyeokWithMark]).
  _HangulJamo? _classifyKieuk() =>
      _giyeokWithMark((s) => _isHorizontal(s) && _isStraight(s)) != null
          ? _HangulJamo.kieuk
          : null;

  /// Whether the most recent two strokes form ㅈ (jieut): ㅋ's shape with a
  /// descending diagonal where the horizontal would be — a ㄱ corner met by
  /// a falling diagonal (see [_giyeokWithMark]).
  _HangulJamo? _classifyJieut() =>
      _giyeokWithMark((s) => _isDiagonal(s) && !_isAscending(s)) != null
          ? _HangulJamo.jieut
          : null;

  /// Whether the most recent three strokes form ㅊ (chieut): a ㅈ (ㄱ corner
  /// met by a descending diagonal) with a horizontal bar added on top, over
  /// the same x range. The three recent strokes are sorted by shape, so
  /// order doesn't matter; the ㄱ and diagonal have to make a ㅈ and the bar
  /// has to ride above the ㄱ's top bar, overlapping its x range.
  _HangulJamo? _classifyChieut() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final giyeoks =
        recent.where((s) => _isCorner(s, bodyAboveChord: true)).toList();
    final slashes =
        recent.where((s) => _isDiagonal(s) && !_isAscending(s)).toList();
    final bars =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    if (giyeoks.length != 1 || slashes.length != 1 || bars.length != 1) {
      return null;
    }
    final giyeok = _boundsOf(giyeoks.single.points);
    final bar = _boundsOf(bars.single.points);
    // The ㄱ and diagonal make a ㅈ: the diagonal touches the ㄱ below its top.
    if (!_touches(slashes.single, giyeoks.single)) return null;
    if (_boundsOf(slashes.single.points).center.dy <=
        giyeok.top + _minTickSeparation) {
      return null;
    }
    // The added bar rides above the ㄱ's top bar, over the same x range.
    if (bar.center.dy >= giyeok.top) return null;
    final overlap =
        math.min(bar.right, giyeok.right) - math.max(bar.left, giyeok.left);
    if (overlap < bar.width / 2) return null;
    return _HangulJamo.chieut;
  }

  /// Whether the most recent four strokes form ㅍ (pieup): a horizontal bar
  /// crossed by two verticals — two intersections ([_crossesBar]) — with a
  /// second horizontal floating above, over the same x range, crossing
  /// neither. That's what tells ㅍ from ㅂ: in ㅍ only the lower bar is run
  /// through (2 intersections) while the upper bar sits above untouched,
  /// whereas ㅂ has both bars crossed (4 intersections).
  _HangulJamo? _classifyPieup() {
    if (_strokes.length < 4) return null;
    final recent = _strokes.sublist(_strokes.length - 4);
    final verticals =
        recent.where((s) => _isVertical(s) && _isStraight(s)).toList();
    final horizontals =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    if (verticals.length != 2 || horizontals.length != 2) return null;
    // One bar is crossed by both verticals (the lower bar); the other by
    // neither (the upper bar, floating above without intersecting).
    final crossed = horizontals
        .where((h) => verticals.every((v) => _crossesBar(v, h)))
        .toList();
    final clear = horizontals
        .where((h) => verticals.every((v) => !_crossesBar(v, h)))
        .toList();
    if (crossed.length != 1 || clear.length != 1) return null;
    final lower = _boundsOf(crossed.single.points);
    final upper = _boundsOf(clear.single.points);
    // The uncrossed bar sits above the crossed one, over a shared x range.
    if (upper.center.dy >= lower.center.dy) return null;
    final overlap =
        math.min(upper.right, lower.right) - math.max(upper.left, lower.left);
    if (overlap < math.min(upper.width, lower.width) / 2) return null;
    return _HangulJamo.pieup;
  }

  /// Whether the most recent three strokes form ㅐ (ae): two vertical stems
  /// bridged by a single horizontal tick that touches both — ㅏ whose right
  /// tick reaches an added ㅣ. Touching both is what parts ㅐ from ㅔ, whose
  /// tick reaches only one stem (leaving the ㅣ a separate cluster for the
  /// side-by-side path).
  _HangulJamo? _classifyAe() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final verticals =
        recent.where((s) => _isVertical(s) && _isStraight(s)).toList();
    final horizontals =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    if (verticals.length != 2 || horizontals.length != 1) return null;
    final tick = horizontals.single;
    for (final vertical in verticals) {
      if (!_touches(tick, vertical)) return null;
      // The verticals are the tall stems and the horizontal a short bridge —
      // the opposite proportion to ㅛ/ㅠ (a long bar with two short ticks on
      // it), which share ㅐ's two-verticals-and-a-horizontal inventory.
      if (_majorExtent(vertical) < _majorExtent(tick) * _minStemTickRatio) {
        return null;
      }
    }
    return _HangulJamo.ae;
  }

  /// Whether the most recent four strokes form ㅒ (yae): two vertical stems
  /// bridged by two horizontal ticks that each touch both — ㅑ whose two right
  /// ticks reach an added ㅣ. The stems have to run at least
  /// [_minStemTickRatio]× longer than the ticks (the ㅣ hugs the ㅑ, so the
  /// ticks are short), which is what tells ㅒ's tall narrow frame from ㅂ's
  /// square one, since both are two verticals bridged by two horizontals.
  _HangulJamo? _classifyYae() {
    if (_strokes.length < 4) return null;
    final recent = _strokes.sublist(_strokes.length - 4);
    final verticals =
        recent.where((s) => _isVertical(s) && _isStraight(s)).toList();
    final horizontals =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    if (verticals.length != 2 || horizontals.length != 2) return null;
    for (final vertical in verticals) {
      for (final horizontal in horizontals) {
        if (!_touches(horizontal, vertical)) return null;
        if (_majorExtent(vertical) <
            _majorExtent(horizontal) * _minStemTickRatio) {
          return null;
        }
      }
    }
    return _HangulJamo.yae;
  }

  /// Whether the most recent two strokes form ㅢ (ui): a horizontal (ㅡ) and a
  /// vertical (ㅣ) of comparable length that genuinely meet — either crossing
  /// through each other ([_crossesBar]) or joining at the top-right corner
  /// (ㅣ hanging off the right end of the ㅡ). Neither may run
  /// [_minStemTickRatio]× the other (that stem-over-tick proportion is what
  /// makes ㅏ/ㅓ/ㅗ/ㅜ); requiring a real crossing or corner — not a bare
  /// endpoint T-junction — keeps a ㅗ/ㅏ that fell short of the 2× ratio from
  /// reading as ㅢ.
  _HangulJamo? _classifyUi() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes[_strokes.length - 1];
    final _Stroke horizontal;
    final _Stroke vertical;
    if (_isHorizontal(a) && _isStraight(a) && _isVertical(b) && _isStraight(b)) {
      horizontal = a;
      vertical = b;
    } else if (_isHorizontal(b) &&
        _isStraight(b) &&
        _isVertical(a) &&
        _isStraight(a)) {
      horizontal = b;
      vertical = a;
    } else {
      return null;
    }
    final h = _majorExtent(horizontal);
    final v = _majorExtent(vertical);
    if (h >= v * _minStemTickRatio || v >= h * _minStemTickRatio) return null;
    if (_crossesBar(vertical, horizontal)) return _HangulJamo.ui;
    final hRight = horizontal.start.dx >= horizontal.end.dx
        ? horizontal.start
        : horizontal.end;
    final vTop =
        vertical.start.dy <= vertical.end.dy ? vertical.start : vertical.end;
    if ((hRight - vTop).distance <= _touchTolerance) return _HangulJamo.ui;
    return null;
  }

  /// Whether the most recent three strokes form ㅟ (wi): ㅜ — a horizontal bar
  /// with a vertical tick hanging below it — plus a vertical ㅣ crossing the
  /// bar. Sorted by shape into the one bar and two verticals: exactly one
  /// vertical must cross the bar ([_crossesBar]) and the other hang below it
  /// (touching, its centre under the bar), which is what tells the crossing ㅣ
  /// of ㅟ from the second below-tick of ㅠ.
  _HangulJamo? _classifyWi() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final horizontals =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    final verticals =
        recent.where((s) => _isVertical(s) && _isStraight(s)).toList();
    if (horizontals.length != 1 || verticals.length != 2) return null;
    final bar = horizontals.single;
    var crossing = 0;
    var hanging = 0;
    for (final vertical in verticals) {
      if (_crossesBar(vertical, bar)) {
        crossing++;
      } else if (_hangsBelow(vertical, bar)) {
        hanging++;
      } else {
        return null;
      }
    }
    return crossing == 1 && hanging == 1 ? _HangulJamo.wi : null;
  }

  /// Whether the most recent three strokes form ㅚ (oe): ㅗ — a horizontal bar
  /// with a tick standing above it — plus a vertical ㅣ crossing the bar. The
  /// mirror of ㅟ ([_classifyWi]): exactly one vertical crosses the bar and the
  /// other stands above it ([_standsAbove]).
  _HangulJamo? _classifyOe() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final horizontals =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    final verticals =
        recent.where((s) => _isVertical(s) && _isStraight(s)).toList();
    if (horizontals.length != 1 || verticals.length != 2) return null;
    final bar = horizontals.single;
    var crossing = 0;
    var standing = 0;
    for (final vertical in verticals) {
      if (_crossesBar(vertical, bar)) {
        crossing++;
      } else if (_standsAbove(vertical, bar)) {
        standing++;
      } else {
        return null;
      }
    }
    return crossing == 1 && standing == 1 ? _HangulJamo.oe : null;
  }

  /// Whether the most recent four strokes form ㅝ (wo): ㅜ (a bar with a tick
  /// hanging below) whose bar is crossed by a ㅓ — a vertical stem with a
  /// left-pointing tick. The four strokes sort into two horizontals (the ㅜ bar
  /// and the ㅓ tick) and two verticals (the ㅜ tick and the ㅓ stem): exactly
  /// one vertical crosses one horizontal ([_crossesBar]) — that pair is the ㅜ
  /// bar and the ㅓ stem — with the other vertical hanging below the bar and
  /// the other horizontal touching the stem to its left.
  _HangulJamo? _classifyWo() {
    if (_strokes.length < 4) return null;
    final recent = _strokes.sublist(_strokes.length - 4);
    final horizontals =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    final verticals =
        recent.where((s) => _isVertical(s) && _isStraight(s)).toList();
    if (horizontals.length != 2 || verticals.length != 2) return null;
    final crossings = [
      for (final h in horizontals)
        for (final v in verticals)
          if (_crossesBar(v, h)) (h, v),
    ];
    if (crossings.length != 1) return null;
    final (bar, stem) = crossings.single;
    final tick = identical(verticals[0], stem) ? verticals[1] : verticals[0];
    final eoTick = identical(horizontals[0], bar) ? horizontals[1] : horizontals[0];
    if (!_hangsBelow(tick, bar)) return null;
    if (!_touches(eoTick, stem)) return null;
    if (_boundsOf(eoTick.points).center.dx >=
        _boundsOf(stem.points).center.dx) {
      return null;
    }
    return _HangulJamo.wo;
  }

  /// Whether the most recent five strokes form ㅞ (we): ㅝ with a trailing ㅣ —
  /// ㅜ + ㅔ. Like [_classifyWo] but with three verticals: the ㅓ stem crossing
  /// the ㅜ bar, the ㅜ tick hanging below it, and a further ㅣ. Exactly one of
  /// the two non-stem verticals hangs below the bar (the ㅜ tick); the other is
  /// the trailing ㅣ.
  _HangulJamo? _classifyWe() {
    if (_strokes.length < 5) return null;
    final recent = _strokes.sublist(_strokes.length - 5);
    final horizontals =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    final verticals =
        recent.where((s) => _isVertical(s) && _isStraight(s)).toList();
    if (horizontals.length != 2 || verticals.length != 3) return null;
    final crossings = [
      for (final h in horizontals)
        for (final v in verticals)
          if (_crossesBar(v, h)) (h, v),
    ];
    if (crossings.length != 1) return null;
    final (bar, stem) = crossings.single;
    final others = verticals.where((v) => !identical(v, stem)).toList();
    if (others.where((v) => _hangsBelow(v, bar)).length != 1) return null;
    final eoTick = identical(horizontals[0], bar) ? horizontals[1] : horizontals[0];
    if (!_touches(eoTick, stem)) return null;
    if (_boundsOf(eoTick.points).center.dx >=
        _boundsOf(stem.points).center.dx) {
      return null;
    }
    return _HangulJamo.we;
  }

  /// Whether the most recent four strokes form ㅘ (wa): ㅝ mirrored — ㅗ (a bar
  /// with a tick standing above) whose bar is crossed by a ㅏ (a stem with a
  /// right-pointing tick). Like [_classifyWo] but the bar's own tick stands
  /// above ([_standsAbove]) and the crossing stem's tick sits to its right.
  _HangulJamo? _classifyWa() {
    if (_strokes.length < 4) return null;
    final recent = _strokes.sublist(_strokes.length - 4);
    final horizontals =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    final verticals =
        recent.where((s) => _isVertical(s) && _isStraight(s)).toList();
    if (horizontals.length != 2 || verticals.length != 2) return null;
    final crossings = [
      for (final h in horizontals)
        for (final v in verticals)
          if (_crossesBar(v, h)) (h, v),
    ];
    if (crossings.length != 1) return null;
    final (bar, stem) = crossings.single;
    final tick = identical(verticals[0], stem) ? verticals[1] : verticals[0];
    final aTick = identical(horizontals[0], bar) ? horizontals[1] : horizontals[0];
    if (!_standsAbove(tick, bar)) return null;
    if (!_touches(aTick, stem)) return null;
    if (_boundsOf(aTick.points).center.dx <=
        _boundsOf(stem.points).center.dx) {
      return null;
    }
    return _HangulJamo.wa;
  }

  /// Whether the most recent five strokes form ㅙ (wae): ㅘ with a trailing ㅣ —
  /// ㅗ + ㅐ. The mirror of [_classifyWe]: three verticals, exactly one of the
  /// two non-stem verticals standing above the bar (the ㅗ tick) and the
  /// crossing stem's tick to its right.
  _HangulJamo? _classifyWae() {
    if (_strokes.length < 5) return null;
    final recent = _strokes.sublist(_strokes.length - 5);
    final horizontals =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    final verticals =
        recent.where((s) => _isVertical(s) && _isStraight(s)).toList();
    if (horizontals.length != 2 || verticals.length != 3) return null;
    final crossings = [
      for (final h in horizontals)
        for (final v in verticals)
          if (_crossesBar(v, h)) (h, v),
    ];
    if (crossings.length != 1) return null;
    final (bar, stem) = crossings.single;
    final others = verticals.where((v) => !identical(v, stem)).toList();
    if (others.where((v) => _standsAbove(v, bar)).length != 1) return null;
    final aTick = identical(horizontals[0], bar) ? horizontals[1] : horizontals[0];
    if (!_touches(aTick, stem)) return null;
    if (_boundsOf(aTick.points).center.dx <=
        _boundsOf(stem.points).center.dx) {
      return null;
    }
    return _HangulJamo.wae;
  }

  /// Whether the most recent four strokes form ㅂ (bieup): two vertical
  /// lines rung together by two horizontal lines. The four recent strokes
  /// are sorted by orientation into two straight verticals and two straight
  /// horizontals, so stroke order doesn't matter, and every horizontal has
  /// to cross every vertical — the four intersections that make ㅂ's ladder.
  _HangulJamo? _classifyBieup() {
    if (_strokes.length < 4) return null;
    final recent = _strokes.sublist(_strokes.length - 4);
    final verticals =
        recent.where((s) => _isVertical(s) && _isStraight(s)).toList();
    final horizontals =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    if (verticals.length != 2 || horizontals.length != 2) return null;
    for (final horizontal in horizontals) {
      for (final vertical in verticals) {
        if (!_touches(horizontal, vertical)) return null;
      }
    }
    return _HangulJamo.bieup;
  }

  /// Whether the most recent three strokes form ㅎ (hieut): a ㅇ loop with
  /// two horizontal bars stacked above it in the same x range — ㅎ's little
  /// hat over its circle. The three recent strokes are sorted by shape into
  /// the one loop ([_selfCrossingCount]) and two straight horizontals, so
  /// stroke order doesn't matter. The bars both have to sit above the
  /// circle, one clearly above the other ([_minTickSeparation]), covering a
  /// shared x range, with the lower bar resting on the circle ([_touches]) —
  /// which is what keeps two stray horizontals near a ㅇ from reading as ㅎ.
  _HangulJamo? _classifyHieut() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final loops = recent.where((s) => _selfCrossingCount(s) == 1).toList();
    final bars =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    if (loops.length != 1 || bars.length != 2) return null;

    // Order the two bars top-to-bottom by their vertical center.
    bars.sort((x, y) => _boundsOf(x.points)
        .center
        .dy
        .compareTo(_boundsOf(y.points).center.dy));
    final circle = _boundsOf(loops.single.points);
    final upper = _boundsOf(bars.first.points);
    final lower = _boundsOf(bars.last.points);

    // Both bars ride above the circle...
    if (lower.center.dy >= circle.center.dy) return null;
    // ...the upper one clearly above the lower...
    if (lower.center.dy - upper.center.dy < _minTickSeparation) return null;
    // ...the two covering the same x range...
    final overlap = math.min(upper.right, lower.right) -
        math.max(upper.left, lower.left);
    if (overlap < math.min(upper.width, lower.width) / 2) return null;
    // ...and the lower bar resting on the circle.
    if (!_touches(bars.last, loops.single)) return null;
    return _HangulJamo.hieut;
  }

  /// Whether the most recent three strokes form ㄹ (rieul): a ㄷ — a ㄴ
  /// corner capped by a horizontal bar — with a ㄱ corner stacked on top,
  /// the ㄱ hooking onto that same bar. The three recent strokes are sorted
  /// by shape into the ㄱ, the ㄴ, and the bar between them, so stroke order
  /// doesn't matter. The bar has to cap the ㄴ into a ㄷ (touch it, riding in
  /// its upper half) and the ㄱ has to sit above the bar and touch it too —
  /// so ㄹ is exactly ㄷ's one intersection (bar on ㄴ) plus a second (ㄱ on
  /// bar), and a stray ㄱ near an unrelated ㄷ isn't read as ㄹ.
  _HangulJamo? _classifyRieul() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final giyeoks =
        recent.where((s) => _isCorner(s, bodyAboveChord: true)).toList();
    final nieuns =
        recent.where((s) => _isCorner(s, bodyAboveChord: false)).toList();
    final bars =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    if (giyeoks.length != 1 || nieuns.length != 1 || bars.length != 1) {
      return null;
    }
    final giyeok = giyeoks.single;
    final nieun = nieuns.single;
    final bar = bars.single;
    final barCenter = _boundsOf(bar.points).center;
    // The bar caps the ㄴ into a ㄷ: touching it, riding in its upper half.
    if (!_touches(bar, nieun)) return null;
    if (barCenter.dy >= _boundsOf(nieun.points).center.dy) return null;
    // The ㄱ rides above that bar and hooks onto it.
    if (!_touches(bar, giyeok)) return null;
    if (_boundsOf(giyeok.points).center.dy >= barCenter.dy) return null;
    return _HangulJamo.rieul;
  }

  /// Whether the most recent three strokes form ㅁ (mieum): a closed box.
  /// The three recent strokes are sorted by shape into a plain vertical
  /// (the left side), a plain horizontal (the bottom), and a ㄱ corner (the
  /// top and right side), so stroke order doesn't matter. The vertical and
  /// horizontal have to meet, and the ㄱ has to touch both — closing all
  /// four corners of the square. A ㄴ corner is bent, not a plain vertical,
  /// so ㄹ (ㄱ + ㄴ + bar) can't be mistaken for ㅁ (ㄱ + vertical + bar).
  _HangulJamo? _classifyMieum() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final giyeoks =
        recent.where((s) => _isCorner(s, bodyAboveChord: true)).toList();
    final verticals =
        recent.where((s) => _isVertical(s) && _isStraight(s)).toList();
    final horizontals =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    if (giyeoks.length != 1 ||
        verticals.length != 1 ||
        horizontals.length != 1) {
      return null;
    }
    final giyeok = giyeoks.single;
    final vertical = verticals.single;
    final horizontal = horizontals.single;
    // The left side meets the bottom, and the ㄱ closes the top and right by
    // touching both of them.
    if (!_touches(vertical, horizontal)) return null;
    if (!_touches(giyeok, horizontal)) return null;
    if (!_touches(giyeok, vertical)) return null;
    return _HangulJamo.mieum;
  }

  /// Whether the most recent three strokes form ㅌ (tieut): a ㄴ corner
  /// crossed by two horizontal bars. With the ㄴ's own bottom bar, the two
  /// added bars make ㅌ's three rungs. The three recent strokes are sorted
  /// by shape into the ㄴ and its two bars, so stroke order doesn't matter.
  /// Both bars have to touch the ㄴ and ride above its bottom bar (else it's
  /// a repeat of that bottom, not a new rung), and the two have to sit at
  /// different heights ([_minTickSeparation]) — a ㄷ with one added bar,
  /// where ㄷ itself is the ㄴ with just one.
  _HangulJamo? _classifyTieut() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final nieuns =
        recent.where((s) => _isCorner(s, bodyAboveChord: false)).toList();
    final bars =
        recent.where((s) => _isHorizontal(s) && _isStraight(s)).toList();
    if (nieuns.length != 1 || bars.length != 2) return null;
    final nieun = nieuns.single;
    final nieunBottom = _boundsOf(nieun.points).bottom;
    final barCenters = <double>[];
    for (final bar in bars) {
      if (!_touches(bar, nieun)) return null;
      final center = _boundsOf(bar.points).center.dy;
      // Above the ㄴ's own bottom bar, so it's a fresh rung.
      if (center >= nieunBottom - _minTickSeparation) return null;
      barCenters.add(center);
    }
    // The two rungs sit at different heights.
    if ((barCenters[0] - barCenters[1]).abs() < _minTickSeparation) return null;
    return _HangulJamo.tieut;
  }

  /// Whether [stroke] is one of the single-stroke right-angle corners — ㄱ
  /// or ㄴ, chosen by [bodyAboveChord]. Both are drawn top-left to
  /// bottom-right, so their start→end chord runs down and to the right (a
  /// descending diagonal); the bend then throws the body of the stroke to
  /// one side of that chord — above it for ㄱ (the elbow high at the
  /// top-right), below it for ㄴ (the elbow low at the bottom-left).
  ///
  /// The test is: the chord genuinely descends on both axes
  /// ([_minCornerChord]); the whole stroke isn't straight (a line has no
  /// elbow to sit off to a side); the deepest-off-chord point — the elbow —
  /// falls in the stroke's middle with a straight leg either side of it,
  /// which is what tells a right-angle corner from a smooth arc bending the
  /// same way; and the body's average offset from the chord clears
  /// [_minCornerBulge] on the requested side.
  bool _isCorner(_Stroke stroke, {required bool bodyAboveChord}) {
    final points = stroke.points;
    if (points.length < 5) return false;
    final chord = stroke.end - stroke.start;
    if (chord.dx < _minCornerChord || chord.dy < _minCornerChord) return false;
    if (_isStraight(stroke)) return false;

    final length = chord.distance;
    // Signed offset of a point from the start→end chord, via the 2D cross
    // product. Screen y runs downward, so a point above the chord (smaller
    // y) comes out positive — hence ㄱ's high elbow is positive and ㄴ's low
    // one negative.
    double sideOf(Offset point) {
      final offset = point - stroke.start;
      return offset.dx * chord.dy - offset.dy * chord.dx;
    }

    // The elbow is the point furthest off the chord; both legs either side
    // of it must themselves be straight for this to be a corner and not a
    // curve.
    var elbow = 0;
    var elbowDistance = 0.0;
    for (var i = 0; i < points.length; i++) {
      final distance = sideOf(points[i]).abs() / length;
      if (distance > elbowDistance) {
        elbowDistance = distance;
        elbow = i;
      }
    }
    if (elbow < 2 || elbow > points.length - 3) return false;
    if (!_isStraight(_Stroke(points.sublist(0, elbow + 1)))) return false;
    if (!_isStraight(_Stroke(points.sublist(elbow)))) return false;

    var sum = 0.0;
    for (final point in points) {
      sum += sideOf(point);
    }
    final side = sum / points.length / length;
    return bodyAboveChord ? side > _minCornerBulge : side < -_minCornerBulge;
  }

  /// Whether the most recent `tickCount + 1` strokes form a stem-and-ticks
  /// vowel with its ticks on [side], and if so reports [letter]. Covers
  /// all eight: ㅏ/ㅑ (right), ㅓ/ㅕ (left), ㅗ/ㅛ (above), ㅜ/ㅠ (below).
  ///
  /// The shape is: exactly one straight stem, exactly [tickCount] straight
  /// ticks running across it, every tick touching the stem ([_touches])
  /// with its center clear to the requested [side] ([_minSideOffset]), and
  /// no two ticks bunched at the same spot along the stem
  /// ([_minTickSeparation]), and the stem at least [_minStemTickRatio]
  /// times longer than every tick. Whether the stem is the vertical or the
  /// horizontal stroke depends on [side] ([_TickSide.stemIsVertical]) —
  /// vertical for ㅏ-family, horizontal for ㅗ-family — with the ticks
  /// being the other orientation. A tick centered on the stem clears
  /// neither side, so a plus-shaped drawing matches no vowel rather than
  /// the first side tried.
  ///
  /// Stroke order doesn't matter: the recent strokes are sorted into stem
  /// and ticks by their own orientation, so drawing the ticks before the
  /// stem reads the same as after — which is worth allowing even though
  /// Hangul's taught order is stem first, since the recognizer has no
  /// business grading penmanship.
  _HangulJamo? _classifyStemAndTicks(
      int tickCount, _TickSide side, _HangulJamo letter) {
    final total = tickCount + 1;
    if (_strokes.length < total) return null;
    final recent = _strokes.sublist(_strokes.length - total);
    if (!recent.every(_isStraight)) return null;

    final stemIsVertical = side.stemIsVertical;
    final stems =
        recent.where(stemIsVertical ? _isVertical : _isHorizontal).toList();
    final ticks =
        recent.where(stemIsVertical ? _isHorizontal : _isVertical).toList();
    if (stems.length != 1 || ticks.length != tickCount) return null;
    final stem = stems.single;
    final stemCenter = _boundsOf(stem.points).center;
    final stemLength = _majorExtent(stem);

    for (final tick in ticks) {
      if (!_touches(tick, stem)) return null;
      if (stemLength < _majorExtent(tick) * _minStemTickRatio) return null;
      final tickCenter = _boundsOf(tick.points).center;
      // Signed so all four sides share one threshold: positive = the tick
      // is on the correct side of the stem for [side].
      final offset = switch (side) {
        _TickSide.right => tickCenter.dx - stemCenter.dx,
        _TickSide.left => stemCenter.dx - tickCenter.dx,
        _TickSide.below => tickCenter.dy - stemCenter.dy,
        _TickSide.above => stemCenter.dy - tickCenter.dy,
      };
      if (offset <= _minSideOffset) return null;
    }
    // Two ticks must sit apart along the stem — measured along the stem's
    // own axis (top-to-bottom for a vertical stem, left-to-right for a
    // horizontal one), so ㅑ's ticks separate by height and ㅛ's by width.
    for (var i = 0; i < ticks.length; i++) {
      for (var j = i + 1; j < ticks.length; j++) {
        final ci = _boundsOf(ticks[i].points).center;
        final cj = _boundsOf(ticks[j].points).center;
        final gap =
            stemIsVertical ? (ci.dy - cj.dy).abs() : (ci.dx - cj.dx).abs();
        if (gap < _minTickSeparation) return null;
      }
    }
    return letter;
  }

  /// Whether [s] runs top-to-bottom (or bottom-to-top) steeply enough to
  /// read as a vertical rather than a diagonal — see [_verticalRatio].
  bool _isVertical(_Stroke s) {
    final dx = (s.end.dx - s.start.dx).abs();
    final dy = (s.end.dy - s.start.dy).abs();
    return dy > dx * _verticalRatio;
  }

  /// Whether [s] runs flat enough to read as a horizontal rather than a
  /// diagonal — [_isVertical]'s mirror image, see [_horizontalRatio].
  bool _isHorizontal(_Stroke s) {
    final dx = (s.end.dx - s.start.dx).abs();
    final dy = (s.end.dy - s.start.dy).abs();
    return dx > dy * _horizontalRatio;
  }

  /// Whether [s] is a straight line running slanted enough to be a diagonal
  /// — neither steep enough for [_isVertical] nor flat enough for
  /// [_isHorizontal] — the strokes ㅅ is made of.
  bool _isDiagonal(_Stroke s) =>
      _isStraight(s) && !_isVertical(s) && !_isHorizontal(s);

  /// Whether the diagonal [s] rises to the right (`/`) rather than falling
  /// (`\`). Screen y runs downward, so a rising line's run and drop have
  /// opposite signs; the test is direction-agnostic since flipping both
  /// ends leaves the product's sign unchanged.
  bool _isAscending(_Stroke s) =>
      (s.end.dx - s.start.dx) * (s.end.dy - s.start.dy) < 0;

  /// Whether every point of [s] stays within [_straightTolerance] of the
  /// straight chord from its start to its end — i.e. the stroke is a line
  /// and not a curve, hook, or zigzag that merely ends up where a line
  /// would have.
  bool _isStraight(_Stroke s) {
    final chord = s.end - s.start;
    final length = chord.distance;
    if (length == 0) return false;
    final slack = math.max(_minStraightSlack, length * _straightTolerance);
    for (final point in s.points) {
      final offset = point - s.start;
      // Perpendicular distance from `point` to the start→end line, via the
      // 2D cross product's magnitude over the chord's length.
      final distance =
          (offset.dx * chord.dy - offset.dy * chord.dx).abs() / length;
      if (distance > slack) return false;
    }
    return true;
  }

  /// Whether [stroke] touches any other committed stroke ([_touches]) —
  /// how [_classifyI]/[_classifyEu] tell a bare ㅣ/ㅡ from the stem or bar
  /// of a compound letter. [stroke] is expected to already be in
  /// [_strokes] (it's the just-committed one), so it's skipped by
  /// identity.
  bool _touchesAnotherStroke(_Stroke stroke) {
    for (final other in _strokes) {
      if (!identical(other, stroke) && _touches(stroke, other)) return true;
    }
    return false;
  }

  /// Whether [a] and [b] come within [_touchTolerance] of each other
  /// anywhere along their lengths — a crossing counts too, since a
  /// crossing's closest approach is zero.
  bool _touches(_Stroke a, _Stroke b) {
    for (final point in a.points) {
      for (var i = 1; i < b.points.length; i++) {
        if (_pointSegmentDistance(point, b.points[i - 1], b.points[i]) <=
            _touchTolerance) {
          return true;
        }
      }
    }
    return false;
  }

  /// Shortest distance from [p] to the segment [a]–[b] — measured to the
  /// nearest endpoint when the perpendicular foot falls outside the
  /// segment, so a tick alongside (but past the end of) a stem doesn't
  /// read as touching it.
  double _pointSegmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final ap = p - a;
    final t =
        ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  /// The stroke's length along its own long axis — its bounding box's
  /// wider dimension. For a roughly straight stroke that's its length
  /// regardless of orientation, so stem-vs-tick length can be compared
  /// without caring which way either one runs.
  double _majorExtent(_Stroke stroke) {
    final bounds = _boundsOf(stroke.points);
    return math.max(bounds.width, bounds.height);
  }

  Rect _boundsOf(List<Offset> points) {
    var left = points.first.dx, right = points.first.dx;
    var top = points.first.dy, bottom = points.first.dy;
    for (final point in points) {
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
      top = math.min(top, point.dy);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

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

    final recognized = _recognized;
    final label = TextPainter(
      text: recognized != null
          ? TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              children: [
                const TextSpan(text: 'Recognized: '),
                TextSpan(
                  text: recognized.glyph,
                  style: const TextStyle(fontSize: 22),
                ),
                TextSpan(
                  text: '  (${recognized.letterName} — "${recognized.sound}")',
                ),
              ],
            )
          : const TextSpan(
              text: 'Draw a letter below to see it recognized',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

/// Builds the scene plus a direct reference to its [HangulLayer], so the
/// hosting page can call [HangulLayer.clear] from the Clear button.
(Scene, HangulLayer) buildHangulScene() {
  final layer = HangulLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
