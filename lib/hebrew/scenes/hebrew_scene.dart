import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/hebrew_letters.dart';
import '../engine/scene.dart';

/// Cream, dot-grid paper background (Moleskine-style notebook page).
/// Copied verbatim from the sibling `hangul` project.
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

/// The shared shape of a recognized result: its glyph plus the caption fields
/// [HebrewLayer._labelSpan] reads. Implemented by [_HebrewLetter] (the letters)
/// and [_PaleoSign] (paleo-only non-letters — the word-separator dot and the
/// tally numbers), so a single [HebrewLayer._recognized] slot holds either.
abstract interface class _Glyph {
  String get glyph;
  String get name;
  String get sound;
}

/// The Hebrew letters the recognizer can currently identify. Grows one entry
/// at a time as classifiers are built; [HebrewLayer.recognizedNames] is kept
/// in step with it so [HebrewPage]'s legend only shows letters that can
/// actually be drawn.
enum _HebrewLetter implements _Glyph {
  aleph('א', 'alef', "'"),
  bet('ב', 'bet', 'b/v'),
  dalet('ד', 'dalet', 'd'),
  vav('ו', 'vav', 'v/w'),
  chet('ח', 'chet', 'ch'),
  hey('ה', 'he', 'h'),
  zayin('ז', 'zayin', 'z'),
  resh('ר', 'resh', 'r'),
  shin('ש', 'shin', 'sh'),
  finalMem('ם', 'final mem', 'm'),
  finalTsadi('ץ', 'final tsadi', 'ts'),
  qof('ק', 'qof', 'q'),
  samech('ס', 'samekh', 's'),
  tsadi('צ', 'tsadi', 'ts'),
  finalPe('ף', 'final pe', 'p/f'),
  lamed('ל', 'lamed', 'l'),
  gimel('ג', 'gimel', 'g'),
  ayin('ע', 'ayin', "'"),
  kaf('כ', 'kaf', 'k/kh'),
  nun('נ', 'nun', 'n'),
  tet('ט', 'tet', 't'),
  mem('מ', 'mem', 'm'),
  pe('פ', 'pe', 'p/f'),
  tav('ת', 'tav', 't');

  const _HebrewLetter(this.glyph, this.name, this.sound);

  @override
  final String glyph;
  @override
  final String name;
  @override
  final String sound;
}

/// Paleo-only recognized results that aren't Hebrew letters: the word-separator
/// dot (a single point, standing in for a space between words) and the paleo
/// numerals — the tally 1–3 (that many non-crossing verticals at the same
/// height) and 10 (a horizontal out-and-back, 𐤗). Only ever produced in paleo
/// mode; see [HebrewLayer._commit].
enum _PaleoSign implements _Glyph {
  dot('·', 'word separator', 'space'),
  one('𐤖', 'one', '1'),
  two('𐤖𐤖', 'two', '2'),
  three('𐤖𐤖𐤖', 'three', '3'),
  ten('𐤗', 'ten', '10');

  const _PaleoSign(this.glyph, this.name, this.sound);

  @override
  final String glyph;
  @override
  final String name;
  @override
  final String sound;
}

/// A set of letters that share one shape when a letter stands alone (a normal
/// Hebrew ambiguity). [base] is the glyph the recognizer reports for the
/// shape; [glyphs] is every letter it could be, and [names] a human-readable
/// list of them for the caption. See [HebrewLayer.sharedGroups].
class SharedGroup {
  const SharedGroup(this.base, this.glyphs, this.names);

  final String base;
  final List<String> glyphs;
  final String names;
}

/// Freehand recognition of Hebrew letters. Like the sibling `hangul` project,
/// each letter is described purely by the strokes it's made of, and the
/// geometry primitives (corner/line detection, straightness, crossings) are
/// lifted straight from there.
///
/// Both letters so far are built on the same base as Hangul's ㄱ (giyeok) — a
/// single right-angle corner drawn top-left to bottom-right, its body riding
/// above the descending chord (see [_isCorner]) — plus one straight line
/// that crosses it exactly once ([_crossingCount]). The crossing line's
/// orientation is the whole difference between the two:
///
/// - ב (bet) — the corner crossed by a **horizontal** line. A horizontal
///   can't cross the corner's flat top (they're parallel), so it runs through
///   the corner's descending right leg: two strokes, one intersection (see
///   [_classifyCornerWithLine]).
/// - ח (chet) — the corner crossed by a **vertical** line. A vertical can't
///   cross the corner's right leg, so it runs through the flat top instead:
///   again two strokes, one intersection, the gate shape of ח.
/// - ה (he) — the same corner and vertical, but the vertical is *detached*:
///   it falls inside the corner's bounding box yet crosses the ㄱ zero times,
///   the way ה's left leg hangs under the top bar with a gap rather than
///   joining it (see [_classifyHey]). The crossing count — one for ח, none
///   for ה — is the whole difference.
///
/// Two letters are built from two corners instead of a corner and a line:
///
/// - ם (final mem) — a giyeok corner (ㄱ) and a nieun corner (ㄴ, the same
///   corner mirrored so its body rides below the chord) that cross each other
///   twice, closing into a box: the ㄱ gives the top and right sides, the ㄴ
///   the left and bottom, and they overlap at the top-left and bottom-right
///   for two intersections in all (see [_classifyFinalMem]).
/// - ף (final pe) — a nieun corner and a *tall, narrow* giyeok corner (its box
///   over twice as high as wide — the long sofit descender) crossing just
///   once, high on the nieun (its top half): the inner tongue of pe catching
///   the frame, where final mem's box crosses twice (see [_classifyFinalPe]).
///
/// Two are a vertical crossed near its top — the crossing line's orientation
/// telling them apart, like ב/ח do lower down:
///
/// - ז (zayin) — a vertical crossed once by a descending diagonal (`\`) up in
///   the top quarter of the stem, seating zayin's head on its stem (see
///   [_classifyZayin]).
/// - ד (dalet) — a vertical crossed once by a horizontal bar up in the top
///   quarter, the top bar of ד over its right descender. Alone this is equally
///   final chaf/kaf (ך), a normal Hebrew ambiguity, so it reports the base
///   form ד and the label lists both (see [_classifyDaletChaf]).
///
/// One shape is a bare giyeok corner on its own, shared by several letters
/// that aren't told apart in isolation and split only by how tall-and-thin it
/// is: a **wide** corner is resh (ר) or yod (י), a **narrow** one vav (ו) or
/// final nun (ן). It reports the group's base form and the label lists the
/// group (see [_classifyLoneCorner], [sharedGroups]).
///
/// Two drop the corner for a descending-line spine:
///
/// - ץ (final tsadi) — a descending line (`\`) crossed once by an ascending
///   diagonal (`/`) whose body sits up and to the right: the arm's center is
///   right of the descending line and above its center, the way the sofit
///   tsadi's arm flags off the top-right of its descender (see
///   [_classifyFinalTsadi]).
/// - צ (tsadi) — the same ascending arm, but its partner is a body that runs
///   out to the right and doubles back left ([_goesRightThenLeft]) rather than
///   a straight descender; the arm crosses that body once, on its rightward-
///   going part (see [_classifyTsadi]).
/// - א (alef) — a descending line spine with a line crossing it up high and
///   another crossing it down low: three strokes, the two arms each meeting
///   the spine once for two intersections in all, one arm above the spine's
///   center and one below (see [_classifyAleph]).
///
/// One shares ה's head-plus-vertical skeleton, split by descender length:
///
/// - ק (qof) — a head that runs out to the right and back to the left
///   ([_goesRightThenLeft]) with a straight vertical whose box overlaps it, but
///   whose leg is a *long descender*: the head's lowest point sits at or above
///   the vertical's centre, the leg dropping well below the head, where ה's
///   short leg hangs inside the head's box. Checked before ה (see
///   [_classifyQof]).
///
/// One is a single stroke that loops back on itself:
///
/// - ס (samech) — one stroke that crosses itself exactly once, the round loop
///   of samech closed by lapping its tail back over its head (see
///   [_classifySamech], [_selfCrossingCount]).
///
/// One is built on the nieun corner (ㄴ) instead:
///
/// - ש (shin) — a nieun corner (the left branch and base) intersected by two
///   ascending lines (`/`): three strokes, each arm crossing the ㄴ once for
///   two intersections in all, the trident of ש rising off its base (see
///   [_classifyShin]).
///
/// Everything above is the modern square alef-bet. When [script] is
/// [HebrewScript.paleo] a wholly separate recognizer runs instead — sharing no
/// letters with the modern chain, only the low-level geometry primitives — for
/// three ancient Paleo-Hebrew shapes:
///
/// - ת (taw) — a `+`: a straight vertical crossing a straight horizontal once
///   (see [_classifyPaleoTaw], [_isCrossOf]).
/// - ט (tet) — that same `+` with a self-crossing loop drawn around it, the
///   cross-in-a-wheel ⊕: the loop's box wraps both arms (see
///   [_classifyPaleoTet]).
/// - ע (ayin) — a bare self-crossing loop, the eye: one stroke meeting itself
///   once and nothing else (see [_classifyPaleoAyin]). This is the same loop
///   modern mode reads as samekh, but the two modes never run together.
/// - ש (shin) — a single unbroken `W`: one stroke that never crosses itself
///   whose vertical motion, left-to-right, runs down-up-down-up (see
///   [_classifyPaleoShin], [_verticalRuns]).
/// - ז (zayin) — an `I`-beam: a straight vertical with a horizontal bar across
///   its top and another across its bottom, two crossings in all (see
///   [_classifyPaleoZayin]).
/// - ל (lamed) — a single stroke crossing nothing whose vertical motion,
///   left-to-right, runs down-up with the upstroke staying low (below centre) —
///   a checkmark (see [_classifyPaleoLamed]).
/// - ג (gimel) — one stroke, up-down with the upstroke staying high (above
///   centre) and **ending to the right** of its start — a boomerang (see
///   [_classifyPaleoGimel]).
/// - פ (pe) — the same up-down stroke but **ending to the left** of its start;
///   the endpoint's side is the whole difference from gimel (see
///   [_classifyPaleoPe]).
/// - א (aleph) — a straight vertical crossed twice by a left-pointing chevron
///   `<` (read top-to-bottom, its horizontal motion runs left-then-right) — the
///   ox-head (see [_classifyPaleoAleph], [_horizontalRuns]).
///
/// Paleo mode also reads a few non-letters ([_PaleoSign]): a **dot** — a single
/// point (a tap), the word separator standing in for a space
/// ([_classifyPaleoDot]) — and the numerals **1–3**, that many non-crossing
/// verticals at the same height ([_classifyPaleoNumber]), and **10** (𐤗), a
/// flat horizontal out-and-back ([_classifyPaleoTen]).
///
/// Everything else is still unrecognized — a drawing that matches nothing
/// leaves the label showing the prompt instead.
class HebrewLayer extends Layer {
  /// A press-and-release shorter than this is a tap, not a drag; taps are
  /// ignored.
  static const double _tapThreshold = 5;

