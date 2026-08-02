import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../data/glyphs.dart';
import '../data/script.dart';
import '../engine/scene.dart';
import 'glyph_images.dart';

/// Cream, dot-grid paper background (Moleskine-style notebook page).
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

class Stroke {
  Stroke(this.points);
  final List<Offset> points;
  Offset get start => points.first;
  Offset get end => points.last;
}

/// One character a recognizer can come to, in whichever script it is
/// reading — [MakasarCharacter] or [LontaraCharacter].
abstract interface class ScriptCharacter {
  /// The Unicode character. Only Makasar's have a font in the bundle, so
  /// see [MakasarInk.glyphsOf] before drawing one.
  String get glyph;

  /// The character's name, which for a letter is also its transliteration.
  String get letterName;

  /// The sound it carries, or null for punctuation, which hasn't one.
  String? get sound;
}

/// The Makasar letters [MakasarLayer] recognizes so far. Each is a row of
/// wedges (`Λ`, see [MakasarLayer._isWedge]) with a mark written underneath
/// — the script's own way of building letters, see [MakasarLetter] in
/// `lib/data/makasar_letters.dart` for how the remaining letters
/// decompose.
enum MakasarCharacter implements ScriptCharacter {
  /// A single wedge, nothing under it.
  na('\u{11EE8}', 'na', 'n'),

  /// A double wedge (`ΛΛ`, one stroke) + a wedge under it.
  ga('\u{11EE1}', 'ga', 'ɡ'),

  /// A double wedge + a mark that closes on itself under it — a loop, or
  /// the wedge shut with a bar the letterform draws.
  ma('\u{11EE5}', 'ma', 'm'),

  /// Two wedges + a chevron (`V`) under them.
  ba('\u{11EE4}', 'ba', 'b'),

  /// A double wedge that crosses itself once, in one stroke.
  ja('\u{11EEA}', 'ja', 'dʒ'),

  /// A triple wedge that crosses itself twice, in one stroke.
  nya('\u{11EEB}', 'nya', 'ɲ'),

  /// One wedge whose arm curls back up, crossing itself once.
  ta('\u{11EE6}', 'ta', 't'),

  /// One wedge + one down-then-up stroke hanging under it.
  nga('\u{11EE2}', 'nga', 'ŋ'),

  /// A right-then-left sweep + a line under it.
  ka('\u{11EE0}', 'ka', 'k'),

  /// A double wedge whose second descent stays high. Also transliterated
  /// fa.
  pa('\u{11EE3}', 'pa', 'p'),

  /// Two wedges riding above a bottom third that joins them.
  da('\u{11EE7}', 'da', 'd'),

  /// A wedge with a loop crossing back over each of its arms.
  ca('\u{11EE9}', 'ca', 'tʃ'),

  /// A wedge that hooks back up, its first arm twice the height of the
  /// rest. Not a letter but a repeater, so it carries no sound of its own
  /// — see [sound].
  angka('\u{11EF2}', 'angka', null),

  /// 𑻲's stroke + a chevron under it.
  ra('\u{11EED}', 'ra', 'r'),

  /// One stroke doubling back twice sideways, starting along the bottom.
  la('\u{11EEE}', 'la', 'l'),

  /// 𑻠's stroke with a second peak on the way back + the same line under
  /// it.
  ya('\u{11EEC}', 'ya', 'j'),

  /// 𑻮's hook drawn a second time, mirrored, about the base between them,
  /// without the pen leaving the paper.
  wa('\u{11EEF}', 'wa', 'w'),

  /// One stroke sweeping sideways five times over. Also read ha.
  a('\u{11EF1}', 'a', 'ʔ'),

  /// One stroke going left, right, then away down to the left.
  sa('\u{11EF0}', 'sa', 's'),

  /// Three taps in a row. Punctuation, so no sound either.
  passimbang('\u{11EF7}', 'passimbang', null),

  /// Six taps drawn together, zigzagging about a centre line rather than
  /// stacked the way 𑻷's three are.
  endOfSection('\u{11EF8}', 'end of section', null);

  const MakasarCharacter(this.glyph, this.letterName, this.sound);

  @override
  final String glyph;
  @override
  final String letterName;
  @override
  final String? sound;
}

/// The Lontara letters recognized so far. Lontara doesn't build its letters
/// the way Makasar does — these are single elements, or a pair of the same
/// element written one against the other, rather than a row of wedges with
/// a mark hung underneath — so they get classifiers of their own rather
/// than sharing Makasar's.
enum LontaraCharacter implements ScriptCharacter {
  /// ᨀ — two ascending lines side by side, their x ranges overlapping.
  ka('\u{1A00}', 'ka', 'k'),

  /// ᨁ — ᨄ's stroke with a dot under the up-down it opens with.
  ga('\u{1A01}', 'ga', 'ɡ'),

  /// ᨆ — a chevron (`V`): one stroke down then up.
  ma('\u{1A06}', 'ma', 'm'),

  /// ᨅ — ᨂ with a stroke that turns left then right in place of the
  /// descending line.
  ba('\u{1A05}', 'ba', 'b'),

  /// ᨇ — the same turned the other way about, right then left.
  mpa('\u{1A07}', 'mpa', 'mp'),

  /// ᨋ — ᨄ's stroke with a wedge under the up-down it opens with.
  nra('\u{1A0B}', 'nra', 'nr'),

  /// ᨌ — a wedge with a stroke turning right then left laid across it.
  ca('\u{1A0C}', 'ca', 'tʃ'),

  /// ᨂ — a descending line crossed once, from below and to its left, by an
  /// ascending one.
  nga('\u{1A02}', 'nga', 'ŋ'),

  /// ᨃ — ᨈ's wedge with a descending line cut once across its climb.
  ngka('\u{1A03}', 'ngka', 'ŋk'),

  /// ᨄ — one stroke up, down and up again, its tail turning right then
  /// left.
  pa('\u{1A04}', 'pa', 'p'),

  /// ᨈ — a wedge (`Λ`): ᨆ the other way up, one stroke up then down.
  ta('\u{1A08}', 'ta', 't'),

  /// ᨉ — ᨆ's chevron with a dot set inside it.
  da('\u{1A09}', 'da', 'd'),

  /// ᨊ — ᨈ's wedge with a dot set inside it.
  na('\u{1A0A}', 'na', 'n'),

  /// ᨍ — one stroke out to the right and back left, the right half a plain
  /// wedge.
  ja('\u{1A0D}', 'ja', 'dʒ'),

  /// ᨎ — a double wedge with a chevron hung under it.
  nya('\u{1A0E}', 'nya', 'ɲ'),

  /// ᨏ — two wedges written across each other, their arms crossing.
  nca('\u{1A0F}', 'nca', 'ɲtʃ'),

  /// ᨑ — two wedges, one above the other, their x ranges overlapping.
  ra('\u{1A11}', 'ra', 'r'),

  /// ᨐ — ᨓ's double wedge with a dot tucked under each of its wedges.
  ya('\u{1A10}', 'ya', 'j'),

  /// ᨕ — the same, dotted under the second wedge only.
  a('\u{1A15}', 'a', 'a'),

  /// ᨒ — one stroke up, down and up again, with a wedge over the climb it
  /// finishes on.
  la('\u{1A12}', 'la', 'l'),

  /// ᨓ — a double wedge (`ΛΛ`): one stroke up, down, up, down.
  wa('\u{1A13}', 'wa', 'w'),

  /// ᨔ — one stroke closing on itself.
  sa('\u{1A14}', 'sa', 's'),

  /// ᨖ — one stroke out to the right and back left, each half up, down and
  /// up again.
  ha('\u{1A16}', 'ha', 'h'),

  /// ᨞ — three taps on a descending line. Punctuation, so no sound.
  pallawa('\u{1A1E}', 'pallawa', null),

  /// ᨟ — four strokes: two crossings written one over the other.
  endOfSection('\u{1A1F}', 'end of section', null);

  const LontaraCharacter(this.glyph, this.letterName, this.sound);

  @override
  final String glyph;
  @override
  final String letterName;
  @override
  final String? sound;
}

/// The vowel signs [MakasarLayer] recognizes. Each replaces the inherent
/// `a` of the letter it's attached to, and each is positioned relative to
/// that letter rather than drawn as a shape of its own — a tap above or
/// below it, or a stroke in front of, behind or over it (see
/// [MakasarLayer._classifyDotVowel] / [MakasarLayer._classifyStrokeVowel]).
///
/// One enum serves both scripts: the first four are the same mark in the
/// same place in Makasar and Lontara alike. [ae] is Lontara's own fifth
/// sign, and is only matched when reading Lontara — hence [lontaraOnly].
enum VowelMark {
  /// A tap above the letter.
  i('\u{11EF3}', 'i'),

  /// A tap below it.
  u('\u{11EF4}', 'u'),

  /// A stroke in front of it (to its left) that doubles back: left, then
  /// right.
  e('\u{11EF5}', 'e'),

  /// A stroke behind it (to its right) that ticks up and then falls, the
  /// rise much the shorter of the two.
  o('\u{11EF6}', 'o'),

  /// A stroke over it that doubles back: right, then left. Lontara only —
  /// Makasar has no such sign.
  ae('\u{1A1B}', 'ae', lontaraOnly: true);

  const VowelMark(this.glyph, this.vowel, {this.lontaraOnly = false});

  final String glyph;
  final String vowel;

  /// Whether this sign belongs to Lontara alone, so Makasar never matches
  /// it — see [MakasarRecognizer.recognizedVowelsFor].
  final bool lontaraOnly;
}

/// Freehand recognition of Makasar letters.
///
/// The script is built out of a handful of geometric elements, so
/// recognition is too: a letter is one to three **wedges** (`Λ`, an
/// upside-down V — [_isWedge]), written without lifting the pen, plus
/// whatever mark is written under them. What's underneath — or whether
/// the wedges themselves cross — is what separates letters sharing a
/// wedge count:
///
/// - 𑻨 (na) — one wedge, nothing under it.
/// - 𑻢 (nga) — one wedge + a **chevron** (`V`, a wedge upside down —
///   [_isChevronShaped]) hanging under it.
/// - 𑻦 (ta) — 𑻢 written without lifting the pen: one wedge whose arm
///   hooks back up ([_hookedWedgeSequence]), crossing itself once.
/// - 𑻡 (ga) — a **double wedge** (`ΛΛ` in one stroke, [_isDoubleWedge]) +
///   a wedge underneath.
/// - 𑻤 (ba) — the same double wedge + a chevron underneath.
/// - 𑻥 (ma) — the same double wedge + a **closed** mark underneath: a
///   stroke that crosses its own path ([_selfIntersections]), which is
///   what shutting a wedge with a bar in one stroke produces.
/// - 𑻪 (ja) — a double wedge on its own, drawn so the stroke crosses its
///   own path once.
/// - 𑻠 (ka) — a stroke that sweeps out to the right and back left, its
///   rightward half rising-falling-rising ([_isKaShaped]), + a line
///   underneath ([_isPlainLine]).
/// - 𑻣 (pa) — a double wedge on its own whose last descent stops in the
///   top half of its own bounding box ([_classifyPa]).
/// - 𑻧 (da) — one stroke standing on a base that runs along the bottom
///   third of its own bounding box ([_piecesAboveBase]), working its way
///   sideways left, right, left, right as it goes ([_classifyDa]).
/// - 𑻲 (angka, the repeater) — a wedge that hooks back up, its opening
///   rise at least twice the height of the rest ([_isAngkaShaped]).
/// - 𑻭 (ra) — that same stroke + a chevron underneath, the way 𑻢 pairs a
///   wedge with one.
/// - 𑻮 (la), 𑻯 (wa), 𑻰 (sa) and 𑻱 (a) — read off *horizontal* direction
///   instead of vertical: 𑻮 goes right, back left and right again,
///   with one end of it along its own base ([_classifyLa]); 𑻯 is that
///   hook drawn twice, the second mirrored, about the base between them —
///   right, left, right, left, right, the middle run being the base
///   ([_classifyWa]); 𑻰 goes left, right, then away down to the
///   left ([_classifySa]); 𑻱 sweeps sideways five times over, starting
///   leftward, which is 𑻯 mirrored ([_classifyA]).
/// - 𑻫 (nya) — a **triple wedge** on its own, crossing itself twice.
/// - 𑻬 (ya) — 𑻠's stroke with one more wedge in it: the same sweep out
///   and back under the same line, but coming back over two peaks rather
///   than one ([_isYaShaped]).
///
/// Every element is read off a single stroke's vertical direction:
/// [_splitByVerticalDirectionChange] cuts the stroke where it reverses
/// (ignoring reversals smaller than [_directionNoise], so hand jitter
/// along an arm doesn't split it), and a wedge is exactly two segments, up
/// then down — a double wedge four, a triple wedge six. Which of a
/// letter's two strokes is the wedges and which is the mark underneath is
/// decided by shape and position, not draw order (see
/// [_wedgesWithMark] / [_isUnder]), so a letter can be drawn in
/// either order.
///
/// Taps are their own family, drawn as hollow circles, and a mark is how
/// many of them belong together:
///
/// - 𑻷 (passimbang, the phrase separator) — three stacked, grouped by
///   which taps overlap in x ([_dotColumns], [_classifyDotColumn]).
/// - 𑻸 (end of section) — six, which the letterform sets zigzagging to
///   either side of a centre line rather than stacking, so they are
///   grouped by having been drawn together instead: near enough to each
///   other, with nothing written in among them ([_dotRuns],
///   [_classifyDotRun]).
///
/// The four vowel signs are read differently again: rather than being
/// shapes in their own right, they are marks placed against a letter
/// that's already been recognized, so they're matched before anything
/// else and leave that letter standing (see [_classifyDotVowel] /
/// [_classifyStrokeVowel]). A tap above it is `-i` and below it `-u`; a
/// stroke doubling back left-then-right in front of it is `-e`, and one
/// behind it that ticks up before falling away is `-o`.
///
/// Recognition is live — it re-evaluates the most recently completed
/// strokes or taps, so drawing keeps updating the readout. Nothing is
/// discarded; marks that don't match are still rendered, just reported as
/// unrecognized.
///
/// All of the above is Makasar. Set to [WritingScript.bugis] a recognizer
/// still collects and draws marks, but claims nothing — no Lontara letter
/// has a classifier yet, and the wedge-and-mark reading here doesn't
/// transfer to letterforms built another way. See [recognizedNamesFor].
///
/// This holds no drawing state of its own beyond the marks it has been
/// given ([addMark]), so one recognizer reads one character: [MakasarLayer]
/// keeps a single one for the whole canvas, while `WritingLayer` keeps one
/// per character in a written row.
class MakasarRecognizer {
  /// A mark whose bounding box is smaller than this in both directions is
  /// a tap, not a stroke; one at least [_minStrokeExtent] across is a
  /// stroke. Both are measured on the mark's own extent rather than on how
  /// far its end landed from its start, since a closed mark (𑻥's, see
  /// [_classifyMa]) deliberately finishes back where it began.
  static const double _maxDotExtent = 5;
  static const double _minStrokeExtent = 8;

