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

/// Which corner of its own bounding box a right-angle bend's elbow sits in
/// (see [CyrillicLayer._isCorner]). It's the one thing that tells the
/// printed right-angle letters apart: Г's elbow rides at the [topLeft],
/// where Hangul's ㄱ — the same shape mirrored horizontally — has it at the
/// [topRight], and an L has it at the [bottomLeft].
enum _Corner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  /// Where this corner falls on [bounds] — what the elbow is measured
  /// against.
  Offset of(Rect bounds) => switch (this) {
        topLeft => bounds.topLeft,
        topRight => bounds.topRight,
        bottomLeft => bounds.bottomLeft,
        bottomRight => bounds.bottomRight,
      };
}

/// Which way one leg of a stroke runs. A stroke is cut into legs along one
/// axis at a time: [up]/[down] when it's cut wherever it reverses
/// vertically ([CyrillicLayer._verticalLegs]), [left]/[right] when
/// horizontally ([CyrillicLayer._horizontalLegs]).
///
/// Consecutive legs always alternate, so a pattern is really just "how
/// many legs, starting which way" — but spelling it out is what makes А's
/// up-down, И's down-up-down, М's up-down-up-down and З's
/// right-left-right-left read as the shapes they are.
enum _Leg { up, down, left, right }

/// The letters the recognizer can currently identify. Grows one entry at a
/// time as classifiers are built; [CyrillicLayer.recognizedNames] is kept
/// in step so the page's legend mutes whatever isn't in here yet.
enum _CyrillicLetter {
  a('А', 'а', 'a', 'a'),
  be('Б', 'б', 'be', 'b'),
  ve('В', 'в', 've', 'v'),
  ge('Г', 'г', 'ge', 'g'),
  de('Д', 'д', 'de', 'd'),
  ye('Е', 'е', 'ye', 'ye'),
  yo('Ё', 'ё', 'yo', 'yo'),
  zhe('Ж', 'ж', 'zhe', 'zh'),
  ze('З', 'з', 'ze', 'z'),
  i('И', 'и', 'i', 'i'),
  shortI('Й', 'й', 'short i', 'y'),
  ka('К', 'к', 'ka', 'k'),
  el('Л', 'л', 'el', 'l'),
  em('М', 'м', 'em', 'm'),
  en('Н', 'н', 'en', 'n'),
  o('О', 'о', 'o', 'o'),
  pe('П', 'п', 'pe', 'p'),
  er('Р', 'р', 'er', 'r'),
  es('С', 'с', 'es', 's'),
  te('Т', 'т', 'te', 't'),
  u('У', 'у', 'u', 'u'),
  ef('Ф', 'ф', 'ef', 'f'),
  kha('Х', 'х', 'kha', 'kh'),
  tse('Ц', 'ц', 'tse', 'ts'),
  che('Ч', 'ч', 'che', 'ch'),
  sha('Ш', 'ш', 'sha', 'sh'),
  shcha('Щ', 'щ', 'shcha', 'shch'),
  hardSign('Ъ', 'ъ', 'hard sign', '—'),
  yery('Ы', 'ы', 'yery', 'y'),
  softSign('Ь', 'ь', 'soft sign', '—'),
  e('Э', 'э', 'e', 'e'),
  yu('Ю', 'ю', 'yu', 'yu'),
  ya('Я', 'я', 'ya', 'ya');

  const _CyrillicLetter(this.capital, this.small, this.letterName, this.sound);

  final String capital;
  final String small;
  final String letterName;
  final String sound;
}

/// Freehand recognition of printed (block) Cyrillic capitals:
///
/// - Б (be, "b") — three strokes: an upright stem standing to the left of
///   the other two, a horizontal bar crossing it up in its top half, and
///   a bowl running right then back left that crosses the stem twice (see
///   [CyrillicLayer._classifyBe]).
/// - В (ve, "v") — two strokes: an upright stem standing to the left, and
///   З's own right-left-right-left stroke laid against it, meeting it 3
///   or 4 times — the two bowls, each joining the stem at both ends (see
///   [CyrillicLayer._classifyVe]).
/// - Г (ge, "g") — a right-angle corner with a horizontal top bar and a
///   vertical leg hanging off its *left* end, i.e. the elbow at the
///   top-left. That's Hangul's ㄱ mirrored horizontally, and mirroring is
///   the whole difference: the two shapes agree on everything except which
///   end of the bar the leg drops from. Drawn either as one bent stroke
///   (see [CyrillicLayer._classifyGe] / [CyrillicLayer._isCorner]) or as a
///   separate bar and leg (see [CyrillicLayer._classifyGeTwoStroke]).
/// - А (a, "a") — two strokes: a stroke that rises then falls (Λ, the
///   letter's two splayed legs), and a horizontal bar crossing each of
///   those legs exactly once (see [CyrillicLayer._classifyA]).
/// - Д (de, "d") — two strokes: Л's own Λ, and a wide shallow base whose
///   two ends turn downward — Hebrew nun's bracket with its feet pointing
///   down instead of to the side — crossing each of Λ's legs once, low
///   down (see [CyrillicLayer._classifyDe]). It's А's arrangement with
///   the bar dropped to the foot of the legs and its ends turned down.
/// - Е (ye, "ye") — four strokes: an upright stem standing to the left,
///   and three horizontal bars meeting it once each — one up at its top,
///   one across its middle, one down at its foot (see
///   [CyrillicLayer._classifyYe]).
/// - Ё (yo, "yo") — an Е with two dots above it: a pair of taps sitting
///   clear above the Е's own bounding box and within its run of widths
///   (see [CyrillicLayer._classifyYo]). The only letter here built from
///   taps rather than drags.
/// - Ж (zhe, "zh") — three strokes: Х's own two crossed diagonals, with an
///   upright stem run down through their crossing, meeting each diagonal
///   once (see [CyrillicLayer._classifyZhe]).
/// - З (ze, "z") — one stroke that runs right, back left, right again and
///   left again — the two bowls of the 3-shape — crossing no other
///   stroke. It may cross itself as much as it likes (see
///   [CyrillicLayer._classifyZe]).
/// - И (i, "i") — one stroke that falls, rises and falls again, its outer
///   legs upright stems and the rise between them a diagonal, crossing
///   nothing at all (see [CyrillicLayer._classifyI]).
/// - Й (short i, "y") — two strokes: an И, and a breve above it — one
///   stroke falling then rising, sitting clear above the И's own bounding
///   box and within its run of widths (see
///   [CyrillicLayer._classifyShortI]). The breve is Л's Λ upside down,
///   which is a shape nothing else here claims.
/// - К (ka, "k") — two strokes: an upright stem, and an arm running left
///   and then right — in to meet the stem, then away again — crossing it
///   once or twice (see [CyrillicLayer._classifyKa]).
/// - Л (el, "l") — one stroke that rises then falls, crossing no other
///   stroke: А's Λ standing on its own, without the bar (see
///   [CyrillicLayer._classifyEl]).
/// - М (em, "m") — one stroke that rises, falls, rises and falls again,
///   crossing nothing at all (see [CyrillicLayer._classifyEm]).
/// - Н (en, "n") — three strokes: two upright stems and a horizontal bar
///   crossing each of them once, with the two crossings falling on
///   opposite sides of the bar's own centre (see
///   [CyrillicLayer._classifyEn]).
/// - Ш (sha, "sh") — three strokes: a ㄴ-shaped corner (Ч's own arm — down
///   the left stem and along the foot), and two upright stems standing on
///   that foot, each meeting it once (see [CyrillicLayer._classifySha]).
/// - Щ (shcha, "shch") — three strokes: Ц's own body, with two upright
///   legs standing on its foot instead of one, each meeting it at its own
///   foot (see [CyrillicLayer._classifyShcha]). Щ stands to Ш exactly as
///   Ц stands to Ч — the same letter with a descender hung off the end of
///   its foot.
/// - Ъ (hard sign) — two strokes: Ь with its stem replaced by a Hebrew
///   vav — a bar at the top running right into the stem, then down, i.e.
///   Hangul's ㄱ (see [CyrillicLayer._classifyHardSign]).
/// - Ы (yery, "y") — three strokes: a Ь, plus a second upright stem
///   standing clear to its right over the same run of heights (see
///   [CyrillicLayer._classifyYery]).
/// - Ь (soft sign) — two strokes: Б without its top bar, so an upright
///   stem with a belly crossing it twice, hanging low on the stem (see
///   [CyrillicLayer._classifySoftSign]). Where the belly sits is the only
///   thing separating it from Р, which is otherwise the same two strokes
///   meeting the same way.
/// - Э (e, "e") — two strokes: a bowl running right then back left, its
///   opening facing left and its own path uncrossed, plus a horizontal
///   bar crossing it once through its middle, reaching away to the left
///   of that crossing (see [CyrillicLayer._classifyE]).
/// - Р (er, "r") — two strokes: an upright stem, and a bowl running right
///   then back left that crosses it twice, hanging off its right and
///   sitting high on it (see [CyrillicLayer._classifyEr]).
/// - П (pe, "p") — one stroke bent into two squared corners sharing a top
///   bar: a Г's elbow joined to a ㄱ's, so the bar runs across the top and
///   a leg hangs down from either end of it (see
///   [CyrillicLayer._classifyPe] / [CyrillicLayer._isArch]). It's the
///   sibling `tifi` project's ⵎ — a squared C opening to the right —
///   turned a quarter turn so it opens downward instead.
/// - С (es, "s") — one stroke running left then back right, both its ends
///   finishing to the right of its own centre, and crossing neither its
///   own path nor anything else: Э's bowl mirrored, and with the bar taken
///   away (see [CyrillicLayer._classifyEs]).
/// - Т (te, "t") — two strokes: a horizontal bar with an upright stem
///   hanging below its middle (see [CyrillicLayer._classifyTe]). Where
///   along the bar the stem hangs is the whole of what tells it from a
///   two-stroke Г, whose leg drops from the bar's left end instead —
///   [CyrillicLayer._junctionSnap] is the one measurement, and it hands
///   the bar's left quarter to Г and its middle half to Т.
/// - У (u, "u") — Х's own two strokes crossing the same way, one rising
///   and one falling, with the falling one lifted up and to the left and
///   all but stopped at the crossing: it leaves a stub below, where the
///   tail carries on down to the foot (see [CyrillicLayer._classifyU]).
///   In a Х the two run on below the crossing much alike, and how much of
///   each is left there is the whole difference.
/// - Ф (ef, "f") — two strokes: an О's ring, run through by an upright
///   stem that crosses it twice (see [CyrillicLayer._classifyEf]).
/// - Х (kha, "kh") — two strokes crossing once, one rising to the right
///   and one falling, read off their endpoints alone (see
///   [CyrillicLayer._classifyKha]).
/// - Ю (yu, "yu") — three strokes: an upright stem on the left, a
///   horizontal bar crossing it across its middle and reaching right, and
///   an О's loop that the bar runs into — two crossings in all, since the
///   loop hangs off the bar clear of the stem (see
///   [CyrillicLayer._classifyYu]).
/// - Я (ya, "ya") — two strokes: an upright stem on the right, and a
///   stroke to its left running left, back right and left again — the
///   bowl's top, its return to the stem, then the leg — meeting the stem
///   on the way (see [CyrillicLayer._classifyYa]).
/// - Ц (tse, "ts") — two strokes: a body running down, right and down
///   again — the left leg, the foot, then the descender — and an upright
///   leg standing to its right, meeting it at the leg's own foot where
///   the body turns into the descender (see [CyrillicLayer._classifyTse]).
///   The body is П's own two-corner test with the left elbow moved to the
///   bottom: a ㄴ joined to a ㄱ, where П is a Г joined to a ㄱ (see
///   [CyrillicLayer._isTseBody]).
/// - Ч (che, "ch") — two strokes: a straight vertical stem, and an arm
///   shaped like Hangul's ㄴ (the same right-angle corner as Г with its
///   elbow at the bottom-left instead) sitting to the stem's left and
///   meeting it in exactly one place (see [CyrillicLayer._classifyChe]).
/// - О (o, "o") — one stroke that crosses its own path exactly once — a
///   closed loop — and crosses nothing else on the page (see
///   [CyrillicLayer._classifyO]).
///
/// Stroke direction is deliberately not checked. A single-stroke Г can be
/// written top-right → left → down or bottom-left → up → right, and a
/// two-stroke one in either stroke order; all four are the same letter to
/// any reader, so [_isCorner] works off where the elbow lands in the
/// stroke's own bounding box rather than off which way the hand travelled.
/// Ч's two strokes sort themselves by shape rather than by draw order for
/// the same reason, and О doesn't care which way round the loop was swept.
///
/// А, И, М and З are all read off the same primitive — cut the stroke
/// wherever it reverses along one axis and look at the run of legs that
/// leaves. The first three cut vertically
/// ([CyrillicLayer._verticalLegs]) and differ only in their pattern:
/// up-down, down-up-down, and up-down-up-down. З cuts the same way
/// horizontally instead ([CyrillicLayer._horizontalLegs]), which is why
/// it can be a curly shape and still be read off a run of four legs.
///
/// Two strokes meeting and one stroke crossing itself are counted
/// differently on purpose. An arm running into a stem is a T-junction —
/// whether the pen overshoots by a pixel or stops a pixel short is noise,
/// so [CyrillicLayer._contacts] counts runs of near-contact
/// ([CyrillicLayer._touchTolerance]). A loop genuinely crosses its own
/// path, so [CyrillicLayer._selfIntersections] counts real segment
/// intersections and an unclosed circle is correctly not a letter.
///
/// Recognition is live and non-destructive — it re-reads the most recently
/// completed stroke(s) after every stroke, and everything drawn stays on
/// the page whether or not it matched.
class CyrillicLayer extends Layer {
  /// A press-and-release shorter than this is a tap, not a drag — a dot
  /// rather than a stroke. Ё's diaeresis is the only thing built from
  /// them, and it's why they're kept at all.
  static const double _tapThreshold = 5;

