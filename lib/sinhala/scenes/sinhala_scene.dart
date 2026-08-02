import 'package:flutter/material.dart';

import '../engine/scene.dart';
import '../engine/stroke_shape.dart';

/// Cream, dot-grid paper background (Moleskine-style notebook page).
/// Ported verbatim from the tifi project — the recognizer draws on top of it.
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

class _Stroke {
  _Stroke(this.points) : shape = StrokeShape.fromPoints(points);

  final List<Offset> points;
  final StrokeShape shape;
}

/// What has been drawn, sorted into the letter and the marks written beside it.
///
/// Sinhala writes some things as a mark rather than as a shape of its own: a
/// dot on a letter can change which letter it is, and a mark to the *right* of
/// a letter is a vowel modifier following it. So the canvas is partitioned by
/// position before any rule runs — [body] is the letter, [dots] are dots on the
/// letter itself, and [markStrokes] / [markDots] are what was written off to
/// its right.
class _Sketch {
  const _Sketch({
    required this.body,
    required this.strokes,
    required this.dots,
    required this.markStrokes,
    required this.markDots,
  });

  /// The letter: the largest thing drawn.
  final StrokeShape body;

  /// Every path stroke on the canvas, [body] among them, in the order they
  /// were drawn. For a glyph built from two whole shapes stacked — ෯ is a ෨
  /// with a ෬ above it — neither is a mark on the other, so the body-and-marks
  /// split has nothing useful to say and the rule reads these instead.
  final List<StrokeShape> strokes;

  /// Dots sitting on the letter, which help say which letter it is.
  final List<Offset> dots;

  /// Strokes written off to the right of the body — a vowel modifier after a
  /// letter, or part of the glyph itself as in ෩.
  final List<StrokeShape> markStrokes;

  /// Dots written off to the right of the body — a vowel modifier.
  final List<Offset> markDots;
}

/// One named condition a drawing has to meet.
typedef _Clause = bool Function(_Sketch);

/// One glyph the recognizer knows, as a set of named conditions over a
/// [_Sketch] — all of which must hold.
///
/// The conditions are named rather than being one anonymous predicate so that
/// a drawing which *doesn't* match can say which part it fell down on. A rule
/// that quietly returns false tells you nothing when a stroke you meant as ෧
/// reads as nothing at all; [unmet] is what the canvas puts on screen instead.
///
/// Rules are tried in list order and the first match wins, so the more
/// specific ones go first — in particular a dotted letter must come before the
/// undotted letter it is built on, or the plain rule would swallow it.
class _GlyphRule {
  const _GlyphRule(this.glyph, this.roman, this.clauses);

  /// The Sinhala glyph, as it appears in `data/sinhala_alphabet.dart` or
  /// `data/lith_scripts.dart`.
  final String glyph;

  /// ISO 15919 romanization; consonants include the inherent /a/. For a
  /// numeral this is its value.
  final String roman;

  /// Every condition that must hold, by name.
  final Map<String, _Clause> clauses;

  bool matches(_Sketch sketch) =>
      clauses.values.every((clause) => clause(sketch));

  /// The conditions [sketch] fails, named — empty when the rule matches.
  List<String> unmet(_Sketch sketch) => [
        for (final clause in clauses.entries)
          if (!clause.value(sketch)) clause.key,
      ];
}

/// Which set of rules the canvas matches a drawing against.
///
/// The systems are kept apart because some glyphs simply *are* the same shape:
/// ෮ (the Lith digit 8) is drawn exactly like ර, so nothing about the stroke
/// can separate them — only knowing which you meant to write.
enum RecognitionSystem {
  letters('Letters', 'Letters'),
  lithNumerals('Lith numerals', 'Lith'),
  illakkamNumerals('Illakkam numerals', 'Illakkam');

  const RecognitionSystem(this.label, this.shortLabel);

  /// The system's full name, for prose.
  final String label;

  /// The name on the tab above the canvas, where three have to fit side by
  /// side on a phone.
  final String shortLabel;

  /// The rules for this system, empty for one not written yet.
  List<_GlyphRule> get _rules => switch (this) {
        RecognitionSystem.letters => _letterRules,
        RecognitionSystem.lithNumerals => _lithRules,
        RecognitionSystem.illakkamNumerals => _illakkamRules,
      };

  /// The glyphs this system can currently recognize. Empty means the system is
  /// listed but has no rules yet.
  Set<String> get recognizedGlyphs => {
        for (final rule in _rules) rule.glyph,
        if (this == RecognitionSystem.letters)
          for (final rule in _modifierRules) rule.mark,
      };
}

/// Every glyph the recognizer can identify, across all systems — what the
/// reference tables tick off as implemented.
Set<String> get recognizedGlyphs => {
      for (final system in RecognitionSystem.values) ...system.recognizedGlyphs,
    };

/// The two numeral systems — everything cord took of this recognizer, and the
/// single source for the page's dropdown, the search index, and the systems a
/// drawing may be pointed at when it matches none of the rules for the one
/// selected.
///
/// That last is **cord's one divergence from the upstream scene**, which looks
/// through all of [RecognitionSystem.values] there. cord took the numerals and
/// left the letters behind (see `pages/sinhala_page.dart`), but the letter
/// rules are still here, and [RecognitionSystem.values] tries them first. Some
/// shapes are shared outright — ෮ is drawn exactly as ර is — so a drawing of
/// the digit made while the page is on Illakkam would be reported as "ර, under
/// Letters": a letter, named under a system the page has no way to select, in
/// place of the Lith digit whose shape it also is. Pointing only at what the
/// page offers is what keeps that advice worth acting on.
const numeralSystems = [
  RecognitionSystem.lithNumerals,
  RecognitionSystem.illakkamNumerals,
];

/// The letters wired up so far.
///
/// This is deliberately a short list: each rule is written and tuned against
/// how the letter actually comes out when drawn freehand on the live canvas,
/// then the next letter is added.
const _letterRules = [
  // ඊ — the ර body, with a dot either side of the tail. Must precede ර.
  _GlyphRule('ඊ', 'ī', {
    'is a ර': _loopsRightThenClimbs,
    'has a dot either side of the tail': _dotsFlankTheTail,
  }),
  // උ — a rightward arch, then a leftward hook that cuts back over it.
  _GlyphRule('උ', 'u', {
    'arches right then hooks left': _archesThenHooks,
    'crosses itself': _crossesItself,
  }),
  // ර — a rightward loop closed by crossing itself, then away and upward.
  _GlyphRule('ර', 'ra', {'loops right then climbs': _loopsRightThenClimbs}),
  // ට — one stroke that only ever bends left, finishing above where it began.
  _GlyphRule('ට', 'ṭa', {
    'bends only left': _bendsOnlyLeft,
    'ends above the start': _endsAboveStart,
  }),
];