  static const double _dotRadius = 15;

  /// How far a stroke has to double back vertically before it counts as a
  /// real change of direction rather than hand jitter (see
  /// [_splitByVerticalDirectionChange]). Without it, every wobble along a
  /// wedge's arm would split it into another segment and no wedge would
  /// ever read as exactly two.
  static const double _directionNoise = 6;

  /// The shortest an arm of a wedge/chevron/bowl can be. Only the
  /// *reversal* is noise-gated above, so without this a stray flick at the
  /// end of an otherwise straight line would still read as a second arm.
  static const double _minArmExtent = 12;

  /// How far a stroke may stray from the run between its own two ends and
  /// still be a line, as a fraction of the distance between them — see
  /// [_isPlainLine].
  static const double _maxLineWaver = 0.15;

  /// How wide a wedge has to be relative to its height — a stroke that
  /// goes up and back down in almost the same place is a hairpin, not a
  /// wedge.
  static const double _minWedgeAspect = 0.5;

  /// How far 𑻧's base has to run, as a fraction of the letter's own
  /// width, for the stroke to read as two wedges standing on a base
  /// rather than two peaks with a dip between them (see [_classifyDa]).
  static const double _minBaseWidth = 1 / 3;

  /// The vertical-direction segments (`true` = down) each element of a
  /// letterform splits into — see [_verticalDirectionSequence]. A wedge
  /// `Λ` goes up then down; a chevron `V` or bowl `U` does the reverse; a
  /// double wedge `ΛΛ` is two wedges without lifting the pen.
  static const _wedgeSequence = [false, true];

  /// A wedge whose descending arm turns back up — 𑻦's bowl, drawn without
  /// lifting the pen, so the stroke crosses itself on the way back up.
  static const _hookedWedgeSequence = [false, true, false];
  static const _doubleWedgeSequence = [false, true, false, true];
  static const _tripleWedgeSequence = [false, true, false, true, false, true];
  static const _chevronSequence = [true, false];

  /// The horizontal-direction segments (`true` = rightward) 𑻵's mark
  /// splits into: back to the left, then forward to the right (see
  /// [_horizontalDirectionSequence]).
  static const _leftThenRightSequence = [false, true];

  /// 𑻮's own horizontal split: out to the right, back left, out right
  /// again.
  static const _rightLeftRightSequence = [true, false, true];

  /// 𑻠's, across its wedges stroke: out to the right, then back left.
  static const _rightThenLeftSequence = [true, false];

  /// 𑻰's: left, right, then away again to the left.
  static const _leftRightLeftSequence = [false, true, false];

  /// 𑻧's, taken across the whole stroke: each of its two pieces doubles
  /// back from left to right, and the base carries the pen from the first
  /// to the second.
  static const _leftRightLeftRightSequence = [false, true, false, true];

  /// 𑻱's: five sideways sweeps, starting leftward.
  static const _leftRightLeftRightLeftSequence = [
    false,
    true,
    false,
    true,
    false,
  ];

  /// 𑻯's: 𑻮's right-left-right with the doubling back done a second
  /// time — the same five sweeps as 𑻱, mirrored, starting rightward.
  static const _rightLeftRightLeftRightSequence = [
    true,
    false,
    true,
    false,
    true,
  ];

  /// How far apart in x two of 𑻸's taps may be drawn and still be the
  /// same mark — see [_dotRuns].
  static const double _maxDotSpacing = _dotRadius * 4;

  /// How far apart 𑻥's mark may leave its two ends and still count as
  /// closed, as a fraction of its own longest side — see [_isClosedMark].
  static const double _maxClosingGap = 0.35;

  /// How far round a mark that doesn't cross itself has to turn before it
  /// can be read as a loop rather than as two arms drawn side by side — a
  /// good half-turn more than 𑻤's chevron, which changes direction once
  /// and so turns half a circle exactly.
  static const double _minLoopTurn = 1.2 * math.pi;

  /// How much shorter 𑻶's rising arm has to be than its falling one — a
  /// short tick up before the long stroke down, rather than the balanced
  /// two arms of a wedge (see [_classifyStrokeVowel]).
  static const double _maxVowelRiseRatio = 0.5;

  /// Which Makasar letters have a classifier, by
  /// [MakasarCharacter.letterName] — used via [recognizedNamesFor] to show
  /// at a glance which of the script's 18 letters can actually be drawn
  /// yet.
  static final recognizedNames = {
    for (final letter in MakasarCharacter.values) letter.letterName,
  };

  /// The same for Lontara, by [LontaraCharacter.letterName].
  static final recognizedLontaraNames = {
    for (final letter in LontaraCharacter.values) letter.letterName,
  };

  /// Which of [script]'s characters have a classifier — used by
  /// [MakasarPage] to show at a glance which of them can be drawn yet, and
  /// what a recognizer set to that script will match.
  static Set<String> recognizedNamesFor(WritingScript script) =>
      switch (script) {
        WritingScript.makasar => recognizedNames,
        WritingScript.bugis => recognizedLontaraNames,
      };

  /// The vowel signs [script] has a classifier for, by [VowelMark.vowel].
  /// The first four are the same mark in the same place in both scripts, so
  /// [_classifyDotVowel] and [_classifyStrokeVowel] serve either; `-ae` is
  /// Lontara's alone ([VowelMark.lontaraOnly]).
  static Set<String> recognizedVowelsFor(WritingScript script) => {
        for (final vowel in VowelMark.values)
          if (script == WritingScript.bugis || !vowel.lontaraOnly) vowel.vowel,
      };

  MakasarRecognizer({WritingScript script = WritingScript.makasar})
      : _script = script;

  WritingScript _script;

  /// Which script's characters this reads — see [recognizedNamesFor].
  WritingScript get script => _script;

  /// Switching scripts wipes the canvas: a reading taken as one script has
  /// no business surviving into the other.
  set script(WritingScript script) {
    if (script == _script) return;
    _script = script;
    clear();
  }

  final List<Stroke> _strokes = [];
  final List<Offset> _dots = [];
  ScriptCharacter? _recognized;
  VowelMark? _vowel;

  /// The strokes and taps given to this recognizer so far, for whoever is
  /// drawing them.
  List<Stroke> get strokes => _strokes;
  List<Offset> get dots => _dots;

  /// The character the marks read as, and the vowel sign on it — the
  /// glyphs a readout shows.
  ScriptCharacter? get character => _recognized;
  VowelMark? get vowel => _vowel;

  /// Everything drawn at the moment [_recognized] was last matched — what
  /// a vowel sign is positioned against ([_classifyDotVowel] /
  /// [_classifyStrokeVowel]). Since the canvas holds one letter at a time
  /// (the Clear button wipes it), this is simply the letter's own extent.
  Rect? _recognizedBounds;

  /// The name of the letter the most recent strokes matched, or null if
  /// they didn't match one — the readout [paint] draws, exposed so it can
  /// be asserted on in tests.
  String? get recognizedName => _recognized?.letterName;

  /// The vowel sign attached to it, if one has been drawn.
  String? get recognizedVowel => _vowel?.vowel;

  /// How the recognized character reads: a letter's own name with its
  /// inherent `a` swapped for whatever vowel sign was added (`ka` + `-i`
  /// = `ki`), or just the name when there's no vowel sign — or when the
  /// character isn't a letter at all and so has no inherent vowel to
  /// replace.
  String? get recognizedSyllable {
    final letter = _recognized;
    if (letter == null) return null;
    final vowel = _vowel;
    if (vowel == null || letter.sound == null) return letter.letterName;
    return letter.letterName.substring(0, letter.letterName.length - 1) +
        vowel.vowel;
  }

  void clear() {
    _strokes.clear();
    _dots.clear();
    _recognized = null;
    _vowel = null;
    _recognizedBounds = null;
  }

  /// Files one finished mark — the points of a single press-to-release —
  /// as either a tap or a stroke, and re-reads what's on the canvas.
  /// Anything in between the two (a wobble too big for a tap, too small
  /// for a stroke) is dropped.
  void addMark(List<Offset> points) {
    if (points.isEmpty) return;
    final extent = _boundsOf(points).longestSide;
    if (extent < _maxDotExtent) {
      // A tap: either a vowel sign on the letter already drawn, or one
      // more dot of a punctuation mark.
      _dots.add(points.first);
      final vowel = _classifyDotVowel(points.first);
      if (vowel != null) {
        _vowel = vowel;
      } else {
        _setRecognized(_firstMatch(_dotClassifiers));
      }
    } else if (points.length >= 2 && extent >= _minStrokeExtent) {
      _commit(Stroke(points));
    }
  }

  void _commit(Stroke stroke) {
    _strokes.add(stroke);

    // A stroke placed in front of or behind an already-recognized letter
    // is a vowel sign on it, not a letter of its own.
    final vowel = _classifyStrokeVowel(stroke);
    if (vowel != null) {
      _vowel = vowel;
      return;
    }

    _setRecognized(_firstMatch(switch (_script) {
      WritingScript.makasar => _makasarClassifiers(stroke),
      WritingScript.bugis => _lontaraClassifiers(stroke),
    }));
  }

  /// Most strokes first, so a letter isn't reported as whichever smaller
  /// letter is hiding inside its own strokes — and, among the
  /// single-stroke letters, the self-crossing ones before 𑻨, whose plain
  /// wedge they'd otherwise be mistaken for.
  List<ScriptCharacter? Function()> _makasarClassifiers(Stroke stroke) => [
        _classifyMa,
        _classifyBa,
        _classifyGa,
        _classifyYa,
        _classifyKa,
        _classifyNga,
        _classifyRa,
        () => _classifyNya(stroke),
        () => _classifyCa(stroke),
        () => _classifyJa(stroke),
        () => _classifyPa(stroke),
        () => _classifyTa(stroke),
        () => _classifyAngka(stroke),
        () => _classifyDa(stroke),
        () => _classifyWa(stroke),
        () => _classifyLa(stroke),
        () => _classifySa(stroke),
        () => _classifyA(stroke),
        () => _classifyNa(stroke),
      ];