  /// Shortest drag that counts as a deliberate stroke rather than a slipped
  /// tap.
  static const double _minDragDistance = 8;

  /// How much taller than wide a stroke must be to read as vertical (and, the
  /// other way round, wider than tall to read as horizontal). A plain
  /// `|dy| > |dx|` would accept a 45°-ish diagonal, which is neither.
  static const double _verticalRatio = 2;
  static const double _horizontalRatio = 2;

  /// How far a stroke may bow off its own straight start-to-end chord and
  /// still read as a straight line: the larger of [_minStraightSlack] and
  /// this fraction of the chord's length.
  static const double _straightTolerance = 0.12;
  static const double _minStraightSlack = 6;

  /// A looser straightness bound (see [_straightTolerance]) for strokes allowed
  /// to be drawn with a bowed or hooked hand rather than dead straight — ג's
  /// descending body. Wide enough for a gentle curve, still too tight for a
  /// hard flat-top-then-down corner.
  static const double _looseStraightTolerance = 0.3;

  /// The least width a leftward-opening hump (כ/נ) must span for its rightward
  /// bulge to count as a real curve and not a straight vertical line — borrowed
  /// from Tifinagh's mirrored-m check (tifi's `_minMShapeBulge`). Reused for the
  /// least height of ט's downward cup.
  static const double _minLeftBulge = 4;

  /// How far ט's stroke may dip back down before its opening upward climb is
  /// taken to have ended — the apex where the leading up-run is cut from the
  /// cup. Small enough to ignore jitter, not a real turn.
  static const double _tetTurnSlack = 6;

  /// How far paleo shin's stroke must reverse vertically before the turn counts
  /// as a real one and starts a new run ([_verticalRuns]) rather than jitter —
  /// the W's valleys and peaks clear this by a wide margin.
  static const double _zigzagTurnSlack = 8;

  /// The largest a paleo dot's bounding box may span (each axis) — a word
  /// separator is a single point, so a tap collapses to one and clears this
  /// easily, while any real stroke is far bigger. See [_classifyPaleoDot].
  static const double _dotMaxExtent = 6;

  /// The least each axis of a corner's start→end chord may span for the chord
  /// to count as a descending diagonal (the giyeok-style corner is drawn
  /// top-left to bottom-right). Below this the "corner" is really a
  /// near-horizontal or near-vertical bend.
  static const double _minCornerChord = 15;

  /// How far, on average, a corner's body must lie off its chord to commit to
  /// a side — positive for the giyeok corner (elbow above the chord). A clean
  /// corner clears roughly 40; this margin keeps a barely-bowed diagonal from
  /// being forced onto one side.
  static const double _minCornerBulge = 12;

  /// Which letters the recognizer supports so far, matched against
  /// [LetterRow.name]. Kept in step with [_HebrewLetter] — used by
  /// [HebrewPage] to mute letters that can't be drawn yet.
  static const recognizedNames = {
    'alef',
    'bet',
    'dalet',
    'vav',
    'chet',
    'he',
    'zayin',
    'yod',
    'resh',
    'shin',
    'final kaf',
    'final mem',
    'final nun',
    'final tsadi',
    'qof',
    'samekh',
    'tsadi',
    'final pe',
    'lamed',
    'gimel',
    'ayin',
    'kaf',
    'nun',
    'tet',
    'mem',
    'pe',
    'tav',
  };

  /// Which letters the paleo recognizer supports — a wholly separate, much
  /// smaller set than [recognizedNames], since paleo mode runs its own
  /// classifiers (see [_commit]). Matched against [LetterRow.name] like
  /// [recognizedNames]; used by [recognizedNamesIn] so [HebrewPage]'s legend
  /// mutes everything but these when the Paleo-Hebrew script is selected.
  static const paleoRecognizedNames = {
    'tet',
    'ayin',
    'tav',
    'shin',
    'zayin',
    'lamed',
    'gimel',
    'alef',
    'pe',
  };

  /// The set of recognized letter names for [script] — [paleoRecognizedNames]
  /// in paleo mode, [recognizedNames] otherwise. Lets the legend mute letters
  /// that can't be drawn in whichever script is showing.
  static Set<String> recognizedNamesIn(HebrewScript script) =>
      script == HebrewScript.paleo ? paleoRecognizedNames : recognizedNames;

  /// Shapes that several letters share when a letter stands alone — a normal
  /// Hebrew ambiguity, since these are only told apart in the flow of a word.
  /// Each group's [SharedGroup.base] glyph is what the recognizer returns (and
  /// [recognizedGlyph] reports); the on-screen label lists the whole group.
  ///
  /// - the wide lone corner (resh/yod) and the narrow one (vav/final nun) —
  ///   see [_classifyLoneCorner];
  /// - the vertical-with-a-top-bar (dalet/final chaf) — see [_classifyDaletChaf].
  static const sharedGroups = [
    SharedGroup('ר', ['ר', 'י'], 'resh or yod'),
    SharedGroup('ו', ['ו', 'ן'], 'vav or final nun'),
    SharedGroup('ד', ['ד', 'ך'], 'dalet or final chaf'),
  ];

  final List<_Stroke> _strokes = [];
  _Glyph? _recognized;
  List<Offset>? _activePoints;

  /// Which script the recognizer is in. Set by the page's dropdown. This picks
  /// both the label's glyphs *and* which classifiers run: [HebrewScript.modern]
  /// reads the modern square shapes (the whole alef-bet), [HebrewScript.paleo]
  /// an entirely separate set of Paleo-Hebrew shapes that shares nothing with
  /// the modern ones — see [_commit]. A shape can therefore mean different
  /// letters in the two modes (a lone loop is samekh in modern, ayin in paleo)
  /// without the two ever colliding.
  HebrewScript script = HebrewScript.modern;