/// The Lith digits wired up so far.
///
/// Two of these are shapes the alphabet already uses — ෮ is drawn as ර is, and
/// ෭ as උ is but left open. They share their predicates rather than restating
/// them, and it is [RecognitionSystem] that decides which glyph a given
/// drawing is reported as.
const _lithRules = [
  // ෦ 0 — up from the bottom, bending left, then right past the crossing.
  _GlyphRule('෦', '0', {
    'starts at the bottom': _startsAtBottom,
    'bends left then right': _bendsLeftThenRight,
    'crosses itself once or twice': _crossesOnceOrTwice,
  }),
  // ෯ 9 — a ෨ with a ෬ stacked above it. First of all the digits: every other
  // rule reads the body alone and would happily match one half of this.
  _GlyphRule('෯', '9', {
    'is two strokes, one above the other': _isTwoStacked,
    'the lower one is a ෨': _lowerIsDeka,
    'the upper one bends only right': _upperBendsOnlyRight,
    'the upper one never drops below its start': _upperStaysAboveItsStart,
    'the upper one crosses itself past halfway': _upperCrossesPastTheMiddle,
    'that crossing is right of its middle': _upperCrossingIsOnTheRight,
  }),
  // ෩ 3 — ෨ with a backwards C beside it. Must precede ෨, which pays marks
  // no attention and would otherwise swallow it.
  _GlyphRule('෩', '3', {
    'first coil bends only right': _firstCoilBendsOnlyRight,
    'crosses itself once or twice': _crossesOnceOrTwice,
    'rises and descends after the first crossing': _archesAfterFirstCrossing,
    'ends below and right of the last crossing': _endsBelowRightOfLastCrossing,
    'has a backwards C beside it': _hasReversedCBeside,
  }),
  // ෨ 2 — ෧ carried on into a second hump: over the top of the first coil and
  // round again. Must precede ෧, being that shape with the hump added.
  _GlyphRule('෨', '2', {
    'first coil bends only right': _firstCoilBendsOnlyRight,
    'crosses itself once or twice': _crossesOnceOrTwice,
    'rises and descends after the first crossing': _archesAfterFirstCrossing,
    'ends below and right of the last crossing': _endsBelowRightOfLastCrossing,
  }),
  // ෬ 6 — a wide sweep either side of where it set off, closing a small curl
  // over on the right. Precedes ෧, which asks only that the crossing exist.
  _GlyphRule('෬', '6', {
    'bends only right': _bendsOnlyRight,
    'crosses itself once': _crossesExactlyOnce,
    'goes above and below the start': _passesAboveAndBelowStart,
    'crosses itself past halfway': _crossesPastTheMiddle,
    'closes only a tiny loop': _closesATinyLoop,
    'that loop is on the right': _loopIsOnTheRight,
  }),
  // ෧ 1 — bends right throughout, over its own line once, then on to finish
  // below and to the right of where it crossed.
  _GlyphRule('෧', '1', {
    'bends only right': _bendsOnlyRight,
    'crosses itself once': _crossesExactlyOnce,
    'ends below and right of the crossing': _endsBelowRightOfCrossing,
  }),
  // ෪ 4 — the ෭ arch, its hook carried on up to the top, then a turn back the
  // other way that closes on itself and leaves a tail pointing straight up.
  _GlyphRule('෪', '4', {
    'opens with an arch': _opensWithAnArch,
    'bends right, then left, then right': _bendsRightLeftRight,
    'crosses itself one to three times': _crossesOneToThreeTimes,
    'ends pointing upwards': _endsPointingUp,
  }),
  // ෫ 5 — right, then left, then round again: the bending changes hand more
  // than the once ෭ does, and the last turn comes back down under itself.
  _GlyphRule('෫', '5', {
    'begins bending right': _beginsBendingRight,
    'ends bending left': _endsBendingLeft,
    'changes bending hand more than once': _changesHandMoreThanOnce,
    'ends below where its last turn began': _endsBelowLastTurnStart,
  }),
  // ෭ 7 — the උ shape left open: an arch and a hook, but no crossing.
  _GlyphRule('෭', '7', {
    'arches right then hooks left': _archesThenHooks,
    'never crosses itself': _neverCrosses,
  }),
  // ෮ 8 — the ර shape exactly.
  _GlyphRule('෮', '8', {'loops right then climbs': _loopsRightThenClimbs}),
];

