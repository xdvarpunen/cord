import 'package:flutter/material.dart';

import '../data/elder_futhark.dart';
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
    for (double y = _spacing; y < size.height; y += _spacing) {
      for (double x = _spacing; x < size.width; x += _spacing) {
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

/// Which rune row [FutharkLayer] recognizes for. The gesture classifiers
/// themselves are shape-based and shared between the modes: an Elder
/// Futhark rune whose glyph is identical to its Younger long-branch
/// counterpart (ᚠ ᚢ ᚦ ᚱ ᚾ ᛁ ᛏ ᛒ ᛚ) reuses the Younger classifier as-is,
/// and Elder mode adds classifiers for its own shapes (ᚨ ᚲ ᚷ ᚹ ᛉ ᚺ ᛃ ᛜ
/// ᛇ ᛈ ᛊ ᛖ ᛗ ᛞ ᛟ) — [FutharkLayer._recognizedRunes] says which shapes
/// count in each mode.
enum FutharkAlphabet {
  younger('Younger Futhark'),
  elder('Elder Futhark');

  const FutharkAlphabet(this.label);

  /// Display name, as shown in [FutharkPage]'s alphabet dropdown.
  final String label;
}

/// The rune shapes the recognizer knows how to draw, one enum case per
/// shape — more get added the same way tifi added Tifinagh letters, one
/// classifier at a time. Each case carries the rune's glyph, name, and
/// the transliteration letter used to match against
/// [YoungerFutharkRow.translit] / [ElderFutharkRow.translit] — Younger
/// long-branch identity for the shapes Younger has, Elder identity for
/// the Elder-only shapes at the end. In Elder mode
/// ([FutharkAlphabet.elder]) the shared shapes are reported under their
/// Elder identity — glyph and name looked up from [elderFutharkRows] at
/// paint time (ᚠ announces as *fehu, not fé).
enum _FutharkRune {
  /// ᛁ (íss, "i") — a single vertical stroke, the full-height stave with
  /// no branches at all.
  iss('ᛁ', 'íss', 'i'),

  /// ᚾ (nauðr, "n") — a vertical stave crossed by one descending branch
  /// around its middle (reaching neither of the stave's outer quarters).
  naudr('ᚾ', 'nauðr', 'n'),

  /// ᚬ (áss, "ą") — a vertical stave crossed by two descending branches.
  ass('ᚬ', 'áss', 'ą'),

  /// ᛅ (ár, "a") — same construction as ᚾ, but the branch ascends: a
  /// vertical stave crossed by one ascending branch.
  ar('ᛅ', 'ár', 'a'),

  /// ᚠ (fé, "f") — same construction as ᚬ, but the branches ascend: a
  /// vertical stave crossed by two ascending branches.
  fe('ᚠ', 'fé', 'f'),

  /// ᚴ (kaun, "k") — same two strokes as ᛅ (a stave crossed by one
  /// ascending branch), told apart by where the branch sits: its center
  /// is up in the stave's top-right, rather than around the middle.
  kaun('ᚴ', 'kaun', 'k'),

  /// ᛦ (ýr, "ʀ") — a vertical stave crossed, below its center, by a
  /// bent stroke that reads as ascending-then-descending when split by
  /// vertical direction change.
  yr('ᛦ', 'ýr', 'ʀ'),

  /// ᚼ (hagall, "h") — a vertical stave crossed by one ascending and
  /// one descending branch.
  hagall('ᚼ', 'hagall', 'h'),

  /// ᛋ (sól, "s") — a single stroke whose vertical direction reads
  /// down, then up while ascending, then down again.
  sol('ᛋ', 'sól', 's'),

  /// ᚢ (úr, "u") — a single stroke whose vertical direction reads up,
  /// then down while descending — the arch.
  ur('ᚢ', 'úr', 'u'),

  /// ᛘ (maðr, "m") — a vertical stave crossed, above its center, by a
  /// bent stroke that reads as down-then-up when split by vertical
  /// direction change — ᛦ upside down.
  madr('ᛘ', 'maðr', 'm'),

  /// ᛏ (Týr, "t") — like ᛘ, but the bent stroke reads as up-then-down:
  /// a "∧" over the stave's top.
  tyr('ᛏ', 'Týr', 't'),

  /// ᚦ (þurs, "þ") — a vertical stave crossed by a bent stroke that
  /// splits horizontally into down-right then down-left: the pocket.
  thurs('ᚦ', 'þurs', 'þ'),

  /// ᚱ (reið, "r") — a stave plus a bow-and-leg part whose horizontal
  /// runs go right, left, right — either as one stroke (stave first,
  /// then the bow-and-leg without lifting) or as two.
  reid('ᚱ', 'reið', 'r'),

  /// ᛒ (bjǫrk, "b") — ᚱ with one more bend: the bow part's horizontal
  /// runs go right, left, right, left — the two stacked pockets.
  bjork('ᛒ', 'bjǫrk', 'b'),

  /// ᛚ (lǫgr, "l") — a single stroke: a vertical line, then a
  /// descending flick that stays on one side of the line's mid-height.
  logr('ᛚ', 'lǫgr', 'l'),

  // Elder-only shapes below — no Younger counterpart, so they carry the
  // Elder glyph and Proto-Germanic name directly and are recognized only
  // in [FutharkAlphabet.elder] mode ([FutharkLayer._recognizedRunes]).

  /// ᚨ (*ansuz, "a") — ᚬ's construction (a stave crossed by two
  /// descending branches), but with both branches sitting above the
  /// stave's midpoint — Latin "F" with drooping bars.
  ansuz('ᚨ', '*ansuz', 'a'),

  /// ᚲ (*kauną, "k") — a single stroke, one vertical run, whose
  /// horizontal runs read left then right — the "<".
  kauna('ᚲ', '*kauną', 'k'),

  /// ᚷ (*gebō, "g") — two crossing diagonals, one ascending and one
  /// descending, each running the other's whole height — the "X".
  gebo('ᚷ', '*gebō', 'g'),

  /// ᚹ (*wunjō, "w") — ᚱ without the leg: a stave plus a bow whose
  /// horizontal runs read right then left, hanging off the stave rather
  /// than crossing it (a crossing pocket reads as ᚦ instead) — Latin
  /// "P".
  wunjo('ᚹ', '*wunjō', 'w'),

  /// ᛉ (*algiz, "z") — ᛘ's gesture exactly (Younger ᛘ descends from ᛉ,
  /// so the shapes coincide): a stave plus a bent branch above its
  /// center whose vertical runs go down then up.
  algiz('ᛉ', '*algiz', 'z'),

  /// ᚺ (*hagalaz, "h") — two staves plus one descending crossbar
  /// crossing both around their middles — Latin "N".
  hagalaz('ᚺ', '*hagalaz', 'h'),

  /// ᛃ (*jēra-, "j") — two strokes: ᚲ's chevron ("<") and its mirror
  /// (">"), drawn in either order, with overlapping bounding boxes but
  /// never touching — the rune's two interlocking halves.
  jera('ᛃ', '*jēra-', 'j'),

  /// ᛜ (*ingwaz, "ŋ") — ᛃ's mirrored chevron pair, but with the two
  /// strokes crossing twice, once up and once down — the diamond.
  ingwaz('ᛜ', '*ingwaz', 'ŋ'),

  /// ᛇ (*ī(h)waz, "ï") — a single stroke whose vertical runs read
  /// down, up, down — the vertical zigzag.
  ihwaz('ᛇ', '*ī(h)waz', 'ï'),

  /// ᛈ (*perþō, "p") — a single stroke whose vertical runs read down,
  /// up, down, up, down — ᛇ's zigzag with one more bend.
  perth('ᛈ', '*perþō', 'p'),

  /// ᛊ (*sōwilō, "s") — a single stroke whose horizontal runs read
  /// left, right, left, right — the sideways zigzag.
  sowilo('ᛊ', '*sōwilō', 's'),

  /// ᛖ (*ehwaz, "e") — a single stroke whose vertical runs read up,
  /// down, up, down — Latin "M" drawn without lifting.
  ehwaz('ᛖ', '*ehwaz', 'e'),

  /// ᛗ (*mannaz, "m") — two "∧" strokes (each splitting vertically
  /// into up then down) crossing each other.
  mannaz('ᛗ', '*mannaz', 'm'),

  /// ᛞ (*dagaz, "d") — ᛖ's up, down, up, down, but with the first down
  /// descending ("\") and the second ascending ("/") — the bowtie.
  dagaz('ᛞ', '*dagaz', 'd'),

  /// ᛟ (*ōþala-, "o") — a single stroke with 2 vertical runs, up then
  /// down, the up run traveling right then left, the down run left
  /// then right, crossing itself where the legs meet — the diamond on
  /// legs.
  othala('ᛟ', '*ōþala-', 'o');

  const _FutharkRune(this.glyph, this.runeName, this.translit);
  final String glyph;
  final String runeName;
  final String translit;
}

/// Freehand recognition of Younger Futhark runes in their long-branch
/// forms (per Wikipedia's "Younger Futhark" article — see
/// `younger_futhark.dart` for the full table). Runes are built from
/// straight strokes around a vertical stave:
///
/// - ᛁ (íss, "i") — a single vertical line, nothing else.
/// - ᚾ (nauðr, "n") — a vertical stave plus a descending branch that
///   crosses it around the middle: the branch reaches neither the
///   stave's top quarter nor its bottom quarter (y-range split into 4,
///   the same rule as ᚴ's), which is what tells a branch from the second
///   diagonal of an X (ᚷ) running the stave's whole height.
/// - ᚬ (áss, "ą") — a vertical stave plus two descending branches, each
///   crossing it.
/// - ᛅ (ár, "a") — same construction as ᚾ, but the crossing branch
///   ascends instead of descends.
/// - ᚠ (fé, "f") — same construction as ᚬ, but both crossing branches
///   ascend instead of descend.
/// - ᚴ (kaun, "k") — the same two strokes as ᛅ; the two are told apart
///   by height ([_classifyKaun] is checked first): split the stave's
///   y-range into 4 quarters, and a branch whose y-range visits the top
///   quarter reads as ᚴ, one that stays below it as ᛅ.
/// - ᛦ (ýr, "ʀ") — a vertical stave plus a bent branch, centered below
///   the stave's midpoint, that crosses the stave and splits (by
///   vertical direction change, same rule as tifi's ⴸ) into exactly 2
///   segments: ascending then descending.
/// - ᛘ (maðr, "m") — ᛦ upside down: the bent branch is centered *above*
///   the stave's midpoint and its 2 vertical runs go down then up.
/// - ᛏ (Týr, "t") — like ᛘ (bent branch above the stave's midpoint),
///   but its 2 vertical runs go up then down — a "∧" over the top,
///   where ᛘ's is a "∨". Vertical runs don't depend on which end the
///   branch is drawn from, so both are draw-direction-agnostic.
/// - ᚦ (þurs, "þ") — a stave crossed by a bent branch that splits
///   *horizontally* ([_horizontalRuns], the sideways counterpart of
///   [_verticalRuns]) into exactly 2 runs: down-right then down-left —
///   the ">" pocket bulging out of the stave.
/// - ᚱ (reið, "r") — the stave plus a bow-and-leg part whose horizontal
///   runs are exactly right, left, right. Two accepted gestures
///   ([_bowRuns]): a single stroke that splits vertically into exactly
///   2 runs — the first reading as a vertical line (the stave), the
///   second carrying the right-left-right pattern — or 2 strokes, where
///   the bow-and-leg stroke needs no vertical split at all (one
///   vertical direction end to end).
/// - ᛒ (bjǫrk, "b") — ᚱ with one more bend: the bow part's horizontal
///   runs are exactly right, left, right, left — the two stacked
///   pockets. Same two gestures as ᚱ.
/// - ᛚ (lǫgr, "l") — a single stroke that splits vertically into
///   exactly 2 runs: the first reading as a vertical line (the stave),
///   the second a descending flick whose y-range stays entirely on one
///   side of the stave run's mid-height — it must not cross that
///   center, which is also what keeps it distinct from ᚢ's arch.
/// - ᚼ (hagall, "h") — a vertical stave plus one ascending and one
///   descending branch, both crossing it — the mixed-direction sibling
///   of ᚬ (both descending) and ᚠ (both ascending).
/// - ᛋ (sól, "s") — a single stroke, no stave: its jitter-smoothed
///   vertical runs ([_verticalRuns]) are exactly down, up-while-
///   ascending, down — the lightning-bolt zigzag.
/// - ᚢ (úr, "u") — a single stroke, no stave: its vertical runs are
///   exactly up, then down-while-descending — the arch. The same bent
///   stroke drawn *across* a stave reads as ᛦ instead ([_classifyYr] is
///   a 2-stroke pattern and checked first).
///
/// The stave is whichever of the most recent strokes is the most
/// vertical ([_staveAndBranches]) — it must itself read as vertical by
/// the same rule as tifi/tally_hand's `_isVertical` (comparing only the
/// stroke's start/end points, whichever axis moved further wins) — and
/// every remaining stroke is a branch. Branches are deliberately *not*
/// held to that rule: a rune's branches are usually drawn steeper than
/// 45° (runes are tall), which would read as "vertical" too and, under a
/// per-stroke test, turn the branch into a second stave and kill the
/// match. Instead a branch counts as descending (reads as "\") when its
/// dominant horizontal and vertical travel directions agree — left-to-
/// right while going down, or right-to-left while going up
/// ([_isDescending]) — and as ascending ("/") when they disagree
/// ([_isAscending]), however steep it is; both are read off each axis's
/// widest-spanning segment ([_isLeftToRight]/[_isGoingDown], ported from
/// tifi) so draw direction and hand jitter don't matter. Branch-crossing
/// checks compare start/end chords only ([_segmentsIntersect], same as
/// tifi's grid check), since all strokes involved are straight lines.
///
/// Classification tries the largest pattern (most strokes) first, and
/// the most specific pattern first within a stroke count — ᚬ/ᚠ/ᚼ (3
/// strokes, mutually exclusive by branch direction) ahead of the
/// 2-stroke runes, where ᛦ/ᛘ/ᛏ (bent branch) are checked ahead of the
/// straight-branch ones (a bent branch's start/end chord could otherwise
/// pass for a straight ascending/descending branch) and ᚴ (position-
/// constrained) ahead of ᛅ (unconstrained), all ahead of the 1-stroke
/// runes, where ᛋ (zigzag) and ᚢ (arch) are checked ahead of ᛁ (bare
/// vertical, whose chord test a bent stroke can easily satisfy) —
/// so a completed ᚬ isn't reported as its ᚾ sub-pattern (nor ᚠ as its ᛅ
/// one), and every new stroke re-evaluates against the most recent
/// strokes.
///
/// Elder-only shapes — same construction toolkit, recognized only in
/// Elder mode ([FutharkAlphabet.elder]):
///
/// - ᚨ (*ansuz, "a") — ᚬ's construction (a stave plus two descending
///   branches, each crossing it) with both branches sitting above the
///   stave's midpoint (their bounds centers, same rule as ᛘ/ᛏ) — Latin
///   "F" with drooping bars. Checked ahead of ᚬ, the unconstrained
///   pattern, the same way ᚴ is checked ahead of ᛅ.
/// - ᚷ (*gebō, "g") — two crossing diagonals, one ascending and one
///   descending, each reaching both the top and bottom quarters of the
///   other's y-range — the "X". The mutual full-height rule (not a
///   steepness limit) separates ᚷ from the stave-plus-branch patterns,
///   so the X may be drawn as tall as any rune.
/// - ᚹ (*wunjō, "w") — ᚱ without the leg: the bow part's horizontal runs
///   are exactly right, left (one pocket) — told apart from ᚦ by the
///   pocket hanging off the stave rather than crossing it. Same two
///   gestures as ᚱ/ᛒ.
/// - ᚲ (*kauną, "k") — a single stroke with one vertical run whose
///   horizontal runs are exactly left, right — the "<" drawn tip → apex
///   → tip.
/// - ᛉ (*algiz, "z") — ᛘ's gesture exactly (a stave plus a bent branch
///   above its center, runs down then up): Younger ᛘ descends from ᛉ,
///   so the same shape spells "m" in Younger mode and "z" in Elder.
/// - ᚺ (*hagalaz, "h") — two staves plus one descending crossbar
///   crossing both around their middles (ᚾ's outer-quarters rule,
///   applied against each stave) — Latin "N".
/// - ᛃ (*jēra-, "j") — ᚲ's chevron plus its mirror image (">"), drawn
///   in either order, with overlapping bounding boxes but never
///   touching — the rune's two interlocking halves.
/// - ᛜ (*ingwaz, "ŋ") — the same mirrored chevron pair, but with the
///   two strokes crossing twice, once in the upper half and once in
///   the lower — the diamond.
/// - ᛇ (*ī(h)waz, "ï") — a single stroke whose vertical runs are
///   exactly down, up, down — like ᛋ, but without the ascending-middle
///   requirement (each alphabet has only one of the two).
/// - ᛈ (*perþō, "p") — down, up, down, up, down: ᛇ with one more bend.
/// - ᛖ (*ehwaz, "e") — up, down, up, down: Latin "M" drawn without
///   lifting.
/// - ᛊ (*sōwilō, "s") — the sideways zigzag: *horizontal* runs exactly
///   left, right, left, right.
/// - ᛗ (*mannaz, "m") — two "∧" strokes (each splitting vertically
///   into up then down) crossing each other.
/// - ᛞ (*dagaz, "d") — ᛖ's up, down, up, down, but with the first down
///   descending ("\") and the second ascending ("/") — the bowtie,
///   checked ahead of ᛖ, the unconstrained pattern.
/// - ᛟ (*ōþala-, "o") — 2 vertical runs, up then down, the up run
///   traveling right then left, the down run left then right, and the
///   stroke crossing itself where the legs meet — the diamond on legs,
///   traced without lifting.
///
/// Recognition is live and non-destructive — nothing is discarded;
/// strokes that don't match are still rendered, just reported as
/// unrecognized.
///
/// Which alphabet a matched shape counts for is a mode ([alphabet]):
/// every pattern in the classification order is gated on the current
/// alphabet having its rune ([_recognizedRunes]), and a blocked pattern
/// falls through to the next — in Elder mode a ᚴ gesture reports
/// unrecognized (Elder has no ᚴ) rather than a Younger rune, in Younger
/// mode ᚨ's position-constrained pattern steps aside so the same strokes
/// read as ᚬ, and the shapes Elder shares with the Younger long-branch
/// forms are announced under their Elder identity.
class FutharkLayer extends Layer {
  static const double _minDragDistance = 8;

  /// Which rune shapes count in each alphabet — enabled one rune at a
  /// time as classifiers are built. Keyed by shape rather than
  /// transliteration because the two alphabets can spell the same letter
  /// with different shapes: Younger "k" is ᚴ, Elder "k" is ᚲ.
  ///
  /// All 16 Younger shapes and all 24 Elder ones are covered: the Elder
  /// set is the 9 runes whose glyph — and thus gesture — is identical
  /// to its Younger long-branch counterpart (ᚠ ᚢ ᚦ ᚱ ᚾ ᛁ ᛏ ᛒ ᛚ) plus
  /// the 15 Elder-only shapes ᚨ ᚲ ᚷ ᚹ ᛉ ᚺ ᛃ ᛜ ᛇ ᛈ ᛊ ᛖ ᛗ ᛞ ᛟ.
  static const _recognizedRunes = {
    FutharkAlphabet.younger: {
      _FutharkRune.iss, _FutharkRune.naudr, _FutharkRune.ass,
      _FutharkRune.ar, _FutharkRune.fe, _FutharkRune.kaun,
      _FutharkRune.yr, _FutharkRune.hagall, _FutharkRune.sol,
      _FutharkRune.ur, _FutharkRune.madr, _FutharkRune.tyr,
      _FutharkRune.thurs, _FutharkRune.reid, _FutharkRune.bjork,
      _FutharkRune.logr,
    },
    FutharkAlphabet.elder: {
      // Shared with the Younger long-branch forms.
      _FutharkRune.fe, _FutharkRune.ur, _FutharkRune.thurs,
      _FutharkRune.reid, _FutharkRune.naudr, _FutharkRune.iss,
      _FutharkRune.tyr, _FutharkRune.bjork, _FutharkRune.logr,
      // Elder-only shapes (ᛉ shares ᛘ's gesture under its own letter).
      _FutharkRune.ansuz, _FutharkRune.kauna, _FutharkRune.gebo,
      _FutharkRune.wunjo, _FutharkRune.algiz, _FutharkRune.hagalaz,
      _FutharkRune.jera, _FutharkRune.ingwaz, _FutharkRune.ihwaz,
      _FutharkRune.perth, _FutharkRune.sowilo, _FutharkRune.ehwaz,
      _FutharkRune.mannaz, _FutharkRune.dagaz, _FutharkRune.othala,
    },
  };

  /// [_recognizedRunes] as transliterations — matched against
  /// [YoungerFutharkRow.translit] / [ElderFutharkRow.translit], and used
  /// by [FutharkPage] to mute not-yet-recognized runes in the legend
  /// rather than listing ones that can't actually be drawn yet.
  static final recognizedTranslit = {
    for (final MapEntry(key: alphabet, value: runes)
        in _recognizedRunes.entries)
      alphabet: {for (final rune in runes) rune.translit},
  };

  final List<_Stroke> _strokes = [];
  _FutharkRune? _recognized;
  List<Offset>? _activePoints;
  FutharkAlphabet _alphabet = FutharkAlphabet.younger;

  /// Which alphabet's runes to recognize. Setting it re-classifies the
  /// strokes already on the canvas — recognition is non-destructive, so
  /// the readout follows the mode switch without redrawing.
  FutharkAlphabet get alphabet => _alphabet;
  set alphabet(FutharkAlphabet value) {
    _alphabet = value;
    _recognized = _classify();
  }

  /// The transliteration of the most recently recognized rune, or null
  /// if the latest stroke(s) didn't match — read by tests; the on-canvas
  /// readout gets the same information via [paint].
  String? get recognized => _recognized?.translit;

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
      // Path length, not the start-to-end chord: the check only exists
      // to drop accidental taps, and a closed stroke (ᛞ's bowtie ends
      // where it began) has a near-zero chord but plenty of path.
      var dragDistance = 0.0;
      for (var i = 1; i < points.length; i++) {
        dragDistance += (points[i] - points[i - 1]).distance;
      }
      if (points.length >= 2 && dragDistance >= _minDragDistance) {
        _strokes.add(_Stroke(points));
        _recognized = _classify();
      }
      _activePoints = null;
    }
  }

  /// Classifies the most recently completed stroke(s), largest pattern
  /// first and the most specific pattern first within a stroke count
  /// (see the class doc). Every pattern is gated on the current
  /// [alphabet] having its rune ([_recognizedRunes]); a blocked pattern
  /// falls through to the next one, so ᚨ (Elder-only, position-
  /// constrained) steps aside in Younger mode and the same strokes read
  /// as ᚬ.
  _FutharkRune? _classify() {
    if (_strokes.isEmpty) return null;
    _FutharkRune? allow(_FutharkRune? rune) =>
        rune != null && _recognizedRunes[_alphabet]!.contains(rune)
            ? rune
            : null;
    return allow(_classifyAnsuz()) ??
        allow(_classifyAss()) ??
        allow(_classifyFe()) ??
        allow(_classifyHagall()) ??
        allow(_classifyHagalaz()) ??
        allow(_classifyYr()) ??
        allow(_classifyMadr()) ??
        allow(_classifyAlgiz()) ??
        allow(_classifyTyr()) ??
        allow(_classifyMannaz()) ??
        allow(_classifyIngwaz()) ??
        allow(_classifyJera()) ??
        allow(_classifyGebo()) ??
        allow(_classifyThurs()) ??
        allow(_classifyBjork()) ??
        allow(_classifyReid()) ??
        allow(_classifyWunjo()) ??
        allow(_classifyNaudr()) ??
        allow(_classifyKaun()) ??
        allow(_classifyAr()) ??
        allow(_classifySol()) ??
        allow(_classifyPerth()) ??
        allow(_classifyDagaz()) ??
        allow(_classifyEhwaz()) ??
        allow(_classifyOthala()) ??
        allow(_classifyIhwaz()) ??
        allow(_classifySowilo()) ??
        allow(_classifyKauna()) ??
        allow(_classifyLogr()) ??
        allow(_classifyUr()) ??
        allow(_isVertical(_strokes.last) ? _FutharkRune.iss : null);
  }

  /// Whether the most recent 2 strokes form ᚾ: a stave plus one
  /// descending branch crossing it around the middle — the branch
  /// reaches neither the stave's top quarter nor its bottom quarter
  /// ([_staveQuarterBounds]), which is what tells a true branch from the
  /// second diagonal of an X (ᚷ) running the stave's whole height.
  _FutharkRune? _classifyNaudr() {
    final split = _staveAndBranches(2);
    if (split == null) return null;
    final branch = split.$2.single;
    if (!_isDescending(branch)) return null;
    final (topQuarter, bottomQuarter) = _staveQuarterBounds(split.$1);
    final bounds = _boundsOf(branch.points);
    return bounds.top > topQuarter && bounds.bottom < bottomQuarter
        ? _FutharkRune.naudr
        : null;
  }

  /// Whether the most recent 3 strokes form ᚨ: ᚬ's construction (a stave
  /// plus two descending branches, each crossing it) with both branches
  /// sitting above the stave's midpoint (their bounds centers — the same
  /// rule as ᛘ/ᛏ's position checks) — Latin "F" with drooping bars.
  /// Elder-only; checked ahead of ᚬ, the unconstrained pattern, the same
  /// way ᚴ is checked ahead of ᛅ.
  _FutharkRune? _classifyAnsuz() {
    final split = _staveAndBranches(3);
    if (split == null) return null;
    final (stave, branches) = split;
    if (!branches.every(_isDescending)) return null;
    final midY = _midpointOf(stave).dy;
    return branches.every((b) => _boundsOf(b.points).center.dy < midY)
        ? _FutharkRune.ansuz
        : null;
  }

  /// Whether the most recent 3 strokes form ᚬ: a stave plus two
  /// descending branches, each crossing it.
  _FutharkRune? _classifyAss() {
    final split = _staveAndBranches(3);
    if (split == null) return null;
    return split.$2.every(_isDescending) ? _FutharkRune.ass : null;
  }

  /// Whether the most recent 3 strokes form ᚠ: a stave plus two
  /// ascending branches, each crossing it — ᚬ's mirror image.
  _FutharkRune? _classifyFe() {
    final split = _staveAndBranches(3);
    if (split == null) return null;
    return split.$2.every(_isAscending) ? _FutharkRune.fe : null;
  }

  /// Whether the most recent 3 strokes form ᚼ: a stave plus one
  /// ascending and one descending branch, each crossing it — the
  /// mixed-direction sibling of ᚬ and ᚠ, so the three are mutually
  /// exclusive.
  _FutharkRune? _classifyHagall() {
    final split = _staveAndBranches(3);
    if (split == null) return null;
    final branches = split.$2;
    return branches.where(_isAscending).length == 1 &&
            branches.where(_isDescending).length == 1
        ? _FutharkRune.hagall
        : null;
  }

  /// Whether the most recent 3 strokes form ᚺ: two staves plus one
  /// descending crossbar — the least vertical of the three, with both
  /// others reading as vertical themselves — that crosses each stave
  /// around its middle (the bar's y-range reaches neither outer quarter
  /// of either stave, ᚾ's rule applied to both) — Latin "N". Elder-only.
  /// The two-staves structure keeps it clear of the one-stave 3-stroke
  /// patterns (ᚬ ᚠ ᚨ ᚼ), whose second branch must cross the stave — a
  /// parallel second stave never does.
  _FutharkRune? _classifyHagalaz() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final bar = recent
        .reduce((a, b) => _verticalness(a) <= _verticalness(b) ? a : b);
    final staves = [
      for (final s in recent)
        if (s != bar) s
    ];
    if (!staves.every(_isVertical)) return null;
    if (!_isDescending(bar)) return null;
    final bounds = _boundsOf(bar.points);
    for (final stave in staves) {
      if (!_crossesChord(stave, bar)) return null;
      final (topQuarter, bottomQuarter) = _staveQuarterBounds(stave);
      if (bounds.top < topQuarter || bounds.bottom > bottomQuarter) {
        return null;
      }
    }
    return _FutharkRune.hagalaz;
  }

  /// Whether the most recent 2 strokes form ᚴ: the same stave-plus-
  /// ascending-branch as ᛅ, told apart by height — split the stave's
  /// y-range into 4 quarters, and ᚴ's branch visits the top quarter
  /// (its y-range reaches above the stave's top-quarter boundary) while
  /// ᛅ's stays below it. Checked ahead of [_classifyAr], the looser of
  /// the two.
  _FutharkRune? _classifyKaun() {
    final split = _staveAndBranches(2);
    if (split == null) return null;
    final branch = split.$2.single;
    if (!_isAscending(branch)) return null;
    final (topQuarter, _) = _staveQuarterBounds(split.$1);
    return _boundsOf(branch.points).top < topQuarter
        ? _FutharkRune.kaun
        : null;
  }

  /// Whether the most recent 2 strokes form ᛅ: a stave plus one
  /// ascending branch crossing it — ᚾ's mirror image. No height
  /// requirement of its own: a branch visiting the stave's top quarter
  /// is caught by [_classifyKaun] first, so this reads as "everything
  /// lower" (the middle area in practice).
  _FutharkRune? _classifyAr() {
    final split = _staveAndBranches(2);
    if (split == null) return null;
    return _isAscending(split.$2.single) ? _FutharkRune.ar : null;
  }

  /// Whether the most recent 2 strokes form ᚷ: two crossing diagonals,
  /// one ascending and one descending, each reaching both the top and
  /// bottom quarters of the other's y-range ([_reachesOuterQuarters]) —
  /// the "X". Elder-only. That mutual full-height rule (rather than any
  /// steepness limit) is what keeps ᚷ apart from the stave-plus-branch
  /// patterns: a branch confined to the stave's middle reads as ᚾ/ᛅ, a
  /// diagonal running the stave's whole height as the X's other arm —
  /// so the X may be drawn as tall as any rune.
  _FutharkRune? _classifyGebo() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    if (!_crossesChord(recent[0], recent[1])) return null;
    if (_isDescending(recent[0]) == _isDescending(recent[1])) return null;
    return _reachesOuterQuarters(recent[0], recent[1]) &&
            _reachesOuterQuarters(recent[1], recent[0])
        ? _FutharkRune.gebo
        : null;
  }

  /// Whether the most recent 2 strokes form ᛦ: a stave plus a bent
  /// branch, centered below the stave's midpoint, that crosses the
  /// stave's chord somewhere along its actual path (not just its own
  /// start/end chord — it's bent, so [_crossesChord] would miss real
  /// crossings) and splits by vertical direction change into exactly 2
  /// segments, ascending then descending. Checked ahead of every
  /// straight-branch 2-stroke classifier, whose chord-based reading a
  /// bent branch could otherwise satisfy.
  _FutharkRune? _classifyYr() {
    final split = _bentBranch();
    if (split == null) return null;
    final (stave, branch, runs) = split;
    final ascendingThenDescending =
        !_runIsDescending(runs[0]) && _runIsDescending(runs[1]);
    if (!ascendingThenDescending) return null;
    final belowCenter =
        _boundsOf(branch.points).center.dy > _midpointOf(stave).dy;
    return belowCenter ? _FutharkRune.yr : null;
  }

  /// Whether the most recent 2 strokes form ᛘ ([_isMadrShape]).
  _FutharkRune? _classifyMadr() =>
      _isMadrShape() ? _FutharkRune.madr : null;

  /// Whether the most recent 2 strokes form ᛉ: ᛘ's gesture exactly —
  /// Younger ᛘ descends from Elder ᛉ, so the same shape spells "z" in
  /// Elder mode. Sits right after ᛘ in the classification order, and
  /// each alphabet has exactly one of the two, so whichever the current
  /// mode has wins.
  _FutharkRune? _classifyAlgiz() =>
      _isMadrShape() ? _FutharkRune.algiz : null;

  /// The shape ᛘ and ᛉ share: ᛦ upside down — the same stave-plus-bent-
  /// branch structure ([_bentBranch]), but the branch's 2 vertical runs
  /// go down then up (a "∨") and its center sits *above* the stave's
  /// midpoint.
  bool _isMadrShape() {
    final split = _bentBranch();
    if (split == null) return false;
    final (stave, branch, runs) = split;
    final downThenUp =
        runs[0].$2.dy > runs[0].$1.dy && runs[1].$2.dy < runs[1].$1.dy;
    if (!downThenUp) return false;
    return _boundsOf(branch.points).center.dy < _midpointOf(stave).dy;
  }

  /// Whether the most recent 2 strokes form ᛏ: like ᛘ (bent branch
  /// above the stave's midpoint), but the branch's 2 vertical runs go
  /// up then down (a "∧" over the top).
  _FutharkRune? _classifyTyr() {
    final split = _bentBranch();
    if (split == null) return null;
    final (stave, branch, runs) = split;
    final upThenDown =
        runs[0].$2.dy < runs[0].$1.dy && runs[1].$2.dy > runs[1].$1.dy;
    if (!upThenDown) return null;
    final aboveCenter =
        _boundsOf(branch.points).center.dy < _midpointOf(stave).dy;
    return aboveCenter ? _FutharkRune.tyr : null;
  }

  /// Whether the most recent 2 strokes form ᛗ: two "∧" strokes — each
  /// splitting vertically into exactly 2 runs, up then down — that
  /// cross each other ([_pathIntersections]). Elder-only. A single "∧"
  /// with a descending second run is ᚢ's arch; a second one crossing it
  /// turns the pair into ᛗ.
  _FutharkRune? _classifyMannaz() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    for (final stroke in [a, b]) {
      final runs = _verticalRuns(stroke);
      if (runs.length != 2) return null;
      final upThenDown =
          runs[0].$2.dy < runs[0].$1.dy && runs[1].$2.dy > runs[1].$1.dy;
      if (!upThenDown) return null;
    }
    return _pathIntersections(a, b).isEmpty ? null : _FutharkRune.mannaz;
  }

  /// Whether the most recent 2 strokes form ᚦ: a stave plus a branch
  /// whose jitter-smoothed *horizontal* runs ([_horizontalRuns]) are
  /// exactly right-while-down then left-while-down — the ">" pocket —
  /// with the branch's actual path crossing the stave's chord. Checked
  /// ahead of the straight-branch classifiers: the pocket's dominant
  /// horizontal run plus its downward travel could otherwise chord-read
  /// as a plain descending (ᚾ) or ascending (ᛅ/ᚴ) branch.
  _FutharkRune? _classifyThurs() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final stave =
        recent.reduce((a, b) => _verticalness(a) >= _verticalness(b) ? a : b);
    if (!_isVertical(stave)) return null;
    final branch = recent.firstWhere((s) => s != stave);

    final runs = _horizontalRuns(branch);
    if (runs.length != 2) return null;
    final downRight = runs[0].$2.dx > runs[0].$1.dx && runs[0].$2.dy > runs[0].$1.dy;
    final downLeft = runs[1].$2.dx < runs[1].$1.dx && runs[1].$2.dy > runs[1].$1.dy;
    if (!downRight || !downLeft) return null;

    return _pathCrossesChord(branch, stave) ? _FutharkRune.thurs : null;
  }

  /// Whether the most recent stroke(s) form ᚱ: a stave plus a
  /// bow-and-leg part ([_bowRuns]) whose horizontal runs are exactly
  /// right, left, right. Runs alternate by construction, so only the
  /// count and the first direction need checking. Checked ahead of the
  /// straight-branch classifiers, whose chord reading the bow could
  /// otherwise satisfy, and after ᛒ, the longer pattern.
  _FutharkRune? _classifyReid() {
    final runs = _bowRuns();
    if (runs == null || runs.length != 3) return null;
    return runs[0].$2.dx > runs[0].$1.dx ? _FutharkRune.reid : null;
  }

  /// Whether the most recent stroke(s) form ᛒ: ᚱ with one more bend —
  /// the bow part's horizontal runs are exactly right, left, right,
  /// left (the two stacked pockets). Checked ahead of ᚱ, its
  /// sub-pattern.
  _FutharkRune? _classifyBjork() {
    final runs = _bowRuns();
    if (runs == null || runs.length != 4) return null;
    return runs[0].$2.dx > runs[0].$1.dx ? _FutharkRune.bjork : null;
  }

  /// Whether the most recent stroke(s) form ᚹ: ᚱ without the leg — the
  /// bow part's horizontal runs are exactly right, left (one pocket
  /// hanging off the stave) — Latin "P". Elder-only. Same two gestures
  /// as ᚱ/ᛒ ([_bowRuns]); checked after ᛒ/ᚱ, the longer patterns, and
  /// after ᚦ, whose pocket shares the right-left runs but *crosses* the
  /// stave instead of hanging off it.
  _FutharkRune? _classifyWunjo() {
    final runs = _bowRuns();
    if (runs == null || runs.length != 2) return null;
    return runs[0].$2.dx > runs[0].$1.dx ? _FutharkRune.wunjo : null;
  }

  /// The bow part's jitter-smoothed horizontal runs for ᚱ/ᛒ, from
  /// either accepted gesture, or null if the recent strokes fit
  /// neither:
  /// - 2 strokes: a stave (most vertical, and vertical itself) plus a
  ///   bow stroke that needs no vertical split (a single vertical run
  ///   end to end).
  /// - 1 stroke: exactly 2 vertical runs, the first reading as a
  ///   vertical line (the stave drawn without lifting) — the second
  ///   run is the bow.
  List<(Offset, Offset)>? _bowRuns() {
    if (_strokes.length >= 2) {
      final recent = _strokes.sublist(_strokes.length - 2);
      final stave = recent
          .reduce((a, b) => _verticalness(a) >= _verticalness(b) ? a : b);
      if (_isVertical(stave)) {
        final bow = recent.firstWhere((s) => s != stave);
        if (_verticalRuns(bow).length == 1) return _horizontalRuns(bow);
      }
    }
    final vRuns = _verticalRunPoints(_strokes.last);
    if (vRuns.length != 2) return null;
    final stavePart = vRuns[0];
    final staveVertical = (stavePart.last.dx - stavePart.first.dx).abs() <
        (stavePart.last.dy - stavePart.first.dy).abs();
    return staveVertical ? _horizontalRuns(_Stroke(vRuns[1])) : null;
  }

  /// Whether the most recent stroke alone forms ᛚ: exactly 2 vertical
  /// runs — the first reading as a vertical line (the stave), the
  /// second a *descending* flick ("\", e.g. the top flick when the
  /// stave is drawn upward) whose y-range stays entirely on one side of
  /// the stave run's mid-height (it must not cross that center). That
  /// stay-on-one-side rule is what separates ᛚ from ᚢ (the arch's
  /// second run always spans back down across the middle), which is why
  /// this is checked ahead of [_classifyUr]. Checked after ᚱ/ᛒ, whose
  /// single-stroke gestures also start with a vertical run.
  _FutharkRune? _classifyLogr() {
    final vRuns = _verticalRunPoints(_strokes.last);
    if (vRuns.length != 2) return null;
    final stavePart = vRuns[0];
    final staveVertical = (stavePart.last.dx - stavePart.first.dx).abs() <
        (stavePart.last.dy - stavePart.first.dy).abs();
    if (!staveVertical) return null;
    final flick = vRuns[1];
    if (!_runIsDescending((flick.first, flick.last))) return null;
    final midY = (stavePart.first.dy + stavePart.last.dy) / 2;
    final bounds = _boundsOf(flick);
    final crossesCenter = bounds.top < midY && bounds.bottom > midY;
    return crossesCenter ? null : _FutharkRune.logr;
  }

  /// The shared structure of ᛦ/ᛘ/ᛏ: splits the most recent 2 strokes
  /// into a stave (most vertical, and vertical itself) plus a bent
  /// branch with exactly 2 jitter-smoothed vertical runs
  /// ([_verticalRuns]) whose actual path crosses the stave's chord —
  /// or null if that structure doesn't hold. Callers check the runs'
  /// directions and where the branch sits relative to the stave.
  (_Stroke, _Stroke, List<(Offset, Offset)>)? _bentBranch() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final stave =
        recent.reduce((a, b) => _verticalness(a) >= _verticalness(b) ? a : b);
    if (!_isVertical(stave)) return null;
    final branch = recent.firstWhere((s) => s != stave);

    final runs = _verticalRuns(branch);
    if (runs.length != 2) return null;
    if (!_pathCrossesChord(branch, stave)) return null;
    return (stave, branch, runs);
  }

  /// Whether the most recent stroke alone forms ᛋ: its jitter-smoothed
  /// vertical runs ([_verticalRuns]) are exactly down, up, down, with
  /// the middle run ascending ("/", up and to the right). Checked ahead
  /// of the bare-vertical ᛁ fallback, whose start/end chord a zigzag
  /// can easily satisfy.
  _FutharkRune? _classifySol() {
    final runs = _verticalRuns(_strokes.last);
    if (runs.length != 3) return null;
    final firstDown = runs[0].$2.dy > runs[0].$1.dy;
    final lastDown = runs[2].$2.dy > runs[2].$1.dy;
    final middleAscends = !_runIsDescending(runs[1]);
    return firstDown && middleAscends && lastDown ? _FutharkRune.sol : null;
  }

  /// Whether the most recent stroke alone forms ᛈ: its jitter-smoothed
  /// vertical runs are exactly down, up, down, up, down — ᛇ's zigzag
  /// with one more bend. Elder-only. Runs alternate by construction, so
  /// only the ends need checking.
  _FutharkRune? _classifyPerth() {
    final runs = _verticalRuns(_strokes.last);
    if (runs.length != 5) return null;
    final firstDown = runs[0].$2.dy > runs[0].$1.dy;
    final lastDown = runs[4].$2.dy > runs[4].$1.dy;
    return firstDown && lastDown ? _FutharkRune.perth : null;
  }

  /// Whether the most recent stroke alone forms ᛞ: vertical runs
  /// exactly up, down, up, down — ᛖ's pattern — but with the first
  /// down reading as descending ("\") and the second as ascending
  /// ("/"): the bowtie, whose closing diagonal travels back down-left.
  /// Elder-only; checked ahead of ᛖ, the unconstrained pattern (an
  /// "M"'s last leg descends, so the two never overlap in practice).
  _FutharkRune? _classifyDagaz() {
    final runs = _verticalRuns(_strokes.last);
    if (runs.length != 4) return null;
    final firstUp = runs[0].$2.dy < runs[0].$1.dy;
    if (!firstUp) return null;
    return _runIsDescending(runs[1]) && !_runIsDescending(runs[3])
        ? _FutharkRune.dagaz
        : null;
  }

  /// Whether the most recent stroke alone forms ᛖ: its jitter-smoothed
  /// vertical runs are exactly up, down, up, down — Latin "M" drawn
  /// without lifting. Elder-only.
  _FutharkRune? _classifyEhwaz() {
    final runs = _verticalRuns(_strokes.last);
    if (runs.length != 4) return null;
    final firstUp = runs[0].$2.dy < runs[0].$1.dy;
    final lastDown = runs[3].$2.dy > runs[3].$1.dy;
    return firstUp && lastDown ? _FutharkRune.ehwaz : null;
  }

  /// Whether the most recent stroke alone forms ᛟ: exactly 2 vertical
  /// runs, up then down ([_verticalRunPoints], so each run can be split
  /// again horizontally, ᚱ/ᛒ's trick), where the up run's horizontal
  /// travel starts right and ends left, the down run's starts left and
  /// ends right (first/last runs only, so mid-phase hand wobble doesn't
  /// kill the match), and the stroke crosses itself
  /// ([_selfIntersects]) — the diamond on legs, traced from one leg tip
  /// over the top and back down through the crossing to the other.
  /// Elder-only. ᚢ's smooth arch never matches: each of its runs
  /// travels one horizontal way, and it never crosses itself.
  _FutharkRune? _classifyOthala() {
    final vRuns = _verticalRunPoints(_strokes.last);
    if (vRuns.length != 2) return null;
    final up = vRuns[0];
    if (up.last.dy >= up.first.dy) return null;
    final upRuns = _horizontalRuns(_Stroke(up));
    final downRuns = _horizontalRuns(_Stroke(vRuns[1]));
    if (upRuns.length < 2 || downRuns.length < 2) return null;
    final upRightThenLeft = upRuns.first.$2.dx > upRuns.first.$1.dx &&
        upRuns.last.$2.dx < upRuns.last.$1.dx;
    final downLeftThenRight = downRuns.first.$2.dx < downRuns.first.$1.dx &&
        downRuns.last.$2.dx > downRuns.last.$1.dx;
    if (!upRightThenLeft || !downLeftThenRight) return null;
    return _selfIntersects(_strokes.last) ? _FutharkRune.othala : null;
  }

  /// Whether the most recent stroke alone forms ᛇ: its jitter-smoothed
  /// vertical runs are exactly down, up, down — the vertical zigzag.
  /// Elder-only: ᛋ owns the same run pattern in Younger mode (with an
  /// ascending-middle requirement on top), and each alphabet has only
  /// one of the two, so the gate hands the shape to whichever applies.
  _FutharkRune? _classifyIhwaz() {
    final runs = _verticalRuns(_strokes.last);
    if (runs.length != 3) return null;
    final firstDown = runs[0].$2.dy > runs[0].$1.dy;
    final lastDown = runs[2].$2.dy > runs[2].$1.dy;
    return firstDown && lastDown ? _FutharkRune.ihwaz : null;
  }

  /// Whether the most recent stroke alone forms ᛊ: its jitter-smoothed
  /// *horizontal* runs ([_horizontalRuns]) are exactly left, right,
  /// left, right — the sideways zigzag, ᛇ/ᛈ's counterpart along the
  /// other axis. Elder-only.
  _FutharkRune? _classifySowilo() {
    final runs = _horizontalRuns(_strokes.last);
    if (runs.length != 4) return null;
    return runs[0].$2.dx < runs[0].$1.dx ? _FutharkRune.sowilo : null;
  }

  /// Whether the most recent stroke alone forms ᚢ: its jitter-smoothed
  /// vertical runs ([_verticalRuns]) are exactly up, then down while
  /// descending ("\", down and to the right) — the arch — and the
  /// stroke never crosses itself: ᛟ's legs do ([_classifyOthala]), ᚢ's
  /// arch cannot, so a sloppy ᛟ that misses its own pattern reports
  /// unrecognized here rather than a false "u". Like ᛋ, checked ahead
  /// of the bare-vertical ᛁ fallback.
  _FutharkRune? _classifyUr() {
    final runs = _verticalRuns(_strokes.last);
    if (runs.length != 2) return null;
    final firstUp = runs[0].$2.dy < runs[0].$1.dy;
    final secondDown = runs[1].$2.dy > runs[1].$1.dy;
    if (!firstUp || !secondDown || !_runIsDescending(runs[1])) return null;
    return _selfIntersects(_strokes.last) ? null : _FutharkRune.ur;
  }

  /// Whether the most recent 2 strokes form ᛜ: ᛃ's mirrored chevron
  /// pair ([_mirroredChevrons]), but with the two strokes actually
  /// crossing twice — once in the upper half of their combined bounds
  /// and once in the lower half ([_pathIntersections]) — the diamond.
  /// Elder-only; checked ahead of ᛃ, its looser sibling, whose halves
  /// must not touch at all.
  _FutharkRune? _classifyIngwaz() {
    final pair = _mirroredChevrons();
    if (pair == null) return null;
    final (a, b) = pair;
    final crossings = _pathIntersections(a, b);
    final midY = _boundsOf([...a.points, ...b.points]).center.dy;
    return crossings.any((p) => p.dy < midY) &&
            crossings.any((p) => p.dy > midY)
        ? _FutharkRune.ingwaz
        : null;
  }

  /// Whether the most recent 2 strokes form ᛃ: ᚲ's chevron ("<") plus
  /// its mirror image (">"), drawn in either order, with the two
  /// strokes' bounding boxes overlapping but the strokes themselves
  /// never touching — the rune's interlocking halves. A pair that
  /// crosses is ᛜ territory ([_classifyIngwaz], checked first).
  /// Elder-only. Checked ahead of ᚦ/ᚱ/ᛒ/ᚹ: a chevron's chord is
  /// nearly vertical, so one of the pair could otherwise pass for those
  /// patterns' stave with the other as its pocket/bow.
  _FutharkRune? _classifyJera() {
    final pair = _mirroredChevrons();
    if (pair == null) return null;
    final (a, b) = pair;
    if (_pathIntersections(a, b).isNotEmpty) return null;
    return _boundsOf(a.points).overlaps(_boundsOf(b.points))
        ? _FutharkRune.jera
        : null;
  }

  /// The most recent 2 strokes as a mirrored chevron pair — ᚲ's "<"
  /// plus its mirror ">", in either order ([_isChevron]) — or null if
  /// they aren't one. The structure ᛃ and ᛜ share; the two are told
  /// apart by whether the halves touch.
  (_Stroke, _Stroke)? _mirroredChevrons() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final mirroredPair =
        (_isChevron(a, leftFirst: true) && _isChevron(b, leftFirst: false)) ||
            (_isChevron(a, leftFirst: false) && _isChevron(b, leftFirst: true));
    return mirroredPair ? (a, b) : null;
  }

  /// Whether the most recent stroke alone forms ᚲ: the "<" chevron
  /// ([_isChevron]). Elder-only; checked ahead of the bare-vertical ᛁ
  /// fallback, whose chord test the "<" satisfies (it starts and ends at
  /// nearly the same x).
  _FutharkRune? _classifyKauna() =>
      _isChevron(_strokes.last, leftFirst: true) ? _FutharkRune.kauna : null;

  /// Whether [s] is a chevron: a single vertical run (no reversal —
  /// drawn straight down tip → apex → tip, or straight back up) with
  /// exactly 2 horizontal runs. [leftFirst] picks the opening: true is
  /// ᚲ's "<" (left then right), false its mirror ">" (right then left,
  /// ᛃ's other half). Runs alternate by construction, so only the first
  /// one's direction needs checking.
  bool _isChevron(_Stroke s, {required bool leftFirst}) {
    if (_verticalRuns(s).length != 1) return false;
    final runs = _horizontalRuns(s);
    if (runs.length != 2) return false;
    return (runs[0].$2.dx < runs[0].$1.dx) == leftFirst;
  }

  /// A raw [_splitByVerticalDirectionChange] can't be counted directly —
  /// a hand-drawn bend has micro up/down reversals (especially around
  /// the apex) that split a visually-2-part "∧" into 3+ segments and
  /// kill an exact-count check. Segments spanning less than this
  /// vertically are treated as jitter by [_verticalRuns].
  static const double _jitterSpan = 12;

  /// The stroke's vertical movement as (start, end) runs with hand
  /// jitter smoothed out — the endpoint view of [_verticalRunPoints].
  List<(Offset, Offset)> _verticalRuns(_Stroke s) => [
        for (final run in _verticalRunPoints(s)) (run.first, run.last),
      ];

  /// The stroke's vertical movement as full point-list runs with hand
  /// jitter smoothed out: split by vertical direction change, fold
  /// segments spanning less than [_jitterSpan] vertically into the
  /// current run, and merge consecutive runs that go the same way.
  /// Keeping each run's points (rather than just its endpoints, as
  /// [_verticalRuns] exposes) lets a run be split *again* horizontally —
  /// ᚱ/ᛒ's bow part ([_bowRuns]).
  List<List<Offset>> _verticalRunPoints(_Stroke s) {
    final runs = <List<Offset>>[];
    for (final seg in _splitByVerticalDirectionChange(s)) {
      if ((seg.last.dy - seg.first.dy).abs() < _jitterSpan) {
        if (runs.isNotEmpty) runs.last.addAll(seg.skip(1));
        continue;
      }
      final down = seg.last.dy > seg.first.dy;
      if (runs.isNotEmpty && (runs.last.last.dy > runs.last.first.dy) == down) {
        runs.last.addAll(seg.skip(1));
      } else {
        runs.add([...seg]);
      }
    }
    return runs;
  }

  /// The sideways counterpart of [_verticalRuns]: the stroke's
  /// horizontal movement as (start, end) runs — split by horizontal
  /// direction change, drop segments spanning less than [_jitterSpan]
  /// horizontally, and merge consecutive survivors that go the same
  /// way.
  List<(Offset, Offset)> _horizontalRuns(_Stroke s) {
    final runs = <(Offset, Offset)>[];
    for (final seg in _splitByHorizontalDirectionChange(s)) {
      final (first, last) = (seg.first, seg.last);
      if ((last.dx - first.dx).abs() < _jitterSpan) continue;
      final right = last.dx > first.dx;
      if (runs.isNotEmpty && (runs.last.$2.dx > runs.last.$1.dx) == right) {
        runs[runs.length - 1] = (runs.last.$1, last);
      } else {
        runs.add((first, last));
      }
    }
    return runs;
  }

  /// Whether a [_verticalRuns] run reads as descending — the same
  /// direction-agreement rule as [_isDescending], read straight off the
  /// run's endpoints since a run has one vertical direction by
  /// construction.
  bool _runIsDescending((Offset, Offset) run) =>
      (run.$2.dx > run.$1.dx) == (run.$2.dy > run.$1.dy);

  /// The y-boundaries of [stave]'s top and bottom quarters — the stave's
  /// chord y-range split into 4: anything above `$1` is in the top
  /// quarter, anything below `$2` in the bottom quarter. The position
  /// rule ᚴ's and ᚾ's checks share.
  (double, double) _staveQuarterBounds(_Stroke stave) {
    final top = stave.start.dy < stave.end.dy ? stave.start.dy : stave.end.dy;
    final bottom =
        stave.start.dy > stave.end.dy ? stave.start.dy : stave.end.dy;
    final quarter = (bottom - top) / 4;
    return (top + quarter, bottom - quarter);
  }

  /// Whether [a]'s y-range reaches both the top and the bottom quarter
  /// of [b]'s y-range (its height split into 4) — ᚷ applies this both
  /// ways, so its two diagonals must run each other's whole height.
  bool _reachesOuterQuarters(_Stroke a, _Stroke b) {
    final other = _boundsOf(b.points);
    final quarter = other.height / 4;
    final own = _boundsOf(a.points);
    return own.top < other.top + quarter &&
        own.bottom > other.bottom - quarter;
  }

  Offset _midpointOf(_Stroke s) => Offset(
      (s.start.dx + s.end.dx) / 2, (s.start.dy + s.end.dy) / 2);

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

  /// Whether any segment of [path]'s actual polyline crosses [chord]'s
  /// start/end chord — for bent strokes, where [_crossesChord]'s
  /// chord-vs-chord check would miss the real crossing.
  bool _pathCrossesChord(_Stroke path, _Stroke chord) {
    for (var i = 0; i < path.points.length - 1; i++) {
      if (_segmentsIntersect(
          path.points[i], path.points[i + 1], chord.start, chord.end)) {
        return true;
      }
    }
    return false;
  }

  /// Splits the most recent [count] strokes into a stave — the most
  /// vertical one ([_verticalness]), which must itself read as vertical
  /// ([_isVertical]) — plus the remaining branch strokes, each of which
  /// must cross the stave ([_crossesChord]). Returns null if that
  /// structure doesn't hold. Picking the stave *relatively* (rather than
  /// testing each stroke with [_isVertical] on its own) is what lets a
  /// branch be drawn steeper than 45° without being mistaken for a
  /// second stave — see the class doc.
  (_Stroke, List<_Stroke>)? _staveAndBranches(int count) {
    if (_strokes.length < count) return null;
    final recent = _strokes.sublist(_strokes.length - count);
    final stave = recent
        .reduce((a, b) => _verticalness(a) >= _verticalness(b) ? a : b);
    if (!_isVertical(stave)) return null;
    final branches = [
      for (final s in recent)
        if (s != stave) s
    ];
    if (!branches.every((b) => _crossesChord(stave, b))) return null;
    return (stave, branches);
  }

  /// How vertical [s]'s start/end chord is, as the share of its total
  /// axis movement that's vertical (0 = flat, 1 = plumb) — used to pick
  /// the stave among recent strokes, scale-independently.
  double _verticalness(_Stroke s) {
    final dx = (s.end.dx - s.start.dx).abs();
    final dy = (s.end.dy - s.start.dy).abs();
    return dx + dy == 0 ? 0 : dy / (dx + dy);
  }

  bool _isVertical(_Stroke s) =>
      (s.end.dx - s.start.dx).abs() < (s.end.dy - s.start.dy).abs();

  /// Whether [s] reads as a descending branch ("\"): its dominant
  /// horizontal and vertical travel directions agree — left-to-right
  /// while going down, or right-to-left while going up — the same visual
  /// line either way, so draw direction doesn't matter. Deliberately no
  /// steepness requirement (see the class doc): a branch may read as
  /// "horizontal" or "vertical" by the axis-dominance rule and still
  /// count.
  bool _isDescending(_Stroke s) => _isLeftToRight(s) == _isGoingDown(s);

  /// The ascending counterpart of [_isDescending] ("/"): dominant
  /// horizontal and vertical travel directions disagree.
  bool _isAscending(_Stroke s) => !_isDescending(s);

  /// Whether [a]'s and [b]'s start/end chords cross — both are expected
  /// to be straight lines, so no full-polyline walk is needed.
  bool _crossesChord(_Stroke a, _Stroke b) =>
      _segmentsIntersect(a.start, a.end, b.start, b.end);

  /// True if [s] travels left to right overall — [s] is split by
  /// horizontal direction change first, and the direction is read off the
  /// segment with the widest horizontal span, so a small reversal (hand
  /// jitter) doesn't flip the result. Ported from tifi.
  bool _isLeftToRight(_Stroke s) {
    final segments = _splitByHorizontalDirectionChange(s);
    if (segments.isEmpty) return s.end.dx > s.start.dx;
    final dominant = segments.reduce((a, b) =>
        (a.last.dx - a.first.dx).abs() > (b.last.dx - b.first.dx).abs()
            ? a
            : b);
    return dominant.last.dx > dominant.first.dx;
  }

  /// True if [s] travels downward overall — the vertical counterpart of
  /// [_isLeftToRight]: split by vertical direction change, and read the
  /// direction off the segment with the widest vertical span.
  bool _isGoingDown(_Stroke s) {
    final segments = _splitByVerticalDirectionChange(s);
    if (segments.isEmpty) return s.end.dy > s.start.dy;
    final dominant = segments.reduce((a, b) =>
        (a.last.dy - a.first.dy).abs() > (b.last.dy - b.first.dy).abs()
            ? a
            : b);
    return dominant.last.dy > dominant.first.dy;
  }

  /// Splits [stroke] wherever its horizontal direction reverses (left-to-
  /// right vs right-to-left) — same `StrokeCutter
  /// .cutByHorizontalDirectionChange` pattern as the shorthand project:
  /// walk consecutive points, and whenever the sign of horizontal
  /// movement flips, close the current segment (re-seeding the next one
  /// with the pivot point) and start a new one.
  List<List<Offset>> _splitByHorizontalDirectionChange(_Stroke stroke) {
    final points = stroke.points;
    final segments = <List<Offset>>[];
    if (points.length < 2) return segments;

    var current = <Offset>[points[0]];
    bool? goingRight;
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final isRight = curr.dx > prev.dx;
      if (goingRight != null && isRight != goingRight) {
        segments.add(current);
        current = <Offset>[prev];
      }
      current.add(curr);
      goingRight = isRight;
    }
    segments.add(current);
    return segments;
  }

  /// Splits [stroke] wherever its vertical direction reverses (down vs
  /// up) — the vertical counterpart of
  /// [_splitByHorizontalDirectionChange].
  List<List<Offset>> _splitByVerticalDirectionChange(_Stroke stroke) {
    final points = stroke.points;
    final segments = <List<Offset>>[];
    if (points.length < 2) return segments;

    var current = <Offset>[points[0]];
    bool? goingDown;
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final isDown = curr.dy > prev.dy;
      if (goingDown != null && isDown != goingDown) {
        segments.add(current);
        current = <Offset>[prev];
      }
      current.add(curr);
      goingDown = isDown;
    }
    segments.add(current);
    return segments;
  }

  /// Whether [s]'s polyline crosses itself anywhere — non-neighboring
  /// segment pairs tested pairwise ([_segmentsIntersect]; neighbors
  /// share an endpoint, which the strict test ignores anyway, and are
  /// skipped).
  bool _selfIntersects(_Stroke s) {
    final points = s.points;
    for (var i = 0; i < points.length - 1; i++) {
      for (var j = i + 2; j < points.length - 1; j++) {
        if (_segmentsIntersect(
            points[i], points[i + 1], points[j], points[j + 1])) {
          return true;
        }
      }
    }
    return false;
  }

  /// Every point where [a]'s and [b]'s polylines cross
  /// ([_segmentIntersection] over all segment pairs) — a hand-drawn
  /// crossing may contribute a couple of near-identical points, so
  /// callers should ask about regions, not exact counts.
  List<Offset> _pathIntersections(_Stroke a, _Stroke b) {
    final crossings = <Offset>[];
    for (var i = 0; i < a.points.length - 1; i++) {
      for (var j = 0; j < b.points.length - 1; j++) {
        final p = _segmentIntersection(
            a.points[i], a.points[i + 1], b.points[j], b.points[j + 1]);
        if (p != null) crossings.add(p);
      }
    }
    return crossings;
  }

  /// Where segments p1-p2 and p3-p4 cross, or null if they don't —
  /// [_segmentsIntersect] plus the actual point (the strict crossing
  /// guarantees the lines aren't parallel, so the division is safe).
  Offset? _segmentIntersection(Offset p1, Offset p2, Offset p3, Offset p4) {
    if (!_segmentsIntersect(p1, p2, p3, p4)) return null;
    final d = (p2.dx - p1.dx) * (p4.dy - p3.dy) -
        (p2.dy - p1.dy) * (p4.dx - p3.dx);
    final t = ((p3.dx - p1.dx) * (p4.dy - p3.dy) -
            (p3.dy - p1.dy) * (p4.dx - p3.dx)) /
        d;
    return Offset(p1.dx + t * (p2.dx - p1.dx), p1.dy + t * (p2.dy - p1.dy));
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
    // In Elder mode the matched shape is announced under its Elder
    // identity — same glyph, different rune name (ᚠ is *fehu, not fé).
    final elderRow = recognized == null || _alphabet != FutharkAlphabet.elder
        ? null
        : elderFutharkRows
            .firstWhere((r) => r.translit == recognized.translit);
    final label = TextPainter(
      text: recognized != null
          ? TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              children: [
                const TextSpan(text: 'Recognized: '),
                TextSpan(
                  text: elderRow?.glyph ?? recognized.glyph,
                  style: const TextStyle(
                    fontFamily: 'NotoSansRunic',
                    fontSize: 22,
                  ),
                ),
                TextSpan(
                  text: '  (${elderRow?.name ?? recognized.runeName}'
                      ' — "${recognized.translit}")',
                ),
              ],
            )
          : const TextSpan(
              text: 'Draw a rune below to see it recognized',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

/// Builds the scene plus a direct reference to its [FutharkLayer], so the
/// hosting page can call [FutharkLayer.clear] from the Clear button.
(Scene, FutharkLayer) buildFutharkScene() {
  final layer = FutharkLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