  /// The same ordering for Lontara: the two-stroke letters first, then ᨔ
  /// before the one-stroke letters it closes over — a loop's own
  /// vertical profile is a wedge or a chevron, so ᨈ and ᨆ would otherwise
  /// claim it.
  List<ScriptCharacter? Function()> _lontaraClassifiers(Stroke stroke) => [
        // Most strokes first, as for Makasar — ᨟ is four of them, and the
        // pairs it is built from are letters in their own right.
        _classifyEndOfSection,
        _classifyLontaraNya,
        _classifyLontaraNra,
        _classifyLontaraLa,
        _classifyLontaraNgka,
        // Before ᨂ: their strokes turn sideways but never vertically, so
        // each is a descending line as well, which is all ᨂ asks for.
        _classifyLontaraBa,
        _classifyLontaraMpa,
        _classifyLontaraNga,
        _classifyLontaraKa,
        _classifyLontaraNca,
        _classifyLontaraRa,
        _classifyLontaraCa,
        () => _classifyLontaraHa(stroke),
        () => _classifyLontaraPa(stroke),
        () => _classifyLontaraSa(stroke),
        () => _classifyLontaraJa(stroke),
        () => _classifyLontaraWa(stroke),
        () => _classifyLontaraTa(stroke),
        () => _classifyLontaraMa(stroke),
      ];

  /// What the taps on the canvas can be, given whatever else is on it.
  ///
  /// Most dots first for Makasar, so a finished 𑻸 (6) isn't reported as the
  /// 𑻷 (3) hiding inside it — and for Lontara ᨐ before ᨕ, which is ᨐ short
  /// of a dot. ᨞ is three dots much as 𑻷 is, but grouped the looser way 𑻸
  /// is, by having been drawn together (see [_classifyPallawa]).
  ///
  /// A tap only reaches these having failed to be a vowel sign, which is
  /// what leaves room for ᨐ and ᨕ: their dots sit *within* the letter,
  /// where [_classifyDotVowel] wants -i above it and -u below it.
  List<ScriptCharacter? Function()> get _dotClassifiers => switch (_script) {
        WritingScript.makasar => [
            () => _classifyDotRun(6, MakasarCharacter.endOfSection),
            () => _classifyDotColumn(3, MakasarCharacter.passimbang),
          ],
        WritingScript.bugis => [
            _classifyLontaraYa,
            _classifyLontaraA,
            _classifyLontaraGa,
            _classifyLontaraNa,
            _classifyLontaraDa,
            _classifyPallawa,
          ],
      };

  /// ᨞: three taps, read the way 𑻸's six are ([_dotRuns]) — asked only to
  /// have been drawn together, near enough to each other with nothing
  /// written in among them.
  ///
  /// Nothing here asks them to line up, to step across or to stack. They
  /// are set out on a descending line in the letterform, but a mark of
  /// three taps is the only thing three taps can be in Lontara, so where
  /// they fall relative to each other is the hand's business rather than
  /// the reading's. Which also means the run can be tapped out from
  /// either end.
  LontaraCharacter? _classifyPallawa() =>
      _newestWith(_dotRuns()).length == 3 ? LontaraCharacter.pallawa : null;

  /// Records what the marks on the canvas now read as, along with their
  /// extent — which is what any vowel sign drawn next is positioned
  /// against ([_recognizedBounds]). A new character supersedes whatever
  /// vowel sign was on the old one.
  void _setRecognized(ScriptCharacter? letter) {
    _recognized = letter;
    _vowel = null;
    _recognizedBounds = letter == null
        ? null
        : _boundsOf([
            for (final stroke in _strokes) ...stroke.points,
            ..._dots,
          ]);
  }

  ScriptCharacter? _firstMatch(List<ScriptCharacter? Function()> classifiers) {
    for (final classify in classifiers) {
      final letter = classify();
      if (letter != null) return letter;
    }
    return null;
  }

  /// 𑻳 (-i) and 𑻴 (-u): a tap above or below the letter already drawn,
  /// within its own x range. Only letters take a vowel sign — a tap over
  /// a punctuation mark ([MakasarCharacter.sound] being null) is just
  /// another dot.
  VowelMark? _classifyDotVowel(Offset dot) {
    final bounds = _recognizedBounds;
    if (bounds == null || _recognized?.sound == null) return null;
    if (dot.dx < bounds.left - _dotRadius ||
        dot.dx > bounds.right + _dotRadius) {
      return null;
    }
    if (dot.dy < bounds.top) return VowelMark.i;
    if (dot.dy > bounds.bottom) return VowelMark.u;
    return null;
  }

  /// 𑻵 (-e), 𑻶 (-o) and ᨛ (-ae): a stroke drawn clear of the letter
  /// already drawn — in front of it (to its left) for -e, behind it (to
  /// its right) for -o, over it for -ae — each with its own shape:
  ///
  /// - -e doubles back horizontally: left, then right
  ///   ([_leftThenRightSequence]).
  /// - -o ticks up and then falls, the rise no more than
  ///   [_maxVowelRiseRatio] of the fall — which is what keeps it clear of
  ///   a wedge, whose two arms are comparable.
  /// - -ae doubles back the other way from -e: right, then left
  ///   ([_rightThenLeftSequence]). Lontara only, so Makasar never claims a
  ///   stroke drawn above a letter.
  ///
  /// -e and -o are tried on their sideways position first, so a mark that
  /// sits beside the letter is never read as the one that goes over it.
  VowelMark? _classifyStrokeVowel(Stroke stroke) {
    final bounds = _recognizedBounds;
    if (bounds == null || _recognized?.sound == null) return null;
    final markBounds = _boundsOf(stroke.points);

    if (markBounds.center.dx < bounds.left) {
      return _matchesHorizontalSequence(stroke, _leftThenRightSequence)
          ? VowelMark.e
          : null;
    }
    if (markBounds.center.dx > bounds.right) {
      final segments = _splitByVerticalDirectionChange(stroke);
      if (!_matchesVerticalSequence(stroke, _wedgeSequence)) return null;
      final rise = (segments.first.first.dy - segments.first.last.dy).abs();
      final fall = (segments.last.last.dy - segments.last.first.dy).abs();
      return rise <= fall * _maxVowelRiseRatio ? VowelMark.o : null;
    }
    if (_script == WritingScript.bugis && markBounds.bottom < bounds.top) {
      return _matchesHorizontalSequence(stroke, _rightThenLeftSequence)
          ? VowelMark.ae
          : null;
    }
    return null;
  }

  /// ᨈ: a lone wedge, the same element 𑻨 is. Checked after ᨔ, whose loop
  /// splits up-then-down as well.
  LontaraCharacter? _classifyLontaraTa(Stroke stroke) =>
      _isWedge(stroke) ? LontaraCharacter.ta : null;

  /// ᨓ: two of ᨈ's wedges in one stroke, up-down-up-down — 𑻡 and 𑻥's own
  /// element, here a letter in its own right. Unlike 𑻪 the two peaks meet
  /// cleanly, so a stroke that crosses itself is ᨔ instead.
  LontaraCharacter? _classifyLontaraWa(Stroke stroke) =>
      _isDoubleWedge(stroke) ? LontaraCharacter.wa : null;

  /// ᨆ: ᨈ the other way up — a chevron, down then up.
  LontaraCharacter? _classifyLontaraMa(Stroke stroke) =>
      _isChevronShaped(stroke) ? LontaraCharacter.ma : null;

  /// ᨔ: one stroke closing on itself, so it crosses its own path.
  LontaraCharacter? _classifyLontaraSa(Stroke stroke) =>
      _selfIntersections(stroke) > 0 ? LontaraCharacter.sa : null;

  /// ᨖ: one stroke out to the right and back left ([_rightThenLeftSequence],
  /// as 𑻠 is written), each half rising, falling and rising again — two
  /// loops set side by side.
  ///
  /// Closing both loops crosses the stroke over itself twice, once apiece —
  /// which it does before ᨔ is asked, since ᨔ wants no more than a stroke
  /// that crosses itself at all.
  LontaraCharacter? _classifyLontaraHa(Stroke stroke) {
    if (!_matchesHorizontalSequence(stroke, _rightThenLeftSequence)) {
      return null;
    }
    final halves = _splitByHorizontalDirectionChange(stroke);
    if (!halves.every((half) =>
        _matchesVerticalSequence(Stroke(half), _hookedWedgeSequence))) {
      return null;
    }
    return _selfIntersections(stroke) == 2 ? LontaraCharacter.ha : null;
  }

  /// ᨍ: the same sideways turn as ᨖ, out to the right and back left, but
  /// with the rightward half a plain wedge — up then down, where ᨖ's climbs
  /// again — and the return kept low: it starts below the top of the wedge
  /// it just made, rather than sweeping back across the apex the way 𑻠's
  /// does.
  ///
  /// Read before ᨈ: taken as a whole the stroke rises once and falls once,
  /// so a lone wedge is what it would otherwise pass for. Read after ᨔ,
  /// whose closed loop turns back the same way and is told apart by
  /// crossing itself.
  LontaraCharacter? _classifyLontaraJa(Stroke stroke) {
    if (!_matchesHorizontalSequence(stroke, _rightThenLeftSequence)) {
      return null;
    }
    final halves = _splitByHorizontalDirectionChange(stroke);
    final wedge = Stroke(halves.first);
    if (!_matchesVerticalSequence(wedge, _wedgeSequence)) return null;
    return _boundsOf(halves.last).top > _boundsOf(wedge.points).top
        ? LontaraCharacter.ja
        : null;
  }

  /// ᨄ: one stroke up, down and up again, whose tail — all of it past that
  /// first climb — turns back on itself, running out to the right and then
  /// left.
  LontaraCharacter? _classifyLontaraPa(Stroke stroke) =>
      _isPaShaped(stroke) ? LontaraCharacter.pa : null;

  /// ᨁ: ᨄ's stroke with a dot set under the up-down it opens with.
  LontaraCharacter? _classifyLontaraGa() {
    if (_strokes.isEmpty) return null;
    final stroke = _strokes.last;
    if (!_isPaShaped(stroke)) return null;
    return _dots.any((dot) => _isDotWithin(dot, _paOpeningWedge(stroke)))
        ? LontaraCharacter.ga
        : null;
  }