/// The Illakkam numerals wired up so far.
///
/// The older system, with no zero and no place value — see
/// `data/illakkam_scripts.dart`. Several of its symbols are a Lith digit with
/// something added, so the Lith shapes are reused rather than restated.
/// The Illakkam numerals wired up so far. All three are the ෧ coil with
/// something added, so they share their opening conditions and are parted only
/// by what follows.
const _illakkamRules = [
  // 𑇨 8 — 𑇤's humps, but where 𑇤 drops away in place, this sweeps its last
  // run back across the glyph to where the first hump began, comes round right
  // again, and runs downhill from the crossing. Precedes 𑇤, which it otherwise
  // matches: same humps, same five runs, same loop.
  _GlyphRule('𑇨', '8', {
    'begins bending right': _beginsBendingRight,
    'has six humps or more': _hasSixHumpsOrMore,
    'the last run sweeps back across the glyph': _lastRunSweepsAcross,
    'runs downhill from the last crossing': _descendsFromLastCrossing,
  }),
  // 𑇤 4 — right, left, right, left, and then a last run that carries down
  // past everything else and closes on itself. First: its five runs would
  // otherwise satisfy 𑇣, which asks only that the bending change hand.
  _GlyphRule('𑇤', '4', {
    'bends right, left, right, left, right': _bendsRightLeftRightLeftRight,
    'carries down to the foot and closes on itself': _dropsToAClosedLoop,
  }),
  // 𑇧 7 — 𑇤 with the two double backs left out, and a tail that drops and
  // comes straight back up past the crossing. After 𑇤, which is this with the
  // humps on the front.
  _GlyphRule('𑇧', '7', {
    'begins bending right': _beginsBendingRight,
    'crosses itself': _crossesItself,
    'past the crossing it splits down and up': _tailGoesDownThenUp,
  }),
  // 𑇥 5 — 𑇣 with one more double back. Checked first, being that shape with
  // the extra turn: a double back cuts over the line it turns on, so it shows
  // up as another crossing rather than as another run.
  _GlyphRule('𑇥', '5', {
    'the run-in bends only right': _firstCoilBendsOnlyRight,
    'changes bending hand more than once': _changesHandMoreThanOnce,
    'crosses itself more than twice': _crossesMoreThanTwice,
  }),
  // 𑇦 6 — up, back down, down again, and then round and all the way up, past
  // everything else. Precedes 𑇣, which asks for less of the same shape.
  _GlyphRule('𑇦', '6', {
    'begins bending right': _beginsBendingRight,
    'changes bending hand more than once': _changesHandMoreThanOnce,
    'ends at the top': _endsAtTop,
  }),
  // 𑇣 3 — the coil doubled back and away again.
  _GlyphRule('𑇣', '3', {
    'the run-in bends only right': _firstCoilBendsOnlyRight,
    'changes bending hand more than once': _changesHandMoreThanOnce,
    'crosses itself': _crossesItself,
  }),
  // 𑇩 9 — humps and a loop, however they fall, and then a clean line up.
  // Precedes 𑇡, which reaches its line without the humps.
  //
  // Neither the runs nor the crossings are counted here, both having moved
  // about across drawings of it: two runs and six, three crossings and one.
  // The humps held at nine every time, so they are what the rule reads.
  _GlyphRule('𑇩', '9', {
    'begins bending right': _beginsBendingRight,
    'has six humps or more': _hasSixHumpsOrMore,
    'one run passes over the top of the rest': _aRunPassesOverTheTop,
    'ends in a vertical line': _endsVertically,
    'that line crosses nothing': _lastVerticalStretchIsClean,
  }),
  // 𑇡 1 — the coil, then a line drawn up, finishing above where it began.
  // Precedes 𑇢, being that shape with the rise added.
  _GlyphRule('𑇡', '1', {
    'the run-in bends only right': _firstCoilBendsOnlyRight,
    'crosses itself': _crossesItself,
    'bends right, then left': _bendsRightThenLeft,
    'ends above the start': _endsAboveStart,
  }),
  // 𑇢 2 — the same bend the other way, and no more: it does not climb.
  _GlyphRule('𑇢', '2', {
    'the run-in bends only right': _firstCoilBendsOnlyRight,
    'crosses itself': _crossesItself,
    'bends right, then left': _bendsRightThenLeft,
  }),
];

// --- Clauses --------------------------------------------------------------
//
// Each is one named condition a rule can ask for. They are deliberately small
// and separately named: when a drawing reads as nothing, the canvas lists the
// ones it failed, which is the only way to tell a rule that is wrong from a
// stroke that was drawn differently than described.

/// The pen bends left throughout, and any rightward bending is hand wobble.
bool _bendsOnlyLeft(_Sketch s) => s.body.turnsLeftOnly();

/// The pen bends right throughout, and any leftward bending is hand wobble.
bool _bendsOnlyRight(_Sketch s) => s.body.turnsRightOnly();

/// The pen finished higher up the page than it started.
bool _endsAboveStart(_Sketch s) => s.body.endsAboveStart;

/// The stroke set off from its own lowest point — drawn from the bottom up.
bool _startsAtBottom(_Sketch s) => s.body.startsAtBottom;

/// The stroke finished at its own highest point.
bool _endsAtTop(_Sketch s) => s.body.endsAtTop;

/// The pen cut back over its own path at some point.
bool _crossesItself(_Sketch s) => s.body.firstCrossing != null;

/// The pen cut back over its own path exactly once.
bool _crossesExactlyOnce(_Sketch s) => s.body.crossings.length == 1;

/// The pen cut back over its own path once or twice — whether the stroke's
/// second half meets the first a second time on its way out is down to how far
/// the tail is carried, not to which glyph it is.
bool _crossesOnceOrTwice(_Sketch s) =>
    s.body.crossings.length == 1 || s.body.crossings.length == 2;

/// The stroke reaches both above and below the height it set off from.
bool _passesAboveAndBelowStart(_Sketch s) => s.body.passesAboveAndBelowStart;

/// The pen was already past the halfway mark of the stroke when it cut back
/// over itself — the curl of ෬ is made at the end, not on the way in.
///
/// Halfway along the path, not halfway across the page: the points are evenly
/// spaced, so the index is the distance travelled.
bool _crossesPastTheMiddle(_Sketch s) {
  final at = s.body.crossingPosition;
  return at != null && at > 0.5;
}

/// How big the loop a stroke closes may be, measured against the stroke as a
/// whole, and still count as tiny. Generous on purpose: a hand's "tiny" curl
/// comes out a good deal larger than the word suggests.
const _tinyLoopShare = 0.5;

/// The circle the stroke closes is small next to the stroke itself — a curl on
/// the end of a sweep, not a coil the whole glyph is built round.
///
/// Measured on [StrokeShape.closedLoop], the enclosed circle, rather than on
/// everything the pen drew before reaching it.
///
/// Both are compared by their longest side rather than axis by axis. ෬ is a
/// wide, shallow glyph, so a curl that is plainly small against it can still
/// stand as tall as half the whole stroke — comparing heights called such a
/// curl large and dropped the digit through to ෧.
bool _closesATinyLoop(_Sketch s) => _closesATinyLoopIn(s.body);

bool _closesATinyLoopIn(StrokeShape stroke) {
  final loop = stroke.closedLoop;
  if (loop == null) return false;

  return loop.bounds.longestSide < stroke.bounds.longestSide * _tinyLoopShare;
}

/// That closed circle sits in the right-hand half of the stroke.
bool _loopIsOnTheRight(_Sketch s) => _loopIsOnTheRightIn(s.body);

bool _loopIsOnTheRightIn(StrokeShape stroke) {
  final loop = stroke.closedLoop;
  return loop != null && loop.bounds.center.dx > stroke.bounds.center.dx;
}

// --- Stacked shapes -------------------------------------------------------
//
// ෯ is the one glyph built from two whole shapes, so ෨ has to be askable of a
// given stroke rather than only of the sketch's body. ෨'s own rule stays
// spelled out as separate named conditions, because that is what lets a
// drawing say which part of it fell short.

/// The ෨ shape, asked of one stroke.
///
/// One crossing or two: whether the second hump closes on itself is down to
/// how it was drawn. What makes it a ෨ rather than a ෧ is the rise and fall
/// after the first coil, not a second loop.
bool _isDekaShape(StrokeShape stroke) {
  final crossings = stroke.crossings.length;
  if (crossings != 1 && crossings != 2) return false;

  final firstCoil = stroke.loopToCrossing;
  if (firstCoil == null) return false;

  return firstCoil.turnsRightOnly() &&
      _humpsAfterFirstCrossing(stroke) &&
      stroke.endsBelowRightOf(stroke.crossings.last.point);
}