  /// How large a tapped dot is drawn. Nothing measures against it; it's
  /// only so a tap leaves something on the page to see.
  static const double _dotRadius = 5;

  /// Shortest drag that counts as a deliberate stroke rather than a
  /// slipped tap.
  static const double _minDragDistance = 8;

  /// How much taller than wide a stroke must be to read as vertical. A
  /// plain `|dy| > |dx|` would accept a 45°-ish diagonal, which belongs to
  /// a different letter (И's and Л's slants, later on).
  static const double _verticalRatio = 2;

  /// The margin [_verticalRatio] relaxes to for Ц's and Щ's descender: it
  /// need only fall further than it runs. That tail is written as a hook
  /// rather than as a stroke, and a hook leans — hold it to a stem's
  /// plumb and an ordinarily written one misses by a few degrees.
  static const double _hookRatio = 1;

  /// The same margin the other way round. Deliberately equal to
  /// [_verticalRatio]: a line slanted enough to be ambiguous should match
  /// neither orientation, rather than falling to whichever check happens
  /// to run first.
  static const double _horizontalRatio = 2;

  /// How far a stroke may bow off its own straight start-to-end chord and
  /// still read as a straight line: the larger of [_minStraightSlack] and
  /// this fraction of the chord's length. It's what keeps a curve or a
  /// hook from passing for one of Г's two legs.
  static const double _straightTolerance = 0.12;
  static const double _minStraightSlack = 6;

  /// How close two strokes must come to count as touching (see [_touches]).
  /// A two-stroke Г meets in a corner rather than a crossing, so a strict
  /// segment-intersection test would turn on whether the hand happened to
  /// overshoot by a pixel — a leg stopping just short of the bar is the
  /// same letter to any reader.
  static const double _touchTolerance = 22;

  /// The least a corner's bounding box may span on each axis. Below this
  /// the "corner" is really a near-horizontal or near-vertical kink, where
  /// which box corner the elbow sits in is noise.
  static const double _minCornerLeg = 15;

  /// How far the elbow may sit from its bounding-box corner, as a fraction
  /// of the box, and still commit to that corner. Two axis-aligned legs
  /// put the elbow *at* the corner, so this only absorbs the rounding of a
  /// hand-drawn bend — it's not enough slack to let a top-left elbow pass
  /// for a top-right one. It's also what rejects a smooth quarter arc
  /// bending Г's way, whose deepest point sits a quarter of the way along
  /// the box rather than in its corner: a bend has to actually be squared
  /// off to read as a letter.
  static const double _cornerSnap = 0.2;

  /// Where along the bar a two-stroke Г's leg may hang and still count as
  /// hanging off its left end, as a fraction of the bar's width (see
  /// [_classifyGeTwoStroke]). A leg at the bar's middle is a different
  /// letter's shape (a Т), and one at its right end is a mirrored ㄱ, so
  /// neither should be allowed to fall through to Г.
  static const double _junctionSnap = 0.25;

  /// How much of У's arm may lie past the crossing, as a share of the
  /// arm's own length. Two lines crossing at their middles is a Х, so half
  /// is where the shape stops being a У: an arm mostly spent by the time
  /// it arrives is the other letter.
  static const double _maxArmBeyond = 0.5;

  /// [_maxArmBeyond]'s opposite number, for Ч: how much of the stem must
  /// carry on below where the arm runs into it. Where У's arm has to be
  /// all but spent by the time it arrives, Ч's stem has to have a real
  /// share of itself still to go — without it the arm has merely met the
  /// stem's own foot, and the shape is a ⊔ rather than a letter.
  static const double _minStemBeyond = 0.25;

  /// And the same for Ц's and Щ's legs: how much of one may be left below
  /// the foot it stands on. A hand runs a leg past the line it meant to
  /// stop at, so a little below is a leg standing on the foot — most of it
  /// below is a leg hanging from the foot, which is another shape.
  static const double _maxLegBeyond = 0.25;

  /// How far a stroke must double back vertically before that counts as
  /// changing direction rather than as the hand wobbling (see
  /// [_verticalLegs]). Without it every tremor along a long stem would
  /// split off a leg of its own, and Н's three legs would come out as a
  /// dozen.
  static const double _directionSlack = 6;

  /// The least a foot on Д's base must drop for it to be a foot at all,
  /// and the most of the base's own width its feet may account for. A
  /// bracket deeper than this is no longer a base with feet — it's the Λ
  /// standing on it (see [_isFootedBar]).
  static const double _minFootDrop = 10;
  static const double _maxFootRatio = 0.5;

  /// How much of a bowl's height, at each end, is not its middle — so a
  /// bar has to cross Э's bowl in the band between rather than along one
  /// of its arms (see [_classifyE]).
  static const double _middleBand = 0.25;

  /// How far Ч's arm must sit clear of its stem to count as being on the
  /// stem's left. An arm centred on the stem is a different shape (a plus,
  /// or a Т with a tail), so it should match nothing rather than fall
  /// through on which side happened to win by a pixel.
  static const double _minSideOffset = 6;

  /// Which letters the recognizer supports so far, matched against
  /// [LetterRow.name]. Kept in step with [_CyrillicLetter] — used by
  /// [CyrillicPage] to mute the letters that can't be drawn yet rather
  /// than listing them as if they could.
  static const recognizedNames = {
    'a', 'be', 've', 'ge', 'de', 'ye', 'yo', 'zhe', 'ze', 'i', 'short i',
    'ka', 'el', 'em', 'en', 'o', 'pe', 'er', 'es', 'te', 'ef', 'kha', 'tse',
    'che', 'sha', 'shcha', 'hard sign', 'yery', 'soft sign', 'e', 'yu', 'ya',
    'u',
  };

  final List<_Stroke> _strokes = [];
  final List<Offset> _dots = [];
  _CyrillicLetter? _recognized;
  List<Offset>? _activePoints;

  /// The capital currently being reported, or null if the drawing matches
  /// no letter. The letters themselves are private ([_CyrillicLetter]);
  /// this exposes just enough of the result for tests to assert on what a
  /// given sequence of strokes recognizes as.
  String? get recognizedGlyph => _recognized?.capital;