  /// ᨋ: the same again with a wedge written under that opening instead of
  /// a dot.
  ///
  /// Read before ᨒ, which asks only for a stroke that climbs, falls and
  /// climbs again — which ᨄ's does — with a wedge somewhere along the run
  /// of x it finishes on.
  LontaraCharacter? _classifyLontaraNra() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final bases = recent.where(_isPaShaped).toList();
    final wedges = recent.where(_isWedge).toList();
    if (bases.length != 1 || wedges.length != 1) return null;
    return _isUnder(wedges.single, Stroke(_paOpeningWedge(bases.single)))
        ? LontaraCharacter.nra
        : null;
  }

  /// The stroke ᨄ is written with, which ᨁ and ᨋ are built on as well: up,
  /// down and up again, with everything past that first climb running out
  /// to the right and then back left.
  bool _isPaShaped(Stroke stroke) {
    if (!_matchesVerticalSequence(stroke, _hookedWedgeSequence)) return false;
    final segments = _splitByVerticalDirectionChange(stroke);
    final tail = Stroke([for (final segment in segments.skip(1)) ...segment]);
    return _matchesHorizontalSequence(tail, _rightThenLeftSequence);
  }

  /// The up-down [stroke] opens with — the wedge ᨁ's dot and ᨋ's own wedge
  /// go under. Only meaningful for a [_isPaShaped] stroke.
  List<Offset> _paOpeningWedge(Stroke stroke) {
    final segments = _splitByVerticalDirectionChange(stroke);
    return [...segments.first, ...segments[1]];
  }

  /// ᨀ: two ascending lines written one against the other.
  LontaraCharacter? _classifyLontaraKa() =>
      _pairOverlappingInX(_isAscendingLine) ? LontaraCharacter.ka : null;

  /// ᨑ: the same pairing with wedges instead of lines — the two sit one
  /// above the other, which is what their overlapping x ranges catch.
  LontaraCharacter? _classifyLontaraRa() =>
      _pairOverlappingInX(_isWedge) ? LontaraCharacter.ra : null;

  /// ᨐ: ᨓ's double wedge with a dot tucked under each of its two wedges.
  LontaraCharacter? _classifyLontaraYa() {
    final dotted = _dottedWedges();
    return dotted != null && dotted.first && dotted.last
        ? LontaraCharacter.ya
        : null;
  }

  /// ᨕ: the same double wedge with only the second of its wedges dotted.
  LontaraCharacter? _classifyLontaraA() {
    final dotted = _dottedWedges();
    return dotted != null && !dotted.first && dotted.last
        ? LontaraCharacter.a
        : null;
  }

  /// Whether each of the two wedges of the double wedge last drawn has a
  /// dot tucked under it — which is all ᨐ and ᨕ differ by. Null when
  /// there's no double wedge on the canvas to read them off.
  List<bool>? _dottedWedges() {
    if (_strokes.isEmpty) return null;
    final stroke = _strokes.last;
    if (!_isDoubleWedge(stroke)) return null;

    // The segments come out up, down, up, down; a wedge is a pair of them.
    final segments = _splitByVerticalDirectionChange(stroke);
    return [
      for (var i = 0; i < segments.length; i += 2)
        _dots.any(
            (dot) => _isDotWithin(dot, [...segments[i], ...segments[i + 1]])),
    ];
  }

  /// ᨊ: ᨈ's wedge with a dot set inside it — under the apex, since that's
  /// the top of the wedge's own box.
  LontaraCharacter? _classifyLontaraNa() =>
      _isDottedInside(_isWedge) ? LontaraCharacter.na : null;

  /// ᨉ: ᨆ's chevron with a dot set inside it — above the point, for the
  /// same reason the other way up.
  LontaraCharacter? _classifyLontaraDa() =>
      _isDottedInside(_isChevronShaped) ? LontaraCharacter.da : null;

  /// Whether the last stroke drawn is the element [isElement] describes and
  /// has a dot sitting inside it.
  bool _isDottedInside(bool Function(Stroke) isElement) {
    if (_strokes.isEmpty) return false;
    final stroke = _strokes.last;
    return isElement(stroke) &&
        _dots.any((dot) => _isDotWithin(dot, stroke.points));
  }

  /// Whether [dot] falls inside [element]'s own bounding box rather than
  /// clear of it: across the run of x it covers, and strictly between its
  /// top and bottom.
  ///
  /// That's what keeps ᨊ, ᨉ, ᨐ and ᨕ's dots apart from the vowel signs,
  /// which want a tap clear of the letter — above it for -i, below it for
  /// -u (see [_classifyDotVowel]). Being inside puts a dot under a wedge's
  /// apex and over a chevron's point, so one test serves both ways up.
  bool _isDotWithin(Offset dot, List<Offset> element) {
    final bounds = _boundsOf(element);
    return dot.dx >= bounds.left &&
        dot.dx <= bounds.right &&
        dot.dy > bounds.top &&
        dot.dy < bounds.bottom;
  }

  /// ᨂ: a descending line with an ascending one run up across its middle,
  /// meeting it once.
  LontaraCharacter? _classifyLontaraNga() =>
      _crossedFromBelowLeft(_isDescendingLine, LontaraCharacter.nga);

  /// ᨅ: ᨂ with the stroke being crossed turned back on itself instead of
  /// running straight down — out to the left and then back to the right,
  /// which puts a hook at the top of it.
  LontaraCharacter? _classifyLontaraBa() => _crossedFromBelowLeft(
      (stroke) => _matchesHorizontalSequence(stroke, _leftThenRightSequence),
      LontaraCharacter.ba);

  /// ᨇ: ᨅ's turn the other way about — out to the right and then back left.
  LontaraCharacter? _classifyLontaraMpa() => _crossedFromBelowLeft(
      (stroke) => _matchesHorizontalSequence(stroke, _rightThenLeftSequence),
      LontaraCharacter.mpa);

  /// ᨟: four strokes — two crossings written one over the other, sharing a
  /// run of x.
  ///
  /// Each crossing is an ascending line with a descending stroke run once
  /// across its middle, and the two differ by which side that falling
  /// stroke lies: below and to the right in one, above and to the left in
  /// the other. Neither is ᨂ, which has the climbing stroke below and left
  /// of the falling one rather than the other way about.
  LontaraCharacter? _classifyEndOfSection() {
    if (_strokes.length < 4) return null;
    final recent = _strokes.sublist(_strokes.length - 4);

    // Which strokes pair up isn't settled by draw order, so every way of
    // splitting the four into two pairs is tried.
    for (final partner in [1, 2, 3]) {
      final first = [recent.first, recent[partner]];
      final second = [
        for (var i = 1; i < recent.length; i++)
          if (i != partner) recent[i],
      ];
      final oneWay = _isCrossedPair(first, fallsBelowRight: true) &&
          _isCrossedPair(second, fallsBelowRight: false);
      final other = _isCrossedPair(first, fallsBelowRight: false) &&
          _isCrossedPair(second, fallsBelowRight: true);
      if (!oneWay && !other) continue;

      final above = _boundsOf([for (final stroke in first) ...stroke.points]);
      final below = _boundsOf([for (final stroke in second) ...stroke.points]);
      if (above.left <= below.right && below.left <= above.right) {
        return LontaraCharacter.endOfSection;
      }
    }
    return null;
  }

  /// Whether [pair] is one of ᨟'s crossings: an ascending stroke and a
  /// descending one meeting exactly once, the falling stroke lying either
  /// below and right of the climbing one or above and left of it.
  bool _isCrossedPair(List<Stroke> pair, {required bool fallsBelowRight}) {
    final climbs = pair.where(_isAscendingLine).toList();
    final falls = pair.where(_isDescendingLine).toList();
    if (climbs.length != 1 || falls.length != 1) return false;
    if (_strokeCrossings(climbs.single, falls.single) != 1) return false;

    final climb = _boundsOf(climbs.single.points);
    final fall = _boundsOf(falls.single.points);
    return fallsBelowRight
        ? fall.center.dx > climb.center.dx && fall.center.dy > climb.center.dy
        : fall.center.dx < climb.center.dx && fall.center.dy < climb.center.dy;
  }

  /// The build ᨂ and ᨅ share: a stroke of their own — [isCrossed] — with an
  /// ascending one run up across it, meeting it once and lying down and to
  /// the left, so its centre is both left of and below the other's.
  ///
  /// That placement is what keeps either from being read off any other pair
  /// of crossed strokes. Which stroke is which needs no deciding: an
  /// ascending line is neither a descending one nor a stroke that turns,
  /// so nothing satisfies both tests.
  LontaraCharacter? _crossedFromBelowLeft(
      bool Function(Stroke) isCrossed, LontaraCharacter letter) {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final crossed = recent.where(isCrossed).toList();
    final climbs = recent.where(_isAscendingLine).toList();
    if (crossed.length != 1 || climbs.length != 1) return null;

    if (_strokeCrossings(crossed.single, climbs.single) != 1) return null;
    final base = _boundsOf(crossed.single.points);
    final climb = _boundsOf(climbs.single.points);
    return climb.center.dx < base.center.dx && climb.center.dy > base.center.dy
        ? letter
        : null;
  }

  /// ᨃ: ᨈ's wedge with a line drawn down across it — cutting the arm it
  /// climbs on, and cutting it once. Which arm is which is read off the
  /// wedge's own direction split, so the crossing has to land on its first
  /// segment rather than the one it falls away on.
  LontaraCharacter? _classifyLontaraNgka() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final wedges = recent.where(_isWedge).toList();
    final lines = recent.where(_isDescendingLine).toList();
    // A line has one direction segment and a wedge two, so neither stroke
    // can be both.
    if (wedges.length != 1 || lines.length != 1) return null;

    if (_strokeCrossings(wedges.single, lines.single) != 1) return null;
    final climb = Stroke(_splitByVerticalDirectionChange(wedges.single).first);
    return _strokesCross(climb, lines.single) ? LontaraCharacter.ngka : null;
  }

  /// ᨌ: a wedge with a stroke that turns — out to the right and then back
  /// left — laid across the run of x it covers.
  ///
  /// Read after ᨃ, which pairs the same wedge with a descending line: a
  /// turning stroke can be one of those too, since turning sideways says
  /// nothing about whether it ever stops falling. What separates them is
  /// that ᨃ wants the line cut once across the wedge's climb, where this
  /// asks only that the two overlap.
  LontaraCharacter? _classifyLontaraCa() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final wedges = recent.where(_isWedge).toList();
    final turns = recent
        .where((stroke) =>
            _matchesHorizontalSequence(stroke, _rightThenLeftSequence))
        .toList();
    if (wedges.length != 1 || turns.length != 1) return null;
    if (identical(wedges.single, turns.single)) return null;

    final wedge = _boundsOf(wedges.single.points);
    final turn = _boundsOf(turns.single.points);
    return wedge.left <= turn.right && turn.left <= wedge.right
        ? LontaraCharacter.ca
        : null;
  }

  /// ᨏ: two wedges again, but written across each other so their arms
  /// cross rather than merely sharing an x range. Checked before ᨑ, whose
  /// looser test two crossing wedges satisfy as well.
  LontaraCharacter? _classifyLontaraNca() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    if (!recent.every(_isWedge)) return null;
    return _strokesCross(recent.first, recent.last)
        ? LontaraCharacter.nca
        : null;
  }

  /// ᨎ: ᨓ's double wedge with a chevron hung under it — 𑻤's own build,
  /// in the other script.
  LontaraCharacter? _classifyLontaraNya() =>
      _wedgesWithMark(_isChevronShaped, LontaraCharacter.nya);

  /// ᨒ: one stroke going up, down and up again ([_hookedWedgeSequence]),
  /// with a wedge written over the climb it finishes on — the two strokes
  /// share the x range of that last segment.
  ///
  /// Overlap rather than containment, as everywhere else a mark is placed
  /// against a shape (see [_isUnder]): the wedge is the wider of the two
  /// and needn't sit squarely over the climb.
  LontaraCharacter? _classifyLontaraLa() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final hooks = recent
        .where(
            (stroke) => _matchesVerticalSequence(stroke, _hookedWedgeSequence))
        .toList();
    final wedges = recent.where(_isWedge).toList();
    // The two sequences are different lengths, so no stroke is both.
    if (hooks.length != 1 || wedges.length != 1) return null;

    final climb = _boundsOf(_splitByVerticalDirectionChange(hooks.single).last);
    final wedge = _boundsOf(wedges.single.points);
    return wedge.left <= climb.right && climb.left <= wedge.right
        ? LontaraCharacter.la
        : null;
  }

  /// Whether [a] and [b] cross at all — [_selfIntersections] read the same
  /// way, but between two strokes rather than within one.
  bool _strokesCross(Stroke a, Stroke b) => _strokeCrossings(a, b) > 0;

  /// How many times [b] runs across [a], counted as the number of [a]'s own
  /// segments that any segment of [b] meets. Counting on [a]'s side keeps
  /// two crossings far apart along it from being collapsed into one, which
  /// is what ᨃ's "just the once" turns on.
  ///
  /// Either stroke that is a line is taken as the straight run between its
  /// ends ([_straightened]) rather than as the path the hand drew. Two
  /// wavering strokes cross and re-cross where they were meant to meet
  /// once, and every letter that counts crossings wants that once.
  int _strokeCrossings(Stroke a, Stroke b) {
    final from = _straightened(a);
    final across = _straightened(b);
    var crossings = 0;
    for (var i = 0; i < from.points.length - 1; i++) {
      for (var j = 0; j < across.points.length - 1; j++) {
        if (_segmentsIntersect(from.points[i], from.points[i + 1],
            across.points[j], across.points[j + 1])) {
          crossings++;
          break;
        }
      }
    }
    return crossings;
  }

  /// [stroke] reduced to the run between its two ends, if it's a line —
  /// which is what [_isPlainLine] has already established it keeps to.
  /// Anything else is left as it was drawn: a wedge is not its own chord.
  Stroke _straightened(Stroke stroke) =>
      _isPlainLine(stroke) ? Stroke([stroke.start, stroke.end]) : stroke;

  /// The shape ᨀ and ᨑ share: the 2 most recent strokes are both the same
  /// element ([isPiece]) and their x ranges overlap — written against each
  /// other rather than clear of one another, which is what separates them
  /// from two of the same letter written side by side.
  bool _pairOverlappingInX(bool Function(Stroke) isPiece) {
    if (_strokes.length < 2) return false;
    final recent = _strokes.sublist(_strokes.length - 2);
    if (!recent.every(isPiece)) return false;
    final first = _boundsOf(recent.first.points);
    final second = _boundsOf(recent.last.points);
    return first.left <= second.right && second.left <= first.right;
  }

  /// Whether [stroke] is a plain line that climbs as it goes right — ᨀ's
  /// own element.
  bool _isAscendingLine(Stroke stroke) {
    if (!_isPlainLine(stroke)) return false;
    final (leftmost, rightmost) = _endsLeftToRight(stroke);
    return leftmost.dy - rightmost.dy >= _minArmExtent;
  }

  /// The same the other way about — falling as it goes right, which is the
  /// line ᨃ is cut across with.
  bool _isDescendingLine(Stroke stroke) {
    if (!_isPlainLine(stroke)) return false;
    final (leftmost, rightmost) = _endsLeftToRight(stroke);
    return rightmost.dy - leftmost.dy >= _minArmExtent;
  }

  /// [stroke]'s two ends, the leftmost of them first — which is how a
  /// line's slope is read.
  ///
  /// Its ends only, not the leftmost and rightmost points along it: a hand
  /// wavering sideways can put either of those in the middle of the stroke,
  /// and the slope then comes off a waver instead of off the line. Ordering
  /// them by x rather than by when they were drawn is what keeps this from
  /// caring which end the stroke was started at.
  (Offset, Offset) _endsLeftToRight(Stroke stroke) =>
      stroke.start.dx <= stroke.end.dx
          ? (stroke.start, stroke.end)
          : (stroke.end, stroke.start);

  /// 𑻨: a lone wedge. Checked last in [_commit], as the fallback for a
  /// wedge that isn't part of a bigger letter yet.
  MakasarCharacter? _classifyNa(Stroke stroke) =>
      _isWedge(stroke) ? MakasarCharacter.na : null;

  /// 𑻡: a double wedge (`ΛΛ` in one stroke) + a wedge under it.
  MakasarCharacter? _classifyGa() =>
      _wedgesWithMark(_isWedge, MakasarCharacter.ga);

  /// 𑻥: the same double wedge as 𑻡 + a mark that closes on itself under
  /// it ([_isClosedMark]) — the wedge shut with a bar that 𑻥 ends on,
  /// drawn in one go, or the loop a hand draws in its place.
  ///
  /// Checked before every other letter built this way, because a closed
  /// mark reads as an open one as soon as it's asked: which of up-down or
  /// down-up it splits into is decided by nothing more than where the pen
  /// started round the loop, so 𑻤 claims a circle begun at the top and 𑻡
  /// one begun at the bottom. Closing on itself is the particular thing
  /// about it, so it gets asked first.
  MakasarCharacter? _classifyMa() =>
      _wedgesWithMark(_isClosedMark, MakasarCharacter.ma);

  /// Whether [stroke] closes on itself: either it crosses its own path
  /// ([_selfIntersections]) or it comes back to where it began, the gap
  /// between its two ends no more than [_maxClosingGap] of its own longest
  /// side.
  ///
  /// The second is what a drawn circle usually is. A tail that laps its
  /// own start along the same curve rather than across it leaves no
  /// crossing to count, and a hand that stops a little short of its start
  /// leaves none either — both still close the shape off, which is all
  /// 𑻥's mark asks.
  ///
  /// What keeps 𑻤's chevron and its narrow bowl out is that a loop comes
  /// the way round to where it began ([_minLoopTurn]) where those turn
  /// through half a circle and stop; and that their ends are the mark's
  /// own two tips, a gap the width of it rather than a fraction of it.
  ///
  /// Nothing here asks the loop to be round, or even upright: the one
  /// drawn under the wedges is as often a flat box as a circle.
  bool _isClosedMark(Stroke stroke) {
    if (_selfIntersections(stroke) > 0) return true;
    final bounds = _boundsOf(stroke.points);
    if (bounds.shortestSide < _minArmExtent) return false;
    if (_totalTurn(stroke) < _minLoopTurn) return false;
    return (stroke.end - stroke.start).distance <=
        bounds.longestSide * _maxClosingGap;
  }

  /// How far [stroke] turns in all, in radians: the angle between each
  /// step and the one before it, summed with its sign so that a hand
  /// wavering to either side cancels itself out, and taken absolute at the
  /// end so it doesn't matter which way round the mark was drawn.
  ///
  /// A circle comes to 2π either way round, a chevron to about π, and a
  /// stroke that snakes to about nothing.
  double _totalTurn(Stroke stroke) {
    final points = stroke.points;
    var turn = 0.0;
    Offset? last;
    for (var i = 1; i < points.length; i++) {
      final step = points[i] - points[i - 1];
      if (step == Offset.zero) continue;
      if (last != null) {
        turn += math.atan2(last.dx * step.dy - last.dy * step.dx,
            last.dx * step.dx + last.dy * step.dy);
      }
      last = step;
    }
    return turn.abs();
  }

  /// The shape 𑻡, 𑻤, 𑻥, 𑻠 and 𑻬 share — and ᨎ, which is built the same
  /// way: of the 2 most recent strokes, one is the letter's wedges (a plain
  /// double wedge unless [isTop] asks for something more particular) and
  /// the other, the mark written under it, satisfies [isMark].
  T? _wedgesWithMark<T extends ScriptCharacter>(
      bool Function(Stroke) isMark, T letter,
      {bool Function(Stroke)? isTop}) {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final isWedges = isTop ?? _isDoubleWedge;
    // Both ways round, rather than counting which strokes answer to
    // which: a mark can be shaped like the wedges it hangs under and
    // still be the mark — 𑻥's crosses itself, which is 𑻪's whole shape —
    // and then counting finds two sets of wedges and no letter at all.
    // Position decides instead, and it can only decide one way, since
    // nothing is under itself.
    for (final (wedges, mark) in [
      (recent.first, recent.last),
      (recent.last, recent.first),
    ]) {
      if (isWedges(wedges) && isMark(mark) && _isUnder(mark, wedges)) {
        return letter;
      }
    }
    return null;
  }

  /// 𑻤: the same double wedge as 𑻡 and 𑻥 + a chevron (`V`) under it.
  MakasarCharacter? _classifyBa() =>
      _wedgesWithMark(_isChevronShaped, MakasarCharacter.ba);

  /// 𑻢: 𑻤's shape with a single wedge instead of a double one — one
  /// wedge + a chevron hanging under it ([_isUnder]).
  MakasarCharacter? _classifyNga() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final wedges = recent.where(_isWedge).toList();
    final marks = recent.where(_isChevronShaped).toList();
    if (wedges.length != 1 || marks.length != 1) return null;
    return _isUnder(marks.single, wedges.single) ? MakasarCharacter.nga : null;
  }

  /// 𑻦: a wedge whose descending arm hooks back up
  /// ([_hookedWedgeSequence]), crossing the arm it came down on — 𑻢's
  /// two strokes written as one, so where 𑻢 has a separate chevron
  /// underneath, 𑻦 has a bowl continuous with the wedge itself.
  MakasarCharacter? _classifyTa(Stroke stroke) =>
      _matchesVerticalSequence(stroke, _hookedWedgeSequence) &&
              _selfIntersections(stroke) == 1
          ? MakasarCharacter.ta
          : null;

  /// 𑻠: 𑻪's own self-crossing double wedge + an ascending line under it.
  /// The crossing count is a floor rather than an exact match, unlike
  /// 𑻪's — with the line underneath already separating the two, there's
  /// no reason to be strict about a second crossing.
  ///
  /// Checked before 𑻪 (which is this letter's first stroke on its own),
  /// like every other two-stroke letter.
  MakasarCharacter? _classifyKa() => _wedgesWithMark(
        _isPlainLine,
        MakasarCharacter.ka,
        isTop: _isKaShaped,
      );

  /// The stroke 𑻠 is written with: sideways it goes out to the right and
  /// then back left ([_rightThenLeftSequence]), with the rightward half
  /// rising, falling and rising again ([_hookedWedgeSequence]).
  ///
  /// Read as two sideways halves rather than as one run of peaks because
  /// that's how it's written: the pen sweeps right over a peak and starts
  /// up again, then comes back left. Only the rightward half's own profile
  /// is checked — what the pen does on the way back, and however many
  /// times the stroke crosses itself, are both left open, since the
  /// sideways turn and that first profile already identify the letter.
  bool _isKaShaped(Stroke stroke) {
    if (!_matchesHorizontalSequence(stroke, _rightThenLeftSequence)) {
      return false;
    }
    final rightward = _splitByHorizontalDirectionChange(stroke).first;
    return _matchesVerticalSequence(Stroke(rightward), _hookedWedgeSequence);
  }

  /// 𑻬: 𑻠 with one more wedge in its stroke, under the same ascending
  /// line. It goes out to the right exactly as 𑻠 does — up, down, up —
  /// and differs only on the way back, which rises and falls twice over
  /// instead of once ([_isYaShaped]).
  ///
  /// Checked before 𑻠, and this ordering is what keeps the two apart:
  /// [_isKaShaped] leaves the leftward half open, so it matches this
  /// letter's stroke too and would claim it if it went first.
  MakasarCharacter? _classifyYa() => _wedgesWithMark(
        _isPlainLine,
        MakasarCharacter.ya,
        isTop: _isYaShaped,
      );

  /// The stroke 𑻬 is written with: 𑻠's own sideways turn
  /// ([_rightThenLeftSequence]) over 𑻠's own outward profile
  /// ([_hookedWedgeSequence]), then back left over two whole peaks — up,
  /// down, up, down ([_doubleWedgeSequence]) — where 𑻠 comes back over
  /// one.
  ///
  /// Both halves are read here, unlike [_isKaShaped]: the return is the
  /// only thing that tells the two letters apart. How often the stroke
  /// crosses itself is still left open.
  bool _isYaShaped(Stroke stroke) {
    if (!_matchesHorizontalSequence(stroke, _rightThenLeftSequence)) {
      return false;
    }
    final halves = _splitByHorizontalDirectionChange(stroke);
    return _matchesVerticalSequence(
            Stroke(halves.first), _hookedWedgeSequence) &&
        _matchesVerticalSequence(Stroke(halves.last), _doubleWedgeSequence);
  }

  /// 𑻣: a double wedge whose last descent finishes in the top half of the
  /// stroke's own bounding box — the second peak drops only a little way
  /// before the stroke ends, rather than running all the way back down to
  /// the baseline as 𑻡/𑻤/𑻥's does.
  ///
  /// Checked against the bare [_doubleWedgeSequence] rather than
  /// [_isDoubleWedge]: that adds a not-too-tall-and-narrow guard, which
  /// this letterform — a tall stem with the wedges tucked at one end —
  /// can legitimately fail.
  ///
  /// An imaginary horizontal line at the top of the bottom third
  /// ([_bottomThirdLine]) separates it from 𑻧: 𑻣's stroke passes through
  /// that line three times, 𑻧's twice.
  MakasarCharacter? _classifyPa(Stroke stroke) {
    if (!_matchesVerticalSequence(stroke, _doubleWedgeSequence)) return null;
    final lastDescent = _splitByVerticalDirectionChange(stroke).last;
    final bounds = _boundsOf(stroke.points);
    if (lastDescent.last.dy >= bounds.center.dy) return null;
    // Down, up, and down again through the line that marks off the bottom
    // third — where 𑻧 passes it only twice, once each way (see
    // [_classifyDa]).
    return _horizontalLineCrossings(stroke, _bottomThirdLine(bounds)) == 3
        ? MakasarCharacter.pa
        : null;
  }

  /// The height that cuts the bottom third of [bounds] off from the rest —
  /// 𑻣 and 𑻧 are both read against it.
  double _bottomThirdLine(Rect bounds) => bounds.top + bounds.height * 2 / 3;

  /// How many times [stroke] passes through the horizontal line at [y],
  /// in either direction.
  int _horizontalLineCrossings(Stroke stroke, double y) {
    final points = stroke.points;
    var count = 0;
    for (var i = 1; i < points.length; i++) {
      final was = points[i - 1].dy < y;
      final is_ = points[i].dy < y;
      if (was != is_) count++;
    }
    return count;
  }

  /// 𑻧: two shapes standing on a base that links them
  /// ([_piecesAboveBase]), written as one stroke that works its way
  /// sideways left, right, left, right
  /// ([_leftRightLeftRightSequence]) — each of the two shapes doubling
  /// back from left to right, with the base carrying the pen from the
  /// first to the second.
  ///
  /// The sideways sequence is read across the whole stroke rather than
  /// piece by piece: which side of the cut the base's own travel falls on
  /// depends on how low the pen dips, and that shouldn't change what the
  /// letter reads as.
  MakasarCharacter? _classifyDa(Stroke stroke) {
    if (_piecesAboveBase(stroke) == null) return null;
    return _matchesHorizontalSequence(stroke, _leftRightLeftRightSequence)
        ? MakasarCharacter.da
        : null;
  }

  /// 𑻯: two 𑻮 hooks over the base between them, the second mirrored, all
  /// in one stroke — right, left, right, left, right
  /// ([_rightLeftRightLeftRightSequence]), with the pen going up on the
  /// first run and down on the second, out along the base on the third,
  /// and up and down again on the last two.
  ///
  /// The base is that middle run, and it has to read as one: lying in the
  /// bottom third of the letter ([_bottomThirdLine]) and travelling
  /// further than it falls. That's what tells this letter from any other
  /// five-run stroke — a hand working its way up a flight of sweeps
  /// crosses the middle of the letter, not its foot — as well as from 𑻱,
  /// which is 𑻯's mirror image sweep for sweep and read off which way the
  /// pen sets out.
  MakasarCharacter? _classifyWa(Stroke stroke) {
    if (!_matchesHorizontalSequence(stroke, _rightLeftRightLeftRightSequence)) {
      return null;
    }
    final base = _boundsOf(_splitByHorizontalDirectionChange(stroke)[2]);
    return base.center.dy > _bottomThirdLine(_boundsOf(stroke.points)) &&
            base.width > base.height
        ? MakasarCharacter.wa
        : null;
  }

  /// The two pieces 𑻧 is built from: what's left of [stroke] once
  /// the part running through the bottom third of its own bounding box is
  /// cut away. Null unless the stroke really is two pieces standing on a
  /// base, which takes three things:
  ///
  /// - it passes through the line marking off that bottom third exactly
  ///   twice, once down into the base and once back out of it — a stroke
  ///   that dips through more often is 𑻣 (see [_classifyPa]);
  /// - exactly two pieces are left above the cut, ignoring any too short
  ///   to be an arm ([_minArmExtent]), so a stroke that grazes back above
  ///   the line mid-base doesn't read as a third piece;
  /// - what the cut removed actually travels, at least [_minBaseWidth] of
  ///   the letter's own width. Without that a plain `ΛΛ` would qualify:
  ///   the dip between its two peaks passes through the bottom third as
  ///   well, it just doesn't go anywhere while it's down there.
  ///
  /// Describing the letters this way round — by what's left once the base
  /// is taken away — sidesteps having to describe the base itself, which
  /// can be a dip, a bar or a bowl depending on how it's written.
  List<Stroke>? _piecesAboveBase(Stroke stroke) {
    final points = stroke.points;
    final bounds = _boundsOf(points);
    final cut = _bottomThirdLine(bounds);
    // Once down into the base and once back out of it — a stroke that
    // dips through more often than that is 𑻣 (see [_classifyPa]), not a
    // letter standing on a base.
    if (_horizontalLineCrossings(stroke, cut) != 2) return null;

    // Where each run of points above the cut starts and ends.
    final pieces = <(int, int)>[];
    int? start;
    for (var i = 0; i < points.length; i++) {
      if (points[i].dy <= cut) {
        start ??= i;
      } else if (start != null) {
        pieces.add((start, i - 1));
        start = null;
      }
    }
    if (start != null) pieces.add((start, points.length - 1));

    final kept = [
      for (final (from, to) in pieces)
        if (_boundsOf(points.sublist(from, to + 1)).height >= _minArmExtent)
          (from, to),
    ];
    if (kept.length != 2) return null;

    final base = points.sublist(kept.first.$2, kept.last.$1 + 1);
    if (_boundsOf(base).width < bounds.width * _minBaseWidth) return null;

    return [
      for (final (from, to) in kept) Stroke(points.sublist(from, to + 1)),
    ];
  }

  /// Whether [stroke] is a plain line: it keeps to the straight run between
  /// its two ends, and climbs or falls at least [_minArmExtent] on the way.
  ///
  /// Read as straightness rather than as "never changes vertical
  /// direction", which is what this used to ask. A hand drawing a long
  /// diagonal wavers by a few pixels either way, and a waver of
  /// [_directionNoise] was enough to cut the stroke into a run of tiny
  /// segments and stop it being a line at all — which took ᨟ with it, since
  /// that wants four lines to read at once.
  ///
  /// Which end it was started from doesn't matter — the same line drawn
  /// top to bottom is the same mark — and no letter uses a line of one
  /// direction to mean something different from the other, so there's
  /// nothing to be gained by insisting.
  bool _isPlainLine(Stroke stroke) {
    final span = stroke.end - stroke.start;
    final length = span.distance;
    if (length < _minArmExtent) return false;
    if ((stroke.end.dy - stroke.start.dy).abs() < _minArmExtent) return false;

    final tolerance = length * _maxLineWaver;
    for (final point in stroke.points) {
      final offset = point - stroke.start;
      // How far off the run between the ends this point sits.
      final across = (offset.dx * span.dy - offset.dy * span.dx).abs() / length;
      if (across > tolerance) return false;
    }
    return true;
  }

  /// Whether [mark] is written under [base]: their x ranges overlap, and
  /// [mark]'s own center sits below [base]'s. Deliberately loose about
  /// the vertical — a mark usually starts before the shape above it has
  /// finished (𑻦's chevron hangs off the wedge's own arm) — and about the
  /// horizontal, since a mark isn't always centred under what it hangs
  /// from.
  bool _isUnder(Stroke mark, Stroke base) {
    final baseBounds = _boundsOf(base.points);
    final markBounds = _boundsOf(mark.points);
    if (markBounds.left > baseBounds.right ||
        baseBounds.left > markBounds.right) {
      return false;
    }
    return markBounds.center.dy > baseBounds.center.dy;
  }

  /// 𑻪: a double wedge drawn in one stroke that crosses its own path
  /// once — the two peaks' inner arms cross rather than meeting in a
  /// clean valley. Checked before 𑻨 for the same reason 𑻥 is checked
  /// before 𑻡: nothing about the crossing shows up in the stroke's
  /// vertical direction alone.
  MakasarCharacter? _classifyJa(Stroke stroke) =>
      _isDoubleWedge(stroke) && _selfIntersections(stroke) == 1
          ? MakasarCharacter.ja
          : null;

  /// 𑻷 (3 taps): whether the column the newest tap belongs to is [count]
  /// taps long.
  MakasarCharacter? _classifyDotColumn(int count, MakasarCharacter mark) =>
      _newestWith(_dotColumns()).length == count ? mark : null;

  /// 𑻸 (6 taps): the same, but off the looser grouping — the letterform
  /// sets its six taps zigzagging to either side of a centre line rather
  /// than stacking them the way 𑻷 does, so they are asked only to have
  /// been drawn together ([_dotRuns]).
  MakasarCharacter? _classifyDotRun(int count, MakasarCharacter mark) =>
      _newestWith(_dotRuns()).length == count ? mark : null;

  /// Which of [groups] the most recent tap ended up in — the mark being
  /// drawn right now, as opposed to any other still on the canvas.
  List<Offset> _newestWith(List<List<Offset>> groups) {
    if (_dots.isEmpty) return const [];
    final newest = _dots.last;
    for (final group in groups) {
      if (group.any((dot) => dot == newest)) return group;
    }
    return const [];
  }

  /// The taps grouped as 𑻸 wants them: sorted left to right and split
  /// only where the run is really broken — where the next tap is further
  /// off than [_maxDotSpacing], or where something else has been drawn
  /// between the two ([_strokeBetween]).
  ///
  /// Nothing here asks a tap to line up with the one before it. 𑻸's six
  /// don't line up with each other in the first place, and what makes
  /// them one mark is that they were put down together with nothing in
  /// among them — which is what this measures.
  List<List<Offset>> _dotRuns() => _groupDots((previous, dot) =>
      dot.dx - previous.dx <= _maxDotSpacing &&
      !_strokeBetween(previous.dx, dot.dx));

  /// Whether a stroke sits between [leftX] and [rightX] — a letter
  /// written between two runs of taps, which makes them two marks however
  /// close together they were drawn.
  bool _strokeBetween(double leftX, double rightX) => _strokes.any((stroke) {
        final centre = _boundsOf(stroke.points).center.dx;
        return centre > leftX && centre < rightX;
      });

  /// The taps on the canvas grouped into columns: sorted left to right,
  /// then split wherever a tap's drawn circle (radius [_dotRadius]) no
  /// longer overlaps in x with the one before it. Grouping rather than
  /// just counting the last few taps means a mark is read on its own,
  /// whatever else has already been written beside it — two columns side
  /// by side are two marks even though their taps interleave from top to
  /// bottom.
  ///
  /// The overlap is checked against the previous tap alone rather than
  /// against the whole column: a column of six drifts sideways as it goes
  /// down the page far more than a column of three does, and every tap
  /// still belongs to the same mark as long as it lines up with its own
  /// neighbour.
  List<List<Offset>> _dotColumns() => _groupDots(
      (previous, dot) => (dot.dx - previous.dx).abs() <= _dotRadius * 2);

  /// The taps sorted left to right and cut into groups wherever
  /// [belongsWith] says a tap no longer goes with the one before it.
  List<List<Offset>> _groupDots(bool Function(Offset, Offset) belongsWith) {
    final sorted = [..._dots]..sort((a, b) => a.dx.compareTo(b.dx));
    final groups = <List<Offset>>[];
    for (final dot in sorted) {
      final group = groups.isEmpty ? null : groups.last;
      if (group != null && belongsWith(group.last, dot)) {
        group.add(dot);
      } else {
        groups.add([dot]);
      }
    }
    return groups;
  }

  /// 𑻲 (angka, the repeater): up, down and back up, with the opening
  /// rise at least twice the height of either of the two that follow —
  /// a tall stem, then a small hook off the bottom of it.
  ///
  /// Shares its up-down-up shape with 𑻦, which is checked first: there
  /// the three arms are comparable and the stroke crosses itself, neither
  /// of which is true here.
  MakasarCharacter? _classifyAngka(Stroke stroke) =>
      _isAngkaShaped(stroke) ? MakasarCharacter.angka : null;

  /// 𑻭: 𑻲's own stem-and-hook stroke + a chevron under it — the same
  /// pairing as 𑻢 (wedge + chevron), one stroke shape further along.
  MakasarCharacter? _classifyRa() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final stems = recent.where(_isAngkaShaped).toList();
    final marks = recent.where(_isChevronShaped).toList();
    if (stems.length != 1 || marks.length != 1) return null;
    return _isUnder(marks.single, stems.single) ? MakasarCharacter.ra : null;
  }

  /// 𑻮: one stroke that doubles back twice sideways — right, left, right
  /// ([_rightLeftRightSequence]) — one end of it running along the
  /// letter's own base ([_hasBaseRun]).
  ///
  /// Read off horizontal rather than vertical direction, like 𑻯, 𑻰 and
  /// 𑻱, so it's checked late: a stroke shaped this way has no vertical
  /// reversal to speak of and won't have matched anything above.
  MakasarCharacter? _classifyLa(Stroke stroke) =>
      _isLaShaped(stroke) ? MakasarCharacter.la : null;

  bool _isLaShaped(Stroke stroke) =>
      _matchesHorizontalSequence(stroke, _rightLeftRightSequence) &&
      _hasBaseRun(stroke);

  /// Whether [stroke] has a base to it: one of its two end runs — the one
  /// it sets off along or the one it finishes on — lying in the bottom
  /// half of its own bounding box, rather than an arm that happens to
  /// travel the same way partway up.
  ///
  /// Either end will do because either is how the letter gets written:
  /// laying the base down and working up off it, or drawing the hook and
  /// running the base out from under it afterwards.
  bool _hasBaseRun(Stroke stroke) {
    final runs = _splitByHorizontalDirectionChange(stroke);
    final middle = _boundsOf(stroke.points).center.dy;
    return _boundsOf(runs.first).center.dy > middle ||
        _boundsOf(runs.last).center.dy > middle;
  }

  /// 𑻰: one stroke going left, right, then left again
  /// ([_leftRightLeftSequence]) — read off horizontal direction like 𑻮
  /// and 𑻱 — where that last leftward run is taller than it is wide, i.e.
  /// the stroke doesn't just double back a third time but drops away.
  MakasarCharacter? _classifySa(Stroke stroke) {
    if (!_matchesHorizontalSequence(stroke, _leftRightLeftSequence)) {
      return null;
    }
    final away = _boundsOf(_splitByHorizontalDirectionChange(stroke).last);
    return away.height > away.width ? MakasarCharacter.sa : null;
  }

  /// 𑻱: one stroke sweeping sideways five times over, starting leftward
  /// ([_leftRightLeftRightLeftSequence]) — 𑻮's own alternating shape with
  /// two more sweeps, and read off horizontal direction the same way.
  MakasarCharacter? _classifyA(Stroke stroke) =>
      _matchesHorizontalSequence(stroke, _leftRightLeftRightLeftSequence)
          ? MakasarCharacter.a
          : null;

  bool _isAngkaShaped(Stroke stroke) {
    if (!_matchesVerticalSequence(stroke, _hookedWedgeSequence)) return false;
    final extents = [
      for (final segment in _splitByVerticalDirectionChange(stroke))
        (segment.last.dy - segment.first.dy).abs(),
    ];
    return extents.first >= 2 * extents[1] && extents.first >= 2 * extents[2];
  }

  /// 𑻩: a stroke that crosses itself twice, once near where it starts
  /// and once near where it ends — the two bowls looping back over the
  /// wedge's arms — with everything between those two crossings reading
  /// as the wedge itself, up then down.
  ///
  /// "Near the start" is the first crossing's earlier stretch falling in
  /// the opening third of the stroke, and "near the end" the second
  /// crossing's later stretch falling in the closing third: at each
  /// crossing one of the two stretches is the arm and the other the bowl
  /// closing over it, and it's the arm that dates the first crossing
  /// while the bowl dates the last.
  MakasarCharacter? _classifyCa(Stroke stroke) {
    final spans = _selfIntersectionSpans(stroke);
    if (spans.length != 2) return null;

    final length = stroke.points.length;
    if (spans.first.$1 > length / 3) return null;
    if (spans.last.$2 < length * 2 / 3) return null;

    final between = stroke.points.sublist(spans.first.$2, spans.last.$1 + 1);
    if (between.length < 2) return null;
    return _matchesVerticalSequence(Stroke(between), _wedgeSequence)
        ? MakasarCharacter.ca
        : null;
  }

  /// 𑻫: the same idea one wedge further — a triple wedge in one stroke,
  /// crossing its own path twice.
  MakasarCharacter? _classifyNya(Stroke stroke) =>
      _isTripleWedge(stroke) && _selfIntersections(stroke) == 2
          ? MakasarCharacter.nya
          : null;

  /// Whether [stroke] is a wedge (`Λ`): one stroke that goes up, then back
  /// down ([_verticalDirectionSequence]), and is wide enough relative to
  /// its height not to be a hairpin ([_minWedgeAspect]).
  bool _isWedge(Stroke stroke) => _isWedgeShaped(stroke, _wedgeSequence);

  /// Whether [stroke] is a double wedge (`ΛΛ`): two wedges in a row
  /// without lifting the pen, so up-down-up-down in one stroke. This is
  /// how the two-wedge letters are written — 𑻡 and 𑻥 are a double wedge
  /// plus a mark underneath.
  bool _isDoubleWedge(Stroke stroke) =>
      _isWedgeShaped(stroke, _doubleWedgeSequence);

  /// Whether [stroke] is a triple wedge (`ΛΛΛ`) — three wedges in one
  /// stroke, which with two self-crossings is 𑻫 (see [_classifyNya]).
  bool _isTripleWedge(Stroke stroke) =>
      _isWedgeShaped(stroke, _tripleWedgeSequence);

  bool _isWedgeShaped(Stroke stroke, List<bool> sequence) {
    if (!_matchesVerticalSequence(stroke, sequence)) return false;
    final bounds = _boundsOf(stroke.points);
    return bounds.width >= bounds.height * _minWedgeAspect;
  }

  /// Whether [stroke] is a chevron (`V`) or bowl (`U`) — a wedge upside
  /// down, down then back up. Nothing distinguishes the wide form from
  /// the narrow one any more: 𑻤 is the only letter with a down-then-up
  /// mark under a double wedge, and 𑻦 the only one with a down-then-up
  /// mark under a single wedge, so either proportion reads as the same
  /// element.
  bool _isChevronShaped(Stroke stroke) =>
      _matchesVerticalSequence(stroke, _chevronSequence);

  /// Whether [stroke]'s vertical-direction segments are exactly
  /// [expected] — one of [_wedgeSequence] / [_hookedWedgeSequence] /
  /// [_doubleWedgeSequence] / [_tripleWedgeSequence] / [_chevronSequence].
  bool _matchesVerticalSequence(Stroke stroke, List<bool> expected) {
    final sequence = _verticalDirectionSequence(stroke);
    return sequence != null && listEquals(sequence, expected);
  }

  /// Whether [stroke]'s horizontal-direction segments are exactly
  /// [expected] — [_leftThenRightSequence], for 𑻵's mark.
  bool _matchesHorizontalSequence(Stroke stroke, List<bool> expected) {
    final sequence = _horizontalDirectionSequence(stroke);
    return sequence != null && listEquals(sequence, expected);
  }

  /// The down-ness (true = down, false = up) of each of [stroke]'s
  /// vertical-direction segments, or null if any of them is shorter than
  /// [_minArmExtent] — an arm that short is a flick at the end of a
  /// stroke, not an element of a letter. Consecutive segments always
  /// alternate, so a sequence is fully described by its length and which
  /// way it starts.
  List<bool>? _verticalDirectionSequence(Stroke stroke) => _directionSequence(
        _splitByVerticalDirectionChange(stroke),
        (point) => point.dy,
      );

  /// The right-ness (true = rightward) of each of [stroke]'s
  /// horizontal-direction segments — the sideways counterpart of
  /// [_verticalDirectionSequence].
  List<bool>? _horizontalDirectionSequence(Stroke stroke) => _directionSequence(
        _splitByHorizontalDirectionChange(stroke),
        (point) => point.dx,
      );

  List<bool>? _directionSequence(
      List<List<Offset>> segments, double Function(Offset) along) {
    if (segments.length < 2) return null;
    for (final segment in segments) {
      if ((along(segment.last) - along(segment.first)).abs() < _minArmExtent) {
        return null;
      }
    }
    return [
      for (final segment in segments)
        along(segment.last) > along(segment.first),
    ];
  }

  /// Splits [stroke] wherever its vertical direction reverses, cutting at
  /// the turning point itself and ignoring reversals shorter than
  /// [_directionNoise] — so a hand-drawn arm that wobbles on its way up
  /// stays one segment, and only the apex actually splits a wedge in two.
  List<List<Offset>> _splitByVerticalDirectionChange(Stroke stroke) =>
      _splitByDirectionChange(stroke.points, (point) => point.dy);

  /// The sideways counterpart of [_splitByVerticalDirectionChange].
  List<List<Offset>> _splitByHorizontalDirectionChange(Stroke stroke) =>
      _splitByDirectionChange(stroke.points, (point) => point.dx);

  List<List<Offset>> _splitByDirectionChange(
      List<Offset> points, double Function(Offset) along) {
    if (points.length < 2) return [];

    final segments = <List<Offset>>[];
    var start = 0;
    // The furthest point reached along the current direction — where the
    // stroke gets cut if it then doubles back far enough.
    var extreme = 0;
    bool? goingForward;

    for (var i = 1; i < points.length; i++) {
      final delta = along(points[i]) - along(points[extreme]);
      if (goingForward == null) {
        // Still too flat to have a direction at all.
        if (delta.abs() >= _directionNoise) {
          goingForward = delta > 0;
          extreme = i;
        }
        continue;
      }
      if (goingForward ? delta >= 0 : delta <= 0) {
        extreme = i;
      } else if (delta.abs() >= _directionNoise) {
        segments.add(points.sublist(start, extreme + 1));
        start = extreme;
        goingForward = !goingForward;
        extreme = i;
      }
    }
    segments.add(points.sublist(start));
    return segments;
  }

  /// How many times [stroke] crosses its own path — what tells 𑻥's
  /// closed mark from 𑻡's open wedge (see [_classifyMa]).
  int _selfIntersections(Stroke stroke) =>
      _selfIntersectionSpans(stroke).length;

  /// Every place [stroke] crosses its own path, as the pair of point
  /// indices whose segments meet: the earlier stretch of the stroke, then
  /// the later one running back over it. Only non-adjacent segments count
  /// (an index gap of at least 2), deduplicated so one real crossing
  /// sampled across several nearby points still counts once.
  ///
  /// 𑻩 needs the positions, not just the count, to tell where along the
  /// stroke each crossing happened (see [_classifyCa]).
  List<(int, int)> _selfIntersectionSpans(Stroke stroke) {
    final points = stroke.points;
    final spans = <(int, int)>[];
    for (var i = 0; i < points.length - 1; i++) {
      for (var j = i + 2; j < points.length - 1; j++) {
        if (!_segmentsIntersect(
            points[i], points[i + 1], points[j], points[j + 1])) {
          continue;
        }
        // One real crossing is picked up by several neighbouring pairs of
        // segments, so it only counts as new if no crossing already found
        // is close along *both* stretches. Comparing both is what lets a
        // stroke double back over an earlier part of itself after having
        // crossed a later one — ᨖ does exactly that, and reading the two
        // as one would leave it a crossing short.
        final seen = spans.any(
            (span) => (span.$1 - i).abs() <= 2 && (span.$2 - j).abs() <= 2);
        if (!seen) spans.add((i, j));
      }
    }
    return spans;
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
}