/// The two strokes of a stacked glyph, upper first — or null unless there are
/// exactly two and one sits clear above the other.
///
/// "Clear above" is the upper stroke's middle being higher than the lower
/// stroke's top edge, which allows the two to overlap a little, as a hand
/// stacking one shape on another will.
(StrokeShape upper, StrokeShape lower)? _stackedPair(_Sketch s) {
  if (s.strokes.length != 2) return null;

  final (first, second) = (s.strokes.first, s.strokes.last);
  final (upper, lower) = first.bounds.center.dy < second.bounds.center.dy
      ? (first, second)
      : (second, first);
  return upper.bounds.center.dy < lower.bounds.top ? (upper, lower) : null;
}

/// Two strokes, one stacked clear above the other.
bool _isTwoStacked(_Sketch s) => _stackedPair(s) != null;

/// The upper of two stacked strokes, or null if there isn't a stacked pair.
StrokeShape? _upperOf(_Sketch s) => _stackedPair(s)?.$1;

/// The lower of two stacked strokes is a ෨.
bool _lowerIsDeka(_Sketch s) {
  final pair = _stackedPair(s);
  return pair != null && _isDekaShape(pair.$2);
}

/// The stroke ෯ carries above its ෨ bends right throughout.
bool _upperBendsOnlyRight(_Sketch s) => _upperOf(s)?.turnsRightOnly() ?? false;

/// Nothing of that upper stroke falls below the point it set off from — which
/// is what parts it from a ෬, whose sweep passes either side of its start.
bool _upperStaysAboveItsStart(_Sketch s) =>
    _upperOf(s)?.startsAtBottom ?? false;

/// The upper stroke cuts back over itself once, and does so in its second
/// half — the crossing belongs to the far side of the stroke, not the run-in.
/// Where exactly past halfway it falls, and how much stroke follows it, is
/// down to the hand.
bool _upperCrossesPastTheMiddle(_Sketch s) {
  final upper = _upperOf(s);
  if (upper == null || upper.crossings.length != 1) return false;
  return (upper.crossingPosition ?? 0) > 0.5;
}

/// That crossing sits right of the middle of the upper stroke.
bool _upperCrossingIsOnTheRight(_Sketch s) {
  final upper = _upperOf(s);
  final crossing = upper?.firstCrossing;
  return crossing != null && crossing.point.dx > upper!.bounds.center.dx;
}

/// One mark beside the digit, drawn as a backwards C.
///
/// It bends right the whole way and finishes below where it began, and both of
/// its ends sit in the left half of its own bounding box — which is what makes
/// it open leftward, a Ɔ rather than a C.
bool _hasReversedCBeside(_Sketch s) {
  if (s.markDots.isNotEmpty || s.markStrokes.length != 1) return false;

  final mark = s.markStrokes.single;
  return mark.turnsRightOnly() &&
      mark.endsBelowStart &&
      mark.startsInLeftHalf &&
      mark.endsInLeftHalf;
}

/// The coil the pen closes first bends right throughout — ෧'s shape, asked of
/// the first coil alone rather than of the whole stroke.
///
/// What comes after is free to bend either way, because it is not one more
/// coil of the same kind: a second hump beside the first has a valley between
/// them, and a valley is a left turn. Demanding right-only throughout rejected
/// ෨ as drawn.
bool _firstCoilBendsOnlyRight(_Sketch s) {
  final loop = s.body.loopToCrossing;
  return loop != null && loop.turnsRightOnly();
}

/// How far the stretch past the first crossing must come round before it
/// counts as a hump of its own.
///
/// ෧'s tail also climbs and drops — it leaves the coil going up and to the
/// right and curves down again — so rising and falling alone does not tell the
/// two apart. Half a turn does: ෧'s flick is well under it, ෨'s second hump
/// well over.
const _humpTurn = 180.0;

/// Past the first crossing the stroke goes over a hump of its own: climbing,
/// coming back down, and turning far enough round to be a second part of the
/// glyph rather than the flick that finishes a ෧.
bool _humpsAfterFirstCrossing(StrokeShape stroke) {
  final tail = stroke.tailFromCrossing;
  return tail != null &&
      tail.risesThenDescends &&
      tail.totalTurn >= _humpTurn;
}

bool _archesAfterFirstCrossing(_Sketch s) => _humpsAfterFirstCrossing(s.body);

/// The pen finished below and to the right of the *last* place it cut back
/// over itself — the same relation ෧ has to its only crossing, asked of the
/// second coil.
bool _endsBelowRightOfLastCrossing(_Sketch s) {
  final crossings = s.body.crossings;
  if (crossings.isEmpty) return false;
  return s.body.endsBelowRightOf(crossings.last.point);
}

/// The pen never cut back over its own path.
bool _neverCrosses(_Sketch s) => s.body.crossings.isEmpty;

/// The pen finished below and to the right of the point where it cut back over
/// itself — which is to say it left the loop it had just closed heading down
/// and away, rather than climbing back out of it as ර does.
bool _endsBelowRightOfCrossing(_Sketch s) {
  final crossing = s.body.firstCrossing;
  if (crossing == null) return false;
  return s.body.endsBelowRightOf(crossing.point);
}

// Note: ෧ deliberately asks nothing about how far round the pen came before
// crossing. The stroke only has to go back over its own line — how much of a
// circle it drew getting there varies with the hand, and a rule that demanded
// a full turn rejected drawings that were perfectly good ෧.

/// The bending changes hand exactly once, left first and then right — ෦'s
/// shape, which is the whole of what tells it apart from a plain loop.
bool _bendsLeftThenRight(_Sketch s) {
  final runs = s.body.turnRuns;
  if (runs.length != 2) return false;
  return runs.first.isLeft && runs.last.isRight;
}

/// The shape උ and ෭ share: the pen bends right through an arch — rising, then
/// descending — then bends left into a hook, finishing in the right half of
/// the drawing and below where it began.
///
/// This is the clause that splits a stroke by [StrokeShape.turnRuns] rather
/// than by where it crosses itself: what identifies it is that the bending
/// changes hand exactly once, an arch one way followed by a hook the other.
/// Whether the hook cuts back over the arch is what separates the two glyphs,
/// and is asked for separately.
bool _archesThenHooks(_Sketch s) =>
    _archesRightThenHooksLeft(s) &&
    s.body.endsInRightHalf &&
    s.body.endsBelowStart;