  void clear() {
    _strokes.clear();
    _dots.clear();
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
      if (dragDistance < _tapThreshold) {
        // A dot re-reads the page just as a stroke does, so the Е already
        // sitting there turns into a Ё the moment its second dot lands.
        _dots.add(points.first);
        _recognized = _classify();
      } else if (points.length >= 2 && dragDistance >= _minDragDistance) {
        _commit(_Stroke(points));
      }
      _activePoints = null;
    }
  }

  void _commit(_Stroke stroke) {
    _strokes.add(stroke);
    _recognized = _classify();
  }

  /// Recognizes the current [_strokes] as one letter, most-strokes-first so
  /// a finished letter isn't reported as the simpler shape it contains.
  ///
  /// О is deliberately not in the list: it asks for nothing but a single
  /// self-crossing, and a one-stroke letter picks one of those up whenever
  /// the hand closes a join it didn't have to — a З whose bowls meet, say.
  /// So every letter with a shape of its own gets first refusal, and О is
  /// only reached once they've all declined. A new classifier belongs in
  /// the list; there is no "after О" to append to.
  _CyrillicLetter? _classify() {
    // Dots alone are no letter, and a tap can now reach here with nothing
    // drawn — which the single-stroke classifiers, reading [_strokes.last]
    // outright, would take badly.
    if (_strokes.isEmpty) return null;
    for (final classifier in [
      // Ahead of Е, which Ё is: take the dots away and what's left is an
      // Е exactly.
      _classifyYo,
      _classifyYe,
      _classifyBe,
      _classifyEn,
      // Ahead of Ш, which claims a Щ outright whenever the descender is
      // short against the foot. [_isStraight]'s slack is a fraction of the
      // chord it measures, and Ш reads the body whole — one long chord,
      // so much slack that a small tail vanishes into it and the body
      // passes for the plain ㄴ Ш wants. Щ cuts the body in half first,
      // halving the chord and the slack with it, so the same tail still
      // reads as the bend it is. Both letters match; only this order
      // settles it.
      //
      // Ahead of Ц too, which Щ contains: finish a Щ with its body and the
      // last two strokes are a leg and a body, which is a Ц exactly.
      _classifyShcha,
      // Ahead of Ч: finish Ш with its corner and Ч sees, in the last two
      // strokes, exactly the arm-and-stem pair it looks for. Moving this
      // below Ч turns the corner-drawn-last test into a Ч.
      _classifySha,
      _classifyYu,
      // Ahead of Х, which Ж contains: drop Ж's stem and the two diagonals
      // left over are a Х exactly.
      _classifyZhe,
      // Ahead of Ь, which Ы contains: drop Ы's spare stem and the two
      // strokes left over are a soft sign exactly. Moving this below Ь
      // turns the Ы test into a Ь.
      _classifyYery,
      _classifyVe,
      _classifyYa,
      _classifyEf,
      _classifyHardSign,
      _classifySoftSign,
      _classifyEr,
      _classifyKa,
      _classifyE,
      _classifyDe,
      _classifyA,
      // Ahead of Ч, whose questions Ц answers two of the same way: a stem,
      // the other stroke to its left, met in one place. Only the body's
      // shape is left, and on a wide Ц with a small descender that isn't
      // enough — Ч reads the body whole, and over a long chord the tail
      // falls inside [_isStraight]'s slack. So this order is load-bearing,
      // exactly as Щ's is over Ш.
      _classifyTse,
      _classifyChe,
      _classifyGeTwoStroke,
      // After Г, with which it splits the bar: Г takes a leg hanging from
      // the left quarter, Т one hanging from the middle half. They meet at
      // a single point, and this order hands that point to Г.
      _classifyTe,
      // Ahead of Х, which is У with both strokes made to fall the whole
      // way: У asks for everything Х does and more, so Х claims every У
      // put after it.
      _classifyU,
      // Last of the two-stroke shapes: it asks only for two lines crossing
      // at opposite slants, which a slanted Г or Ч answers just as well.
      _classifyKha,
      _classifyGe,
      _classifyEm,
      // Ahead of И, which Й contains: draw a Й's breve first and the И
      // arrives last, which is an И exactly.
      _classifyShortI,
      _classifyI,
      _classifyZe,
      // Ahead of Л: a П rises and falls exactly as Λ does — both are a
      // horizontal stroke with its two ends below its middle — so Л would
      // otherwise claim it. Only П's flat top separates the two.
      _classifyPe,
      // After А, which is this same Λ with a bar laid across it.
      _classifyEl,
      // After К and Э, both of which contain this arc: К's arm is the same
      // run of legs, and Э's bowl is it mirrored with a bar across.
      _classifyEs,
    ]) {
      final letter = classifier();
      if (letter != null) return letter;
    }
    return _classifyO();
  }

  /// Whether the last stroke is a one-stroke Г: a single right-angle bend
  /// with its elbow at the top-left, so the bar runs right from it and the
  /// leg drops down from it (see [_isCorner]).
  _CyrillicLetter? _classifyGe() =>
      _isCorner(_strokes.last, elbow: _Corner.topLeft)
          ? _CyrillicLetter.ge
          : null;

  /// Whether the last two strokes are a two-stroke Г: a horizontal bar and
  /// a vertical leg that touch, with the leg hanging off the bar's left
  /// end ([_junctionSnap]) and dropping below it — the same elbow-at-the-
  /// top-left shape [_classifyGe] looks for, just lifted the pen between
  /// the two legs. Either stroke order works, since the two are sorted by
  /// their own orientation rather than by when they were drawn.
  _CyrillicLetter? _classifyGeTwoStroke() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke bar;
    final _Stroke leg;
    if (_isHorizontal(a) && _isVertical(b)) {
      bar = a;
      leg = b;
    } else if (_isHorizontal(b) && _isVertical(a)) {
      bar = b;
      leg = a;
    } else {
      return null;
    }
    if (!_isStraight(bar) || !_isStraight(leg)) return null;
    if (!_touches(bar, leg)) return null;

    final barBounds = _boundsOf(bar.points);
    final legBounds = _boundsOf(leg.points);
    // The leg hangs off the bar's left end, and below it — not from its
    // middle (a Т) and not from its right end (ㄱ mirrored back again).
    if (legBounds.center.dx > barBounds.left + barBounds.width * _junctionSnap) {
      return null;
    }
    if (legBounds.center.dy <= barBounds.center.dy) return null;
    return _CyrillicLetter.ge;
  }

  /// Whether the last two strokes form Т: a horizontal bar and an upright
  /// stem that touch, with the stem hanging below the bar's *middle*
  /// ([_junctionSnap]). Either stroke order.
  ///
  /// This and [_classifyGeTwoStroke] are the same two strokes measured the
  /// same way, and they divide the bar between them: a leg in its left
  /// quarter is a Г, one in its middle half is a Т. The remaining quarter
  /// is ㄱ mirrored back again and belongs to neither, which is why the
  /// band is stated as a distance from the bar's centre rather than as
  /// "not Г's end".
  _CyrillicLetter? _classifyTe() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke bar;
    final _Stroke stem;
    if (_isBar(a) && _isStem(b)) {
      bar = a;
      stem = b;
    } else if (_isBar(b) && _isStem(a)) {
      bar = b;
      stem = a;
    } else {
      return null;
    }
    if (!_touches(bar, stem)) return null;

    final barBounds = _boundsOf(bar.points);
    final stemBounds = _boundsOf(stem.points);
    if ((stemBounds.center.dx - barBounds.center.dx).abs() >
        barBounds.width * _junctionSnap) {
      return null;
    }
    // Below the bar, not through it: a stem centred on the bar is a cross.
    return stemBounds.center.dy > barBounds.center.dy + _minSideOffset
        ? _CyrillicLetter.te
        : null;
  }

  /// Whether the last two strokes form Д: Л's own Λ, plus a wide shallow
  /// base whose ends turn downward ([_isFootedBar]), crossing each of the
  /// Λ's legs exactly once, low down in the Λ rather than across its
  /// middle.
  ///
  /// This is А's arrangement with the bar dropped to the foot of the legs
  /// and its ends turned down, and either difference on its own is enough
  /// to tell the two apart: А's bar has to be dead straight, which a
  /// footed one isn't. Either stroke order.
  _CyrillicLetter? _classifyDe() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke apex;
    final _Stroke base;
    if (_isFootedBar(a) && _hasLegs(b, const [_Leg.up, _Leg.down])) {
      base = a;
      apex = b;
    } else if (_isFootedBar(b) && _hasLegs(a, const [_Leg.up, _Leg.down])) {
      base = b;
      apex = a;
    } else {
      return null;
    }

    final bounds = _boundsOf(apex.points);
    final low = bounds.bottom - bounds.height * _middleBand;
    for (final leg in _verticalLegs(apex)) {
      final crossings = _crossingPoints(base, leg);
      if (crossings.length != 1) return null;
      if (crossings.single.dy < low) return null;
    }
    return _CyrillicLetter.de;
  }

  /// Whether [s] is Д's base: a broadly horizontal stroke, wide and
  /// shallow ([_maxFootRatio]), whose two ends both turn downward — a
  /// bracket with its feet pointing down.
  ///
  /// The wide-and-shallow part is what keeps a Λ out. A Λ is also a
  /// horizontal stroke with both ends below its middle — it's a bar with
  /// very long feet — and only its proportions say otherwise.
  bool _isFootedBar(_Stroke s) {
    if (!_isHorizontal(s)) return false;
    final bounds = _boundsOf(s.points);
    if (bounds.height < _minFootDrop) return false;
    if (bounds.height > bounds.width * _maxFootRatio) return false;
    final middle = bounds.center.dy;
    return s.start.dy > middle && s.end.dy > middle;
  }

  /// Whether the last two strokes form А: a stroke that rises then falls
  /// — Λ, the letter's two splayed legs — plus a straight horizontal bar
  /// crossing each of those legs exactly once. Checking the two legs
  /// separately rather than counting two crossings against the whole Λ is
  /// what rules out a bar that clips one leg twice and misses the other.
  /// Either stroke order works.
  _CyrillicLetter? _classifyA() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke apex;
    final _Stroke bar;
    if (_isBar(a) && _hasLegs(b, const [_Leg.up, _Leg.down])) {
      bar = a;
      apex = b;
    } else if (_isBar(b) && _hasLegs(a, const [_Leg.up, _Leg.down])) {
      bar = b;
      apex = a;
    } else {
      return null;
    }
    for (final leg in _verticalLegs(apex)) {
      if (_crossings(bar, leg) != 1) return null;
    }
    return _CyrillicLetter.a;
  }

  /// Whether the last stroke is П: an arch — two squared corners sharing a
  /// top bar ([_isArch]) — crossing no other stroke on the page.
  _CyrillicLetter? _classifyPe() =>
      _isArch(_strokes.last) && !_crossesAnotherStroke(_strokes.last)
          ? _CyrillicLetter.pe
          : null;

  /// Whether the last stroke is Л: one stroke rising then falling, and
  /// crossing no other stroke on the page — А's Λ standing on its own.
  ///
  /// This is a loose test, and deliberately so: it's the same rise-and-
  /// fall А asks of its legs, with only the bar taken away. It sits after
  /// А in [_classify] for that reason, so a Λ that does have a bar across
  /// it is read as the А it is.
  _CyrillicLetter? _classifyEl() =>
      _hasLegs(_strokes.last, const [_Leg.up, _Leg.down]) &&
              !_crossesAnotherStroke(_strokes.last)
          ? _CyrillicLetter.el
          : null;

  /// Whether the last stroke is М: one stroke rising, falling, rising and
  /// falling again — the two peaks and the valley between them — and
  /// crossing nothing, its own path included.
  _CyrillicLetter? _classifyEm() =>
      _hasLegs(_strokes.last,
                  const [_Leg.up, _Leg.down, _Leg.up, _Leg.down]) &&
              _crossesNothing(_strokes.last)
          ? _CyrillicLetter.em
          : null;

  /// Whether the last stroke is З: one stroke running right, back left,
  /// right again and left again — the top bowl of the 3-shape, then the
  /// bottom one — crossing no other stroke on the page.
  ///
  /// Unlike М and И, its own path is fair game: the two bowls of a З meet
  /// in the middle, and whether a given hand closes that join into a
  /// crossing or stops just shy of it isn't the difference between one
  /// letter and another.
  _CyrillicLetter? _classifyZe() =>
      _isZeShaped(_strokes.last) && !_crossesAnotherStroke(_strokes.last)
          ? _CyrillicLetter.ze
          : null;

  /// Whether the last three strokes form Ш: a ㄴ-shaped corner — Ч's own
  /// arm, down the left stem and along the foot — with two upright stems
  /// standing on that foot, each meeting it exactly once, down at the
  /// bottom of the corner where the foot runs rather than up its upright.
  ///
  /// Stroke order doesn't matter here, but it does decide whether Ч would
  /// otherwise get in first: finish the letter with its corner and the
  /// last two strokes are a stem and a ㄴ-arm, which is Ч exactly. Hence
  /// Ш sits above Ч in [_classify].
  _CyrillicLetter? _classifySha() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final corners =
        recent.where((s) => _isCorner(s, elbow: _Corner.bottomLeft)).toList();
    final stems = recent.where(_isStem).toList();
    if (corners.length != 1 || stems.length != 2) return null;
    final corner = corners.single;

    final bounds = _boundsOf(corner.points);
    final low = bounds.bottom - bounds.height * _middleBand;
    for (final stem in stems) {
      final crossings = _crossingPoints(stem, corner);
      if (crossings.length != 1) return null;
      if (crossings.single.dy < low) return null;
    }
    return _CyrillicLetter.sha;
  }

  /// Whether the last three strokes form Ю: an upright stem on the left, a
  /// horizontal bar crossing it across its middle and reaching away to its
  /// right, and a loop — О's own shape — that the bar runs into once.
  ///
  /// Two crossings in all, which is what says the loop hangs off the far
  /// end of the bar: a loop drawn over the stem as well would make three.
  /// Stroke order doesn't matter.
  _CyrillicLetter? _classifyYu() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final stems = recent.where(_isStem).toList();
    final bars = recent.where(_isBar).toList();
    final loops = recent.where(_isLoop).toList();
    if (stems.length != 1 || bars.length != 1 || loops.length != 1) return null;
    final stem = stems.single;
    final bar = bars.single;
    final loop = loops.single;

    final crossings = _crossingPoints(bar, stem);
    if (crossings.length != 1) return null;
    if (_crossings(bar, loop) != 1) return null;
    if (_crossings(loop, stem) != 0) return null;

    final bounds = _boundsOf(stem.points);
    final along = (crossings.single.dy - bounds.top) / bounds.height;
    if (along < _middleBand || along > 1 - _middleBand) return null;
    return _boundsOf(bar.points).center.dx >
            bounds.center.dx + _minSideOffset
        ? _CyrillicLetter.yu
        : null;
  }

  /// Whether the last two strokes form Я: an upright stem on the right,
  /// and a stroke to its left running left, back right and left again —
  /// across the top of the bowl, back to the stem, then away down the leg
  /// — meeting it 2 or 3 times on the way. Either stroke order.
  ///
  /// The bowl joins the stem at its top and again at its waist, and the
  /// leg may set off from the stem too, hence 2 or 3 rather than a single
  /// count. The run of legs is what separates Я from В, which is the same
  /// idea with the bowls on the other side and a leg more.
  _CyrillicLetter? _classifyYa() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke stem;
    final _Stroke body;
    if (_isStem(a) && _isYaShaped(b)) {
      stem = a;
      body = b;
    } else if (_isStem(b) && _isYaShaped(a)) {
      stem = b;
      body = a;
    } else {
      return null;
    }

    final meetings = _crossings(body, stem);
    if (meetings < 2 || meetings > 3) return null;
    return _boundsOf(body.points).center.dx <
            _boundsOf(stem.points).center.dx - _minSideOffset
        ? _CyrillicLetter.ya
        : null;
  }

  /// Whether the last two strokes form Ф: an О's ring with an upright stem
  /// run through it, crossing it at least twice — in at the top, out at
  /// the foot. Either stroke order.
  ///
  /// At least, not exactly: a ring closes by overlapping itself, so a stem
  /// passing through where the two ends cross picks up a third meeting it
  /// didn't ask for. Twice is the shape; more than that is the same shape
  /// drawn by a hand.
  _CyrillicLetter? _classifyEf() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke stem;
    final _Stroke ring;
    if (_isStem(a) && _isLoop(b)) {
      stem = a;
      ring = b;
    } else if (_isStem(b) && _isLoop(a)) {
      stem = b;
      ring = a;
    } else {
      return null;
    }
    return _crossings(stem, ring) >= 2 ? _CyrillicLetter.ef : null;
  }

  /// Whether the last three strokes form Ж: Х's own two diagonals crossing
  /// once, with an upright stem run down through them, meeting each
  /// diagonal exactly once.
  ///
  /// The stem is picked out first ([_isStem]) and the slants read off what
  /// is left, rather than the other way round: a hand-drawn upright that
  /// leans a little is [_isAscending] or [_isDescending] too, and letting
  /// it stand in for a diagonal would make a Х with a leaning stem match
  /// twice over. Stroke order doesn't matter.
  _CyrillicLetter? _classifyZhe() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final stems = recent.where(_isStem).toList();
    if (stems.length != 1) return null;
    final stem = stems.single;
    final arms = recent.where((s) => !identical(s, stem)).toList();
    if (arms.where(_isAscending).length != 1) return null;
    if (arms.where(_isDescending).length != 1) return null;

    if (_crossings(arms.first, arms.last) != 1) return null;
    for (final arm in arms) {
      if (_crossings(stem, arm) != 1) return null;
    }
    return _CyrillicLetter.zhe;
  }

  /// Whether the last two strokes form У: Х's two slants, with the falling
  /// one — the arm — lifted up and to the left of the rising one, and
  /// stopping where the two meet instead of running on past it. Either
  /// stroke order.
  ///
  /// Both letters genuinely cross; what separates them is how much of the
  /// arm is left on the far side of that crossing. In a У the arm runs
  /// into the tail and all but stops, leaving a stub while the tail makes
  /// the whole rest of the drop; in a Х the arm carries on down as far as
  /// the tail does.
  ///
  /// That stub is asked about twice over, along the arm and down the page.
  /// Along the arm, more than half of its length past the crossing is a Х
  /// outright ([_maxArmBeyond], walked point by point — see
  /// [_shareBeyond]) since that is what two lines crossing at their
  /// middles looks like. Down the page, the two drops below the crossing
  /// are measured against each other ([_middleBand]) rather than either
  /// being measured against the canvas, so a stub stays a stub whatever
  /// size the letter is drawn.
  ///
  /// Where the arm sits is asked about as well, and isn't implied by
  /// either: a small tick laid across the top of a long diagonal leaves
  /// just as little below the crossing. The arm's middle has to fall on
  /// the tail's upper-left side ([_dropFrom]), which for a stroke rising
  /// to the right is one half of the page rather than two conditions.
  _CyrillicLetter? _classifyU() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke arm;
    final _Stroke tail;
    if (_isDescending(a) && _isAscending(b)) {
      arm = a;
      tail = b;
    } else if (_isDescending(b) && _isAscending(a)) {
      arm = b;
      tail = a;
    } else {
      return null;
    }
    final crossings = _crossingPoints(arm, tail);
    if (crossings.length != 1) return null;
    final at = crossings.single;

    // How much of the arm is left past the crossing, walked along the arm
    // itself: more than half of it and the shape is a Х, whatever the
    // drops below say.
    final armFoot = arm.start.dy > arm.end.dy ? arm.start : arm.end;
    if (_shareBeyond(arm, at, armFoot) > _maxArmBeyond) return null;

    if (_dropFrom(tail, _boundsOf(arm.points).center) <= _minSideOffset) {
      return null;
    }
    final armBounds = _boundsOf(arm.points);
    final tailBounds = _boundsOf(tail.points);
    return armBounds.bottom - at.dy <=
            (tailBounds.bottom - at.dy) * _middleBand
        ? _CyrillicLetter.u
        : null;
  }

  /// How far [point] sits off [stroke] on its upper-left side, or 0 if it
  /// sits on the other side of it — the perpendicular distance, signed by
  /// which way it falls.
  ///
  /// A stroke rising to the right cuts the page in two, and "above it" and
  /// "left of it" name the same half. That half is where У's arm has its
  /// middle: in a Х the two cross at their middles, so the arm's own
  /// middle lands *on* the tail and this reads 0.
  ///
  /// Measured against the tail's line rather than against its bounding
  /// box, which is not the same thing and matters: a У's tail runs the
  /// whole width of the letter, so its box's centre can easily sit to the
  /// right of the arm's — and does, on an ordinarily drawn У.
  double _dropFrom(_Stroke stroke, Offset point) {
    // Orient the stroke from its lower end to its upper one, so which way
    // the hand travelled doesn't decide which side is which.
    final foot = stroke.start.dy > stroke.end.dy ? stroke.start : stroke.end;
    final head = stroke.start.dy > stroke.end.dy ? stroke.end : stroke.start;
    final along = head - foot;
    final length = along.distance;
    if (length == 0) return 0;
    final side = along.dx * (point.dy - foot.dy) - along.dy * (point.dx - foot.dx);
    return side < 0 ? -side / length : 0;
  }

  /// The share of [stroke]'s own length lying past [at] — where something
  /// crossed it — on the side its [towards] end is on.
  ///
  /// Walked point by point rather than taken off the start-to-end chord,
  /// so a stroke that bows on its way is measured as it was drawn. A hand
  /// draws no straight lines, and the chord of a bowed one reads short.
  double _shareBeyond(_Stroke stroke, Offset at, Offset towards) {
    final points = stroke.points;
    var nearest = 0;
    var closest = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final distance = (points[i] - at).distance;
      if (distance < closest) {
        closest = distance;
        nearest = i;
      }
    }

    var before = 0.0;
    var after = 0.0;
    for (var i = 1; i < points.length; i++) {
      final step = (points[i] - points[i - 1]).distance;
      if (i <= nearest) {
        before += step;
      } else {
        after += step;
      }
    }
    if (before + after == 0) return 0;
    final beyond = (points.last - towards).distance <
            (points.first - towards).distance
        ? after
        : before;
    return beyond / (before + after);
  }

  /// Whether the last two strokes form Х: two strokes crossing once, one
  /// rising to the right and one falling. Slant is read off the two
  /// endpoints alone, so a hand-drawn stroke that wanders on the way still
  /// counts as whichever way it ended up going. Either stroke order.
  ///
  /// Both strokes must also reach across the letter, with an end clear
  /// either side of the pair's own vertical middle. That is what keeps an
  /// upright out: no hand draws one exactly plumb, and a leg leaning by a
  /// pixel reads as rising or falling like anything else — so Ц's leg, or
  /// Ч's, arrives here as one of two opposite slants that cross. A leg
  /// stays on its own side of the middle where a Х's arms cross it.
  ///
  /// It's the loosest of the two-stroke shapes and sits last among them
  /// for that reason: a Г or a Ч drawn on a slant is also two strokes
  /// crossing at opposite slants.
  _CyrillicLetter? _classifyKha() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final rising = [a, b].where(_isAscending).length;
    final falling = [a, b].where(_isDescending).length;
    if (rising != 1 || falling != 1) return null;
    if (_crossings(a, b) != 1) return null;

    // Both strokes have to reach across the letter — an end clear either
    // side of the pair's own vertical middle. Slant is read off the two
    // endpoints alone, so an upright leaning by a pixel counts as rising
    // or falling like anything else, and a Ц or a Ч whose leg leans that
    // way would otherwise arrive here as two opposite slants that cross.
    // A leg stays on its own side of the middle; a Х's arms do not.
    final middle = _boundsOf([...a.points, ...b.points]).center.dx;
    for (final stroke in [a, b]) {
      final ends = [stroke.start.dx, stroke.end.dx];
      if (ends.every((x) => x > middle - _minSideOffset) ||
          ends.every((x) => x < middle + _minSideOffset)) {
        return null;
      }
    }
    return _CyrillicLetter.kha;
  }

  /// Whether [s] ends up to the right of and above where it started, or
  /// the reverse — a `/`. Screen y runs downward, so a rising stroke's run
  /// and drop have opposite signs; the test is direction-agnostic, since
  /// swapping both ends leaves the product's sign alone. A stroke that
  /// ends level with or directly under where it began is neither this nor
  /// [_isDescending].
  bool _isAscending(_Stroke s) =>
      (s.end.dx - s.start.dx) * (s.end.dy - s.start.dy) < 0;

  /// [_isAscending]'s mirror — a `\`.
  bool _isDescending(_Stroke s) =>
      (s.end.dx - s.start.dx) * (s.end.dy - s.start.dy) > 0;

  /// Whether the last two strokes form Ь: Б without its top bar, so an
  /// upright stem with a belly crossing it twice. Either stroke order.
  _CyrillicLetter? _classifySoftSign() {
    if (_strokes.length < 2) return null;
    return _bellyOn(_strokes[_strokes.length - 2], _strokes.last, _isStem,
                high: false) !=
            null
        ? _CyrillicLetter.softSign
        : null;
  }

  /// Whether the last two strokes form Р: the soft sign's own two strokes
  /// — an upright stem with a bowl crossing it twice off to its right —
  /// with the bowl riding high on the stem instead of hanging low.
  ///
  /// That is the whole of the difference. Р and Ь are the same stem, the
  /// same right-then-left bowl and the same two crossings; only where the
  /// bowl sits along the stem tells them apart, so [_bellyOn] takes it as
  /// an argument rather than either letter owning it.
  _CyrillicLetter? _classifyEr() {
    if (_strokes.length < 2) return null;
    return _bellyOn(_strokes[_strokes.length - 2], _strokes.last, _isStem,
                high: true) !=
            null
        ? _CyrillicLetter.er
        : null;
  }

  /// Whether the last two strokes form Ъ: Ь with its stem replaced by a
  /// Hebrew vav — a bar at the top running right into the stem, then down,
  /// which is Hangul's ㄱ and so a corner with its elbow at the top right.
  /// Either stroke order.
  _CyrillicLetter? _classifyHardSign() {
    if (_strokes.length < 2) return null;
    return _bellyOn(_strokes[_strokes.length - 2], _strokes.last,
                (s) => _isCorner(s, elbow: _Corner.topRight), high: false) !=
            null
        ? _CyrillicLetter.hardSign
        : null;
  }

  /// Whether the last three strokes form Ы: a Ь, plus a second upright
  /// stem standing clear to its right over the same run of heights.
  ///
  /// Clear of it, not joined to it: the two halves of Ы are drawn apart,
  /// and a stem that did meet the belly would be inside it rather than
  /// beside it. Stroke order doesn't matter — whichever of the three is
  /// the spare stem is found by trying each in turn.
  _CyrillicLetter? _classifyYery() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    for (var i = 0; i < recent.length; i++) {
      final spare = recent[i];
      if (!_isStem(spare)) continue;
      final rest = [
        for (var j = 0; j < recent.length; j++)
          if (j != i) recent[j],
      ];
      final pair = _bellyOn(rest.first, rest.last, _isStem, high: false);
      if (pair == null) continue;
      final (stem, belly) = pair;

      if (_crossings(spare, stem) != 0 || _crossings(spare, belly) != 0) {
        continue;
      }
      final spareBounds = _boundsOf(spare.points);
      if (spareBounds.center.dx <
          _boundsOf(belly.points).center.dx + _minSideOffset) {
        continue;
      }
      // Over the same run of heights as the soft sign's own stem.
      final stemBounds = _boundsOf(stem.points);
      if (spareBounds.bottom <= stemBounds.top ||
          spareBounds.top >= stemBounds.bottom) {
        continue;
      }
      return _CyrillicLetter.yery;
    }
    return null;
  }

  /// Whether the last two strokes form К: an upright stem, and an arm
  /// running left and then right — in to meet the stem, then away again —
  /// hanging off the stem's right and crossing it once or twice. Once
  /// where the arm turns on the stem, twice where it carries past and
  /// comes back. Either stroke order.
  ///
  /// The arm's run of legs is the mirror of Ь's belly, which is what keeps
  /// the two apart: Ь's swings out to the right and returns, К's comes in
  /// to the left and leaves.
  _CyrillicLetter? _classifyKa() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke stem;
    final _Stroke arm;
    if (_isStem(a) && _isKaArm(b)) {
      stem = a;
      arm = b;
    } else if (_isStem(b) && _isKaArm(a)) {
      stem = b;
      arm = a;
    } else {
      return null;
    }
    if (_boundsOf(stem.points).center.dx >
        _boundsOf(arm.points).center.dx - _minSideOffset) {
      return null;
    }
    final meetings = _crossings(arm, stem);
    return meetings >= 1 && meetings <= 2 ? _CyrillicLetter.ka : null;
  }

  /// Whether [s] runs left and then right — К's arm, and the mirror of
  /// [_isBowl]'s right-then-left.
  bool _isKaArm(_Stroke s) => _hasSideLegs(s, const [_Leg.left, _Leg.right]);

  /// The upright and the belly among [a] and [b], if between them they
  /// make the soft sign's own shape: an upright — whatever [isUpright]
  /// accepts, a plain stem for Ь or a vav for Ъ — with a bowl crossing it
  /// twice and hanging off to its right. Null if they don't.
  ///
  /// [high] picks which of the two letters built this way is meant: the
  /// bowl's own centre above the upright's for Р, below it for Ь (and so
  /// for Ъ and Ы, which are built on Ь). Nothing else separates them.
  (_Stroke, _Stroke)? _bellyOn(
      _Stroke a, _Stroke b, bool Function(_Stroke) isUpright,
      {required bool high}) {
    final _Stroke upright;
    final _Stroke belly;
    if (isUpright(a) && _isBowl(b)) {
      upright = a;
      belly = b;
    } else if (isUpright(b) && _isBowl(a)) {
      upright = b;
      belly = a;
    } else {
      return null;
    }
    if (_crossings(belly, upright) != 2) return null;

    final uprightCentre = _boundsOf(upright.points).center;
    final bellyCentre = _boundsOf(belly.points).center;
    if (uprightCentre.dx > bellyCentre.dx - _minSideOffset) return null;
    if (high) {
      if (bellyCentre.dy > uprightCentre.dy - _minSideOffset) return null;
    } else if (bellyCentre.dy < uprightCentre.dy + _minSideOffset) {
      return null;
    }
    return (upright, belly);
  }

  /// Whether [s] runs left, back right and left again — Я's bowl and leg
  /// in one stroke.
  bool _isYaShaped(_Stroke s) =>
      _hasSideLegs(s, const [_Leg.left, _Leg.right, _Leg.left]);

  /// Whether [s] closes into a loop: one crossing of its own path, which
  /// is what makes a stroke a ring rather than an open arc.
  bool _isLoop(_Stroke s) => _selfIntersections(s) == 1;

  /// Whether the last two strokes form В: an upright stem, and З's own
  /// right-left-right-left stroke laid against it, meeting it 3 or 4
  /// times. Each bowl joins the stem at both ends, which would be 4
  /// meetings; where a bowl's foot and the next one's head arrive at the
  /// same spot they read as one, hence 3. The stem stands to the left of
  /// the bowls ([_minSideOffset]), so they hang off it rather than
  /// straddle it. Either stroke order.
  _CyrillicLetter? _classifyVe() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke stem;
    final _Stroke bowls;
    if (_isStem(a) && _isZeShaped(b)) {
      stem = a;
      bowls = b;
    } else if (_isStem(b) && _isZeShaped(a)) {
      stem = b;
      bowls = a;
    } else {
      return null;
    }

    final meetings = _crossings(bowls, stem);
    if (meetings < 3 || meetings > 4) return null;
    return _boundsOf(stem.points).center.dx <
            _boundsOf(bowls.points).center.dx - _minSideOffset
        ? _CyrillicLetter.ve
        : null;
  }

  /// Whether [s] runs right, back left, right again and left again — the
  /// 3-shape, which is З on its own and В's pair of bowls when it's laid
  /// against a stem.
  bool _isZeShaped(_Stroke s) => _hasSideLegs(
      s, const [_Leg.right, _Leg.left, _Leg.right, _Leg.left]);

  /// Whether the last stroke is И: one stroke falling, rising and falling
  /// again — down the left stem, up the diagonal, down the right stem —
  /// with the two outer legs being upright stems, and crossing nothing,
  /// its own path included.
  ///
  /// The stems are what make this И rather than merely something that
  /// falls, rises and falls: a circle drawn not quite closed does that
  /// too, entering and leaving on its right-hand side, and only the stems
  /// tell the two apart.
  _CyrillicLetter? _classifyI() =>
      _isIShaped(_strokes.last) && _crossesNothing(_strokes.last)
          ? _CyrillicLetter.i
          : null;

  /// Whether [s] is И's own stroke: falling, rising and falling again,
  /// with the two outer legs upright stems.
  bool _isIShaped(_Stroke s) {
    if (!_hasLegs(s, const [_Leg.down, _Leg.up, _Leg.down])) return false;
    final legs = _verticalLegs(s);
    return _isStem(legs.first) && _isStem(legs.last);
  }

  /// Whether the last two strokes form Й: an И, and a breve sitting clear
  /// above it ([_sitsAbove]). Either stroke order.
  ///
  /// Nothing is asked of the two beyond where the breve sits, because
  /// nothing else here is a falling-then-rising stroke: it is Л's Λ upside
  /// down, and the Л tests already record that a V matches no letter.
  _CyrillicLetter? _classifyShortI() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke body;
    final _Stroke breve;
    if (_isIShaped(a) && _isBreve(b)) {
      body = a;
      breve = b;
    } else if (_isIShaped(b) && _isBreve(a)) {
      body = b;
      breve = a;
    } else {
      return null;
    }
    return _sitsAbove(breve.points, _boundsOf(body.points))
        ? _CyrillicLetter.shortI
        : null;
  }

  /// Whether [s] is Й's breve: one stroke falling then rising.
  bool _isBreve(_Stroke s) => _hasLegs(s, const [_Leg.down, _Leg.up]);

  /// Whether the last four strokes form Е with two dots above it, which is
  /// Ё. The Е is asked for by running [_classifyYe] itself, since Ё is
  /// that letter exactly plus its diaeresis.
  ///
  /// The dots are located against the Е's own bounding box rather than
  /// against the page, so where on the page the letter was drawn doesn't
  /// come into it.
  _CyrillicLetter? _classifyYo() {
    if (_dots.length < 2 || _strokes.length < 4) return null;
    if (_classifyYe() == null) return null;
    final bounds = _boundsOf([
      for (final stroke in _strokes.sublist(_strokes.length - 4))
        ...stroke.points,
    ]);
    return _sitsAbove(_dots.sublist(_dots.length - 2), bounds)
        ? _CyrillicLetter.yo
        : null;
  }

  /// Whether every point of [mark] sits clear above [bounds] and stays
  /// within its run of widths — where Ё's two dots and Й's breve both go.
  bool _sitsAbove(List<Offset> mark, Rect bounds) {
    for (final point in mark) {
      if (point.dy >= bounds.top) return false;
      if (point.dx < bounds.left || point.dx > bounds.right) return false;
    }
    return true;
  }

  /// Whether the last four strokes form Е: an upright stem, and three
  /// horizontal bars meeting it once each — one up in its top third, one
  /// across its middle third, one down in its bottom third — all three
  /// reaching away to the stem's right ([_minSideOffset]).
  ///
  /// Where along the stem the bars land is the whole letter: three bars
  /// bunched at the top is no more an Е than one bar is, so the crossings
  /// are located and sorted into thirds rather than merely counted.
  /// Stroke order doesn't matter.
  _CyrillicLetter? _classifyYe() {
    if (_strokes.length < 4) return null;
    final recent = _strokes.sublist(_strokes.length - 4);
    final stems = recent.where(_isStem).toList();
    final bars = recent.where(_isBar).toList();
    if (stems.length != 1 || bars.length != 3) return null;
    final stem = stems.single;
    final bounds = _boundsOf(stem.points);
    final stemCentre = bounds.center.dx;

    var top = 0, middle = 0, bottom = 0;
    for (final bar in bars) {
      final crossings = _crossingPoints(bar, stem);
      if (crossings.length != 1) return null;
      if (_boundsOf(bar.points).center.dx < stemCentre + _minSideOffset) {
        return null;
      }
      final along = (crossings.single.dy - bounds.top) / bounds.height;
      if (along < 1 / 3) {
        top++;
      } else if (along > 2 / 3) {
        bottom++;
      } else {
        middle++;
      }
    }
    return top == 1 && middle == 1 && bottom == 1 ? _CyrillicLetter.ye : null;
  }

  /// Whether the last three strokes form Б: an upright stem, a horizontal
  /// bar crossing it once up in its top half, and a bowl running right
  /// then back left that crosses the stem twice — the belly, meeting the
  /// stem at its top and again at its foot. The stem stands to the left of
  /// both the others ([_minSideOffset]), which is what makes the bar and
  /// the belly hang off it rather than straddle it.
  ///
  /// Stroke order doesn't matter: the three sort themselves by shape.
  _CyrillicLetter? _classifyBe() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final stems = recent.where(_isStem).toList();
    final bars = recent.where(_isBar).toList();
    final bowls = recent.where(_isBowl).toList();
    if (stems.length != 1 || bars.length != 1 || bowls.length != 1) return null;
    final stem = stems.single;
    final bar = bars.single;
    final bowl = bowls.single;

    if (_crossings(bar, stem) != 1) return null;
    if (_crossings(bowl, stem) != 2) return null;

    final stemCentre = _boundsOf(stem.points).center;
    final barCentre = _boundsOf(bar.points).center;
    if (barCentre.dy > stemCentre.dy - _minSideOffset) return null;
    if (stemCentre.dx > barCentre.dx - _minSideOffset) return null;
    if (stemCentre.dx >
        _boundsOf(bowl.points).center.dx - _minSideOffset) {
      return null;
    }
    return _CyrillicLetter.be;
  }

  /// Whether the last three strokes form Н: two upright stems and a
  /// horizontal bar crossing each of them exactly once, with the two
  /// crossings falling on opposite sides of the bar's own centre
  /// ([_minSideOffset]).
  ///
  /// Where along the bar the stems land is the whole shape. Both stems on
  /// the same side of its centre is a bar with a tail, not an Н, so the
  /// crossing points are located ([_intersectionPoint]) rather than merely
  /// counted. Stroke order doesn't matter: the three sort themselves by
  /// orientation.
  _CyrillicLetter? _classifyEn() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final stems = recent.where(_isStem).toList();
    final bars = recent.where(_isBar).toList();
    if (stems.length != 2 || bars.length != 1) return null;
    final bar = bars.single;

    final centre = _boundsOf(bar.points).center.dx;
    var left = 0, right = 0;
    for (final stem in stems) {
      final crossings = _crossingPoints(bar, stem);
      if (crossings.length != 1) return null;
      final at = crossings.single;
      if (at.dx < centre - _minSideOffset) left++;
      if (at.dx > centre + _minSideOffset) right++;
    }
    return left == 1 && right == 1 ? _CyrillicLetter.en : null;
  }

  /// Whether the last two strokes form Э: a bowl running right then back
  /// left — the backwards-C outline, its opening facing left, its own path
  /// uncrossed — plus a horizontal bar crossing it exactly once through
  /// its middle, the bar reaching away to the left of that crossing.
  ///
  /// Which side of the crossing the bar lies on is what makes this Э and
  /// not Е: the same bowl mirrored, with its bar reaching right instead.
  /// The crossing has to fall in the bowl's middle band too, so a bar laid
  /// across one of the bowl's arms is no letter rather than this one.
  /// Either stroke order.
  _CyrillicLetter? _classifyE() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke bowl;
    final _Stroke bar;
    if (_isBar(a) && _isBowl(b)) {
      bar = a;
      bowl = b;
    } else if (_isBar(b) && _isBowl(a)) {
      bar = b;
      bowl = a;
    } else {
      return null;
    }

    final crossings = _crossingPoints(bar, bowl);
    if (crossings.length != 1) return null;
    final at = crossings.single;

    final bounds = _boundsOf(bowl.points);
    if (at.dy < bounds.top + bounds.height * _middleBand ||
        at.dy > bounds.bottom - bounds.height * _middleBand) {
      return null;
    }
    return _boundsOf(bar.points).center.dx < at.dx - _minSideOffset
        ? _CyrillicLetter.e
        : null;
  }

  /// Whether [s] is Э's bowl: a stroke out to the right and back left
  /// again, never crossing itself.
  bool _isBowl(_Stroke s) =>
      _hasSideLegs(s, const [_Leg.right, _Leg.left]) &&
      _selfIntersections(s) == 0;

  /// Whether the last stroke is С: [_isBowl] mirrored — one stroke out to
  /// the left and back right again, its opening facing right — crossing
  /// neither its own path nor any other stroke on the page.
  ///
  /// That's Э with the bar taken away and the bowl turned round, and both
  /// differences matter: an arc facing the other way is Э's bowl waiting
  /// for its bar, and one with a bar across it is the Э itself.
  ///
  /// Loose, like Л, and placed late in [_classify] for the same reason —
  /// К's arm is this very shape, and only the stem beside it says
  /// otherwise.
  _CyrillicLetter? _classifyEs() =>
      _isArc(_strokes.last) && !_crossesAnotherStroke(_strokes.last)
          ? _CyrillicLetter.es
          : null;

  /// Whether [s] is С's arc: out to the left and back right again, never
  /// crossing itself, with both its ends standing to the right of its own
  /// bounding box's centre — the opening facing right.
  ///
  /// Only where the two ends land is asked about, deliberately. How the
  /// arc rises and falls on the way is a matter of hand: the terminals of
  /// a printed С curl back toward the opening, so it goes up over the top,
  /// down the back and up again into the foot — three vertical legs, not
  /// the one a plain crescent would leave.
  bool _isArc(_Stroke s) {
    if (!_isKaArm(s) || _selfIntersections(s) != 0) return false;
    final centre = _boundsOf(s.points).center.dx;
    return s.start.dx > centre && s.end.dx > centre;
  }

  /// Whether [stroke] crosses neither its own path nor any other stroke on
  /// the page — what makes a shape a letter in its own right rather than
  /// one piece of a bigger, tangled one.
  bool _crossesNothing(_Stroke stroke) =>
      _selfIntersections(stroke) == 0 && !_crossesAnotherStroke(stroke);

  /// Whether [stroke] crosses any other stroke on the page. [stroke] is
  /// expected to already be in [_strokes] (it's the just-committed one),
  /// so it's skipped by identity.
  bool _crossesAnotherStroke(_Stroke stroke) {
    for (final other in _strokes) {
      if (identical(other, stroke)) continue;
      if (_crossings(stroke, other) > 0) return true;
    }
    return false;
  }

  /// Whether [stroke] is a plain flat line — А's crossbar.
  bool _isBar(_Stroke s) => _isHorizontal(s) && _isStraight(s);

  /// Whether [stroke] rises and falls in exactly the pattern [expected]
  /// spells out, one entry per leg (see [_verticalLegs]).
  bool _hasLegs(_Stroke stroke, List<_Leg> expected) =>
      _matches(_verticalLegs(stroke), expected,
          (leg) => leg.end.dy > leg.start.dy ? _Leg.down : _Leg.up);

  /// [_hasLegs] turned on its side: whether [stroke] runs to and fro in
  /// exactly the pattern [expected] spells out (see [_horizontalLegs]).
  bool _hasSideLegs(_Stroke stroke, List<_Leg> expected) =>
      _matches(_horizontalLegs(stroke), expected,
          (leg) => leg.end.dx > leg.start.dx ? _Leg.right : _Leg.left);

  bool _matches(List<_Stroke> legs, List<_Leg> expected,
      _Leg Function(_Stroke) directionOf) {
    if (legs.length != expected.length) return false;
    for (var i = 0; i < legs.length; i++) {
      if (directionOf(legs[i]) != expected[i]) return false;
    }
    return true;
  }

  /// Cuts [stroke] wherever it genuinely reverses vertically — Λ's apex,
  /// М's peaks and valley, И's bottom-left and top-right.
  List<_Stroke> _verticalLegs(_Stroke stroke) =>
      _splitAtReversals(stroke, (point) => point.dy);

  /// The same cut turned on its side, wherever [stroke] reverses
  /// horizontally — З's two turns back and the one between its bowls.
  List<_Stroke> _horizontalLegs(_Stroke stroke) =>
      _splitAtReversals(stroke, (point) => point.dx);

  /// Cuts [stroke] wherever the coordinate [along] reads off each point
  /// reverses direction, and returns the pieces in the order they were
  /// drawn.
  ///
  /// A reversal only counts once the stroke has doubled back
  /// [_directionSlack] from the furthest point it had reached — otherwise
  /// the hand's tremor along a long stem would shred it into legs. The cut
  /// falls at that furthest point, which is where the eye sees the turn.
  List<_Stroke> _splitAtReversals(
      _Stroke stroke, double Function(Offset) along) {
    final points = stroke.points;
    if (points.length < 2) return [];

    final legs = <_Stroke>[];
    var start = 0;
    var turn = 0;
    bool? rising;
    for (var i = 1; i < points.length; i++) {
      final at = along(points[i]);
      if (rising == null) {
        // Still looking for the stroke's first committed direction.
        if ((at - along(points[start])).abs() < _directionSlack) continue;
        rising = at > along(points[start]);
        turn = i;
        continue;
      }
      final furtherOn = rising ? at > along(points[turn]) : at < along(points[turn]);
      if (furtherOn) {
        turn = i;
      } else if ((at - along(points[turn])).abs() >= _directionSlack) {
        legs.add(_Stroke(points.sublist(start, turn + 1)));
        start = turn;
        rising = !rising;
        turn = i;
      }
    }
    legs.add(_Stroke(points.sublist(start)));
    return legs;
  }

  /// Whether the last two strokes form Ц: a body running down, right and
  /// down again ([_isTseBody]), with an upright leg standing clear to its
  /// right ([_minSideOffset]) on the body's own foot ([_standsOn]), where
  /// it turns into the descender. Either stroke order.
  ///
  /// Ч is the letter to keep clear of, since Ц answers two of its three
  /// questions the same way — a stem, with the other stroke to its left,
  /// met once. Only the body's shape is left to separate them, and it does
  /// so only up to a point: Ч reads the body whole, and [_isStraight]
  /// allows a fraction of the chord it measures, so on a wide Ц with a
  /// small descender the foot and the tail together still pass for one
  /// straight leg and Ч matches. Being ahead of Ч in [_classify] is what
  /// actually settles those, not the shape test — the same arrangement Щ
  /// has with Ш.
  _CyrillicLetter? _classifyTse() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke leg;
    final _Stroke body;
    if (_isStem(a) && _isTseBody(b)) {
      leg = a;
      body = b;
    } else if (_isStem(b) && _isTseBody(a)) {
      leg = b;
      body = a;
    } else {
      return null;
    }

    if (_boundsOf(leg.points).center.dx <
        _boundsOf(body.points).center.dx + _minSideOffset) {
      return null;
    }
    return _standsOn(leg, body) ? _CyrillicLetter.tse : null;
  }

  /// Whether the last three strokes form Щ: Ц's own body, with two upright
  /// legs standing on its foot instead of one. Stroke order doesn't
  /// matter — the three sort themselves by shape.
  ///
  /// Where the legs stand isn't asked about, only that they stand apart
  /// ([_minSideOffset]): Щ's are the middle one and the right one, and the
  /// middle one sits over the body's own centre, so neither side of it is
  /// the answer. Ц's single leg can be pinned to the right; a pair can't.
  ///
  /// Ahead of Ш and Ц both in [_classify]. Ц because Щ contains one:
  /// finish a Щ with its body and the last two strokes are a leg and a
  /// body, which is a Ц exactly. Ш because it genuinely claims a Щ whose
  /// descender is short against its foot — [_isStraight] allows a fraction
  /// of the chord, Ш reads the body whole, and over that long a chord a
  /// small tail falls inside the slack and the body passes for a plain ㄴ.
  /// Cutting the body in half first halves the chord, which is why the
  /// same tail still reads as a bend here. Both letters match such a Щ;
  /// only the order tells them apart.
  ///
  /// The other direction needs no guarding: Ш's own ㄴ has no descender,
  /// so its right-hand half is a straight half-foot and no Ц body.
  _CyrillicLetter? _classifyShcha() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final bodies = recent.where(_isTseBody).toList();
    final legs = recent.where(_isStem).toList();
    if (bodies.length != 1 || legs.length != 2) return null;
    final body = bodies.single;

    for (final leg in legs) {
      if (!_standsOn(leg, body)) return null;
    }
    final apart = (_boundsOf(legs.first.points).center.dx -
            _boundsOf(legs.last.points).center.dx)
        .abs();
    return apart > _minSideOffset ? _CyrillicLetter.shcha : null;
  }

  /// Whether [leg] stands on [body]: an upright meeting it in exactly one
  /// place, and meeting it there at the leg's own foot rather than
  /// anywhere else along its length.
  ///
  /// The meeting is counted as a T-junction ([_contacts]) rather than a
  /// crossing, for Ч's reason: whether the hand overshot the foot by a
  /// pixel or stopped a pixel short is not the difference between one
  /// letter and another.
  ///
  /// "At its foot" is asked as Ч and У ask it — how little of the leg is
  /// left below the meeting ([_maxLegBeyond], see [_shareBeyond]) — and
  /// not as how near the leg's own end lands, which would turn on a hand
  /// stopping neatly. A leg run well past the foot still stands on it; a
  /// leg hung *from* it, with all of itself below, does not. Which end is
  /// the foot is read off the two endpoints' heights rather than off which
  /// was drawn first, so which way the leg was drawn doesn't matter.
  bool _standsOn(_Stroke leg, _Stroke body) {
    if (_contacts(leg, body) != 1) return false;
    final foot = leg.start.dy > leg.end.dy ? leg.start : leg.end;
    return _shareBeyond(leg, _nearestPointTo(leg, body), foot) <=
        _maxLegBeyond;
  }

  /// Whether the last two strokes form Ч: a straight vertical stem, and an
  /// arm bent like Hangul's ㄴ — the same right-angle corner Г is, with the
  /// elbow at the bottom-left instead of the top-left — whose own centre
  /// sits clear to the stem's left ([_minSideOffset]), meeting the stem in
  /// exactly one place. Either stroke order works, since the two are told
  /// apart by their own shape rather than by when they were drawn.
  ///
  /// One meeting place is what separates Ч from the shapes built out of
  /// the same two pieces: an arm that runs into the stem twice is a
  /// different letter, and one that never reaches it is two unrelated
  /// marks.
  ///
  /// The stem also has to carry on below that meeting ([_minStemBeyond]),
  /// which is У's question asked the other way round: there the arm must
  /// be all but spent where the two meet, here the stem must have a real
  /// share of itself still to go. An arm running into the foot of a stem
  /// rather than its middle makes a ⊔, and a ⊔ is no letter here.
  _CyrillicLetter? _classifyChe() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke stem;
    final _Stroke arm;
    if (_isStem(a) && _isCorner(b, elbow: _Corner.bottomLeft)) {
      stem = a;
      arm = b;
    } else if (_isStem(b) && _isCorner(a, elbow: _Corner.bottomLeft)) {
      stem = b;
      arm = a;
    } else {
      return null;
    }
    final offset =
        _boundsOf(stem.points).center.dx - _boundsOf(arm.points).center.dx;
    if (offset <= _minSideOffset) return null;
    if (_contacts(arm, stem) != 1) return null;

    // The stem carries on below where the arm runs into it — that drop is
    // the letter's whole lower half. The junction is the point along the
    // arm that comes nearest the stem, not either of the arm's ends: a ㄴ
    // whose upright is long can have its *top* end nearer the stem than
    // the foot that actually runs into it.
    final junction = _nearestPointTo(arm, stem);
    final foot = stem.start.dy > stem.end.dy ? stem.start : stem.end;
    return _shareBeyond(stem, junction, foot) >= _minStemBeyond
        ? _CyrillicLetter.che
        : null;
  }

  /// Whether the last stroke is О: a single stroke that crosses its own
  /// path exactly once — the crossing is what makes it a closed loop
  /// rather than an open arc — and that crosses no other stroke on the
  /// page, since a loop tangled with something else is part of a bigger
  /// letter, not an О.
  ///
  /// This is the loosest test here, which is why [_classify] only reaches
  /// it once every letter with a shape of its own has declined.
  _CyrillicLetter? _classifyO() =>
      _isLoop(_strokes.last) && !_crossesAnotherStroke(_strokes.last)
          ? _CyrillicLetter.o
          : null;

  /// Whether [s] is a plain upright line — Ч's spine.
  bool _isStem(_Stroke s) => _isVertical(s) && _isStraight(s);

  /// Whether [stroke] is a single right-angle corner — one horizontal leg
  /// and one vertical leg meeting at an elbow — with that elbow in the
  /// [elbow] corner of the stroke's own bounding box.
  ///
  /// The test is: the box genuinely spans both axes ([minLeg]); the whole
  /// stroke isn't straight (a line has no elbow); the point furthest off
  /// the start→end chord — the elbow — falls in the stroke's middle with a
  /// straight leg either side of it, which is what tells a right-angle
  /// corner from a smooth arc bending the same way; those two legs run one
  /// across and one down; and the elbow lands within [_cornerSnap] of the
  /// requested box corner.
  ///
  /// [minLeg] defaults to [_minCornerLeg] and is lowered only by Ц, whose
  /// descender is deliberately tiny (see [_isTseBody]). Lowering it gives
  /// up less than it looks: a bend too shallow to be a bend is already
  /// turned away by [_isStraight], since it leaves the elbow inside
  /// [_straightTolerance] of the chord.
  bool _isCorner(_Stroke stroke,
      {required _Corner elbow,
      double minLeg = _minCornerLeg,
      double uprightRatio = _verticalRatio}) {
    final points = stroke.points;
    if (points.length < 5) return false;
    final bounds = _boundsOf(points);
    if (bounds.width < minLeg || bounds.height < minLeg) {
      return false;
    }
    if (_isStraight(stroke)) return false;

    final chord = stroke.end - stroke.start;
    final length = chord.distance;
    if (length == 0) return false;

    // The elbow is the point furthest off the start→end chord; both legs
    // either side of it must themselves be straight for this to be a
    // corner and not a curve.
    var index = 0;
    var furthest = 0.0;
    for (var i = 0; i < points.length; i++) {
      final offset = points[i] - stroke.start;
      // Perpendicular distance to the chord, via the 2D cross product's
      // magnitude over the chord's length.
      final distance =
          (offset.dx * chord.dy - offset.dy * chord.dx).abs() / length;
      if (distance > furthest) {
        furthest = distance;
        index = i;
      }
    }
    if (index < 2 || index > points.length - 3) return false;

    final first = _Stroke(points.sublist(0, index + 1));
    final second = _Stroke(points.sublist(index));
    if (!_isStraight(first) || !_isStraight(second)) return false;
    final squared =
        (_isHorizontal(first) && _isSteep(second, uprightRatio)) ||
            (_isSteep(first, uprightRatio) && _isHorizontal(second));
    if (!squared) return false;

    final corner = elbow.of(bounds);
    return (points[index].dx - corner.dx).abs() <=
            bounds.width * _cornerSnap &&
        (points[index].dy - corner.dy).abs() <= bounds.height * _cornerSnap;
  }

  /// Whether [stroke] is a pair of squared corners sharing a middle leg:
  /// cut where it first passes the middle of its own bounding box
  /// horizontally, its left-hand piece is a corner with its elbow at
  /// [left] and its right-hand piece one with its elbow at [right].
  ///
  /// Cutting at the middle is what leaves one corner in each piece. A
  /// shape built this way stands its outer legs at either extreme of its
  /// box, so the middle is only ever reached along the leg between them.
  ///
  /// Which piece the hand drew first says nothing about the letter, so the
  /// pieces are sorted by where they sit rather than by when they arrived.
  bool _isTwoCorners(_Stroke stroke,
      {required _Corner left,
      required _Corner right,
      double minLeg = _minCornerLeg,
      double uprightRatio = _verticalRatio}) {
    final points = stroke.points;
    final middle = _boundsOf(points).center.dx;
    final startsLeft = points.first.dx < middle;
    var split = -1;
    for (var i = 1; i < points.length; i++) {
      if (startsLeft ? points[i].dx >= middle : points[i].dx <= middle) {
        split = i;
        break;
      }
    }
    if (split < 0) return false;

    final before = _Stroke(points.sublist(0, split + 1));
    final after = _Stroke(points.sublist(split));
    final (leftPiece, rightPiece) =
        startsLeft ? (before, after) : (after, before);
    return _isCorner(leftPiece,
            elbow: left, minLeg: minLeg, uprightRatio: uprightRatio) &&
        _isCorner(rightPiece,
            elbow: right, minLeg: minLeg, uprightRatio: uprightRatio);
  }

  /// Whether [stroke] is П's arch: two squared corners sharing a top bar —
  /// a Г's elbow joined to a ㄱ's — so the bar runs across the top and a
  /// leg hangs down from either end of it.
  ///
  /// On a Λ the same cut lands on the apex, and the two pieces are
  /// straight diagonals — which [_isCorner] refuses outright, since a line
  /// has no elbow. That is the whole of what separates the two letters,
  /// and it needs to be, because everything else about them agrees: both
  /// are one horizontal stroke that rises and falls with its two ends
  /// below its middle. A smoothly rounded ∩ is turned away by the same
  /// [_cornerSnap] that stops an arc passing for Г — a bend has to be
  /// squared off to read as a letter.
  bool _isArch(_Stroke stroke) => _isTwoCorners(stroke,
      left: _Corner.topLeft, right: _Corner.topRight);

  /// Whether [stroke] is Ц's body: the same pair of corners П is built
  /// from, with the left elbow moved to the bottom — a ㄴ joined to a ㄱ,
  /// where П is a Г joined to a ㄱ. It runs down the left leg, right along
  /// the foot, and down again into the descender.
  ///
  /// The right-hand piece is half the foot plus that descender, so its own
  /// box has its top at the foot and its bottom at the tail's end, putting
  /// the elbow in the top-right corner — Hebrew vav, and tiny. The tail is
  /// what makes that piece a corner at all: without one it is a straight
  /// half-foot, which is why a plain ㄴ (Ч's arm, Ш's corner) is not a Ц
  /// body. [_minCornerLeg] is set aside here so the tail may be as small
  /// as it is drawn; [_isStraight] still keeps a tail that is really noise
  /// from passing for one.
  bool _isTseBody(_Stroke stroke) => _isTwoCorners(stroke,
      left: _Corner.bottomLeft,
      right: _Corner.topRight,
      minLeg: 0,
      uprightRatio: _hookRatio);

  /// Whether [s] runs top-to-bottom (or bottom-to-top) steeply enough to
  /// read as a vertical rather than a diagonal — see [_verticalRatio].
  bool _isVertical(_Stroke s) => _isSteep(s, _verticalRatio);

  /// [_isVertical] with the margin given rather than fixed: how many times
  /// taller than wide [s] has to be. [_verticalRatio] for a stroke that
  /// should stand plumb, [_hookRatio] for one that need only fall more
  /// than it runs.
  bool _isSteep(_Stroke s, double ratio) {
    final dx = (s.end.dx - s.start.dx).abs();
    final dy = (s.end.dy - s.start.dy).abs();
    return dy > dx * ratio;
  }

  /// Whether [s] runs flat enough to read as a horizontal rather than a
  /// diagonal — [_isVertical]'s mirror image, see [_horizontalRatio].
  bool _isHorizontal(_Stroke s) {
    final dx = (s.end.dx - s.start.dx).abs();
    final dy = (s.end.dy - s.start.dy).abs();
    return dx > dy * _horizontalRatio;
  }

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
      final distance =
          (offset.dx * chord.dy - offset.dy * chord.dx).abs() / length;
      if (distance > slack) return false;
    }
    return true;
  }

  /// Whether [a] and [b] come within [_touchTolerance] of each other
  /// anywhere along their lengths — a crossing counts too, since a
  /// crossing's closest approach is zero.
  bool _touches(_Stroke a, _Stroke b) => _contacts(a, b) > 0;

  /// How many separate places along [a] come within [_touchTolerance] of
  /// [b]: consecutive near points are one meeting, so an arm that runs
  /// into a stem and stops counts once however many of its samples land
  /// inside the tolerance, while an arm that leaves and comes back counts
  /// twice.
  int _contacts(_Stroke a, _Stroke b) {
    var count = 0;
    var wasNear = false;
    for (final point in a.points) {
      final near = _distanceTo(point, b) <= _touchTolerance;
      if (near && !wasNear) count++;
      wasNear = near;
    }
    return count;
  }

  /// The point along [stroke]'s own path that comes nearest [other] —
  /// where the two meet, when they do.
  Offset _nearestPointTo(_Stroke stroke, _Stroke other) {
    var nearest = stroke.points.first;
    var closest = double.infinity;
    for (final point in stroke.points) {
      final distance = _distanceTo(point, other);
      if (distance < closest) {
        closest = distance;
        nearest = point;
      }
    }
    return nearest;
  }

  /// The shortest distance from [point] to [stroke]'s own path.
  double _distanceTo(Offset point, _Stroke stroke) {
    var nearest = double.infinity;
    for (var i = 1; i < stroke.points.length; i++) {
      nearest = math.min(nearest,
          _pointSegmentDistance(point, stroke.points[i - 1], stroke.points[i]));
    }
    return nearest;
  }

  /// How many times [a] genuinely crosses [b].
  int _crossings(_Stroke a, _Stroke b) => _crossingPoints(a, b).length;

  /// Where [a] crosses [b] — segment intersections, deduplicated so one
  /// crossing sampled across a few neighbouring segments still counts
  /// once. Works off the sampled path rather than a start-to-end chord, so
  /// it locates a crossing against a curved stroke (Э's bowl) as readily
  /// as against a straight one (Н's stem).
  List<Offset> _crossingPoints(_Stroke a, _Stroke b) {
    final crossings = <Offset>[];
    var lastI = -10, lastJ = -10;
    for (var i = 0; i < a.points.length - 1; i++) {
      for (var j = 0; j < b.points.length - 1; j++) {
        if (_segmentsIntersect(
            a.points[i], a.points[i + 1], b.points[j], b.points[j + 1])) {
          if ((i - lastI).abs() > 2 || (j - lastJ).abs() > 2) {
            final at = _intersectionPoint(
                a.points[i], a.points[i + 1], b.points[j], b.points[j + 1]);
            if (at != null) crossings.add(at);
          }
          lastI = i;
          lastJ = j;
        }
      }
    }
    return crossings;
  }

  /// How many times [stroke] crosses its own path — non-adjacent segments
  /// (an index gap of at least 2, so a sharp turn isn't read as a
  /// crossing) that intersect, deduplicated the same way [_crossings] is.
  int _selfIntersections(_Stroke stroke) {
    final points = stroke.points;
    var count = 0;
    var last = -10;
    for (var i = 0; i < points.length - 1; i++) {
      for (var j = i + 2; j < points.length - 1; j++) {
        if (_segmentsIntersect(
            points[i], points[i + 1], points[j], points[j + 1])) {
          if (j - last > 2) count++;
          last = j;
        }
      }
    }
    return count;
  }

  /// Where the lines through [p1]–[p2] and [p3]–[p4] meet, or null if
  /// they're parallel. Only asked for after [_crossings] has confirmed the
  /// two segments really do cross, so the meeting point lies on both.
  Offset? _intersectionPoint(Offset p1, Offset p2, Offset p3, Offset p4) {
    final denominator =
        (p2.dx - p1.dx) * (p4.dy - p3.dy) - (p2.dy - p1.dy) * (p4.dx - p3.dx);
    if (denominator == 0) return null;
    final t = ((p3.dx - p1.dx) * (p4.dy - p3.dy) -
            (p3.dy - p1.dy) * (p4.dx - p3.dx)) /
        denominator;
    return Offset(p1.dx + t * (p2.dx - p1.dx), p1.dy + t * (p2.dy - p1.dy));
  }

  /// Whether the segments [p1]–[p2] and [p3]–[p4] cross: each segment has
  /// the other's endpoints on opposite sides.
  ///
  /// A point landing exactly *on* the other segment still counts. Strokes
  /// arrive as sampled points, so a bar crossing a stem lands on one of
  /// the stem's own samples often enough to matter — demanding both sides
  /// be strictly opposite would drop that crossing entirely and, with it,
  /// the letter. Whichever neighbouring segment also registers the same
  /// touch is folded away by [_crossings]' own dedup.
  ///
  /// Two collinear segments are the exception: that's a stroke retracing
  /// its own path, which runs alongside where it came from rather than
  /// through it, so it's no crossing.
  bool _segmentsIntersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    double side(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);

    final d1 = side(p3, p4, p1);
    final d2 = side(p3, p4, p2);
    final d3 = side(p1, p2, p3);
    final d4 = side(p1, p2, p4);
    if (d1 == 0 && d2 == 0) return false;
    return d1 * d2 <= 0 && d3 * d4 <= 0;
  }

  /// Shortest distance from [p] to the segment [a]–[b] — measured to the
  /// nearest endpoint when the perpendicular foot falls outside the
  /// segment, so a leg alongside (but past the end of) a bar doesn't read
  /// as touching it.
  double _pointSegmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
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
    for (final dot in _dots) {
      canvas.drawCircle(dot, _dotRadius, Paint()..color = paint.color);
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
                  text: '${recognized.capital} ${recognized.small}',
                  style: const TextStyle(fontSize: 22),
                ),
                TextSpan(
                  text: '  (${recognized.letterName} — "${recognized.sound}")',
                ),
              ],
            )
          : const TextSpan(
              text: 'Draw a letter above to see it recognized',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

/// Builds the scene plus a direct reference to its [CyrillicLayer], so the
/// hosting page can call [CyrillicLayer.clear] from the Clear button.
(Scene, CyrillicLayer) buildCyrillicScene() {
  final layer = CyrillicLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