/// How marks are drawn on a canvas: the ink of a stroke, the two sizes of
/// tap, and the half-transparent preview of the stroke in progress. Shared
/// by [MakasarLayer] and `WritingLayer` so a character looks the same
/// however it's being read.
class MakasarInk {
  /// A tap alongside a stroke is a plain filled dot — a vowel sign on a
  /// letter is small, written against the letter. A tap on its own is a
  /// hollow circle of [dotRadius], the size the punctuation marks are read
  /// at ([MakasarRecognizer.recognizedNames]'s passimbang and end of
  /// section), which also makes the run of them easy to count while
  /// writing.
  static const double dotRadius = MakasarRecognizer._dotRadius;
  static const double plainDotRadius = 4;

  static const Color color = Color(0xFF1B2A4A);

  static final Paint _stroke = Paint()
    ..color = color
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  static final Paint _circledTap = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;
  static final Paint _plainTap = Paint()..color = color;
  static final Paint _preview = Paint()
    ..color = color.withValues(alpha: 0.5)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;

  static void drawMarks(
    Canvas canvas, {
    required List<Stroke> strokes,
    required List<Offset> dots,
    List<Offset>? preview,
  }) {
    for (final stroke in strokes) {
      drawPath(canvas, stroke.points, _stroke);
    }
    for (final dot in dots) {
      if (_sharesXRangeWithAny(dot, strokes)) {
        canvas.drawCircle(dot, plainDotRadius, _plainTap);
      } else {
        canvas.drawCircle(dot, dotRadius, _circledTap);
      }
    }
    if (preview != null) drawPath(canvas, preview, _preview);
  }