/// The structure alone: the bending changes hand exactly once, a right-bending
/// arch that rises and descends followed by a hook the other way.
///
/// Where the hook then goes is left to the callers — ෭ stops as it turns, ෫
/// carries it the whole way round and back under itself.
bool _archesRightThenHooksLeft(_Sketch s) {
  final runs = s.body.turnRuns;
  if (runs.length != 2) return false;

  final arch = runs.first;
  return arch.isRight && arch.shape.risesThenDescends && runs.last.isLeft;
}

/// The stroke's first run of bending goes right.
bool _beginsBendingRight(_Sketch s) {
  final runs = s.body.turnRuns;
  return runs.isNotEmpty && runs.first.isRight;
}

/// The stroke's last run of bending goes left.
bool _endsBendingLeft(_Sketch s) {
  final runs = s.body.turnRuns;
  return runs.isNotEmpty && runs.last.isLeft;
}

/// The stroke opens with an arch: its first run rises to a high point and
/// comes back down.
bool _opensWithAnArch(_Sketch s) {
  final runs = s.body.turnRuns;
  return runs.isNotEmpty && runs.first.shape.risesThenDescends;
}

/// Two runs of bending, right then left.
bool _bendsRightThenLeft(_Sketch s) {
  final runs = s.body.turnRuns;
  return runs.length == 2 && runs.first.isRight && runs.last.isLeft;
}

/// Five runs of bending, right and left turn about, starting right.
bool _bendsRightLeftRightLeftRight(_Sketch s) {
  final runs = s.body.turnRuns;
  return runs.length == 5 && runs.first.isRight;
}

// Runs alternate by construction, so once the first is known to bend right the
// rest follow — there is no need to spell each one out.

/// The stroke's last run covers most of the width of the whole glyph — 𑇨
/// carrying back across to where its first hump began, rather than dropping
/// away where it stands as 𑇤 does.
///
/// This is what parts the two. Everything else about them agrees: the humps,
/// the five runs, the loop, even the tail running downhill afterwards.
bool _lastRunSweepsAcross(_Sketch s) {
  final runs = s.body.turnRuns;
  if (runs.isEmpty) return false;

  return runs.last.shape.bounds.width > s.body.bounds.width * 0.6;
}

/// The line from the last place the stroke crossed itself to where it stops
/// runs downhill — 𑇨's tail, taken end to end rather than followed.
bool _descendsFromLastCrossing(_Sketch s) {
  final crossings = s.body.crossings;
  if (crossings.isEmpty) return false;

  return s.body.end.dy >
      crossings.last.point.dy + s.body.bounds.height * 0.05;
}

/// Some run of the stroke reaches the top of the whole glyph — the loop of 𑇩
/// going round and over the humps it encloses.
///
/// Asked of a run rather than of the stroke, so that it means "one stretch of
/// pen went over everything else", which is what going *around* looks like.
bool _aRunPassesOverTheTop(_Sketch s) {
  final whole = s.body.bounds;
  return s.body.turnRuns
      .any((run) => run.shape.bounds.top <= whole.top + whole.height * 0.05);
}

/// The stroke climbs and falls six times over or more.
///
/// A glyph with a row of humps inside it runs up a count like this whichever
/// way it is drawn, where the bending and the crossings both move about. 𑇩
/// measured nine humps in every drawing of it; 𑇡, which has no humps at all,
/// four.
bool _hasSixHumpsOrMore(_Sketch s) => s.body.verticalRuns.length >= 6;

/// The stroke finishes as a vertical line, however long or short.
bool _endsVertically(_Sketch s) => s.body.endsVertically;

/// Past the place it first crossed itself, the stroke goes down and then up,
/// and nothing else — and does so *vertically*, dropping and rising in much
/// the same place rather than travelling as it goes.
///
/// The narrowness matters. 𑇡's tail also falls and then climbs, over the whole
/// width of the glyph; 𑇧's is a split, twice as tall as it is wide.
bool _tailGoesDownThenUp(_Sketch s) {
  final tail = s.body.tailFromCrossing;
  if (tail == null) return false;

  final runs = tail.verticalRuns;
  if (runs.length != 2 || runs.first.goingUp || !runs.last.goingUp) {
    return false;
  }
  return tail.bounds.width < tail.bounds.height * 0.5;
}

/// The stroke's last stretch of unbroken vertical travel crosses nothing — the
/// line it finishes on is clean.
///
/// Cutting at the last change of vertical direction is what isolates that
/// line, whatever went before it: [StrokeShape.verticalRuns] hands back each
/// stretch as a shape of its own, so the last one can be asked about directly.
bool _lastVerticalStretchIsClean(_Sketch s) {
  final runs = s.body.verticalRuns;
  return runs.isNotEmpty && runs.last.shape.crossings.isEmpty;
}

/// Some run of the stroke carries down to the foot of the whole glyph, past
/// everything drawn before it, and closes on itself down there.
///
/// Asked of a run rather than of the stroke, because it is one stretch of the
/// pen that does both — the drop and the loop at the bottom of ෪ and ෯ alike.
/// Which run it is depends on whether the glyph then climbs away again, so it
/// is looked for rather than being taken as the last.
bool _dropsToAClosedLoop(_Sketch s) {
  final whole = s.body.bounds;
  return s.body.turnRuns.any((run) =>
      run.shape.bounds.bottom >= whole.bottom - whole.height * 0.05 &&
      run.shape.crossings.isNotEmpty);
}

/// Three runs of bending, right then left then right.
bool _bendsRightLeftRight(_Sketch s) {
  final runs = s.body.turnRuns;
  return runs.length == 3 &&
      runs[0].isRight &&
      runs[1].isLeft &&
      runs[2].isRight;
}

/// The pen cut back over its own path between once and three times.
///
/// ෪'s last run closes on itself once, and on the way there passes across the
/// run before it — cleanly through and out, catching it the once, or missing
/// it altogether. Which of those a hand produces is not the letter, so the
/// whole range is allowed rather than the count being pinned.
bool _crossesOneToThreeTimes(_Sketch s) {
  final crossings = s.body.crossings.length;
  return crossings >= 1 && crossings <= 3;
}

/// The stroke finishes travelling upward — a tail pointing up.
bool _endsPointingUp(_Sketch s) => s.body.endsPointingUp;