  /// The glyph currently being reported, or null if the drawing matches no
  /// letter. The letters themselves are private ([_HebrewLetter]); this
  /// exposes just enough of the result for tests to assert on.
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
      } else if (script == HebrewScript.paleo) {
        // In paleo mode a tap is a dot (word separator) — commit it as a single
        // point. In modern mode taps stay ignored.
        _commit(_Stroke([points.first]));
      }
      _activePoints = null;
    }
  }

  void _commit(_Stroke stroke) {
    _strokes.add(stroke);
    // Paleo-Hebrew is a wholly separate recognizer sharing no letters with the
    // modern chain below: in paleo mode only the paleo classifiers run, so a
    // shape can read as different letters in the two modes (a lone loop is
    // samekh here in modern, ayin over there in paleo) without ever colliding.
    if (script == HebrewScript.paleo) {
      _recognized = _classifyPaleoDot() ??
          _classifyPaleoTet() ??
          _classifyPaleoZayin() ??
          _classifyPaleoAleph() ??
          _classifyPaleoTaw() ??
          _classifyPaleoShin() ??
          _classifyPaleoLamed() ??
          _classifyPaleoGimel() ??
          _classifyPaleoPe() ??
          _classifyPaleoAyin() ??
          _classifyPaleoTen() ??
          _classifyPaleoNumber();
      return;
    }
    _recognized = _classifyCornerWithLine() ??
        _classifyQof() ??
        _classifyHey() ??
        _classifyFinalMem() ??
        _classifyFinalPe() ??
        _classifyPe() ??
        _classifyTav() ??
        _classifyMem() ??
        _classifyZayin() ??
        _classifyDaletChaf() ??
        _classifyAyin() ??
        _classifyFinalTsadi() ??
        _classifyTsadi() ??
        _classifyGimel() ??
        _classifyAleph() ??
        _classifyShin() ??
        _classifyTet() ??
        _classifyKafNun() ??
        _classifyLamed() ??
        _classifySamech() ??
        _classifyLoneCorner();
  }

  /// Whether the drawing is a giyeok-style corner crossed once by a single
  /// straight line — ב if that line is horizontal, ח if it's vertical.
  ///
  /// Exactly two strokes: one a corner ([_isCorner]) and the other a straight
  /// line ([_isStraight]), sorted by shape so stroke order doesn't matter. The
  /// two have to cross exactly once ([_crossingCount]) — a genuine
  /// intersection, not a mere touch at an endpoint — which is what "with a
  /// line intersecting it" means and what tells these apart from a bare
  /// corner with a line resting alongside it.
  _HebrewLetter? _classifyCornerWithLine() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke corner;
    final _Stroke line;
    if (_isCorner(a, bodyAboveChord: true) && _isStraight(b)) {
      corner = a;
      line = b;
    } else if (_isCorner(b, bodyAboveChord: true) && _isStraight(a)) {
      corner = b;
      line = a;
    } else {
      return null;
    }
    if (_crossingCount(corner, line) != 1) return null;
    if (_isHorizontal(line)) return _HebrewLetter.bet;
    if (_isVertical(line)) return _HebrewLetter.chet;
    return null;
  }

  /// Whether the drawing is ה (he): a giyeok-style corner and a vertical line
  /// where the vertical is *detached* — its span falls inside the corner's
  /// bounding box, but it crosses the corner strokes zero times.
  ///
  /// Exactly two strokes: one a corner ([_isCorner]), the other a straight
  /// vertical, sorted by shape so stroke order doesn't matter. The two must
  /// not cross ([_crossingCount] of zero) — a crossing vertical is ח, not ה —
  /// yet the vertical's bounding box has to overlap the corner's, which is
  /// what places ה's left leg hanging under the top bar with a gap, rather
  /// than off on its own away from the frame.
  _HebrewLetter? _classifyHey() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke corner;
    final _Stroke line;
    if (_isCorner(a, bodyAboveChord: true) &&
        _isVertical(b) &&
        _isStraight(b)) {
      corner = a;
      line = b;
    } else if (_isCorner(b, bodyAboveChord: true) &&
        _isVertical(a) &&
        _isStraight(a)) {
      corner = b;
      line = a;
    } else {
      return null;
    }
    if (_crossingCount(corner, line) != 0) return null;
    if (!_boundsOf(corner.points).overlaps(_boundsOf(line.points))) return null;
    return _HebrewLetter.hey;
  }

  /// Whether the drawing is ק (qof): a head that runs out to the right and
  /// back to the left with a long vertical descender dropping past it.
  ///
  /// Exactly two strokes: one that goes right then left ([_goesRightThenLeft] —
  /// qof's head, its rightmost point mid-stroke), the other a straight
  /// vertical, sorted by shape so stroke order doesn't matter. The vertical's
  /// bounding box overlaps the head's, and the head's lowest point sits at or
  /// above the vertical's centre — the leg drops well below the head. Checked
  /// before ה ([_classifyHey]), which shares the head-plus-vertical skeleton
  /// but has a short leg hanging inside the head's box (its lowest point *below*
  /// the leg's centre), so a long descender settles here first.
  _HebrewLetter? _classifyQof() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke head;
    final _Stroke line;
    if (_goesRightThenLeft(a) && _isVertical(b) && _isStraight(b)) {
      head = a;
      line = b;
    } else if (_goesRightThenLeft(b) && _isVertical(a) && _isStraight(a)) {
      head = b;
      line = a;
    } else {
      return null;
    }
    // The vertical reaches up into the head's bounding box...
    if (!_boundsOf(line.points).overlaps(_boundsOf(head.points))) return null;
    // ...and it's a long descender: the head's lowest point doesn't fall below
    // the vertical's centre, so the leg drops well past the head (qof) rather
    // than hanging short inside it (ה). This is checked before ה, which shares
    // the head-plus-vertical skeleton but has the short inside leg.
    if (_boundsOf(head.points).bottom > _boundsOf(line.points).center.dy) {
      return null;
    }
    return _HebrewLetter.qof;
  }

  /// Whether the drawing is ם (final mem): a closed box drawn as a giyeok
  /// corner (ㄱ) and a nieun corner (ㄴ) crossing each other twice.
  ///
  /// Exactly two strokes, one corner of each hand ([_isCorner] with
  /// `bodyAboveChord` true then false), sorted by shape so stroke order
  /// doesn't matter. The ㄱ carries the top and right sides, the ㄴ the left
  /// and bottom; where their ends overlap — top-left and bottom-right — the
  /// two strokes cross, for exactly two intersections ([_crossingCount]). A
  /// single crossing would be an open corner-pair, none would be two corners
  /// drawn apart; two is what closes the box.
  _HebrewLetter? _classifyFinalMem() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke giyeok;
    final _Stroke nieun;
    if (_isCorner(a, bodyAboveChord: true) &&
        _isCorner(b, bodyAboveChord: false)) {
      giyeok = a;
      nieun = b;
    } else if (_isCorner(b, bodyAboveChord: true) &&
        _isCorner(a, bodyAboveChord: false)) {
      giyeok = b;
      nieun = a;
    } else {
      return null;
    }
    if (_crossingCount(giyeok, nieun) != 2) return null;
    return _HebrewLetter.finalMem;
  }

  /// Whether the drawing is ף (final pe): a nieun corner (ㄴ) crossing a tall,
  /// narrow giyeok corner (ㄱ) exactly once, high on the nieun.
  ///
  /// Exactly two strokes, one corner of each hand ([_isCorner] with
  /// `bodyAboveChord` true then false), sorted by shape so stroke order doesn't
  /// matter. The giyeok is tall and narrow — its box more than twice as high as
  /// wide, the long descender of the sofit pe. The two cross exactly once
  /// ([_crossingCount]) — a single intersection, where final mem's box crosses
  /// twice — and that crossing lands in the **top half** of the nieun
  /// ([_crossingPoint]), the inner tongue of pe catching the frame high up.
  _HebrewLetter? _classifyFinalPe() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke giyeok;
    final _Stroke nieun;
    if (_isCorner(a, bodyAboveChord: true) &&
        _isCorner(b, bodyAboveChord: false)) {
      giyeok = a;
      nieun = b;
    } else if (_isCorner(b, bodyAboveChord: true) &&
        _isCorner(a, bodyAboveChord: false)) {
      giyeok = b;
      nieun = a;
    } else {
      return null;
    }
    // The giyeok is a tall, narrow descender: over twice as high as wide.
    final gb = _boundsOf(giyeok.points);
    if (gb.height <= gb.width * 2) return null;
    if (_crossingCount(giyeok, nieun) != 1) return null;
    // The single crossing lands high on the nieun — its top half.
    final cross = _crossingPoint(giyeok, nieun);
    if (cross == null) return null;
    if (cross.dy > _boundsOf(nieun.points).center.dy) return null;
    return _HebrewLetter.finalPe;
  }

  /// Whether the drawing is ע (ayin): a falling stroke (`\`) and a rising one
  /// (`/`) crossing once like an X — ayin's left arm bracketing its right arm.
  ///
  /// Exactly two strokes, told apart only by whether their endpoints rise or
  /// fall ([_isAscending]) — no straightness or steepness required, so a
  /// near-vertical or curved arm still qualifies. They cross once, checked on
  /// the raw strokes ([_crossingCount]); and, by the strokes' own endpoints,
  /// the descender's start lies left of the ascender's start and the ascender's
  /// end left of the descender's end. That second test is what tells ayin from
  /// final tsadi and gimel, whose crossing line flags out past the descender's
  /// end on the right — so ayin runs before both and claims the X first.
  _HebrewLetter? _classifyAyin() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    // One stroke's endpoints fall (`\`), the other's rise (`/`) — judged purely
    // by endpoints ([_isAscending]), with no straightness or steepness demanded,
    // so a near-vertical arm or a curved one still sorts correctly.
    final _Stroke descender;
    final _Stroke ascender;
    if (!_isAscending(a) && _isAscending(b)) {
      descender = a;
      ascender = b;
    } else if (!_isAscending(b) && _isAscending(a)) {
      descender = b;
      ascender = a;
    } else {
      return null;
    }
    // Cross checked on the raw strokes, not their endpoint chords.
    if (_crossingCount(descender, ascender) != 1) return null;
    // Ayin's arms cross like an X, judged by the strokes' own endpoints: the
    // descender's start sits left of the ascender's start, and the ascender's
    // end left of the descender's end — the wide falling arm bracketing the
    // rising one. Final tsadi and gimel flag their crossing line out past the
    // descender's end on the right, failing the second test.
    if (descender.start.dx >= ascender.start.dx) return null;
    if (ascender.end.dx >= descender.end.dx) return null;
    return _HebrewLetter.ayin;
  }

  /// Whether the drawing is ץ (final tsadi): a descending line (`\`) crossed
  /// once by an ascending diagonal (`/`) whose body sits up and to the right.
  ///
  /// Exactly two strokes, both straight diagonals ([_isDiagonal]) — one
  /// descending, one ascending ([_isAscending]) — sorted by slope so stroke
  /// order doesn't matter. The two cross exactly once ([_crossingCount]) — the
  /// single intersection — and the ascending arm's center lies to the right of
  /// the descending line and above its center, which is what puts the sofit
  /// tsadi's arm flagging off the top-right of its descender rather than
  /// hanging low or off to the left.
  _HebrewLetter? _classifyFinalTsadi() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke descender;
    final _Stroke arm;
    if (_isDiagonal(a) && !_isAscending(a) && _isDiagonal(b) && _isAscending(b)) {
      descender = a;
      arm = b;
    } else if (_isDiagonal(b) &&
        !_isAscending(b) &&
        _isDiagonal(a) &&
        _isAscending(a)) {
      descender = b;
      arm = a;
    } else {
      return null;
    }
    if (_crossingCount(descender, arm) != 1) return null;
    final descenderCenter = _boundsOf(descender.points).center;
    final armCenter = _boundsOf(arm.points).center;
    // The arm's body sits up and to the right of the descender.
    if (armCenter.dx <= descenderCenter.dx) return null;
    if (armCenter.dy >= descenderCenter.dy) return null;
    return _HebrewLetter.finalTsadi;
  }

  /// Whether the drawing is ג (gimel): a descending diagonal (`\`) crossed once
  /// by an ascending diagonal (`/`) whose body sits below the descender — the
  /// little foot kicking off the bottom of gimel's stem.
  ///
  /// Exactly two strokes: one a descending body drawn with a loose enough hand
  /// to allow a gentle curve or hook ([_isLooseDescender]), the other a
  /// straight ascending diagonal ([_isDiagonal], [_isAscending]), sorted by
  /// shape so stroke order doesn't matter. They cross exactly once
  /// ([_crossingCount]), and the arm's centre sits below the descender's centre
  /// (greater y). Disjoint from final tsadi ([_classifyFinalTsadi]), whose arm
  /// sits above the descender instead, and from tsadi ([_classifyTsadi], run
  /// first), whose body doubles back right-to-left — the loose descender is a
  /// one-way fall, not an out-and-back, so a right-then-left body is refused.
  _HebrewLetter? _classifyGimel() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke descender;
    final _Stroke arm;
    if (_isLooseDescender(a) && _isDiagonal(b) && _isAscending(b)) {
      descender = a;
      arm = b;
    } else if (_isLooseDescender(b) && _isDiagonal(a) && _isAscending(a)) {
      descender = b;
      arm = a;
    } else {
      return null;
    }
    // A body that doubles back to the left is tsadi's, not gimel's one-way fall.
    if (_goesRightThenLeft(descender)) return null;
    if (_crossingCount(descender, arm) != 1) return null;
    final descenderCenter = _boundsOf(descender.points).center;
    final armCenter = _boundsOf(arm.points).center;
    // The arm's body sits below the descender.
    if (armCenter.dy <= descenderCenter.dy) return null;
    return _HebrewLetter.gimel;
  }

  /// Whether the drawing is צ (tsadi): a body stroke that runs out to the
  /// right and back to the left, crossed once on its rightward-going part by
  /// an ascending diagonal arm.
  ///
  /// Exactly two strokes: one that goes right then left
  /// ([_goesRightThenLeft] — its rightmost point falls in its middle, so it
  /// heads out rightward and returns), the other a straight ascending diagonal
  /// ([_isDiagonal], [_isAscending]), sorted by shape so stroke order doesn't
  /// matter. They cross exactly once ([_crossingCount]), and that crossing
  /// lands on the body's outbound (rightward-going) part — the segments up to
  /// its rightmost point, before it turns back left ([_crossesWithin]) — the
  /// arm of tsadi flagging off the right of its body. Disjoint from final
  /// tsadi ([_classifyFinalTsadi]), whose body is a straight descending line
  /// rather than a stroke that doubles back.
  _HebrewLetter? _classifyTsadi() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke body;
    final _Stroke arm;
    if (_goesRightThenLeft(a) && _isDiagonal(b) && _isAscending(b)) {
      body = a;
      arm = b;
    } else if (_goesRightThenLeft(b) && _isDiagonal(a) && _isAscending(a)) {
      body = b;
      arm = a;
    } else {
      return null;
    }
    if (_crossingCount(body, arm) != 1) return null;
    // The crossing lands on the body's rightward-going (outbound) part — the
    // segments up to its rightmost point — not on the return leg.
    if (!_crossesWithin(body, arm, 1, _rightmostIndex(body))) return null;
    return _HebrewLetter.tsadi;
  }

  /// Whether the drawing is מ (mem): a body stroke plus a descending line
  /// crossing it. The body climbs first ([_tetApex]), then the part past that
  /// apex runs out to the right and back left ([_goesRightThenLeft]) — the hood
  /// over mem's top. The second stroke is a straight descending diagonal (`\`)
  /// that cuts across the body's opening upward climb.
  ///
  /// Two strokes, sorted so the straight descending diagonal is the line and
  /// the other is the body. The body's apex must sit a couple of points in (a
  /// real climb, not an immediate fall), its post-apex tail must go right then
  /// left, and the line must cross that climbing lead at least once
  /// ([_crossingCount] on the lead alone).
  _HebrewLetter? _classifyMem() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke line;
    final _Stroke body;
    if (_isDiagonal(a) && !_isAscending(a)) {
      line = a;
      body = b;
    } else if (_isDiagonal(b) && !_isAscending(b)) {
      line = b;
      body = a;
    } else {
      return null;
    }
    final apex = _tetApex(body);
    if (apex < 2) return null; // the body must climb first
    final lead = _Stroke(body.points.sublist(0, apex + 1));
    final rest = _Stroke(body.points.sublist(apex));
    if (!_goesRightThenLeft(rest)) return null;
    if (_crossingCount(lead, line) < 1) return null;
    return _HebrewLetter.mem;
  }

  /// Whether the drawing is פ (pe): כ's leftward-opening hump ([_isLeftBulge])
  /// with a nieun corner (ㄴ, [_isCorner] `bodyAboveChord: false`) poking into
  /// it from the top — pe's inward tongue.
  ///
  /// Two strokes, sorted so the hump and the nieun are told apart by shape.
  /// They cross exactly once ([_crossingCount]), and that crossing lands in the
  /// top half of the hump ([_crossingPoint]) — the tongue coming in from above.
  /// Disjoint from final mem (ם, two corners crossing twice) and final pe (ף,
  /// whose first stroke is a giyeok corner, not a hump).
  _HebrewLetter? _classifyPe() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke hump;
    final _Stroke nieun;
    if (_isLeftBulge(a) && _isCorner(b, bodyAboveChord: false)) {
      hump = a;
      nieun = b;
    } else if (_isLeftBulge(b) && _isCorner(a, bodyAboveChord: false)) {
      hump = b;
      nieun = a;
    } else {
      return null;
    }
    if (_crossingCount(hump, nieun) != 1) return null;
    final cross = _crossingPoint(hump, nieun);
    if (cross == null) return null;
    if (cross.dy >= _boundsOf(hump.points).center.dy) return null;
    return _HebrewLetter.pe;
  }

  /// Whether the drawing is ת (tav): a giyeok corner (ㄱ, [_isCorner]
  /// `bodyAboveChord: true`) crossed once from the top by a nieun corner (ㄴ)
  /// mirrored to kick **left** ([_isMirroredNieun]) — tav's two legs under the
  /// top bar, the left one footing the opposite way from the giyeok's leg.
  ///
  /// Two strokes, sorted so the giyeok and the left-footed nieun are told apart
  /// by shape. They cross exactly once ([_crossingCount]), high on the giyeok
  /// ([_crossingPoint] in its top half). Disjoint from final mem (ם), whose
  /// nieun foots right and crosses the giyeok twice.
  _HebrewLetter? _classifyTav() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke giyeok;
    final _Stroke nieun;
    if (_isCorner(a, bodyAboveChord: true) && _isMirroredNieun(b)) {
      giyeok = a;
      nieun = b;
    } else if (_isCorner(b, bodyAboveChord: true) && _isMirroredNieun(a)) {
      giyeok = b;
      nieun = a;
    } else {
      return null;
    }
    if (_crossingCount(giyeok, nieun) != 1) return null;
    final cross = _crossingPoint(giyeok, nieun);
    if (cross == null) return null;
    if (cross.dy >= _boundsOf(giyeok.points).center.dy) return null;
    return _HebrewLetter.tav;
  }

  /// Whether the drawing is ז (zayin): a vertical line crossed once by a
  /// descending diagonal (`\`) up near the vertical's top.
  ///
  /// Exactly two strokes: one a straight vertical, the other a straight
  /// descending diagonal ([_isDiagonal], not [_isAscending]), sorted by shape
  /// so stroke order doesn't matter. The two cross exactly once
  /// ([_crossingCount]), and the crossing falls in the top quarter of the
  /// vertical — split the stem into four and the arm meets it in the topmost
  /// part — which is what seats zayin's head on top of its stem.
  _HebrewLetter? _classifyZayin() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke vertical;
    final _Stroke arm;
    if (_isVertical(a) &&
        _isStraight(a) &&
        _isDiagonal(b) &&
        !_isAscending(b)) {
      vertical = a;
      arm = b;
    } else if (_isVertical(b) &&
        _isStraight(b) &&
        _isDiagonal(a) &&
        !_isAscending(a)) {
      vertical = b;
      arm = a;
    } else {
      return null;
    }
    if (_crossingCount(vertical, arm) != 1) return null;
    // Where the arm crosses the stem: its y where x meets the stem's center.
    final bounds = _boundsOf(vertical.points);
    final run = arm.end.dx - arm.start.dx;
    if (run == 0) return null;
    final t = (bounds.center.dx - arm.start.dx) / run;
    final crossY = arm.start.dy + t * (arm.end.dy - arm.start.dy);
    if (crossY > bounds.top + bounds.height / 4) return null;
    return _HebrewLetter.zayin;
  }

  /// Where ט's leading upward climb ends — the apex, the topmost point reached
  /// before the stroke turns back down past it (by more than [_tetTurnSlack]).
  /// Everything from here on is the cup ([_classifyTet] checks it); everything
  /// before is the up-going lead. Zero if the stroke never climbs first.
  int _tetApex(_Stroke s) {
    final points = s.points;
    var apex = 0;
    for (var i = 1; i < points.length; i++) {
      if (points[i].dy < points[apex].dy) {
        apex = i; // still climbing — a new topmost
      } else if (points[i].dy > points[apex].dy + _tetTurnSlack) {
        break; // turned down past the apex — the climb is over
      }
    }
    return apex;
  }

  /// Whether the drawing is ט (tet): a single stroke that never crosses itself,
  /// whose tail — everything after its opening upward climb ([_tetApex]) is cut
  /// away — is a downward cup, both its endpoints hanging in the **top** half of
  /// that tail's bounding box with the body bulging down between them. This is
  /// the upward mirror of כ/נ's leftward hump (Tifinagh's `_isDShapedLbMirrored`
  /// vs `_isMShapedMirrored`); the lead is dropped first because its low
  /// starting point would otherwise fail the both-endpoints-high test.
  _HebrewLetter? _classifyTet() {
    if (_strokes.length != 1) return null;
    final stroke = _strokes.single;
    if (_selfCrossingCount(stroke) != 0) return null;
    final rest = _Stroke(stroke.points.sublist(_tetApex(stroke)));
    if (rest.points.length < 3) return null;
    final bounds = _boundsOf(rest.points);
    if (bounds.height <= _minLeftBulge) return null;
    // The tail's start→end chord runs horizontal (a cup, not a wall).
    final chord = rest.end - rest.start;
    if (chord.dy.abs() >= chord.dx.abs()) return null;
    if (rest.start.dy >= bounds.center.dy) return null;
    if (rest.end.dy >= bounds.center.dy) return null;
    return _HebrewLetter.tet;
  }

  /// Whether the drawing is כ (kaf) or נ (nun): a single stroke that never
  /// crosses itself, bulging out to the right from two endpoints both hanging
  /// in the **left** half of its bounding box — the leftward-opening hump the
  /// two share. The check is Tifinagh's mirrored-m shape (tifi's
  /// `_isMShapedMirrored`): a real bulge ([_minLeftBulge] wide), a start→end
  /// chord that runs more vertical than horizontal, and both endpoints left of
  /// centre. Split, like [_classifyLoneCorner] splits resh/vav, by how tall and
  /// thin the hump is: a narrow one (height ≥ 2× width) is nun (נ), otherwise
  /// the wider kaf (כ). Run before [_classifyLamed], whose start-to-foot chord
  /// crosses this closed hump; a real lamed keeps its start off in the right
  /// half, so it fails the both-endpoints-left test and isn't stolen here.
  _HebrewLetter? _classifyKafNun() {
    if (_strokes.length != 1) return null;
    final stroke = _strokes.single;
    if (_selfCrossingCount(stroke) != 0) return null;
    if (!_isLeftBulge(stroke)) return null;
    final bounds = _boundsOf(stroke.points);
    return bounds.height >= bounds.width * 2
        ? _HebrewLetter.nun
        : _HebrewLetter.kaf;
  }

  /// Whether [stroke] is a leftward-opening hump — כ/נ's shape and פ's outer
  /// body: a bulge wide enough to be a curve ([_minLeftBulge]), a start→end
  /// chord running more vertical than horizontal (both endpoints stacked on the
  /// left), and both those endpoints in the left half of its bounding box.
  bool _isLeftBulge(_Stroke stroke) {
    final bounds = _boundsOf(stroke.points);
    if (bounds.width <= _minLeftBulge) return false;
    final chord = stroke.end - stroke.start;
    if (chord.dx.abs() >= chord.dy.abs()) return false;
    return stroke.start.dx < bounds.center.dx &&
        stroke.end.dx < bounds.center.dx;
  }

  /// Whether the drawing is a lone giyeok-style corner on its own — a top bar
  /// with a right leg coming down ([_isCorner]) — and which letter group it
  /// falls in.
  ///
  /// This shape is shared by several letters that aren't told apart in
  /// isolation (a normal Hebrew ambiguity), split only by how tall and thin
  /// the corner is (its bounding box):
  ///
  /// - a **wide** corner (leg under twice the top bar) is resh (ר) or yod (י),
  ///   reported as ר;
  /// - a **narrow** corner (leg twice the top bar or more) is vav (ו) or final
  ///   nun (ן), reported as ו.
  ///
  /// The on-screen label lists the whole group ([sharedGroups]). A single
  /// stroke on its own; the multi-stroke letters that open with the same
  /// corner (ב, ח, ה, ם) only reach their own classifiers once a second stroke
  /// lands, so a bare corner settling here doesn't shadow them.
  _HebrewLetter? _classifyLoneCorner() {
    if (_strokes.length != 1) return null;
    final stroke = _strokes.last;
    if (!_isCorner(stroke, bodyAboveChord: true)) return null;
    final bounds = _boundsOf(stroke.points);
    // Tall and thin (leg ≥ 2× the top bar) → vav/final nun; otherwise the
    // wider resh/yod.
    return bounds.height >= bounds.width * 2
        ? _HebrewLetter.vav
        : _HebrewLetter.resh;
  }

  /// Whether the drawing is ד (dalet) — equally final chaf/kaf (ך) in
  /// isolation: a vertical line crossed once by a horizontal line up in the
  /// top quarter of the vertical.
  ///
  /// Exactly two strokes: one a straight vertical, the other a straight
  /// horizontal, sorted by shape so stroke order doesn't matter. They cross
  /// once ([_crossingCount]) and the crossing falls in the top quarter of the
  /// vertical — split the stem into four and the bar meets it in the topmost
  /// part — the top bar of ד sitting over its right descender. It reports the
  /// base form ד; the label lists ד and ך ([sharedGroups]).
  _HebrewLetter? _classifyDaletChaf() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke vertical;
    final _Stroke bar;
    if (_isVertical(a) &&
        _isStraight(a) &&
        _isHorizontal(b) &&
        _isStraight(b)) {
      vertical = a;
      bar = b;
    } else if (_isVertical(b) &&
        _isStraight(b) &&
        _isHorizontal(a) &&
        _isStraight(a)) {
      vertical = b;
      bar = a;
    } else {
      return null;
    }
    if (_crossingCount(vertical, bar) != 1) return null;
    // The bar crosses the stem up in its top quarter (the bar is horizontal,
    // so its own y is the crossing height).
    final vbounds = _boundsOf(vertical.points);
    if (_boundsOf(bar.points).center.dy > vbounds.top + vbounds.height / 4) {
      return null;
    }
    return _HebrewLetter.dalet;
  }

  /// Whether the drawing is א (alef): a descending line (`\`) — the spine —
  /// with a line crossing it up high and another crossing it down low, for
  /// two intersections in all.
  ///
  /// Three strokes. One is a descending diagonal spine ([_isDiagonal], not
  /// [_isAscending]); the other two are the arms. Each arm crosses the spine
  /// exactly once ([_crossingCount]) and the two arms don't cross each other
  /// (so there are two intersections total, as alef has), and one arm sits
  /// above the spine's center with the other below — the upper and lower arms
  /// that hang off alef's diagonal. Any of the three strokes may be the spine;
  /// it's found by trying each.
  _HebrewLetter? _classifyAleph() {
    if (_strokes.length != 3) return null;
    for (var i = 0; i < 3; i++) {
      final spine = _strokes[i];
      if (!_isDiagonal(spine) || _isAscending(spine)) continue;
      final arms = [
        for (var k = 0; k < 3; k++)
          if (k != i) _strokes[k],
      ];
      if (_crossingCount(spine, arms[0]) != 1) continue;
      if (_crossingCount(spine, arms[1]) != 1) continue;
      if (_crossingCount(arms[0], arms[1]) != 0) continue;
      final spineY = _boundsOf(spine.points).center.dy;
      final arm0Above = _boundsOf(arms[0].points).center.dy < spineY;
      final arm1Above = _boundsOf(arms[1].points).center.dy < spineY;
      // One arm above the spine's center, the other below.
      if (arm0Above == arm1Above) continue;
      return _HebrewLetter.aleph;
    }
    return null;
  }

  /// Whether the drawing is ש (shin): a nieun corner (ㄴ) — the left branch
  /// and base — intersected by two ascending lines (`/`), the other two
  /// branches, for two intersections in all.
  ///
  /// Three strokes. One is a nieun corner ([_isCorner] with `bodyAboveChord`
  /// false); the other two are ascending diagonals ([_isDiagonal],
  /// [_isAscending]). Each arm crosses the nieun exactly once
  /// ([_crossingCount]) and the two arms don't cross each other, so there are
  /// two intersections total — the trident of ש rising off its base. Any of
  /// the three strokes may be the nieun; it's found by trying each.
  _HebrewLetter? _classifyShin() {
    if (_strokes.length != 3) return null;
    for (var i = 0; i < 3; i++) {
      final nieun = _strokes[i];
      if (!_isCorner(nieun, bodyAboveChord: false)) continue;
      final arms = [
        for (var k = 0; k < 3; k++)
          if (k != i) _strokes[k],
      ];
      if (!arms.every((a) => _isDiagonal(a) && _isAscending(a))) continue;
      if (_crossingCount(nieun, arms[0]) != 1) continue;
      if (_crossingCount(nieun, arms[1]) != 1) continue;
      if (_crossingCount(arms[0], arms[1]) != 0) continue;
      return _HebrewLetter.shin;
    }
    return null;
  }

  /// Whether the drawing is ס (samech): a single stroke that crosses itself
  /// exactly once — the round loop of samech, closed by running its tail back
  /// Whether the drawing is ל (lamed) — the tall one-stroke letter with its
  /// flag up top and a foot that kicks out to the **left** at the bottom.
  ///
  /// A single stroke that never crosses itself ([_selfCrossingCount] is zero),
  /// whose final move runs right-to-left (the foot), and — the telling part —
  /// the straight line from the pen-down point at the top to the centre of
  /// that leftward foot cuts back through the stroke at least once, because
  /// lamed's hooked, non-convex body bows across it. A plain corner or line
  /// leaves that connecting chord clear (zero crossings), so it settles here
  /// rather than falling through to the bare-corner fallback.
  _HebrewLetter? _classifyLamed() {
    final chord = _lamedChord();
    if (chord == null) return null;
    final stroke = _strokes.single;
    if (_selfCrossingCount(stroke) != 0) return null;
    if (_crossingCount(stroke, _Stroke(chord)) < 1) return null;
    return _HebrewLetter.lamed;
  }

  /// ל's foot: the trailing run of consecutive left-going points at the end of
  /// the single stroke. Null unless the drawing is a single stroke that ends in
  /// a right-to-left move.
  List<Offset>? _lamedFoot() {
    if (_strokes.length != 1) return null;
    final points = _strokes.single.points;
    if (points.length < 5) return null;
    // Walk back from the end over every consecutive leftward step — the foot.
    var footStart = points.length - 1;
    while (footStart > 0 && points[footStart].dx < points[footStart - 1].dx) {
      footStart--;
    }
    if (footStart == points.length - 1) return null; // no leftward foot
    return points.sublist(footStart);
  }

  /// The connecting line ל's test hangs on: from the pen-down point at the top
  /// to the **centre of the left-going foot** ([_lamedFoot]), as
  /// `[start, footCentre]`, or null when there's no foot.
  List<Offset>? _lamedChord() {
    final foot = _lamedFoot();
    if (foot == null) return null;
    final footCentre = Offset(
        (foot.first.dx + foot.last.dx) / 2, (foot.first.dy + foot.last.dy) / 2);
    return [_strokes.single.points.first, footCentre];
  }

  /// over where it began ([_selfCrossingCount]).
  _HebrewLetter? _classifySamech() {
    if (_strokes.length != 1) return null;
    if (_selfCrossingCount(_strokes.single) != 1) return null;
    return _HebrewLetter.samech;
  }

  // --- Paleo-Hebrew classifiers ------------------------------------------
  //
  // These run *only* in paleo mode (see [_commit]) and describe the ancient
  // Paleo-Hebrew shapes, which are unrelated to the modern square ones above.
  // They reuse the generic geometry primitives (crossings, straightness,
  // vertical/horizontal) — those are plain math, not letters — but share no
  // letter recognition with the modern chain: the two never run together, so
  // the same drawing can mean different letters in the two scripts.

  /// Whether the drawing is Paleo-Hebrew taw (ת): a `+` — a straight vertical
  /// line crossing a straight horizontal line exactly once.
  ///
  /// Exactly two strokes, one vertical and one horizontal ([_isVertical] /
  /// [_isHorizontal], both [_isStraight]), sorted by orientation so stroke
  /// order doesn't matter, meeting once ([_crossingCount]). Paleo taw is a plus
  /// sign; the arms cross near the middle rather than up top the way modern
  /// dalet's bar does, but modern dalet lives in the other mode entirely, so
  /// there's nothing to tell apart here.
  _HebrewLetter? _classifyPaleoTaw() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    if (!_isCrossOf(a, b)) return null;
    return _HebrewLetter.tav;
  }

  /// Whether the drawing is Paleo-Hebrew tet (ט): a `+` cross (as in
  /// [_classifyPaleoTaw]) with a self-crossing loop drawn around it — the
  /// cross-in-a-wheel ⊕.
  ///
  /// Exactly three strokes. One is a loop that crosses itself once
  /// ([_selfCrossingCount]); the other two are a straight vertical and a
  /// straight horizontal crossing each other once ([_isCrossOf]). The loop only
  /// has to *enclose* the cross, tested by bounding-box overlap ([Rect.overlaps])
  /// against each line — its actual crossings with the lines aren't checked, so
  /// the wheel may be drawn loosely around the arms. Any of the three strokes
  /// may be the loop; it's found by trying each.
  _HebrewLetter? _classifyPaleoTet() {
    if (_strokes.length != 3) return null;
    for (var i = 0; i < 3; i++) {
      final loop = _strokes[i];
      if (_selfCrossingCount(loop) != 1) continue;
      final rest = [
        for (var k = 0; k < 3; k++)
          if (k != i) _strokes[k],
      ];
      if (!_isCrossOf(rest[0], rest[1])) continue;
      // The loop's box wraps both arms — bounding-box overlap only, no need to
      // check where the loop meets the lines.
      final loopBounds = _boundsOf(loop.points);
      if (!loopBounds.overlaps(_boundsOf(rest[0].points))) continue;
      if (!loopBounds.overlaps(_boundsOf(rest[1].points))) continue;
      return _HebrewLetter.tet;
    }
    return null;
  }

  /// Whether the drawing is Paleo-Hebrew zayin (ז): an `I`-beam — a straight
  /// vertical with a straight horizontal bar across its top and another across
  /// its bottom.
  ///
  /// Exactly three strokes. One is a straight vertical; the other two are
  /// straight horizontals ([_isVertical] / [_isHorizontal], both [_isStraight]).
  /// Each bar crosses the vertical exactly once ([_crossingCount]) — two
  /// intersections in all — and the two land on opposite sides of the vertical's
  /// centre, one in its top area and one in its bottom. Any of the three strokes
  /// may be the vertical; it's found by trying each. Disjoint from paleo tet
  /// (which needs a self-crossing loop among its three strokes, not three
  /// straight lines).
  _HebrewLetter? _classifyPaleoZayin() {
    if (_strokes.length != 3) return null;
    for (var i = 0; i < 3; i++) {
      final vertical = _strokes[i];
      if (!_isVertical(vertical) || !_isStraight(vertical)) continue;
      final bars = [
        for (var k = 0; k < 3; k++)
          if (k != i) _strokes[k],
      ];
      if (!bars.every((b) => _isHorizontal(b) && _isStraight(b))) continue;
      if (_crossingCount(vertical, bars[0]) != 1) continue;
      if (_crossingCount(vertical, bars[1]) != 1) continue;
      // One bar high on the vertical, the other low — opposite sides of centre.
      final mid = _boundsOf(vertical.points).center.dy;
      final y0 = _boundsOf(bars[0].points).center.dy;
      final y1 = _boundsOf(bars[1].points).center.dy;
      if ((y0 < mid) == (y1 < mid)) continue;
      return _HebrewLetter.zayin;
    }
    return null;
  }

  /// Whether the drawing is Paleo-Hebrew aleph (א): a straight vertical crossed
  /// twice by a left-pointing chevron `<` — the ox-head, two arms flaring off an
  /// apex on the left through a vertical stem.
  ///
  /// Exactly two strokes. One is a straight vertical ([_isVertical],
  /// [_isStraight]); the other — the chevron — crosses it exactly twice
  /// ([_crossingCount]), once on each arm. Read top-to-bottom (flipped when
  /// drawn the other way), the chevron's horizontal runs ([_horizontalRuns])
  /// must be exactly two — **left then right** — its apex the leftmost point in
  /// the middle, both arms reaching right across the stem. A right-pointing `>`
  /// (right-then-left) is refused.
  _HebrewLetter? _classifyPaleoAleph() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    final _Stroke vertical;
    final _Stroke arm;
    if (_isVertical(a) && _isStraight(a)) {
      vertical = a;
      arm = b;
    } else if (_isVertical(b) && _isStraight(b)) {
      vertical = b;
      arm = a;
    } else {
      return null;
    }
    if (_crossingCount(vertical, arm) != 2) return null;
    // Read the chevron top-to-bottom, so draw direction doesn't matter.
    final points = arm.start.dy <= arm.end.dy
        ? arm.points
        : arm.points.reversed.toList();
    final runs = _horizontalRuns(_Stroke(points));
    if (runs.length != 2 || runs[0] != -1 || runs[1] != 1) return null;
    return _HebrewLetter.aleph;
  }

  /// Whether the drawing is Paleo-Hebrew ayin (ע): a single stroke that crosses
  /// itself exactly once and nothing else — a bare loop, the eye of ayin.
  ///
  /// One stroke, self-crossing once ([_selfCrossingCount]); with only the one
  /// stroke on the page there's nothing else for it to meet. Geometrically this
  /// is the same loop the modern recognizer reads as samekh, but samekh is only
  /// reachable in modern mode, so in paleo mode the loop is unambiguously ayin.
  _HebrewLetter? _classifyPaleoAyin() {
    if (_strokes.length != 1) return null;
    if (_selfCrossingCount(_strokes.single) != 1) return null;
    return _HebrewLetter.ayin;
  }

  /// Whether the drawing is a Paleo-Hebrew dot — the word separator standing in
  /// for a space: a single stroke that's just a point, its bounding box no
  /// bigger than [_dotMaxExtent] on either axis. Taps are turned into
  /// single-point strokes in paleo mode (see [handlePointerEvent]).
  _PaleoSign? _classifyPaleoDot() {
    if (_strokes.length != 1) return null;
    final b = _boundsOf(_strokes.single.points);
    if (b.width > _dotMaxExtent || b.height > _dotMaxExtent) return null;
    return _PaleoSign.dot;
  }

  /// Whether the drawing is a Paleo-Hebrew tally number 1–3: that many straight
  /// vertical strokes, none crossing another, all sharing a common vertical
  /// (y) band — marks stood side by side at the same height.
  ///
  /// One, two, or three strokes, each a straight vertical ([_isVertical],
  /// [_isStraight]); no two cross ([_crossingCount] of zero); and their y-ranges
  /// have a non-empty common overlap (the deepest top above the shallowest
  /// bottom), which is what "same y range" means and keeps a stack of marks at
  /// different heights from counting. The count is the number.
  _PaleoSign? _classifyPaleoNumber() {
    final n = _strokes.length;
    if (n < 1 || n > 3) return null;
    for (final s in _strokes) {
      if (!_isVertical(s) || !_isStraight(s)) return null;
    }
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        if (_crossingCount(_strokes[i], _strokes[j]) != 0) return null;
      }
    }
    // A common y band: the lowest top must sit above the highest bottom.
    var top = double.negativeInfinity;
    var bottom = double.infinity;
    for (final s in _strokes) {
      final b = _boundsOf(s.points);
      top = math.max(top, b.top);
      bottom = math.min(bottom, b.bottom);
    }
    if (top >= bottom) return null;
    return const [_PaleoSign.one, _PaleoSign.two, _PaleoSign.three][n - 1];
  }

  /// Whether the drawing is the Paleo-Hebrew numeral 10 (𐤗): a single flat
  /// horizontal mark that runs out and doubles back — its pen going right then
  /// left along one horizontal band.
  ///
  /// One stroke, never crossing itself ([_selfCrossingCount]), clearly
  /// horizontal (its box over twice as wide as tall — so an aleph-style chevron,
  /// which is taller than wide, is excluded), whose horizontal runs
  /// ([_horizontalRuns]) are exactly two: it heads one way and comes back, the
  /// out-and-back of the numeral.
  _PaleoSign? _classifyPaleoTen() {
    if (_strokes.length != 1) return null;
    final stroke = _strokes.single;
    if (_selfCrossingCount(stroke) != 0) return null;
    final b = _boundsOf(stroke.points);
    if (b.width <= b.height * 2) return null;
    if (_horizontalRuns(stroke).length != 2) return null;
    return _PaleoSign.ten;
  }

  /// Whether the drawing is Paleo-Hebrew shin (ש): a single unbroken `W` — one
  /// stroke that never crosses itself and, read from left to right, drops to a
  /// valley, climbs to a middle peak, drops to a second valley, then climbs to
  /// the end.
  ///
  /// One stroke, self-crossing zero times ([_selfCrossingCount]). Traversed
  /// left-to-right (the points are flipped when drawn right-to-left, so draw
  /// direction doesn't matter — the "split vertically into bands" is spatial),
  /// its dominant vertical runs ([_verticalRuns]) must be exactly four and
  /// alternate **down, up, down, up** — the two troughs of the W. Any other run
  /// count or a leading up-run (an `M`) is refused.
  _HebrewLetter? _classifyPaleoShin() {
    if (_strokes.length != 1) return null;
    final stroke = _strokes.single;
    if (_selfCrossingCount(stroke) != 0) return null;
    // Read the stroke left-to-right, so a W drawn either way splits into the
    // same left-to-right vertical bands.
    final points = stroke.start.dx <= stroke.end.dx
        ? stroke.points
        : stroke.points.reversed.toList();
    final runs = _verticalRuns(_Stroke(points));
    if (runs.length != 4) return null;
    if (runs[0] != 1 || runs[1] != -1 || runs[2] != 1 || runs[3] != -1) {
      return null;
    }
    return _HebrewLetter.shin;
  }

  /// Whether the drawing is Paleo-Hebrew lamed (ל): a single stroke crossing
  /// nothing that, read left-to-right, drops to a valley and climbs back a
  /// little — a checkmark whose upstroke stays low.
  ///
  /// One stroke, self-crossing zero times ([_selfCrossingCount]). Read
  /// left-to-right (flipped when drawn the other way, so draw direction doesn't
  /// matter), its vertical runs ([_verticalRuns]) must be exactly two — **down
  /// then up** — and the up-run stays in the bottom half: its far end (the top
  /// of the climb) sits below the stroke's vertical centre. Mirror of paleo
  /// gimel ([_classifyPaleoGimel]), whose runs go up then down.
  _HebrewLetter? _classifyPaleoLamed() {
    if (_strokes.length != 1) return null;
    final stroke = _strokes.single;
    if (_selfCrossingCount(stroke) != 0) return null;
    final points = stroke.start.dx <= stroke.end.dx
        ? stroke.points
        : stroke.points.reversed.toList();
    final s = _Stroke(points);
    final runs = _verticalRuns(s);
    if (runs.length != 2 || runs[0] != 1 || runs[1] != -1) return null;
    // The up part stays low: the end of the climb is below the vertical centre.
    if (s.end.dy <= _boundsOf(points).center.dy) return null;
    return _HebrewLetter.lamed;
  }

  /// Whether the drawing is Paleo-Hebrew gimel (ג): a single stroke crossing
  /// nothing that climbs to a peak then falls away, **ending to the right** of
  /// where it began — a boomerang whose upstroke stays high.
  ///
  /// One stroke, self-crossing zero times ([_selfCrossingCount]), ending to the
  /// right of its start (`end.dx > start.dx`). In draw order its vertical runs
  /// ([_verticalRuns]) must be exactly two — **up then down** — and the up-run
  /// stays in the top half: its foot sits above the stroke's vertical centre.
  /// The same up-down shape ending to the *left* is paleo pe
  /// ([_classifyPaleoPe]); the direction is the whole difference, so gimel cedes
  /// the leftward one.
  _HebrewLetter? _classifyPaleoGimel() {
    if (_strokes.length != 1) return null;
    final s = _strokes.single;
    if (_selfCrossingCount(s) != 0) return null;
    if (s.end.dx <= s.start.dx) return null; // ends leftward → pe, not gimel
    final runs = _verticalRuns(s);
    if (runs.length != 2 || runs[0] != -1 || runs[1] != 1) return null;
    // The up part stays high: the foot of the climb is above the vertical centre.
    if (s.start.dy >= _boundsOf(s.points).center.dy) return null;
    return _HebrewLetter.gimel;
  }

  /// Whether the drawing is Paleo-Hebrew pe (פ): a single stroke crossing
  /// nothing that climbs to a peak then falls away, **ending to the left** of
  /// where it began.
  ///
  /// One stroke, self-crossing zero times ([_selfCrossingCount]), ending to the
  /// left of its start (`end.dx < start.dx`), its vertical runs ([_verticalRuns])
  /// exactly two — **up then down**. It's the leftward-ending twin of paleo
  /// gimel ([_classifyPaleoGimel]); the endpoint's side of the start is the
  /// whole difference between them.
  _HebrewLetter? _classifyPaleoPe() {
    if (_strokes.length != 1) return null;
    final s = _strokes.single;
    if (_selfCrossingCount(s) != 0) return null;
    if (s.end.dx >= s.start.dx) return null; // endpoint left of start
    final runs = _verticalRuns(s);
    if (runs.length != 2 || runs[0] != -1 || runs[1] != 1) return null;
    return _HebrewLetter.pe;
  }

  /// The sequence of dominant vertical directions [s] passes through, in
  /// traversal order: +1 for a downward run (screen-y rising), -1 for an upward
  /// one. Consecutive moves the same way collapse into a single run, and a
  /// reversal shorter than [_zigzagTurnSlack] is ignored as jitter rather than
  /// starting a new run — so a clean `W` yields `[1, -1, 1, -1]`.
  List<int> _verticalRuns(_Stroke s) {
    final points = s.points;
    final runs = <int>[];
    var dir = 0; // 0 = not moving yet, 1 = down, -1 = up
    var pivotY = points.first.dy; // the extreme reached in the current run
    for (var i = 1; i < points.length; i++) {
      final y = points[i].dy;
      if (dir == 0) {
        if (y - pivotY > _zigzagTurnSlack) {
          dir = 1;
          runs.add(1);
          pivotY = y;
        } else if (pivotY - y > _zigzagTurnSlack) {
          dir = -1;
          runs.add(-1);
          pivotY = y;
        }
      } else if (dir == 1) {
        if (y > pivotY) {
          pivotY = y; // still descending — a new low
        } else if (pivotY - y > _zigzagTurnSlack) {
          dir = -1;
          runs.add(-1);
          pivotY = y; // turned up past the slack
        }
      } else {
        if (y < pivotY) {
          pivotY = y; // still climbing — a new high
        } else if (y - pivotY > _zigzagTurnSlack) {
          dir = 1;
          runs.add(1);
          pivotY = y; // turned down past the slack
        }
      }
    }
    return runs;
  }

  /// The horizontal mirror of [_verticalRuns]: the sequence of dominant
  /// horizontal directions [s] passes through, in traversal order — +1 for a
  /// rightward run (x rising), -1 for a leftward one, reversals below
  /// [_zigzagTurnSlack] ignored as jitter. A left-pointing chevron `<` read
  /// top-to-bottom yields `[-1, 1]`.
  List<int> _horizontalRuns(_Stroke s) {
    final points = s.points;
    final runs = <int>[];
    var dir = 0; // 0 = not moving yet, 1 = right, -1 = left
    var pivotX = points.first.dx; // the extreme reached in the current run
    for (var i = 1; i < points.length; i++) {
      final x = points[i].dx;
      if (dir == 0) {
        if (x - pivotX > _zigzagTurnSlack) {
          dir = 1;
          runs.add(1);
          pivotX = x;
        } else if (pivotX - x > _zigzagTurnSlack) {
          dir = -1;
          runs.add(-1);
          pivotX = x;
        }
      } else if (dir == 1) {
        if (x > pivotX) {
          pivotX = x; // still going right — a new rightmost
        } else if (pivotX - x > _zigzagTurnSlack) {
          dir = -1;
          runs.add(-1);
          pivotX = x; // turned left past the slack
        }
      } else {
        if (x < pivotX) {
          pivotX = x; // still going left — a new leftmost
        } else if (x - pivotX > _zigzagTurnSlack) {
          dir = 1;
          runs.add(1);
          pivotX = x; // turned right past the slack
        }
      }
    }
    return runs;
  }

  /// Whether strokes [a] and [b] form a `+`: one a straight vertical, the other
  /// a straight horizontal ([_isVertical] / [_isHorizontal], both
  /// [_isStraight]), crossing each other exactly once ([_crossingCount]).
  /// Orientation-sorted, so which stroke is which doesn't matter. The shared
  /// spine of paleo taw and paleo tet.
  bool _isCrossOf(_Stroke a, _Stroke b) {
    final _Stroke vertical;
    final _Stroke horizontal;
    if (_isVertical(a) && _isStraight(a) && _isHorizontal(b) && _isStraight(b)) {
      vertical = a;
      horizontal = b;
    } else if (_isVertical(b) &&
        _isStraight(b) &&
        _isHorizontal(a) &&
        _isStraight(a)) {
      vertical = b;
      horizontal = a;
    } else {
      return false;
    }
    return _crossingCount(vertical, horizontal) == 1;
  }

  /// How many times [s] crosses itself: the count of non-adjacent segment
  /// pairs within the one stroke that properly cross ([_segmentsCross]).
  /// Segments that meet end-to-end along the stroke are skipped (they share a
  /// point, not a crossing); a closed loop drawn in one stroke meets itself
  /// once where its tail laps back over its head.
  int _selfCrossingCount(_Stroke s) {
    final points = s.points;
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

  /// How many times strokes [a] and [b] cross transversally: the count of
  /// segment pairs (one from each stroke) that properly cross
  /// ([_segmentsCross]). A single straight line run through one leg of a
  /// corner meets it once, so this is one; a line resting alongside or short
  /// of the corner meets it zero times.
  int _crossingCount(_Stroke a, _Stroke b) {
    var count = 0;
    for (var i = 1; i < a.points.length; i++) {
      for (var j = 1; j < b.points.length; j++) {
        if (_segmentsCross(
            a.points[i - 1], a.points[i], b.points[j - 1], b.points[j])) {
          count++;
        }
      }
    }
    return count;
  }

  /// Whether segments [a1]–[a2] and [b1]–[b2] cross transversally: each
  /// segment's endpoints straddle the other's line, tested by the sign of the
  /// four orientation cross-products. Strict signs mean a mere touch — an
  /// endpoint grazing the other segment, or the two running collinear —
  /// doesn't count.
  bool _segmentsCross(Offset a1, Offset a2, Offset b1, Offset b2) {
    double orientation(Offset p, Offset q, Offset r) =>
        (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
    final d1 = orientation(b1, b2, a1);
    final d2 = orientation(b1, b2, a2);
    final d3 = orientation(a1, a2, b1);
    final d4 = orientation(a1, a2, b2);
    return (d1 > 0) != (d2 > 0) && (d3 > 0) != (d4 > 0);
  }

  /// The point where strokes [a] and [b] first cross ([_segmentsCross]), or
  /// null if they don't — the intersection of the first crossing segment pair,
  /// found by solving the two segments' parametric lines.
  Offset? _crossingPoint(_Stroke a, _Stroke b) {
    for (var i = 1; i < a.points.length; i++) {
      final a1 = a.points[i - 1];
      final a2 = a.points[i];
      for (var j = 1; j < b.points.length; j++) {
        final b1 = b.points[j - 1];
        final b2 = b.points[j];
        if (!_segmentsCross(a1, a2, b1, b2)) continue;
        final r = a2 - a1;
        final s = b2 - b1;
        final denom = r.dx * s.dy - r.dy * s.dx;
        if (denom == 0) continue;
        final t = ((b1.dx - a1.dx) * s.dy - (b1.dy - a1.dy) * s.dx) / denom;
        return a1 + r * t;
      }
    }
    return null;
  }

  /// Whether [stroke] is the single-stroke right-angle corner shared by both
  /// letters — the same shape as Hangul's ㄱ. It's drawn top-left to
  /// bottom-right, so its start→end chord runs down and to the right (a
  /// descending diagonal); the bend throws the body of the stroke above that
  /// chord (the elbow high at the top-right) when [bodyAboveChord] is true.
  ///
  /// The test is: the chord genuinely descends on both axes
  /// ([_minCornerChord]); the whole stroke isn't straight (a line has no
  /// elbow); the deepest-off-chord point — the elbow — falls in the stroke's
  /// middle with a straight leg either side of it, which tells a right-angle
  /// corner from a smooth arc; and the body's average offset from the chord
  /// clears [_minCornerBulge] on the requested side.
  bool _isCorner(_Stroke stroke, {required bool bodyAboveChord}) {
    final points = stroke.points;
    if (points.length < 5) return false;
    final chord = stroke.end - stroke.start;
    if (chord.dx < _minCornerChord || chord.dy < _minCornerChord) return false;
    if (_isStraight(stroke)) return false;

    final length = chord.distance;
    // Signed offset of a point from the start→end chord, via the 2D cross
    // product. Screen y runs downward, so a point above the chord (smaller y)
    // comes out positive — hence the giyeok corner's high elbow is positive.
    double sideOf(Offset point) {
      final offset = point - stroke.start;
      return offset.dx * chord.dy - offset.dy * chord.dx;
    }

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

  /// [s] reflected across a vertical axis (x negated), so a shape drawn toward
  /// the left reads as its rightward mirror.
  _Stroke _mirrorX(_Stroke s) =>
      _Stroke([for (final p in s.points) Offset(-p.dx, p.dy)]);

  /// Whether [stroke] is a nieun corner (ㄴ) drawn mirrored — its foot kicking
  /// **left** instead of right (its chord descending to the left, which plain
  /// [_isCorner] rejects). Detected by reflecting x ([_mirrorX]) and reusing the
  /// nieun test — tav's left leg.
  bool _isMirroredNieun(_Stroke stroke) =>
      _isCorner(_mirrorX(stroke), bodyAboveChord: false);

  /// The index of [s]'s rightmost point (largest x), the first if several tie.
  int _rightmostIndex(_Stroke s) {
    var idx = 0;
    for (var i = 1; i < s.points.length; i++) {
      if (s.points[i].dx > s.points[idx].dx) idx = i;
    }
    return idx;
  }

  /// Whether [s] heads out to the right and doubles back to the left — its
  /// rightmost point falling in its middle, so x rises to it then falls, with
  /// a run either side. The stroke isn't a straight line (which turns at no
  /// point) and spans enough width ([_minCornerChord]) to be a real out-and-
  /// back rather than a wiggle: tsadi's body, whose rightward-going part the
  /// arm crosses.
  bool _goesRightThenLeft(_Stroke s) {
    if (s.points.length < 5) return false;
    if (_isStraight(s)) return false;
    if (_boundsOf(s.points).width < _minCornerChord) return false;
    final idx = _rightmostIndex(s);
    return idx >= 2 && idx <= s.points.length - 3;
  }

  /// Whether [b] crosses [a] on one of [a]'s segments whose index lies within
  /// [[lo], [hi]] (a's segment `i` running from point `i-1` to point `i`) —
  /// used to pin a crossing to a chosen span of [a] rather than anywhere along
  /// it (see [_segmentsCross]).
  bool _crossesWithin(_Stroke a, _Stroke b, int lo, int hi) {
    for (var i = math.max(1, lo); i < a.points.length && i <= hi; i++) {
      for (var j = 1; j < b.points.length; j++) {
        if (_segmentsCross(
            a.points[i - 1], a.points[i], b.points[j - 1], b.points[j])) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether [s] runs top-to-bottom steeply enough to read as a vertical
  /// rather than a diagonal — see [_verticalRatio].
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

  /// Whether [s] is a straight line running slanted enough to be a diagonal —
  /// neither steep enough for [_isVertical] nor flat enough for
  /// [_isHorizontal] — the stroke final tsadi's arm is made of.
  bool _isDiagonal(_Stroke s) =>
      _isStraight(s) && !_isVertical(s) && !_isHorizontal(s);

  /// Whether the diagonal [s] rises to the right (`/`) rather than falling
  /// (`\`). Screen y runs downward, so a rising line's run and drop have
  /// opposite signs; the test is direction-agnostic since flipping both ends
  /// leaves the product's sign unchanged.
  bool _isAscending(_Stroke s) =>
      (s.end.dx - s.start.dx) * (s.end.dy - s.start.dy) < 0;

  /// Whether the diagonal [s] falls to the right (`\`) drawn with a looser hand
  /// than [_isDiagonal] demands: its chord slants (neither vertical nor
  /// horizontal) and descends, and it holds to that chord within the wider
  /// [_looseStraightTolerance] — so a gently bowed or hooked descender counts,
  /// but a hard flat-top-then-down corner still doesn't. ג's body.
  bool _isLooseDescender(_Stroke s) =>
      !_isVertical(s) &&
      !_isHorizontal(s) &&
      !_isAscending(s) &&
      _isStraight(s, tolerance: _looseStraightTolerance);

  /// Whether every point of [s] stays within [tolerance] (default
  /// [_straightTolerance]) of the straight chord from its start to its end —
  /// i.e. the stroke is a line and not a curve, hook, or the bent corner.
  bool _isStraight(_Stroke s, {double tolerance = _straightTolerance}) {
    final chord = s.end - s.start;
    final length = chord.distance;
    if (length == 0) return false;
    final slack = math.max(_minStraightSlack, length * tolerance);
    for (final point in s.points) {
      final offset = point - s.start;
      final distance =
          (offset.dx * chord.dy - offset.dy * chord.dx).abs() / length;
      if (distance > slack) return false;
    }
    return true;
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

  /// The recognized-letter caption. Nothing recognized shows the prompt; a
  /// shape shared by several letters ([sharedGroups]) lists the whole group,
  /// since those aren't told apart when a letter stands alone; anything else
  /// shows its single glyph, name, and sound.
  TextSpan _labelSpan() {
    final recognized = _recognized;
    if (recognized == null) {
      return const TextSpan(
        text: 'Draw a letter below to see it recognized',
        style: TextStyle(color: Colors.black54, fontSize: 16),
      );
    }
    for (final group in sharedGroups) {
      if (group.base == recognized.glyph) {
        return TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          children: [
            const TextSpan(text: 'Recognized: '),
            TextSpan(
              text: group.glyphs.map((g) => glyphIn(g, script)).join(' '),
              style: const TextStyle(fontSize: 22),
            ),
            TextSpan(text: '  (alone — ${group.names})'),
          ],
        );
      }
    }
    return TextSpan(
      style: const TextStyle(color: Colors.black87, fontSize: 16),
      children: [
        const TextSpan(text: 'Recognized: '),
        TextSpan(
            text: glyphIn(recognized.glyph, script),
            style: const TextStyle(fontSize: 22)),
        TextSpan(text: '  (${recognized.name} — "${recognized.sound}")'),
      ],
    );
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

    final label = TextPainter(
      text: _labelSpan(),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

/// Builds the scene plus a direct reference to its [HebrewLayer], so the
/// hosting page can call [HebrewLayer.clear] from the Clear button.
(Scene, HebrewLayer) buildHebrewScene() {
  final layer = HebrewLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