  /// Whether the circle [dot] would occupy overlaps the x range of any of
  /// [strokes] — i.e. whether the tap was placed against something rather
  /// than in clear space. Only how it's drawn depends on this; what it's
  /// recognized as doesn't.
  static bool _sharesXRangeWithAny(Offset dot, List<Stroke> strokes) {
    final left = dot.dx - dotRadius;
    final right = dot.dx + dotRadius;
    for (final stroke in strokes) {
      var strokeLeft = stroke.points.first.dx;
      var strokeRight = strokeLeft;
      for (final point in stroke.points) {
        if (point.dx < strokeLeft) strokeLeft = point.dx;
        if (point.dx > strokeRight) strokeRight = point.dx;
      }
      if (left <= strokeRight && strokeLeft <= right) return true;
    }
    return false;
  }

  static void drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], paint);
    }
  }

  /// The glyph(s) a recognizer read, in the Makasar font — a letter plus
  /// its vowel sign.
  ///
  /// Empty when nothing was recognized, and empty for Lontara whatever was:
  /// nothing in the bundle covers the Buginese block, so a Lontara reading
  /// is shown by name instead ([MakasarRecognizer.recognizedSyllable]).
  static String glyphsOf(MakasarRecognizer recognizer) {
    final character = recognizer.character;
    if (character == null || recognizer.script != WritingScript.makasar) {
      return '';
    }
    return '${character.glyph}${recognizer.vowel?.glyph ?? ''}';
  }

  /// The letterforms a recognizer read, as `assets/makasar/glyphs` stems — what
  /// gets drawn under a reading whichever script it was read in, and the
  /// only picture there is of a New Lontara one.
  static List<String> glyphImagesOf(MakasarRecognizer recognizer) =>
      glyphImagesFor(
        recognizer.script,
        name: recognizer.character?.letterName,
        vowel: recognizer.vowel?.vowel,
      );

  /// The same as one character: the letterform and the mark written on it,
  /// which is what [drawGlyphClusters] takes.
  static GlyphCluster glyphClusterOf(MakasarRecognizer recognizer) =>
      glyphClusterFor(
        recognizer.script,
        name: recognizer.character?.letterName,
        vowel: recognizer.vowel?.vowel,
      );

  /// The `sign_*` stems a vowel sign can be composed onto its letter from —
  /// every one the character tables use, which a test holds this to. A sign
  /// missing from it would quietly go undrawn, leaving the letter reading
  /// as if it carried its inherent `a`.
  static Iterable<String> get composableSigns => _signGeometry.keys;

  /// How tall a letterform is drawn under a reading.
  static const double glyphImageHeight = 34;

  /// The gap left between one character and the next.
  static const double _glyphImageGap = 8;

  /// Draws [clusters] left to right with their letterforms' tops at [at],
  /// each letter at [glyphImageHeight] and its own width, inked in the same
  /// colour the marks are so the reading and what drew it match.
  ///
  /// A vowel sign is drawn **on** its letter, at the place the letter's own
  /// size puts it — above, below, in front or behind ([_placeMark]) — so a
  /// syllable is one picture and a written row reads as a word. Drawn side
  /// by side instead, as the images come, ki would read as ka followed by
  /// a mark on an empty circle.
  ///
  /// One still being decoded takes no room rather than shifting the rest
  /// along: they come in within a frame or two of being asked for, and a
  /// row that settles into place reads better than one that slides.
  static void drawGlyphClusters(
    Canvas canvas,
    List<GlyphCluster> clusters,
    Offset at,
  ) {
    final paint = Paint()
      ..colorFilter = const ColorFilter.mode(color, BlendMode.srcIn)
      ..filterQuality = FilterQuality.medium;
    var x = at.dx;
    for (final cluster in clusters) {
      final laid = _layOut(cluster, at.dy);
      if (laid == null) continue;
      // The whole character is moved as one, so a mark reaching out in
      // front of its letter (-e) isn't cut off at the start of the row.
      final shift = Offset(x - laid.bounds.left, 0);
      canvas.drawImageRect(
        laid.letter,
        laid.letterSource,
        laid.letterBox.shift(shift),
        paint,
      );
      final sign = laid.sign;
      if (sign != null) {
        canvas.drawImageRect(
          sign,
          laid.markSource!,
          laid.markBox!.shift(shift),
          paint,
        );
      }
      x += laid.bounds.width + _glyphImageGap;
    }
  }

  /// How far above and below the letterforms a row of [clusters] reaches —
  /// the room its vowel signs need, which is nothing until one is drawn.
  /// The scenes ask before painting, so the reading above the row is lifted
  /// only by as much as the marks actually take.
  static ({double above, double below}) glyphClusterOverhang(
    List<GlyphCluster> clusters,
  ) {
    var above = 0.0, below = 0.0;
    for (final cluster in clusters) {
      final laid = _layOut(cluster, 0);
      if (laid == null) continue;
      above = math.max(above, -laid.bounds.top);
      below = math.max(below, laid.bounds.bottom - glyphImageHeight);
    }
    return (above: above, below: below);
  }

  /// One character laid out with the letter band's top at [top] and the
  /// character's left edge at 0 — null while the letterform is still being
  /// decoded, or when there is no letterform to draw (angka, or nothing
  /// read).
  ///
  /// Every letterform image is drawn on the same grid, whichever of the two
  /// sizes the file is: the letter sits in [_letterBox] on it, which is the
  /// very box the `sign_*` images draw their dotted circle in. So a mark
  /// needs no placing — drawn at its own place on that grid it lands on the
  /// letter correctly, whatever letter it is. All that is left to do is
  /// leave the circle out (only [_SignGeometry.mark] is drawn), crop the
  /// margins off (each image's own [GlyphImages.inkOf]), and scale the grid
  /// so a letter stands [glyphImageHeight] tall.
  static _LaidOutCluster? _layOut(GlyphCluster cluster, double top) {
    final letterName = cluster.letter;
    if (letterName == null) return null;
    final letter = GlyphImages.of(letterName);
    final ink = GlyphImages.inkOf(letterName);
    if (letter == null || ink == null) return null;

    // The whole grid at the size that makes [_letterBox] stand
    // [glyphImageHeight] tall — so letters keep their sizes relative to
    // each other rather than all being squeezed to one height.
    final gridHeight = glyphImageHeight / _letterBox.height;
    final gridWidth = gridHeight * letter.width / letter.height;
    Rect place(Rect on) => Rect.fromLTRB(
          on.left * gridWidth,
          top + (on.top - _letterBox.top) * gridHeight,
          on.right * gridWidth,
          top + (on.bottom - _letterBox.top) * gridHeight,
        );

    final letterBox = place(ink);
    final signName = cluster.vowel;
    final sign = signName == null ? null : GlyphImages.of(signName);
    final geometry = signName == null ? null : _signGeometry[signName];
    if (sign == null || geometry == null) {
      return _LaidOutCluster(letter, _pixels(letter, ink), letterBox, null,
          null, null, letterBox);
    }
    final markBox = place(geometry.mark);
    return _LaidOutCluster(
      letter,
      _pixels(letter, ink),
      letterBox,
      sign,
      _pixels(sign, geometry.mark),
      markBox,
      letterBox.expandToInclude(markBox),
    );
  }

  /// A box given as fractions of [image], in that image's own pixels.
  static Rect _pixels(ui.Image image, Rect fractions) => Rect.fromLTRB(
        fractions.left * image.width,
        fractions.top * image.height,
        fractions.right * image.width,
        fractions.bottom * image.height,
      );
}