/// The pen cut back over its own path more than twice.
///
/// One more double back is hard to see in either of the obvious places. It
/// does not reliably add a *run*: turning the same way as the stretch before
/// it, the two merge, and that run simply comes further round — one drawing
/// put the extra turn in its first run, another in its third, both leaving
/// four runs. It does not reliably add a *crossing* either, only usually.
///
/// What it always adds is a hump, which is why [StrokeShape.verticalRuns] is
/// on the readout: a hand keeps those steady even as the bending and the
/// crossings move about.
bool _crossesMoreThanTwice(_Sketch s) => s.body.crossings.length > 2;

/// The bending changes hand more than once — three runs or more, where an arch
/// and a hook is two. This is what parts ෫ from ෭, which shares its first two
/// runs but stops there.
bool _changesHandMoreThanOnce(_Sketch s) => s.body.turnRuns.length >= 3;

/// How far to either side of where a turn began the pen may finish and still
/// count as having come back down *under* it rather than away to one side.
const _underShare = 0.25;

/// The pen finished below the point at which its last run of bending began,
/// and roughly beneath it — that turn having come the whole way round rather
/// than simply curving off.
bool _endsBelowLastTurnStart(_Sketch s) {
  final runs = s.body.turnRuns;
  if (runs.isEmpty) return false;

  final turnStart = runs.last.shape.start;
  final bounds = s.body.bounds;
  return s.body.end.dy > turnStart.dy + bounds.height * 0.05 &&
      (s.body.end.dx - turnStart.dx).abs() < bounds.width * _underShare;
}

/// The shape ර and ෮ share: the pen bends right, and only right, until it cuts
/// back over its own path; from that crossing it finishes higher than it
/// crossed.
///
/// The self-crossing splits the shape in two, so this measures the halves
/// separately rather than looking at the stroke as a whole. Only the loop's
/// angles are checked — past the crossing the single thing that matters is
/// that the tail ends up above it, however it gets there.
///
/// Dots are ignored. A ර flanked by a pair of them is an ඊ, which is why that
/// rule is tried first; any other arrangement of dots falls through to plain ර.
bool _loopsRightThenClimbs(_Sketch s) {
  final loop = s.body.loopToCrossing;
  final tail = s.body.tailFromCrossing;
  if (loop == null || tail == null) return false;
  return loop.turnsRightOnly() && tail.endsAboveStart;
}

/// Two dots sit either side of the tail — one to its left and one to its
/// right, as the pen faced while drawing it. That makes the pair read the same
/// whichever way up the letter is written; which dot went down first doesn't
/// matter, and neither does whether they came before or after the body.
bool _dotsFlankTheTail(_Sketch s) {
  final tail = s.body.tailFromCrossing;
  if (tail == null || s.dots.length != 2) return false;

  final sides = s.dots.map(tail.sideOf).toSet();
  return sides.contains(TurnDirection.left) &&
      sides.contains(TurnDirection.right);
}

/// A vowel modifier — a mark written after a letter rather than a letter of
/// its own. Matched separately from [_letterRules] and appended to whatever
/// letter was recognized, so ට plus ං reads ටං.
class _ModifierRule {
  const _ModifierRule(this.mark, this.roman, this.matches);

  /// The combining glyph, as it appears in `data/sinhala_alphabet.dart`.
  final String mark;

  /// ISO 15919 romanization of the mark alone.
  final String roman;

  final bool Function(_Sketch) matches;
}

/// The vowel modifiers wired up so far. Both are defined only by what sits to
/// the right of the letter — [_Sketch] has already sorted that out, so the
/// rules themselves only have to describe the mark's own shape.
const _modifierRules = [
  // ං — anusvāraya, a single dot.
  _ModifierRule('ං', 'ṁ', _isAnusvara),
  // ඃ — visargaya, two dots one above the other.
  _ModifierRule('ඃ', 'ḥ', _isVisarga),
];

/// ං (anusvāraya): a single dot beside the letter.
///
/// Both modifiers refuse to read while there is also a stroke beside the
/// letter, so an unrecognized mark cannot be quietly ignored in favour of the
/// dots next to it.
bool _isAnusvara(_Sketch s) =>
    s.markStrokes.isEmpty && s.markDots.length == 1;

/// ඃ (visargaya): two dots beside the letter, one above the other.
///
/// "Above each other" is taken as the description gives it — the dots are
/// stacked closely enough that, drawn as circles, those circles would still
/// overlap horizontally. That makes the allowed sideways drift one dot
/// diameter, which is tight; it is the first thing to loosen if a real hand
/// keeps missing.
bool _isVisarga(_Sketch s) {
  if (s.markStrokes.isNotEmpty || s.markDots.length != 2) return false;

  final (first, second) = (s.markDots.first, s.markDots.last);
  final drift = (first.dx - second.dx).abs();
  final separation = (first.dy - second.dy).abs();
  return drift <= SinhalaLetterLayer.dotDiameter &&
      separation > SinhalaLetterLayer.dotDiameter;
}

/// Freehand recognition of Sinhala glyphs.
///
/// The work is done by [StrokeShape], which measures the signed angle change
/// along the stroke and buckets it into left and right — the shorthand
/// project's model, ported over. A rule is then a predicate over those
/// numbers: how far the pen turned each way, and coarse facts like whether it
/// finished above or below where it set off.
///
/// [system] picks which set of rules a drawing is matched against, because
/// some glyphs share a shape outright — see [RecognitionSystem]. Vowel
/// modifiers are only read in [RecognitionSystem.letters]; a numeral has
/// nothing for them to modify.
///
/// The glyph is assumed to be drawn as a single continuous stroke, and taken
/// to be the largest thing on the canvas. Everything else — dots, and any
/// stroke off to the right — is a mark on it, sorted out by [_sketch].
///
/// Recognition is live — [_commit] re-evaluates on every completed stroke or
/// dot, so the readout updates as you draw. Nothing is discarded; a stroke that
/// doesn't match any rule is still rendered, just reported as unrecognized.
class SinhalaLetterLayer extends Layer {
  /// A press that travels less than this is a dot rather than a path.
  ///
  /// Measured along the path travelled, not start-to-end: a letter drawn as a
  /// closed loop finishes back where it began, and judging it end to end would
  /// file the whole thing away as a stray tap.
  static const double _minPathLength = 8;

  /// How big a dot is drawn on the canvas.
  static const double dotRadius = 4;
  static const double dotDiameter = dotRadius * 2;

  final List<_Stroke> _strokes = [];
  final List<Offset> _dots = [];
  _GlyphRule? _glyph;
  _ModifierRule? _modifier;
  List<Offset>? _activePoints;

  RecognitionSystem _system = RecognitionSystem.letters;