/// Where a letter sits on the grid the letterform images share, as
/// fractions of one — and so also where the `sign_*` images put the dotted
/// circle that stands in for it. Measured off the assets, which draw every
/// character to the same layout at one of two resolutions.
const Rect _letterBox = Rect.fromLTRB(0.396, 0.336, 0.608, 0.692);

/// One character as it is drawn: the letterform's `assets/makasar/glyphs`
/// stem, and the vowel sign written on it. Either may be missing — nothing
/// read, no sign on it, or a character with no image of it (angka).
typedef GlyphCluster = ({String? letter, String? vowel});

/// A character ready to paint: its letterform, where that goes, and the
/// vowel sign cropped out of its `sign_*` image and placed on it. The boxes
/// are all in canvas coordinates bar the two sources, which are in their
/// own image's pixels.
class _LaidOutCluster {
  const _LaidOutCluster(
    this.letter,
    this.letterSource,
    this.letterBox,
    this.sign,
    this.markSource,
    this.markBox,
    this.bounds,
  );

  final ui.Image letter;

  /// The part of the letterform image that is ink — the margins around it
  /// are what would set a row of characters wide apart.
  final Rect letterSource;
  final Rect letterBox;
  final ui.Image? sign;

  /// The part of the `sign_*` image that is the mark itself — the dotted
  /// circle beside it stands in for the letter and is left out.
  final Rect? markSource;
  final Rect? markBox;

  /// Letter and mark together, which is what the row advances by.
  final Rect bounds;
}

/// Where the mark sits in each `sign_*` image, as fractions of it —
/// measured off the assets themselves.
///
/// The rest of the image is the dotted circle standing in for the letter
/// the mark attaches to. It is never drawn: the letter itself is there
/// instead, in the very box the circle occupies ([_letterBox]).
class _SignGeometry {
  const _SignGeometry(this.mark);

  /// The mark itself, which is all that gets drawn.
  final Rect mark;
}

const _signGeometry = <String, _SignGeometry>{
  // The dot above.
  'sign_i': _SignGeometry(Rect.fromLTRB(0.392, 0.137, 0.452, 0.233)),
  // The dot below.
  'sign_u': _SignGeometry(Rect.fromLTRB(0.572, 0.733, 0.628, 0.829)),
  // The hook in front of the letter…
  'sign_e': _SignGeometry(Rect.fromLTRB(0.260, 0.397, 0.384, 0.842)),
  // …and the one behind it.
  'sign_o': _SignGeometry(Rect.fromLTRB(0.620, 0.390, 0.848, 0.842)),
  // Lontara's own, a hook above — drawn on the smaller of the two image
  // sizes, which is the same grid at half the resolution.
  'sign_ae': _SignGeometry(Rect.fromLTRB(0.458, 0.000, 0.542, 0.286)),
};

/// A whole canvas given over to one character: collects marks, hands them
/// to a single [MakasarRecognizer], and draws them with the readout of
/// what they came to underneath.
class MakasarLayer extends Layer {
  final MakasarRecognizer recognizer = MakasarRecognizer();

  /// Every finished mark, in the order it was drawn — kept so the last one
  /// can be taken back ([undo]). The recognizer sorts each mark into a
  /// stroke or a tap as it arrives and has no memory of which came last,
  /// so the order is the layer's to hold.
  final List<List<Offset>> _marks = [];
  List<Offset>? _activePoints;

  /// See [MakasarRecognizer.recognizedNamesFor] /
  /// [MakasarRecognizer.recognizedVowelsFor] — re-exposed so the hosting
  /// page doesn't have to reach past the layer for them.
  static Set<String> recognizedNamesFor(WritingScript script) =>
      MakasarRecognizer.recognizedNamesFor(script);
  static Set<String> recognizedVowelsFor(WritingScript script) =>
      MakasarRecognizer.recognizedVowelsFor(script);

  String? get recognizedName => recognizer.recognizedName;
  String? get recognizedVowel => recognizer.recognizedVowel;
  String? get recognizedSyllable => recognizer.recognizedSyllable;

  /// Which script the canvas reads — wipes it on a change, see
  /// [MakasarRecognizer.script].
  set script(WritingScript script) {
    recognizer.script = script;
    _marks.clear();
    _activePoints = null;
  }

  void clear() {
    recognizer.clear();
    _marks.clear();
    _activePoints = null;
  }

  /// Drops the mark drawn most recently and reads the character again.
  ///
  /// Read again from the marks that are left rather than unpicked: a
  /// reading is made of whatever is on the paper at the time, and taking a
  /// mark away can leave what remains reading as something else entirely —
  /// 𑻥 without its loop is nothing, 𑻸 without its sixth tap is 𑻷.
  ///
  /// Does nothing on an empty canvas, so the button offering it needn't
  /// know whether there is anything to take back.
  void undo() {
    if (_marks.isEmpty) return;
    _marks.removeLast();
    recognizer.clear();
    for (final mark in _marks) {
      recognizer.addMark(mark);
    }
    _activePoints = null;
  }

  @override
  void handlePointerEvent(PointerEvent event, Size size) {
    if (event is PointerDownEvent) {
      _activePoints = [event.localPosition];
    } else if (event is PointerMoveEvent && _activePoints != null) {
      _activePoints!.add(event.localPosition);
    } else if (event is PointerUpEvent && _activePoints != null) {
      _marks.add(_activePoints!);
      recognizer.addMark(_activePoints!);
      _activePoints = null;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    MakasarInk.drawMarks(
      canvas,
      strokes: recognizer.strokes,
      dots: recognizer.dots,
      preview: _activePoints,
    );

    final character = recognizer.character;
    final vowel = recognizer.vowel;
    // Empty for a Lontara reading, which has no font to be shown in — the
    // letterform drawn under the text carries it there, and the
    // description goes unbracketed beside it.
    final glyphs = MakasarInk.glyphsOf(recognizer);
    final description = character == null || character.sound == null
        ? character?.letterName ?? ''
        : '${recognizer.recognizedSyllable} — '
            '"${character.sound}${vowel?.vowel ?? 'a'}"';
    final label = TextPainter(
      text: character != null
          ? TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              children: [
                const TextSpan(text: 'Recognized: '),
                if (glyphs.isNotEmpty)
                  TextSpan(
                    text: '$glyphs  ',
                    style: const TextStyle(
                      fontFamily: 'NotoSerifMakasar',
                      fontSize: 22,
                    ),
                  ),
                TextSpan(text: glyphs.isEmpty ? description : '($description)'),
              ],
            )
          : TextSpan(
              text: recognizer.script == WritingScript.makasar
                  ? 'Draw a letter below to see it recognized'
                  // Which letters those are is already on show underneath,
                  // and by name rather than glyph: no font here covers
                  // Lontara.
                  : 'Draw a letter below — the characters not greyed out '
                      'underneath are the ones read so far',
              style: const TextStyle(color: Colors.black54, fontSize: 16),
            ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);

    // The letterform sits under the text, along the foot of the page, and
    // the text is lifted to make room for it — so the reading reads down:
    // what it is, then what it looks like drawn. A vowel sign is part of
    // that letterform rather than a second picture beside it, so what is
    // drawn for ka plus the -i mark is ki.
    final clusters = [MakasarInk.glyphClusterOf(recognizer)];
    final overhang = MakasarInk.glyphClusterOverhang(clusters);
    final glyphTop =
        size.height - 24 - overhang.below - MakasarInk.glyphImageHeight;
    if (clusters.first.letter == null) {
      label.paint(canvas, Offset(24, size.height - 24 - label.height));
      return;
    }
    label.paint(
      canvas,
      Offset(24, glyphTop - overhang.above - 8 - label.height),
    );
    MakasarInk.drawGlyphClusters(canvas, clusters, Offset(24, glyphTop));
  }
}

/// Builds the scene plus a direct reference to its [MakasarLayer], so the
/// hosting page can call [MakasarLayer.clear] from the Clear button.
(Scene, MakasarLayer) buildMakasarScene() {
  final layer = MakasarLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