  /// Which set of rules a drawing is matched against. Changing it re-reads
  /// what is already on the canvas, so the same drawing can be looked at as a
  /// letter and then as a numeral.
  RecognitionSystem get system => _system;
  set system(RecognitionSystem system) {
    if (_system == system) return;
    _system = system;
    _classify();
  }

  /// The glyph matched by what is on the canvas, without any vowel modifier
  /// written after it, or null if nothing matched.
  String? get recognizedLetter => _glyph?.glyph;

  /// The vowel modifier written after the glyph, or null if there is none.
  String? get recognizedModifier => _modifier?.mark;

  /// What is on the canvas, glyph and modifier together — the same value
  /// [paint] puts in the readout, e.g. `ටං`.
  String? get recognizedText =>
      _glyph == null ? null : '${_glyph!.glyph}${_modifier?.mark ?? ''}';

  /// The romanization of [recognizedText].
  String? get recognizedRoman =>
      _glyph == null ? null : '${_glyph!.roman}${_modifier?.roman ?? ''}';

  /// The measurements behind the glyph, for tuning rule thresholds against
  /// strokes that were actually drawn.
  StrokeShape? get letterShape => _sketch?.body;

  /// For every glyph in the current system, the conditions the drawing does
  /// not meet — empty list meaning that glyph matches.
  ///
  /// This is the whole picture behind [nearestMiss], and the honest one: which
  /// glyph a failed drawing was "meant" to be is only ever a guess, but what
  /// each rule wanted is a fact.
  Map<String, List<String>> get unmetConditions {
    final sketch = _sketch;
    if (sketch == null) return const {};
    return {
      for (final rule in _system._rules) rule.glyph: rule.unmet(sketch),
    };
  }

  /// When nothing here matched, but the very same drawing *does* match under a
  /// different system: that glyph, and where it was found.
  ///
  /// Systems are kept apart because glyphs share shapes, which means a drawing
  /// read against the wrong one fails for a reason that has nothing to do with
  /// how it was drawn. Saying so beats leaving the picker to be noticed.
  ///
  /// Only the systems the page offers are looked in — see [numeralSystems],
  /// cord's one change to this scene.
  (String glyph, RecognitionSystem system)? get matchInAnotherSystem {
    final sketch = _sketch;
    if (sketch == null || _glyph != null) return null;

    for (final system in numeralSystems) {
      if (system == _system) continue;
      for (final rule in system._rules) {
        if (rule.matches(sketch)) return (rule.glyph, system);
      }
    }
    return null;
  }

  /// When something *did* match, but a rule tried before it came close: that
  /// glyph, and what it wanted.
  ///
  /// Rules are ordered most specific first, so a rule ahead of the one that
  /// matched is one that would have won had the drawing met it. Without this a
  /// stroke meant as ෯ simply reads as ෨ — the right answer for the rules as
  /// written, and no help at all in seeing which condition to look at.
  ///
  /// Only reported when it is genuinely near: at most two conditions
  /// outstanding, *and* three quarters of them met. The count alone is not
  /// enough — a rule of three conditions missing one is a different glyph, not
  /// a near miss, and saying so every time is noise.
  (String glyph, List<String> unmet)? get narrowlyMissed {
    final sketch = _sketch;
    final matched = _glyph;
    if (sketch == null || matched == null) return null;

    (String, List<String>)? best;
    for (final rule in _system._rules) {
      if (identical(rule, matched)) break;

      final unmet = rule.unmet(sketch);
      if (unmet.isEmpty || unmet.length > 2) continue;
      final met = (rule.clauses.length - unmet.length) / rule.clauses.length;
      if (met < 0.75) continue;

      if (best == null || unmet.length < best.$2.length) {
        best = (rule.glyph, unmet);
      }
    }
    return best;
  }

  /// When nothing matched: the rule that came closest, and what it wanted that
  /// the drawing didn't give it.
  ///
  /// Closest is by the *proportion* of conditions met, not the count, so that a
  /// rule written as one broad condition doesn't beat one spelled out in five
  /// simply by having less to fail. Ties go to whichever has the least left to
  /// put right, that being the more useful thing to be told. It is a guess at
  /// what was being drawn, not a claim — but it turns "not recognized" into
  /// something that says why, which is what writing a rule against a real hand
  /// needs.
  (String glyph, List<String> unmet)? get nearestMiss {
    final sketch = _sketch;
    if (sketch == null || _glyph != null) return null;

    (String, List<String>)? best;
    var bestScore = -1.0;
    for (final rule in _system._rules) {
      final unmet = rule.unmet(sketch);
      final met = (rule.clauses.length - unmet.length) / rule.clauses.length;
      final closer = best == null ||
          met > bestScore ||
          (met == bestScore && unmet.length < best.$2.length);
      if (closer) {
        bestScore = met;
        best = (rule.glyph, unmet);
      }
    }
    return best;
  }

  /// The dots currently on the canvas, in the order they were put down.
  List<Offset> get dots => List.unmodifiable(_dots);

  void clear() {
    _strokes.clear();
    _dots.clear();
    _glyph = null;
    _modifier = null;
  }

  @override
  void handlePointerEvent(PointerEvent event, Size size) {
    if (event is PointerDownEvent) {
      _activePoints = [event.localPosition];
    } else if (event is PointerMoveEvent && _activePoints != null) {
      _activePoints!.add(event.localPosition);
    } else if (event is PointerUpEvent && _activePoints != null) {
      _commit(_activePoints!);
      _activePoints = null;
    }
  }

  void _commit(List<Offset> points) {
    if (_pathLength(points) < _minPathLength) {
      _dots.add(_centreOf(points));
    } else {
      _strokes.add(_Stroke(points));
    }
    _classify();
  }

  /// Re-reads what is on the canvas under the current [system].
  void _classify() {
    _glyph = null;
    _modifier = null;

    final sketch = _sketch;
    if (sketch == null) return;

    for (final rule in _system._rules) {
      if (rule.matches(sketch)) {
        _glyph = rule;
        break;
      }
    }
    // A modifier modifies something, so it is only looked for once there is a
    // glyph for it to follow — and only where the glyph is a letter, a numeral
    // having no vowel to modify.
    if (_glyph == null || _system != RecognitionSystem.letters) return;

    for (final rule in _modifierRules) {
      if (rule.matches(sketch)) {
        _modifier = rule;
        break;
      }
    }
  }

  /// What has been drawn, sorted into a letter and the marks beside it — or
  /// null if no path has been drawn yet, dots alone being a mark on nothing.
  ///
  /// The letter is the stroke covering the most ground. Anything written past
  /// its right-hand edge is a vowel modifier; dots elsewhere belong to the
  /// letter. A stroke that is neither the letter nor to its right is left out
  /// of the sketch entirely.
  _Sketch? get _sketch {
    if (_strokes.isEmpty) return null;

    var body = _strokes.first.shape;
    for (final stroke in _strokes) {
      if (_area(stroke.shape.bounds) > _area(body.bounds)) {
        body = stroke.shape;
      }
    }

    return _Sketch(
      body: body,
      strokes: [for (final stroke in _strokes) stroke.shape],
      dots: [
        for (final dot in _dots)
          if (!_isBesideLetter(dot, body.bounds)) dot,
      ],
      markStrokes: [
        for (final stroke in _strokes)
          if (!identical(stroke.shape, body) &&
              _isBesideLetter(stroke.shape.bounds.center, body.bounds))
            stroke.shape,
      ],
      markDots: [
        for (final dot in _dots)
          if (_isBesideLetter(dot, body.bounds)) dot,
      ],
    );
  }

  /// Whether [point] sits past the letter's right-hand edge — the side vowel
  /// modifiers are written on.
  bool _isBesideLetter(Offset point, Rect letter) => point.dx > letter.right;

  double _area(Rect rect) => rect.width * rect.height;

  double _pathLength(List<Offset> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
    }
    return total;
  }

  Offset _centreOf(List<Offset> points) =>
      points.reduce((a, b) => a + b) / points.length.toDouble();

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
      canvas.drawCircle(dot, dotRadius, Paint()..color = paint.color);
    }
    if (_activePoints != null) {
      final previewPaint = Paint()
        ..color = paint.color.withValues(alpha: 0.5)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      _drawPath(canvas, _activePoints!, previewPaint);
    }

    _paintReadout(canvas, size);
  }

  /// The bottom-left readout: what was recognized, and underneath it the
  /// measurements the decision was made on, so a stroke that reads wrong on
  /// the live canvas says why.
  void _paintReadout(Canvas canvas, Size size) {
    final text = recognizedText;
    final sketch = _sketch;
    final shape = sketch?.body;

    final label = TextPainter(
      text: text != null
          ? TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              children: [
                const TextSpan(text: 'Recognized: '),
                TextSpan(
                  text: text,
                  style: const TextStyle(fontFamily: 'Yaldevi', fontSize: 26),
                ),
                TextSpan(text: '  $recognizedRoman'),
              ],
            )
          : TextSpan(
              style: const TextStyle(color: Colors.black54, fontSize: 16),
              children: shape == null
                  ? const [
                      TextSpan(
                          text: 'Draw a glyph below to see it recognized'),
                    ]
                  : _missSpans(),
            ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);

    final detail = shape == null
        ? null
        : (TextPainter(
            text: TextSpan(
              text: '${_system.label.toLowerCase()}   '
                  'left ${shape.leftTotal.round()}°   '
                  'right ${shape.rightTotal.round()}°   '
                  '${_runSummary(shape)}   '
                  '${shape.verticalRuns.length} humps   '
                  'ends ${shape.endsAboveStart ? 'above' : 'below/level'}   '
                  '${shape.crossings.length} crossing'
                  '${shape.crossings.length == 1 ? '' : 's'}'
                  '${sketch!.dots.isEmpty ? '' : '   ${sketch.dots.length} dot'
                      '${sketch.dots.length == 1 ? '' : 's'}'}'
                  '${_besideCount(sketch) == 0 ? '' : '   '
                      '${_besideCount(sketch)} beside'}',
              style: const TextStyle(color: Colors.black45, fontSize: 13),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: size.width - 48));

    // A more specific glyph that all but matched. Worth saying even though
    // something *was* recognized: it is usually what was being drawn.
    final missed = narrowlyMissed;
    final note = missed == null
        ? null
        : (TextPainter(
            text: TextSpan(
              style: const TextStyle(color: Colors.black54, fontSize: 13),
              children: [
                TextSpan(
                  text: missed.$1,
                  style: const TextStyle(fontFamily: 'Yaldevi', fontSize: 20),
                ),
                TextSpan(
                    text: ' was close — it wanted: ${missed.$2.join(', ')}'),
              ],
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: size.width - 48));

    var y = size.height - 24;
    if (detail != null) {
      y -= detail.height;
      detail.paint(canvas, Offset(24, y));
      y -= 4;
    }
    if (note != null) {
      y -= note.height;
      note.paint(canvas, Offset(24, y));
      y -= 4;
    }
    label.paint(canvas, Offset(24, y - label.height));
  }

  /// How many marks are sitting off to the right of the letter, waiting to be
  /// read as a vowel modifier.
  int _besideCount(_Sketch sketch) =>
      sketch.markStrokes.length + sketch.markDots.length;

  /// Each run of bending along the stroke, which way it goes and how far it
  /// comes round — "R218-L203-R116-L39".
  ///
  /// Rules are written against the number of runs and their sizes, and neither
  /// shows up in any of the other measurements. The sizes matter as much as
  /// the count: a run of about 180° is the pen doubling back on itself, which
  /// is a quite different thing from the same letters with a run of 40°.
  String _runSummary(StrokeShape shape) {
    final runs = shape.turnRuns;
    return runs.isEmpty ? 'no turns' : runs.join('-');
  }

  /// Why nothing was recognized: either that the drawing is a glyph in some
  /// other system and the picker is on the wrong one, or the glyph it came
  /// closest to here and the conditions it did not meet.
  List<InlineSpan> _missSpans() {
    final elsewhere = matchInAnotherSystem;
    if (elsewhere != null) {
      return [
        TextSpan(text: 'No ${_system.label.toLowerCase()} match — but this is '),
        TextSpan(
          text: elsewhere.$1,
          style: const TextStyle(fontFamily: 'Yaldevi', fontSize: 22),
        ),
        TextSpan(text: ' under ${elsewhere.$2.label}'),
      ];
    }

    final miss = nearestMiss;
    if (miss == null || miss.$2.isEmpty) {
      return const [TextSpan(text: 'Not recognized')];
    }
    return [
      const TextSpan(text: 'Not recognized — closest is '),
      TextSpan(
        text: miss.$1,
        style: const TextStyle(fontFamily: 'Yaldevi', fontSize: 22),
      ),
      TextSpan(text: ', which wants: ${miss.$2.join(', ')}'),
    ];
  }
}

/// Builds the scene plus a direct reference to its [SinhalaLetterLayer], so the
/// hosting page can call [SinhalaLetterLayer.clear] from the Clear button.
(Scene, SinhalaLetterLayer) buildSinhalaLetterScene() {
  final layer = SinhalaLetterLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
