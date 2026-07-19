import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

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

/// How dots are read as a single grouped mark. [column] and [row] check
/// a single axis (see [TifinaghLayer._matchesColumnDots] /
/// [TifinaghLayer._matchesRowDots]); [cross] requires exactly 4 dots
/// forming the corners of a rectangle — a top row of 2 sharing a y
/// center, and a bottom row of 2 sharing a different y center — whose
/// diagonals read as an "X" (see [TifinaghLayer._matchesCrossDots]);
/// [crossCenter] requires that same 4-dot rectangle plus a 5th dot inside
/// its bounding box that doesn't share an x or y range with any of the
/// other 4 (see [TifinaghLayer._matchesCrossCenterDots]).
enum _DotArrangement { column, row, cross, crossCenter }

enum _TifinaghLetter {
  ya('ⴰ', 'ya', 'a', 1, 0, 0),
  yu('ⵓ', 'yu', 'u', 2, 0, 0),
  yak('ⴾ', 'yak', 'k', 0, 0, 0),
  yakh('ⵆ', 'yakh', 'x', 4, 0, 0, dotArrangement: _DotArrangement.cross),
  yagh('ⵗ', 'yaɣ', 'ɣ', 3, 0, 0),
  yaghc('ⵘ', 'yaɣ', 'ɣ', 5, 0, 0, dotArrangement: _DotArrangement.crossCenter),
  yaq('ⵈ', 'yaq', 'q', 3, 0, 0, dotArrangement: _DotArrangement.row),
  yah('ⵂ', 'yah', 'h', 4, 0, 0),
  yaj('ⴶ', 'yaj', 'ġ/ɟ', 0, 0, 0),
  yang('ⵑ', 'yang', 'ŋ', 0, 0, 0),
  yar('ⵔ', 'yar', 'r', 0, 0, 0),
  yag('ⴳ', 'yag', 'ɡ', 0, 0, 0),
  yash('ⵛ', 'yaš', 'ʃ', 0, 0, 0),
  yas('ⵙ', 'yas', 's', 0, 0, 0),
  yab('ⵀ', 'yab', 'b', 0, 0, 0),
  yazz('ⵋ', 'yaž', 'ž/j', 0, 0, 0),
  yay('ⵢ', 'yay', 'j', 0, 0, 0),
  yaz('ⵣ', 'yaz', 'z', 0, 0, 0),
  yad('ⴸ', 'yad', 'd', 0, 0, 0),
  yal('ⵍ', 'yal', 'l', 0, 0, 0),
  yam('ⵎ', 'yam', 'm', 0, 0, 0),
  yadd('ⴹ', 'yaḍ', 'dˤ', 0, 0, 0),
  yatt('ⵟ', 'yaṭ', 'tˤ', 0, 0, 0),
  yaf('ⴼ', 'yaf', 'f', 0, 0, 0),
  // n is a single vertical line that doesn't cross any other recent
  // stroke (see [TifinaghLayer._classifyN]) — not a plain reuse of the
  // generic grid classifier, since several letters (t/s⁴, z¹, ṭ, z³) use
  // a vertical line crossing something else too.
  yan('ⵏ', 'yan', 'n', 0, 0, 0),
  yat('ⵜ', 'yat', 't', 0, 1, 1),
  yagn('ⵐ', 'yagn', 'ñ', 0, 1, 2),
  yazh('ⵌ', 'yazh', 'ẓ', 0, 2, 2),
  yi('ⵉ', 'yi', 'j', 0, 0, 0),
  // Libyco-Berber-only shapes (see TifinaghLayer._libycoBerberShapes):
  // no Unicode glyph exists for this script, so [glyph] is just the
  // transliteration letter, shown as a text fallback until the actual
  // letterform image ([TifinaghLayer._libycoBerberImages]) loads.
  // l and w are drawn identically (two vertical lines whose y-ranges
  // overlap — side by side, not stacked — with neither crossing the
  // other, see [TifinaghLayer._classifyLibycoBerberLW]), so this shape
  // is labeled "l | w" rather than picking one — see
  // [TifinaghLayer._libycoBerberImages] for which bundled image is shown
  // for the combo.
  yalLb('l | w', 'yal', 'l | w', 0, 0, 0),
  yahLb('h', 'yah', 'h', 0, 0, 0),
  // z² is a single horizontal line that doesn't cross any other stroke
  // (see [TifinaghLayer._classifyLibycoBerberZ2]) — not a plain reuse of
  // the generic grid classifier, since Libyco-Berber's own t/s⁴, ṭ, z¹,
  // and q/ɣ? all involve a horizontal line crossing something else too.
  yaz2Lb('z²', 'yaz2', 'z²', 0, 0, 0),
  // Also Libyco-Berber-only: r and f are both a self-crossing loop split
  // into exactly 3 horizontal-direction segments (see
  // [TifinaghLayer._classifyLibycoBerberRF]), distinguished from each
  // other only by which way the first segment goes — unlike Ahaggar's own
  // r (any self-crossing loop, no segment-count/direction check) or g
  // (the same 3-segment split, but checked by vertical, not horizontal,
  // direction), neither of which reliably tells these two apart.
  yarLb('r', 'yar', 'r', 0, 0, 0),
  yafLb('f', 'yaf', 'f', 0, 0, 0),
  // Also Libyco-Berber-only: s² is like f above — a self-crossing loop
  // split by horizontal direction change, starting right — but with a
  // 4th segment appended (right-left-right-left) that must itself read
  // as horizontal (see [TifinaghLayer._classifyLibycoBerberS2]).
  yas2Lb('s²', 'yas2', 's²', 0, 0, 0),
  // Also Libyco-Berber-only: y and s³ are each a single stroke split by
  // horizontal direction change, both descending overall (see
  // [TifinaghLayer._isGoingDown]) — y into 3 segments (right-left-right),
  // s³ into 4 (right-left-right-left). Each is the mirror image of an
  // existing Tuareg shape: y is [_TifinaghLetter.yay]'s own
  // right-left-right sequence, but paired with descending instead of
  // ascending; s³ is [_TifinaghLetter.yi]'s own segment count, but with
  // the opposite left/right sequence (see
  // [TifinaghLayer._classifyLibycoBerberY] /
  // [TifinaghLayer._classifyLibycoBerberS3]).
  yayLb('y', 'yay', 'y', 0, 0, 0),
  yas3Lb('s³', 'yas3', 's³', 0, 0, 0),
  // Also Libyco-Berber-only: t and s⁴ are both a vertical line crossed by
  // a horizontal line — the same shape as every Tuareg region's own t
  // ([_TifinaghLetter.yat]) — distinguished from each other by where
  // along the horizontal line the crossing falls (see
  // [TifinaghLayer._classifyLibycoBerberTS4]): the middle half for t, the
  // leftmost quarter for s⁴.
  yatLb('t', 'yat', 't', 0, 0, 0),
  yas4Lb('s⁴', 'yas4', 's⁴', 0, 0, 0),
  // Also Libyco-Berber-only: q/ɣ? is a horizontal line with a dot above
  // it and a dot below it, both x-aligned with the line (see
  // [TifinaghLayer._classifyLibycoBerberQ]) — the mirrored layout of
  // Ahaggar's own ⵑ (a vertical line with just one dot below it).
  yaqLb('q/ɣ?', 'yaq', 'q/ɣ?', 0, 0, 0),
  // Also Libyco-Berber-only: m is a single stroke whose first and last
  // points both fall in the *left* half of its own bounding box (see
  // [TifinaghLayer._isMShapedMirrored]) — the horizontal mirror of
  // Ahaggar's own m ([_TifinaghLetter.yam], right half), the same
  // mirrored shape already used for one bulge of Ahaggar's ⴼ.
  yamLb('m', 'yam', 'm', 0, 0, 0),
  // Also Libyco-Berber-only: z¹ is two vertical lines, each crossed
  // exactly once by one horizontal line, with one vertical falling left
  // of the horizontal's own center and the other right of it (see
  // [TifinaghLayer._classifyLibycoBerberZ1]) — not a plain reuse of the
  // generic grid classifier ([TifinaghLayer._matchesGrid]), since that
  // doesn't care where the two verticals fall relative to each other.
  yaz1Lb('z¹', 'yaz1', 'z¹', 0, 0, 0),
  // Also Libyco-Berber-only: g is a single stroke split by horizontal
  // direction change into exactly 2 segments — the first going left
  // while also moving up, the second going right while reading as
  // horizontal (see [TifinaghLayer._classifyLibycoBerberG]) — unrelated
  // to Ahaggar's own g ([_TifinaghLetter.yag], a 3-segment self-crossing
  // shape).
  yagLb('g', 'yag', 'g', 0, 0, 0),
  // Also Libyco-Berber-only: k is g's own shape (left-and-up then
  // right-and-horizontal) plus a second stroke above it, split the same
  // way but going left-and-down instead of left-and-up (see
  // [TifinaghLayer._classifyLibycoBerberK]).
  yakLb('k', 'yak', 'k', 0, 0, 0),
  // Also Libyco-Berber-only: ṭ is a horizontal line crossing a second
  // line that's split by horizontal direction change into exactly 2
  // segments — the first going right, the second going left (see
  // [TifinaghLayer._classifyLibycoBerberTt]).
  yattLb('ṭ', 'yatt', 'ṭ', 0, 0, 0),
  // Also Libyco-Berber-only: d is [_TifinaghLetter.yam]'s own shape check
  // with the split axis rotated 90° — both endpoints in the *bottom*
  // half of the stroke's own bounding box (instead of the right half),
  // and the start/end chord reads as horizontal (instead of vertical) —
  // see [TifinaghLayer._classifyLibycoBerberD]. Unrelated to Ahaggar's
  // own d ([_TifinaghLetter.yad], a down-then-up vertical-direction
  // split).
  yadLb('d', 'yad', 'd', 0, 0, 0),
  // Also Libyco-Berber-only: z³ is the d shape ([_isDShapedLb], the same
  // shape as [_TifinaghLetter.yadLb]) crossed by a vertical line through
  // its middle (see [TifinaghLayer._classifyLibycoBerberZ3]).
  yaz3Lb('z³', 'yaz3', 'z³', 0, 0, 0),
  // Adrar-only shape (see TifinaghLayer._classifyAdrarSh): Adrar's š is a
  // different glyph from every other region's ⵛ, so it isn't drawn the
  // same way either.
  yashDr('𐌚', 'yaš', 'ʃ', 0, 0, 0),
  // Neo-Tifinagh-only shapes (see TifinaghLayer._classifyLoop): a loop
  // plus a second, non-looping stroke, the same building blocks as
  // Ahaggar's own b/s (yab/yas), but split differently — by the second
  // stroke's orientation and crossing count rather than just "vertical,
  // crosses twice" (b) or "a dot inside" (s). b is the horizontal
  // counterpart of Ahaggar's own b: a loop crossed twice by a horizontal
  // line instead of a vertical one. ṛ and ṣ are both a loop crossed only
  // once by a line of either orientation, distinguished by whether that
  // line descends (ṛ) or ascends (ṣ) overall ([TifinaghLayer._isGoingDown]).
  yabNt('ⴱ', 'yab', 'b', 0, 0, 0),
  yarrNt('ⵕ', 'yaṛ', 'rˤ', 0, 0, 0),
  yassNt('ⵚ', 'yaṣ', 'sˤ', 0, 0, 0),
  // Also Neo-Tifinagh-only (see TifinaghLayer._classifyZEmphatic): ẓ is
  // Ahaggar's own z shape (1 vertical line + 2 strokes each split into an
  // up-then-down/down-then-up pair, starting in opposite directions —
  // [_TifinaghLetter.yaz]) plus a 4th, plain horizontal line that crosses
  // the vertical line and sits between the other two strokes.
  yazhNt('ⵥ', 'yaẓ', 'zˤ', 0, 0, 0),
  // Also Neo-Tifinagh-only (see TifinaghLayer._classifyNeoTifinaghH): ḥ is
  // a vertical line crossed by a diagonal one ([TifinaghLayer._isDiagonal]
  // — meaningfully both horizontal and vertical movement, unlike Neo-
  // Tifinagh's own t below, whose crossbar is strictly horizontal), where
  // the diagonal's own y-range doesn't reach into the vertical's own top
  // quarter (splitting the vertical's y-range into 4 equal quarters, the
  // diagonal only occupies the bottom 3).
  yahNt('ⵃ', 'yaḥ', 'ħ', 0, 0, 0),
  // Also Neo-Tifinagh-only (see TifinaghLayer._classifyNeoTifinaghKh): kh
  // is 3 strokes drawn close together so every pair's bounding box overlaps
  // in both x and y (not a literal crossing) — one leaning ascending, one
  // leaning descending, and the third close to plain vertical.
  yakhNt('ⵅ', 'yakh', 'χ', 0, 0, 0),
  // Also Neo-Tifinagh-only (see TifinaghLayer._classifyNeoTifinaghGw): gw
  // is g's own shape ([_TifinaghLetter.yafLb]) plus a second stroke shaped
  // like w ([_TifinaghLetter.yawNt]), positioned above and to the right of
  // g's own self-intersection point.
  yagwNt('ⴳⵯ', 'yagw', 'ɡʷ', 0, 0, 0),
  // Also Neo-Tifinagh-only (see TifinaghLayer._classifyNeoTifinaghW): w is
  // d ([_TifinaghLetter.yadLb]) upside down — the same shape
  // ([TifinaghLayer._isDShapedLb]) mirrored vertically, both endpoints in
  // the top half of the stroke's own bounding box instead of the bottom.
  yawNt('ⵡ', 'yaw', 'w', 0, 0, 0);

  const _TifinaghLetter(this.glyph, this.letterName, this.sound, this.dots,
      this.verticals, this.horizontals,
      {this.dotArrangement = _DotArrangement.column});
  final String glyph;
  final String letterName;
  final String sound;

  /// How many of the most recent dots (taps) are needed for this letter to
  /// be recognized. Zero for line-based letters.
  final int dots;

  /// How [dots] dots must be arranged relative to one another.
  final _DotArrangement dotArrangement;

  /// How many of the most recent strokes must be vertical/horizontal, and
  /// all cross one another, for this letter to be recognized. Checked
  /// largest-pattern-first so e.g. a completed ⵌ isn't reported as a ⵜ.
  /// Zero for dot-based letters.
  final int verticals;
  final int horizontals;
}

/// Freehand recognition of Tifinagh letters (Ahaggar Tuareg forms, per
/// Wikipedia — see [TifinaghLayer.region] for how other regions reuse or
/// override these). Most letters are a grid of crossing vertical/horizontal
/// lines; a run of dots (taps) is a separate family of letters; one letter
/// mixes both:
///
/// - ⴰ (ya, "a") — a single dot.
/// - ⵓ (yu, "u") — two dots, a vertical column.
/// - ⴾ (yak, "k") — three dots: two with overlapping x ranges (a
///   column), and the third clear of that x range, to the right, with
///   its y between the column pair's own bounding-box top and bottom.
/// - ⵗ (yaɣ, "ɣ/gh") — three dots, a vertical column. Tuareg-only; no
///   Neo-Tifinagh equivalent.
/// - ⵈ (yaq, "q") — three dots, a horizontal row. Tuareg-only; no
///   Neo-Tifinagh equivalent.
/// - ⵂ (yah, "h") — four dots, a vertical column. Tuareg-only; no
///   Neo-Tifinagh equivalent.
/// - ⵆ (yakh, "x") — four dots at the corners of a rectangle: a top pair
///   sharing a y center and a bottom pair sharing a different y center.
///   Tuareg-only; no Neo-Tifinagh equivalent.
/// - ⵘ (yaghc, "ɣ/gh" in Aïr) — the same 4-dot rectangle as ⵆ, plus a 5th
///   dot inside its bounding box that shares neither an x nor a y range
///   with any of the other 4 — i.e. genuinely off both the rectangle's
///   rows and its columns, not just one of the two. Aïr-only.
/// - ⴶ (yaj, "ġ/ɟ") — two dots sharing a y center (a row), directly above
///   a vertical line whose x center lines up with the midpoint between
///   them.
/// - ⵑ (yang, "ŋ") — a vertical line with a dot below it, sharing the
///   line's x center.
/// - ⵔ (yar, "r") — a single stroke that crosses itself exactly once, i.e.
///   a loop, with both its start and end points above the vertical center
///   of its own bounding box (see [TifinaghLayer._classifyR]) — the loop
///   hangs below the endpoints, not beside or above them.
/// - ⴳ (yag, "ɡ") — a single stroke, split by horizontal direction change
///   into exactly 3 segments, whose first segment moves up and whose
///   last moves down, crossing itself exactly once.
/// - ⵛ (yash, "ʃ") — a single stroke that crosses itself exactly twice,
///   with one crossing above and the other below the vertical center of
///   the stroke's bounding box.
/// - ⵙ (yas, "s") — the same loop as ⵔ, with a dot inside it.
/// - ⵀ (yab, "b") — the same loop as ⵔ, with a separate vertical line that
///   crosses it exactly twice.
/// - ⵋ (yazz, "ž/j") — two strokes with opposite horizontal travel
///   direction (one drawn left-to-right, the other right-to-left;
///   whether each goes up or down doesn't matter), crossing each other
///   once or twice.
/// - ⵢ (yay, "j") — a single zigzag stroke, split into exactly 3
///   horizontal-direction segments: left-right-left if the stroke goes
///   down overall, or right-left-right if it goes up.
/// - ⵣ (yaz, "z") — one vertical line plus two non-vertical strokes, each
///   split into exactly 2 vertical-direction segments, with one stroke
///   going up-then-down and the other down-then-up.
/// - ⴸ (yad, "d") — a single stroke, split into exactly 2
///   vertical-direction segments, going down then up.
/// - ⵍ (yal, "l") — two vertical lines plus a third stroke that
///   intersects both, ascending left to right (travels left to right
///   while moving upward).
/// - ⵎ (yam, "m") — a single stroke whose first and last points both fall
///   in the right half of its own bounding box, and whose straight
///   start-to-end chord reads as vertical.
/// - ⴹ (yadd, "dˤ") — the same shape as ⵎ, plus a second stroke of any
///   kind that intersects it.
/// - ⵟ (yatt, "tˤ") — like ⴹ, but the crossing stroke must be horizontal,
///   and a third, vertical stroke must cross that horizontal one.
/// - ⴼ (yaf, "f") — a ⵎ-shaped stroke to the right of a horizontal line's
///   center, a second stroke shaped the same way but mirrored
///   horizontally (both endpoints in the *left* half of its own bounding
///   box instead) to that horizontal's left, and the horizontal line
///   itself crossing each of them exactly once.
/// - ⵏ (yan, "n") — a single vertical line that doesn't cross any other
///   recent stroke.
/// - ⵜ (yat, "t") — a vertical line crossed by one horizontal line.
/// - ⵐ (yagn, "ñ") — a vertical line crossed by two horizontal lines.
/// - ⵌ (yazh, "ẓ") — two vertical lines crossed by two horizontal lines.
///
/// Dots are drawn as hollow circles (a tap, not a drag). A vertical column
/// is dots ordered top to bottom, checked pairwise for overlapping x
/// centers; a horizontal row is dots ordered left to right, checked
/// pairwise for overlapping y centers; a cross splits 4 dots into a top
/// row and a bottom row, each checked for overlapping y centers like a
/// row, but at two different heights. Either way, they read as one
/// grouped mark rather than unrelated taps. ⴶ and ⵑ are checked separately
/// (see [TifinaghLayer._classifyMixed] / [TifinaghLayer._classifyLineDot])
/// since they combine dots with a line stroke, and take priority over a
/// plain dot or line match. ⵔ and ⵙ and ⵀ are also checked separately (see
/// [TifinaghLayer._selfIntersections] / [TifinaghLayer._classifyLoop]):
/// find whichever of the last 2 strokes is the loop, then check the most
/// recent dot (ⵙ) or the other stroke, if it's a non-looping vertical line
/// crossing the loop exactly twice (ⵀ). ⵋ is checked by each stroke's
/// horizontal travel direction — [TifinaghLayer._isLeftToRight] splits the
/// stroke by horizontal direction change (see
/// [TifinaghLayer._splitByHorizontalDirectionChange]) and reads the
/// direction off the widest resulting segment, unlike
/// [TifinaghLayer._isVertical] which just compares which axis moved
/// further overall — so it doesn't care whether a stroke is vertical,
/// horizontal, or diagonal, only which way it went; plus
/// [TifinaghLayer._crossings] between the two strokes, reused from ⵀ. ⵢ
/// reuses that same horizontal split, but on a single stroke — 3
/// segments in an alternating left/right/left or right/left/right
/// sequence — plus [TifinaghLayer._isGoingDown], the vertical
/// counterpart of [TifinaghLayer._isLeftToRight] (split by vertical
/// direction change, direction read off the widest segment), to pick
/// which of the two sequences is expected. ⵣ splits its two non-vertical
/// strokes by vertical direction change too — [TifinaghLayer
/// ._verticalDirectionSequence] requires exactly 2 segments per stroke
/// (unlike ⵢ's 3, and read off every segment, not just the widest, since
/// a 2-segment split always alternates) and requires the two strokes'
/// sequences to start in opposite directions. ⴸ reuses
/// [TifinaghLayer._verticalDirectionSequence] on a single stroke,
/// requiring the down-then-up sequence specifically. ⴳ combines the
/// horizontal split (3 segments, as for ⵢ, but only the first and last
/// segments' vertical direction is checked — up then down) with
/// [TifinaghLayer._selfIntersections], and is checked ahead of the bare
/// ⵔ self-intersection match since it's the more specific of the two. ⵛ
/// needs exactly 2 self-intersections, located via
/// [TifinaghLayer._selfIntersectionPoints] (same dedup as
/// [TifinaghLayer._selfIntersections], but keeping each crossing's
/// location, computed by [TifinaghLayer._intersectionPoint]) — one above
/// and one below the bounding box's vertical center. ⵍ reuses
/// [TifinaghLayer._isLeftToRight] and [TifinaghLayer._isGoingDown]
/// together on the non-vertical stroke to require it ascends left to
/// right, plus a plain start/end crossing check against both verticals,
/// like [TifinaghLayer._matchesGrid]'s. ⵎ just checks where the stroke's
/// endpoints fall relative to its own bounding box center, plus
/// [TifinaghLayer._isVertical] on the stroke as a whole. ⴹ reuses that
/// same shape check ([TifinaghLayer._isMShaped]) on exactly one of the
/// last 2 strokes, and requires the other one — of any shape — to
/// actually cross its path ([TifinaghLayer._crossings], reused from ⵀ
/// and ⵋ), not just its start/end chord. ⵟ adds a third stroke on top of
/// ⴹ's shape: the crossing stroke must specifically be horizontal, and a
/// separate vertical stroke must cross that horizontal one (a plain
/// start/end check, since both are straight). ⴼ reuses ⵎ's shape check
/// too, plus [TifinaghLayer._isMShapedMirrored] (the same check with the
/// bounding-box-half comparison flipped) for a second, mirrored stroke,
/// requires the plain-ⵎ stroke's own bounding-box center to fall right of
/// the third (horizontal) stroke's center and the mirrored one's to fall
/// left of it, and requires that horizontal stroke's
/// [TifinaghLayer._crossings] against each of the other two to be exactly
/// 1. ⴾ is a dot-only pattern:
/// among the last 3 dots, find a pair with overlapping x ranges (same x
/// check as [TifinaghLayer._matchesColumnDots]), confirm the remaining
/// dot's x range is clear of the pair's, to the right, and that its y
/// falls between the pair's own top and bottom.
///
/// A stroke counts as vertical/horizontal using the same rule as
/// `TallyLayer`'s `_isVertical`: comparing only the stroke's start/end
/// points, whichever axis moved further wins.
///
/// Recognition is live — it re-evaluates the most recently completed
/// stroke(s), so drawing keeps updating the readout. Nothing is discarded;
/// strokes that don't match are still rendered, just reported as
/// unrecognized.
class TifinaghLayer extends Layer {
  static const double _dotThreshold = 5;
  static const double _dotRadius = 15;
  static const double _minDragDistance = 8;

  /// Minimum bounding-box width/height for [_isMShaped]/
  /// [_isMShapedMirrored]'s "which half" endpoint check (and
  /// [_isDShapedLb]'s own rotated version) to be meaningful. A plain,
  /// nearly straight line (like Libyco-Berber's own n or z²) has a
  /// bounding box that's almost flat along the axis these checks split
  /// on, so its start/end could fall on either side of the box's own
  /// center purely from sub-pixel jitter — without this floor, that
  /// could get it mistaken for an ⵎ (or d) bulge it was never meant to
  /// have.
  static const double _minMShapeBulge = 4;

  /// Ahaggar (the recognizer's native forms, see the class doc) enables
  /// every shape except [_regionOnlyShapes]. Ghat reuses whichever Ahaggar
  /// shapes it draws identically, or shares the same abstract stroke
  /// pattern as, plus its own shapes for letters Ahaggar doesn't have —
  /// see [_ghatShapes] — covering a-n, q-t, w, y, z, and ẓ so far. Ghat has
  /// no ñ, ng, ṭ, or ž/j letter at all. Aïr reuses shapes the same way —
  /// see [_airShapes] — covering a-n, q, r-t, w-y, z, ž/j, and ġ so far,
  /// and has no ḍ, ñ, ng, ṭ, or ẓ letter at all. Azawagh reuses shapes the same
  /// way too — see [_azawaghShapes] — covering a, b, d, f, g, h, k-n, q,
  /// r-z, ẓ, ž/j, and ɣ/gh so far (q shares x's gesture, and ẓ shares z's —
  /// both pairs drawn identically, glyph ⵆ and ⵣ respectively, unlike
  /// every other region), and has no ḍ, ġ, ñ, ng, or ṭ letter at all.
  /// Adrar reuses shapes the same way too — see
  /// [_adrarShapes] — covering every sound its own alphabet has a letter
  /// for (a, b, d, f, g, h, k-n, q, ɣ/gh, r, s, š, t, w, x, y, z), and has
  /// no ḍ, ġ, ñ, ng, ṭ, ẓ, or ž/j letter at all. Libyco-Berber is a
  /// different alphabet entirely (not a Tuareg regional variant) — see
  /// [_libycoBerberShapes] — with its own dedicated shapes covering n, l,
  /// h, z², b, r, f, y, s³, t, s⁴, q/ɣ?, m, s¹, z¹, s², g, w, k, ṭ, d, and
  /// z³ so far (s¹ reuses Ahaggar's own m gesture, and w is drawn
  /// identically to Libyco-Berber's own l — see [_regionLabelOverrides]
  /// and [_TifinaghLetter.yalLb] respectively). f is implemented for
  /// every Tuareg region: Ahaggar,
  /// Ghat, Aïr, and Azawagh all share [_TifinaghLetter.yaf] (their f glyph
  /// is identical, ⴼ); Adrar's f glyph (ⵊ) differs, so it reuses
  /// [_TifinaghLetter.yagn] instead (see [_adrarShapes]). Neo-Tifinagh,
  /// IRCAM's modern standardized alphabet, is a different alphabet entirely
  /// too (not a Tuareg regional variant) — see [_neoTifinaghShapes] for the
  /// full letter-by-letter breakdown — covering a, b, c, d, ḍ, e, f, g, gw,
  /// h, ḥ, i, j, kh, l, m, n, r, ṛ, s, ṣ, t, ṭ, u, y, z, and ẓ so far: most reuse an
  /// existing Ahaggar/Libyco-Berber/Adrar gesture as-is or relabeled (see
  /// [_regionLabelOverrides]); b, ṛ, ṣ, and ẓ are dedicated Neo-Tifinagh
  /// shapes with no equivalent elsewhere (loop-plus-a-second-line variants
  /// for b/ṛ/ṣ, see [_classifyLoop]; ⵣ-plus-a-4th-line for ẓ, see
  /// [_classifyZEmphatic]); and ḥ is one more dedicated shape — a vertical
  /// line crossed by a diagonal one (unlike t's own vertical-crossed-by-
  /// horizontal), positioned clear of the vertical's own top quarter (see
  /// [_classifyNeoTifinaghH]).
  String region = 'Ahaggar';

  /// Which sounds the recognizer currently supports per region — matched
  /// against [TuaregRow.ipa] for Tuareg regions, [NeoTifinaghRow.ipa] for
  /// Neo-Tifinagh, or against
  /// [LibycoBerberRow.transliteration] for Libyco-Berber — enabled one
  /// letter at a time as classifiers are built, so this always matches
  /// [_isEnabledInRegion]/[_ghatShapes]/[_airShapes]/[_azawaghShapes]/
  /// [_adrarShapes]/[_libycoBerberShapes]/[_neoTifinaghShapes]. Used by
  /// [TifinaghPage] to hide
  /// not-yet-recognized letters from the legend rather than listing ones
  /// that can't actually be drawn yet.
  static const recognizedIpa = {
    'Ahaggar': {
      'a', 'b', 'd', 'ḍ', 'f', 'g', 'ġ', 'h', 'x', 'k', 'l', 'm', 'n', 'ñ',
      'ng', 'q', 'ɣ/gh', 'r', 's', 'š', 't', 'ṭ', 'w', 'y', 'z', 'ẓ', 'ž/j',
    },
    'Ghat': {
      'a', 'b', 'd', 'ḍ', 'f', 'g', 'ġ', 'h', 'x', 'k', 'l', 'm', 'n',
      'q', 'ɣ/gh', 'r', 's', 'š', 't', 'w', 'y', 'z', 'ẓ',
    },
    'Aïr': {
      'a', 'b', 'd', 'f', 'g', 'ġ', 'h', 'x', 'k', 'l', 'm', 'n',
      'q', 'ɣ/gh', 'r', 's', 'š', 't', 'w', 'y', 'z', 'ž/j',
      // no ḍ or ẓ letter at all.
    },
    'Azawagh': {
      'a', 'b', 'd', 'f', 'g', 'h', 'x', 'k', 'l', 'm', 'n', 'q', 'ɣ/gh',
      'r', 's', 'š', 't', 'w', 'y', 'z', 'ẓ', 'ž/j',
      // x and q are drawn identically (same glyph, ⵆ), and so are z, ẓ,
      // and ž/j (all glyph ⵣ) — see _regionLabelOverrides.
    },
    'Adrar': {
      'a', 'b', 'd', 'f', 'g', 'h', 'x', 'k', 'l', 'm', 'n', 'q', 'ɣ/gh',
      'r', 's', 'š', 't', 'w', 'y', 'z',
      // every sound Adrar's own alphabet has a letter for is implemented.
    },
    'Libyco-Berber': {
      'n', 'l', 'h', 'z²', 'b', 'r', 'f', 'y', 's³', 't', 's⁴', 'q/ɣ?', 'm',
      's¹', 'z¹', 's²', 'g', 'w', 'k', 'ṭ', 'd', 'z³',
      // everything else isn't implemented yet.
    },
    // Matched against [NeoTifinaghRow.ipa], not [NeoTifinaghRow.latin] (see
    // [TifinaghPage]'s letterChips) — so this lists 'æ' for a, not 'a'.
    'Neo-Tifinagh': {
      'æ', 'h', 'n', 'ɡ', 'dˤ', 'ə', 'f', 'm', 's', 'r', 'rˤ', 'j', 'w', 'b',
      'ʃ', 'sˤ', 't', 'd', 'tˤ', 'z', 'zˤ', 'ʒ', 'i', 'ħ', 'l', 'χ', 'ɡʷ',
      // everything else isn't implemented yet.
    },
  };

  /// Shapes recognized under Ghat: same-drawn letters reused as-is (a, b,
  /// d, ḍ, f, h, x, k, l, m, n, q, ɣ/gh, r, s, š, t, w), four reused from
  /// Ahaggar under a different label (see [_regionLabelOverrides]), and one
  /// shape ([_TifinaghLetter.yi]) that only exists in Ghat's alphabet (see
  /// [_regionOnlyShapes]):
  /// - [_TifinaghLetter.yaj] — Ghat's g is glyph ⴶ, the same glyph/shape
  ///   as Ahaggar's ġ (two dots over a vertical line).
  /// - [_TifinaghLetter.yagn] — Ghat's ġ is glyph ⵊ, drawn as a vertical
  ///   line crossed by two horizontal lines (one above its center, one
  ///   below) — the same abstract shape as Ahaggar's ñ (ⵐ), though a
  ///   different glyph, since the grid classifier only checks that each
  ///   horizontal crosses the vertical, not where along it.
  /// - [_TifinaghLetter.yi] — Ghat's y is glyph ⵉ: the same zigzag as
  ///   Ahaggar's y (ⵢ, [_TifinaghLetter.yay]) with one more segment
  ///   appended, going right and down (see [_classifyYi]).
  /// - [_TifinaghLetter.yazh] and [_TifinaghLetter.yaz] — Ghat swaps z and
  ///   ẓ relative to Ahaggar: Ghat's z is glyph ⵌ, the same glyph/shape as
  ///   Ahaggar's ẓ (two vertical lines crossed by two horizontal lines);
  ///   Ghat's ẓ is glyph ⵣ, the same glyph/shape as Ahaggar's z.
  static const _ghatShapes = {
    _TifinaghLetter.ya,
    _TifinaghLetter.yab,
    _TifinaghLetter.yad,
    _TifinaghLetter.yadd,
    _TifinaghLetter.yaf,
    _TifinaghLetter.yah,
    _TifinaghLetter.yakh,
    _TifinaghLetter.yak,
    _TifinaghLetter.yal,
    _TifinaghLetter.yam,
    _TifinaghLetter.yan,
    _TifinaghLetter.yaj,
    _TifinaghLetter.yagn,
    _TifinaghLetter.yaq,
    _TifinaghLetter.yagh,
    _TifinaghLetter.yar,
    _TifinaghLetter.yas,
    _TifinaghLetter.yash,
    _TifinaghLetter.yat,
    _TifinaghLetter.yu,
    _TifinaghLetter.yi,
    _TifinaghLetter.yazh,
    _TifinaghLetter.yaz,
  };

  /// Shapes recognized under Aïr: same-drawn letters reused as-is (a, b,
  /// f, h, k, l, m, n, r, s, š, t, w), five reused from Ahaggar/Ghat under a
  /// different label (see [_regionLabelOverrides]), the same shape Ghat
  /// uses for y ([_TifinaghLetter.yi], which doesn't exist in Ahaggar's
  /// own alphabet — see [_regionOnlyShapes]), and one shape
  /// ([_TifinaghLetter.yaghc]) that only exists in Aïr's alphabet:
  /// - [_TifinaghLetter.yaj] — Aïr's g is glyph ⴶ, same as Ghat's g (two
  ///   dots over a vertical line).
  /// - [_TifinaghLetter.yad] — Aïr's d is glyph ⴹ, drawn with the same
  ///   down-then-up stroke as Ahaggar/Ghat's d (glyph ⴸ there); Aïr just
  ///   labels that gesture with a different glyph.
  /// - [_TifinaghLetter.yah] — Aïr's h is glyph ⵂ, the same four-dot column
  ///   as Ahaggar/Ghat's h, drawn and labeled identically (no override).
  /// - [_TifinaghLetter.yagh] and [_TifinaghLetter.yaq] — Aïr's x and q
  ///   are both glyph ⵗ (the real Wikipedia table gives them the same
  ///   glyph for Aïr), so both shapes are labeled "x | q" rather than
  ///   picking one, the same combo treatment as Azawagh's x/q (see
  ///   [_azawaghShapes]) — [_TifinaghLetter.yagh] drawn as the three-dot
  ///   column Ahaggar/Ghat use for ɣ/gh, [_TifinaghLetter.yaq] drawn as
  ///   the three-dot row Ahaggar/Ghat use for q (glyph ⵈ there); unlike
  ///   Azawagh, these are two distinct gestures rather than one shared
  ///   gesture, but since a human can't reliably tell a tight 3-dot row
  ///   from a 3-dot column at a glance either, both get the combined label.
  /// - [_TifinaghLetter.yi] — Aïr's y is glyph ⵉ, same shape as Ghat's y.
  /// - [_TifinaghLetter.yaz] — Aïr's z is glyph ⵣ, same glyph/shape as
  ///   Ahaggar's z (unlike Ghat, which swaps z and ẓ, Aïr doesn't have ẓ
  ///   at all so no swap is needed).
  /// - [_TifinaghLetter.yazh] — Aïr's ž/j is glyph ⵌ, the same glyph/shape
  ///   as Ahaggar's ẓ (two vertical lines crossed by two horizontal
  ///   lines); Aïr has no ẓ, so this shape is free to mean ž/j instead.
  /// - [_TifinaghLetter.yaghc] — Aïr's ɣ/gh is glyph ⵘ: Ahaggar's x
  ///   (ⵆ, the four-dot rectangle) with a 5th dot added in the middle
  ///   (see [_matchesCrossCenterDots]). Aïr's ġ is the same glyph ⵘ, so
  ///   this shape is labeled "ɣ | gh | ġ", combining all three readings the
  ///   same way Azawagh's x/q combo does (see [_azawaghShapes]) — joined
  ///   with "|" rather than "/" so it reads as distinct alternatives rather
  ///   than a single sound's two spellings (contrast the plain "ɣ/gh"
  ///   label used elsewhere for that unambiguous case).
  static const _airShapes = {
    _TifinaghLetter.ya,
    _TifinaghLetter.yab,
    _TifinaghLetter.yad,
    _TifinaghLetter.yaf,
    _TifinaghLetter.yah,
    _TifinaghLetter.yaq,
    _TifinaghLetter.yagh,
    _TifinaghLetter.yaghc,
    _TifinaghLetter.yak,
    _TifinaghLetter.yal,
    _TifinaghLetter.yam,
    _TifinaghLetter.yan,
    _TifinaghLetter.yaj,
    _TifinaghLetter.yar,
    _TifinaghLetter.yas,
    _TifinaghLetter.yash,
    _TifinaghLetter.yat,
    _TifinaghLetter.yu,
    _TifinaghLetter.yi,
    _TifinaghLetter.yaz,
    _TifinaghLetter.yazh,
  };

  /// Shapes recognized under Azawagh: same-drawn letters reused as-is (a,
  /// b, d, f, h, x, k, l, m, n, r, s, š, t, w, y, z), plus one reused from
  /// Ahaggar/Ghat/Aïr under a different label (see
  /// [_regionLabelOverrides]), and Ahaggar/Ghat's own ɣ/gh shape:
  /// - [_TifinaghLetter.yaj] — Azawagh's g is glyph ⴶ, same as Ghat/Aïr's g
  ///   (two dots over a vertical line).
  /// - [_TifinaghLetter.yakh] — Azawagh's x is glyph ⵆ, same glyph/shape
  ///   as Ahaggar's x (unlike Aïr, which relabels it ⵗ); Azawagh's q is
  ///   also glyph ⵆ (drawn the exact same way, unlike every other region,
  ///   where x and q are distinct glyphs/gestures), so this shape is
  ///   relabeled "x | q" — see [_regionLabelOverrides] — rather than
  ///   picking just one.
  /// - [_TifinaghLetter.yagh] — Azawagh's ɣ/gh is glyph ⵗ, the same
  ///   three-dot column as Ahaggar/Ghat's ɣ/gh (Aïr's ɣ/gh instead uses
  ///   the Aïr-only [_TifinaghLetter.yaghc]).
  /// - [_TifinaghLetter.yaz] — Azawagh's z and ẓ are both glyph ⵣ (unlike
  ///   every other region, where they're distinct glyphs), so this
  ///   shape — the same one-vertical-plus-two-strokes shape as Ahaggar's
  ///   own z — is relabeled "z | ẓ", the same combo treatment as
  ///   [_TifinaghLetter.yakh]'s x | q.
  /// - [_TifinaghLetter.yazh] — Azawagh's ž/j is glyph ⵌ, the same
  ///   two-vertical-lines-crossed-by-two-horizontal-lines shape as
  ///   Ahaggar's own ẓ; Azawagh has no ẓ of its own separate from z (see
  ///   [_TifinaghLetter.yaz] above), so this shape is free to mean ž/j
  ///   instead, with no combo needed.
  static const _azawaghShapes = {
    _TifinaghLetter.ya,
    _TifinaghLetter.yab,
    _TifinaghLetter.yad,
    _TifinaghLetter.yaf,
    _TifinaghLetter.yah,
    _TifinaghLetter.yakh,
    _TifinaghLetter.yak,
    _TifinaghLetter.yal,
    _TifinaghLetter.yam,
    _TifinaghLetter.yan,
    _TifinaghLetter.yaj,
    _TifinaghLetter.yagh,
    _TifinaghLetter.yar,
    _TifinaghLetter.yas,
    _TifinaghLetter.yash,
    _TifinaghLetter.yat,
    _TifinaghLetter.yu,
    _TifinaghLetter.yay,
    _TifinaghLetter.yaz,
    _TifinaghLetter.yazh,
  };

  /// Shapes recognized under Adrar: same-drawn letters reused as-is (a, b,
  /// d, h, k, l, m, n, q, ɣ/gh, r, s, t, x), Ghat/Aïr's own
  /// [_TifinaghLetter.yi] for y and (like Ghat/Aïr) [_TifinaghLetter.yu]
  /// for w with no relabeling needed, plus three reused from Ahaggar/Ghat
  /// under a different label (see [_regionLabelOverrides]):
  /// - [_TifinaghLetter.yaj] — Adrar's g is glyph ⴶ, same as Ghat/Aïr/
  ///   Azawagh's g (two dots over a vertical line).
  /// - [_TifinaghLetter.yazz] — Adrar's z is glyph ⵋ, the same two-crossing-
  ///   strokes shape as Ahaggar's ž/j (Adrar has no ž/j of its own, so this
  ///   shape is free to mean z instead — unlike Ahaggar's own z, which is a
  ///   different shape, [_TifinaghLetter.yaz]).
  /// - [_TifinaghLetter.yagn] — Adrar's f is glyph ⵊ, the same vertical-
  ///   line-crossed-by-two-horizontals shape as Ghat's ġ (Adrar has no ñ of
  ///   its own — the letter this shape is natively defined for — so it's
  ///   free to mean f instead).
  /// - [_TifinaghLetter.yashDr] — Adrar's š is glyph 𐌚, its own dedicated
  ///   shape (see [_regionOnlyShapes] and [_classifyAdrarSh]) — unlike
  ///   every other region's š (ⵛ, [_TifinaghLetter.yash]).
  static const _adrarShapes = {
    _TifinaghLetter.ya,
    _TifinaghLetter.yab,
    _TifinaghLetter.yad,
    _TifinaghLetter.yaj,
    _TifinaghLetter.yah,
    _TifinaghLetter.yakh,
    _TifinaghLetter.yak,
    _TifinaghLetter.yal,
    _TifinaghLetter.yam,
    _TifinaghLetter.yan,
    _TifinaghLetter.yaq,
    _TifinaghLetter.yagh,
    _TifinaghLetter.yar,
    _TifinaghLetter.yas,
    _TifinaghLetter.yat,
    _TifinaghLetter.yu,
    _TifinaghLetter.yi,
    _TifinaghLetter.yazz,
    _TifinaghLetter.yashDr,
    _TifinaghLetter.yagn,
  };

  /// Shapes recognized under Libyco-Berber, the ancient script ancestor of
  /// Tifinagh — not a Tuareg regional variant, so unlike the other
  /// regions its letters have no relation to [tuaregRows]/[TuaregRow] at
  /// all (see [LibycoBerberRow] instead), and its recognized letters have
  /// no Unicode glyph of their own (see [_libycoBerberImages]):
  /// - [_TifinaghLetter.yan] — n is a single vertical line that doesn't
  ///   cross any other recent stroke (see [_classifyN]), the same shape
  ///   as every Tuareg region's own n.
  /// - [_TifinaghLetter.yalLb] — l (and w, the same shape, hence the
  ///   "l | w" label) is two vertical lines whose y-ranges overlap, with
  ///   neither crossing the other (see [_classifyLibycoBerberLW]),
  ///   unlike any Tuareg region's own l.
  /// - [_TifinaghLetter.yahLb] — h is three horizontal lines stacked with
  ///   an overlapping x-range (see [_classifyLibycoBerberH]).
  /// - [_TifinaghLetter.yaz2Lb] — z² is a single horizontal line that
  ///   doesn't cross any other stroke (see [_classifyLibycoBerberZ2]).
  /// - [_TifinaghLetter.yas] — b is drawn the same loop-with-a-dot-inside
  ///   gesture as Ahaggar's own s (see [_regionLabelOverrides]; the closest
  ///   modern equivalent shown is still Ahaggar's b, ⵀ, not ⵙ).
  /// - [_TifinaghLetter.yarLb] and [_TifinaghLetter.yafLb] — r and f are
  ///   both a self-crossing loop split into exactly 3 horizontal-direction
  ///   segments, with both endpoints below the loop's own self-intersection
  ///   point ([_isGShaped]), distinguished from each other by which way the
  ///   first segment goes (see [_classifyLibycoBerberRF]) — dedicated
  ///   shapes rather than reuses of Ahaggar's own r/g, since neither of
  ///   those gestures reliably tells this pair apart.
  /// - [_TifinaghLetter.yayLb] and [_TifinaghLetter.yas3Lb] — y and s³ are
  ///   both a single stroke, split by horizontal direction change, that
  ///   descends overall: y into 3 segments (right-left-right, see
  ///   [_classifyLibycoBerberY]), s³ into 4 (right-left-right-left, see
  ///   [_classifyLibycoBerberS3]) — each the mirror image of an existing
  ///   Tuareg shape (Ahaggar's own y/ⵢ and Ghat's y/ⵉ respectively), so
  ///   dedicated shapes rather than reuses.
  /// - [_TifinaghLetter.yatLb] and [_TifinaghLetter.yas4Lb] — t and s⁴ are
  ///   both a vertical line crossed by a horizontal line — the same shape
  ///   as every Tuareg region's own t ([_TifinaghLetter.yat]) — but
  ///   distinguished from each other by *where* along the horizontal line
  ///   the crossing falls (see [_classifyLibycoBerberTS4]): the middle
  ///   half (roughly its own 2nd/3rd quarter) for t, its own leftmost
  ///   quarter for s⁴. Dedicated shapes rather than a reuse of
  ///   [_TifinaghLetter.yat], since that generic pattern doesn't check
  ///   crossing position at all.
  /// - [_TifinaghLetter.yaqLb] — q/ɣ? is a horizontal line with a dot
  ///   above it and a dot below it, both x-aligned with the line's own x
  ///   center (see [_classifyLibycoBerberQ]) — the mirrored layout of
  ///   Ahaggar's own ⵑ (a vertical line with just one dot below it).
  /// - [_TifinaghLetter.yamLb] — m is a single stroke whose first and last
  ///   points both fall in the *left* half of its own bounding box (see
  ///   [_isMShapedMirrored]) — the horizontal mirror of Ahaggar's own m
  ///   ([_TifinaghLetter.yam], right half instead).
  /// - [_TifinaghLetter.yaz1Lb] — z¹ is two vertical lines, each crossed
  ///   exactly once by one horizontal line, one falling left of the
  ///   horizontal's own center and the other right of it (see
  ///   [_classifyLibycoBerberZ1]).
  /// - [_TifinaghLetter.yas2Lb] — s² is [_TifinaghLetter.yafLb]'s own
  ///   self-crossing loop shape with a 4th segment appended
  ///   (right-left-right-left), where that last segment must itself read
  ///   as horizontal (see [_classifyLibycoBerberS2]).
  /// - [_TifinaghLetter.yagLb] — g is a single stroke split by horizontal
  ///   direction change into exactly 2 segments: the first going left
  ///   while also moving up, the second going right while reading as
  ///   horizontal (see [_classifyLibycoBerberG]) — unrelated to Ahaggar's
  ///   own g ([_TifinaghLetter.yag], a 3-segment self-crossing shape).
  /// - [_TifinaghLetter.yakLb] — k is [_TifinaghLetter.yagLb]'s own shape
  ///   plus a second stroke above it, shaped the same way but with its
  ///   first segment going down instead of up (see
  ///   [_classifyLibycoBerberK]).
  /// - [_TifinaghLetter.yattLb] — ṭ is a horizontal line crossing a
  ///   second line split by horizontal direction change into exactly 2
  ///   segments, right then left (see [_classifyLibycoBerberTt]).
  /// - [_TifinaghLetter.yadLb] — d is [_TifinaghLetter.yam]'s own
  ///   endpoint check rotated 90°: bottom half instead of right half,
  ///   horizontal chord instead of vertical (see [_isDShapedLb]).
  /// - [_TifinaghLetter.yaz3Lb] — z³ is the d shape (the same shape as
  ///   [_TifinaghLetter.yadLb]) crossed by a vertical line through its
  ///   middle (see [_classifyLibycoBerberZ3]).
  static const _libycoBerberShapes = {
    _TifinaghLetter.yan,
    _TifinaghLetter.yalLb,
    _TifinaghLetter.yahLb,
    _TifinaghLetter.yaz2Lb,
    _TifinaghLetter.yas,
    _TifinaghLetter.yarLb,
    _TifinaghLetter.yafLb,
    _TifinaghLetter.yayLb,
    _TifinaghLetter.yas3Lb,
    _TifinaghLetter.yatLb,
    _TifinaghLetter.yas4Lb,
    _TifinaghLetter.yaqLb,
    _TifinaghLetter.yamLb,
    _TifinaghLetter.yaz1Lb,
    _TifinaghLetter.yas2Lb,
    _TifinaghLetter.yagLb,
    _TifinaghLetter.yakLb,
    _TifinaghLetter.yattLb,
    _TifinaghLetter.yadLb,
    _TifinaghLetter.yaz3Lb,
    // s¹ reuses Ahaggar's own m gesture as-is (see _regionLabelOverrides),
    // since the two letterforms resemble each other closely.
    _TifinaghLetter.yam,
  };

  /// Libyco-Berber's own letterform image per shape (`assets/tifi/
  /// libyco_berber/<file>`, see [_ensureLibycoBerberImage]) — there's no Unicode glyph
  /// for this script, so [TifinaghLayer.paint] draws this bundled image
  /// instead of (in addition to) the shape's [_TifinaghLetter.glyph] text.
  /// [_TifinaghLetter.yalLb] shows `l.png` even though it's also drawn for
  /// w — an arbitrary pick between the two, same as its "l | w" label.
  static const _libycoBerberImages = {
    _TifinaghLetter.yan: 'n.png',
    _TifinaghLetter.yalLb: 'l.png',
    _TifinaghLetter.yahLb: 'h.png',
    _TifinaghLetter.yaz2Lb: 'z2.png',
    _TifinaghLetter.yas: 'b.png',
    _TifinaghLetter.yarLb: 'r.png',
    _TifinaghLetter.yafLb: 'f.png',
    _TifinaghLetter.yayLb: 'y.png',
    _TifinaghLetter.yas3Lb: 's3.png',
    _TifinaghLetter.yatLb: 't.png',
    _TifinaghLetter.yas4Lb: 's4.png',
    _TifinaghLetter.yaqLb: 'q.png',
    _TifinaghLetter.yamLb: 'm.png',
    _TifinaghLetter.yam: 's1.png',
    _TifinaghLetter.yaz1Lb: 'z1.png',
    _TifinaghLetter.yas2Lb: 's2.png',
    _TifinaghLetter.yagLb: 'g.png',
    _TifinaghLetter.yakLb: 'k.png',
    _TifinaghLetter.yattLb: 'tt.png',
    _TifinaghLetter.yadLb: 'd.png',
    _TifinaghLetter.yaz3Lb: 'z3.png',
  };

  /// Shapes recognized under Neo-Tifinagh, IRCAM's modern standardized
  /// alphabet — not a Tuareg regional variant (its letters have no
  /// relation to [tuaregRows]/[TuaregRow]; see [NeoTifinaghRow] instead)
  /// and not Libyco-Berber either (though it reuses some of its shapes),
  /// so far covering a, b, c, d, ḍ, e, f, g, gw, h, ḥ, i, j, kh, m, n, r,
  /// s, ṣ, t, ṭ, u, y, z, and ẓ:
  /// - [_TifinaghLetter.ya] — Neo-Tifinagh's a is glyph ⴰ, the same single
  ///   dot as every Tuareg region's own a.
  /// - [_TifinaghLetter.yab] — Neo-Tifinagh's h is glyph ⵀ, the same
  ///   loop-with-a-crossing-vertical-line shape as Ahaggar's own b (see
  ///   [_regionLabelOverrides]; Neo-Tifinagh has no letter drawn this way
  ///   for b itself, glyph ⴱ, so the shape is free to mean h instead).
  /// - [_TifinaghLetter.yabNt] — Neo-Tifinagh's own b (glyph ⴱ) is instead
  ///   a loop crossed twice by a *horizontal* line — the horizontal
  ///   counterpart of Ahaggar's own b/h shape above (see [_classifyLoop]).
  /// - [_TifinaghLetter.yan] — Neo-Tifinagh's n is glyph ⵏ, the same
  ///   non-crossing vertical line as every Tuareg region's own n (see
  ///   [_classifyN]) — no override needed, since the glyph/label/sound
  ///   already match.
  /// - [_TifinaghLetter.yafLb] — Neo-Tifinagh's g is glyph ⴳ, the same
  ///   self-crossing-loop-split-into-3-horizontal-segments shape as
  ///   Libyco-Berber's own f (see [_regionLabelOverrides] and
  ///   [_classifyLibycoBerberRF]), but recognized regardless of which way
  ///   the first segment goes (see [_classifyNeoTifinaghG]) — unlike
  ///   Libyco-Berber, which reserves the other direction for its own r
  ///   ([_TifinaghLetter.yarLb]), Neo-Tifinagh has no letter that needs
  ///   that direction, so both read as g there. Unrelated to Ahaggar's
  ///   own g ([_TifinaghLetter.yag], a different 3-segment self-crossing
  ///   shape, split by vertical rather than horizontal direction change).
  /// - [_TifinaghLetter.yadd] — Neo-Tifinagh's ḍ is glyph ⴹ, the same
  ///   ⵎ-shaped-stroke-plus-a-crossing-stroke shape as Ahaggar's own ḍ
  ///   ([_classifyDEmphatic]) — no override needed, since the
  ///   glyph/label/sound already match.
  /// - [_TifinaghLetter.yaqLb] — Neo-Tifinagh's e is glyph ⴻ, the same
  ///   horizontal-line-with-a-dot-above-and-a-dot-below shape as
  ///   Libyco-Berber's own q/ɣ? (see [_regionLabelOverrides] and
  ///   [_classifyLibycoBerberQ]).
  /// - [_TifinaghLetter.yaf] — Neo-Tifinagh's f is glyph ⴼ, the same
  ///   3-stroke shape as Ahaggar's own f — no override needed, since the
  ///   glyph/label/sound already match.
  /// - [_TifinaghLetter.yam] — Neo-Tifinagh's m is glyph ⵎ, the same
  ///   single-stroke shape as Ahaggar's own m — no override needed.
  /// - [_TifinaghLetter.yas] — Neo-Tifinagh's s is glyph ⵙ, the same
  ///   loop-with-a-dot-inside shape as Ahaggar's own s — no override
  ///   needed.
  /// - [_TifinaghLetter.yar] — Neo-Tifinagh's r is glyph ⵔ, the same
  ///   self-crossing stroke as Ahaggar's own r — no override needed.
  /// - [_TifinaghLetter.yarrNt] and [_TifinaghLetter.yassNt] — Neo-Tifinagh's
  ///   ṛ and ṣ are both a loop crossed only once by a second line —
  ///   distinguished from each other by whether that line descends (ṛ) or
  ///   ascends (ṣ) overall (see [_classifyLoop]/[_isGoingDown]) —
  ///   unrelated to Ahaggar's own r ([_TifinaghLetter.yar], a single
  ///   self-crossing stroke with no second line at all, now reused above
  ///   for Neo-Tifinagh's own plain r).
  /// - [_TifinaghLetter.yay] — Neo-Tifinagh's y is glyph ⵢ, the same
  ///   3-segment zigzag as Ahaggar's own y — no override needed.
  /// - [_TifinaghLetter.yash] — Neo-Tifinagh's c is glyph ⵛ, the same
  ///   twice-self-crossing shape as Ahaggar's own š — no override needed,
  ///   since the glyph/label/sound already match.
  /// - [_TifinaghLetter.yat] — Neo-Tifinagh's t is glyph ⵜ, the same
  ///   vertical-line-crossed-by-a-horizontal-line shape as Ahaggar's own
  ///   t — no override needed, since the glyph/label/sound already match.
  /// - [_TifinaghLetter.yahNt] — Neo-Tifinagh's ḥ is glyph ⵃ: a vertical
  ///   line crossed by a *diagonal* one instead ([_isDiagonal]), whose own
  ///   y-range stays clear of the vertical's own top quarter (see
  ///   [_classifyNeoTifinaghH]) — unrelated to Ahaggar, which has no ḥ.
  /// - [_TifinaghLetter.yu] — Neo-Tifinagh's u is glyph ⵓ, the same 2-dot
  ///   column as Ahaggar's own u/w (Ahaggar draws both the same way; see
  ///   [TuaregRow]'s own w row) — no override needed, since the
  ///   glyph/label/sound already match. Neo-Tifinagh's own w (ⵡ) is a
  ///   different glyph — see [_TifinaghLetter.yawNt] below.
  /// - [_TifinaghLetter.yadLb] — Neo-Tifinagh's d is glyph ⴷ, the same
  ///   rotated-ⵎ-endpoint shape as Libyco-Berber's own d (see
  ///   [_regionLabelOverrides] and [_isDShapedLb]) — relabeled from
  ///   Libyco-Berber's plain-text glyph to the real Unicode glyph, since
  ///   Neo-Tifinagh (unlike Libyco-Berber) has one.
  /// - [_TifinaghLetter.yatt] — Neo-Tifinagh's ṭ is glyph ⵟ, the same
  ///   ⵎ-shape-crossed-by-a-horizontal-crossed-by-a-vertical shape as
  ///   Ahaggar's own ṭ — no override needed, since the glyph/label/sound
  ///   already match.
  /// - [_TifinaghLetter.yaz] — Neo-Tifinagh's z is glyph ⵣ, the same
  ///   1-vertical-plus-2-opposite-direction-strokes shape as Ahaggar's own
  ///   z — no override needed.
  /// - [_TifinaghLetter.yazhNt] — Neo-Tifinagh's ẓ is glyph ⵥ: Ahaggar's
  ///   own z shape plus a 4th, plain horizontal line crossing the vertical
  ///   line between the other two strokes (see [_classifyZEmphatic]) — no
  ///   Ahaggar/Libyco-Berber equivalent.
  /// - [_TifinaghLetter.yagn] — Neo-Tifinagh's j is glyph ⵊ, the same
  ///   vertical-line-crossed-by-two-horizontal-lines shape as Adrar's own
  ///   f (see [_regionLabelOverrides]; Adrar reuses this shape for f since
  ///   it has no ñ of its own — Neo-Tifinagh has no ñ either, so it's free
  ///   to mean j instead).
  /// - [_TifinaghLetter.yi] — Neo-Tifinagh's i is glyph ⵉ, the same
  ///   4-segment zigzag as Adrar (and Ghat/Aïr)'s own y (see
  ///   [_regionLabelOverrides]; only the sound differs, since Neo-Tifinagh
  ///   has no y drawn this way of its own yet).
  /// - [_TifinaghLetter.yal] — Neo-Tifinagh's l is glyph ⵍ, the same
  ///   two-verticals-plus-an-ascending-crossing-stroke gesture as every
  ///   Tuareg region's own l — glyph/label/sound already match, so no
  ///   [_regionLabelOverrides] entry is needed.
  /// - [_TifinaghLetter.yakhNt] — Neo-Tifinagh's kh is glyph ⵅ: 3 strokes
  ///   drawn close enough together that every pair's bounding box overlaps
  ///   in both x and y — one leaning ascending, one leaning descending,
  ///   and the third close to plain vertical (see
  ///   [_classifyNeoTifinaghKh]) — unrelated to Ahaggar, which has no kh
  ///   of its own (Ahaggar's x is the dot-based [_TifinaghLetter.yakh]
  ///   instead).
  /// - [_TifinaghLetter.yagwNt] — Neo-Tifinagh's gw is glyph ⴳⵯ: g's own
  ///   shape ([_TifinaghLetter.yafLb]) plus a second stroke shaped like w
  ///   ([_TifinaghLetter.yawNt]), positioned above and to the right of g's
  ///   own self-intersection point (see [_classifyNeoTifinaghGw]) — no
  ///   Ahaggar/Libyco-Berber equivalent.
  /// - [_TifinaghLetter.yawNt] — Neo-Tifinagh's own w is glyph ⵡ: d's own
  ///   shape ([_TifinaghLetter.yadLb]) flipped vertically, both endpoints
  ///   in the top half of the stroke's own bounding box instead of the
  ///   bottom (see [_classifyNeoTifinaghW]) — no Ahaggar/Libyco-Berber
  ///   equivalent.
  static const _neoTifinaghShapes = {
    _TifinaghLetter.ya,
    _TifinaghLetter.yab,
    _TifinaghLetter.yabNt,
    _TifinaghLetter.yan,
    _TifinaghLetter.yafLb,
    _TifinaghLetter.yadd,
    _TifinaghLetter.yaqLb,
    _TifinaghLetter.yaf,
    _TifinaghLetter.yam,
    _TifinaghLetter.yas,
    _TifinaghLetter.yar,
    _TifinaghLetter.yarrNt,
    _TifinaghLetter.yassNt,
    _TifinaghLetter.yay,
    _TifinaghLetter.yash,
    _TifinaghLetter.yat,
    _TifinaghLetter.yahNt,
    _TifinaghLetter.yu,
    _TifinaghLetter.yadLb,
    _TifinaghLetter.yatt,
    _TifinaghLetter.yal,
    _TifinaghLetter.yaz,
    _TifinaghLetter.yazhNt,
    _TifinaghLetter.yagn,
    _TifinaghLetter.yi,
    _TifinaghLetter.yakhNt,
    _TifinaghLetter.yagwNt,
    _TifinaghLetter.yawNt,
  };

  /// Shapes that don't exist in Ahaggar's own alphabet — excluded even
  /// though Ahaggar would otherwise enable every shape, since Ahaggar has
  /// no letter drawn this way. [_TifinaghLetter.yi] is shared by Ghat, Aïr,
  /// and Adrar, all of which use it for their own y; [_TifinaghLetter.yaghc]
  /// is Aïr-only; [_TifinaghLetter.yalLb], [_TifinaghLetter.yahLb],
  /// [_TifinaghLetter.yaz2Lb], [_TifinaghLetter.yarLb],
  /// [_TifinaghLetter.yafLb], [_TifinaghLetter.yayLb],
  /// [_TifinaghLetter.yas3Lb], [_TifinaghLetter.yatLb],
  /// [_TifinaghLetter.yas4Lb], [_TifinaghLetter.yaqLb],
  /// [_TifinaghLetter.yamLb], [_TifinaghLetter.yaz1Lb],
  /// [_TifinaghLetter.yas2Lb], [_TifinaghLetter.yagLb],
  /// [_TifinaghLetter.yakLb], [_TifinaghLetter.yattLb],
  /// [_TifinaghLetter.yadLb], and [_TifinaghLetter.yaz3Lb] are
  /// Libyco-Berber-only ([_TifinaghLetter.yam] itself isn't, since
  /// Ahaggar already uses it natively for its own m);
  /// [_TifinaghLetter.yashDr] is Adrar-only.
  static const _regionOnlyShapes = {
    _TifinaghLetter.yi,
    _TifinaghLetter.yaghc,
    _TifinaghLetter.yalLb,
    _TifinaghLetter.yahLb,
    _TifinaghLetter.yaz2Lb,
    _TifinaghLetter.yarLb,
    _TifinaghLetter.yafLb,
    _TifinaghLetter.yayLb,
    _TifinaghLetter.yas3Lb,
    _TifinaghLetter.yatLb,
    _TifinaghLetter.yas4Lb,
    _TifinaghLetter.yaqLb,
    _TifinaghLetter.yamLb,
    _TifinaghLetter.yaz1Lb,
    _TifinaghLetter.yas2Lb,
    _TifinaghLetter.yagLb,
    _TifinaghLetter.yakLb,
    _TifinaghLetter.yattLb,
    _TifinaghLetter.yadLb,
    _TifinaghLetter.yaz3Lb,
    _TifinaghLetter.yashDr,
  };

  /// Per-region (glyph, letterName, sound) overrides for a shape recognized
  /// under a different region's letter than the one it's natively defined
  /// for.
  static const _regionLabelOverrides = {
    'Ghat': {
      _TifinaghLetter.yaj: ('ⴶ', 'yag', 'ɡ'),
      _TifinaghLetter.yagn: ('ⵊ', 'yaj', 'ġ/ɟ'),
      _TifinaghLetter.yazh: ('ⵌ', 'yaz', 'z'),
      _TifinaghLetter.yaz: ('ⵣ', 'yazh', 'zˤ'),
    },
    'Aïr': {
      _TifinaghLetter.yaj: ('ⴶ', 'yag', 'ɡ'),
      _TifinaghLetter.yad: ('ⴹ', 'yad', 'd'),
      _TifinaghLetter.yagh: ('ⵗ', 'yaɣ', 'x | q'),
      _TifinaghLetter.yaghc: ('ⵘ', 'yaɣ', 'ɣ | gh | ġ'),
      _TifinaghLetter.yaq: ('ⵗ', 'yaq', 'x | q'),
      _TifinaghLetter.yazh: ('ⵌ', 'yaž', 'ž/j'),
    },
    'Azawagh': {
      _TifinaghLetter.yaj: ('ⴶ', 'yag', 'ɡ'),
      _TifinaghLetter.yakh: ('ⵆ', 'yakh', 'x | q'),
      _TifinaghLetter.yaz: ('ⵣ', 'yaz', 'z | ẓ'),
      _TifinaghLetter.yazh: ('ⵌ', 'yaž', 'ž/j'),
    },
    'Adrar': {
      _TifinaghLetter.yaj: ('ⴶ', 'yag', 'ɡ'),
      _TifinaghLetter.yazz: ('ⵋ', 'yaz', 'z'),
      _TifinaghLetter.yagn: ('ⵊ', 'yaf', 'f'),
    },
    'Libyco-Berber': {
      // b is drawn the same loop-with-a-dot-inside gesture as Ahaggar's s,
      // but its closest modern equivalent is Ahaggar's own b (ⵀ), not s
      // (ⵙ) — see [LibycoBerberRow.ahaggar].
      _TifinaghLetter.yas: ('ⵀ', 'yab', 'b'),
      // s¹ is drawn the same gesture as Ahaggar's own m, but has no
      // Ahaggar equivalent at all (see [LibycoBerberRow.ahaggar]), so
      // there's no glyph to show in its place — just the transliteration,
      // same as every fully dedicated Libyco-Berber-only shape.
      _TifinaghLetter.yam: ('s¹', 'yas1', 's¹'),
    },
    'Neo-Tifinagh': {
      // b's own loop-with-a-crossing-vertical-line shape, relabeled: Neo-
      // Tifinagh's h (not b) is drawn this way (see _neoTifinaghShapes).
      _TifinaghLetter.yab: ('ⵀ', 'yah', 'h'),
      // Libyco-Berber's own f shape, relabeled: Neo-Tifinagh's g (not f)
      // is drawn this way (see _neoTifinaghShapes).
      _TifinaghLetter.yafLb: ('ⴳ', 'yag', 'ɡ'),
      // Libyco-Berber's own q/ɣ? shape, relabeled: Neo-Tifinagh's e (not
      // q/ɣ?) is drawn this way (see _neoTifinaghShapes). Named 'ye' —
      // not 'ya'-prefixed — matching the vowel-naming convention already
      // used for _TifinaghLetter.ya/yu/yi.
      _TifinaghLetter.yaqLb: ('ⴻ', 'ye', 'ə'),
      // Libyco-Berber's own d shape, relabeled to the real Unicode glyph
      // (Libyco-Berber has none of its own — see _libycoBerberImages).
      _TifinaghLetter.yadLb: ('ⴷ', 'yad', 'd'),
      // Adrar's own f shape, relabeled: Neo-Tifinagh's j (not f) is drawn
      // this way (see _neoTifinaghShapes).
      _TifinaghLetter.yagn: ('ⵊ', 'yaj', 'ʒ'),
      // Adrar/Ghat/Aïr's own y shape, relabeled: Neo-Tifinagh's i (not y)
      // is drawn this way — only the sound differs, since the glyph (ⵉ)
      // and letterName (yi) already match.
      _TifinaghLetter.yi: ('ⵉ', 'yi', 'i'),
    },
  };

  bool _isEnabledInRegion(_TifinaghLetter letter) => switch (region) {
        'Ahaggar' => !_regionOnlyShapes.contains(letter),
        'Ghat' => _ghatShapes.contains(letter),
        'Aïr' => _airShapes.contains(letter),
        'Azawagh' => _azawaghShapes.contains(letter),
        'Adrar' => _adrarShapes.contains(letter),
        'Libyco-Berber' => _libycoBerberShapes.contains(letter),
        'Neo-Tifinagh' => _neoTifinaghShapes.contains(letter),
        _ => false,
      };

  /// Drops [letter] to unrecognized if it isn't enabled for [region].
  _TifinaghLetter? _filterRegion(_TifinaghLetter? letter) =>
      letter != null && _isEnabledInRegion(letter) ? letter : null;

  /// Tries each of [classifiers] in order, applying [_filterRegion] to
  /// every individual result and returning the first one that's actually
  /// enabled for [region] — rather than stopping at the first non-null
  /// result the way a plain `??` chain would. Classifiers are written to
  /// recognize a shape regardless of region (e.g. [_classifyDEmphatic]
  /// doesn't know it's Ahaggar-only), so a shape that happens to loosely
  /// match a stroke drawn for a *different* region's letter (e.g. hand
  /// jitter on a straight line occasionally satisfying [_isMShaped]) must
  /// not be allowed to shadow a later classifier that would have matched
  /// correctly for the current region.
  _TifinaghLetter? _firstValidInRegion(
      List<_TifinaghLetter? Function()> classifiers) {
    for (final classify in classifiers) {
      final result = _filterRegion(classify());
      if (result != null) return result;
    }
    return null;
  }

  final List<_Stroke> _strokes = [];
  final List<Offset> _dots = [];
  _TifinaghLetter? _recognized;
  List<Offset>? _activePoints;

  /// Decoded Libyco-Berber letterform images, keyed by asset filename
  /// (see [_libycoBerberImages]) — loaded once per filename and cached,
  /// since [Layer.paint] can't itself be async (see
  /// [_ensureLibycoBerberImage]).
  final Map<String, ui.Image> _libycoBerberImageCache = {};
  final Set<String> _libycoBerberImageLoading = {};

  void clear() {
    _strokes.clear();
    _dots.clear();
    _recognized = null;
  }

  /// Kicks off decoding `assets/tifi/libyco_berber/[asset]` if it isn't already
  /// cached or in flight. [GameCanvas] repaints every frame regardless of
  /// state changes (see its `Ticker`), so once the image lands in
  /// [_libycoBerberImageCache] the very next frame just picks it up —
  /// nothing needs to explicitly request a repaint.
  void _ensureLibycoBerberImage(String asset) {
    if (_libycoBerberImageCache.containsKey(asset) ||
        _libycoBerberImageLoading.contains(asset)) {
      return;
    }
    _libycoBerberImageLoading.add(asset);
    rootBundle.load('assets/tifi/libyco_berber/$asset').then((data) async {
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _libycoBerberImageCache[asset] = frame.image;
      _libycoBerberImageLoading.remove(asset);
    });
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
      if (dragDistance < _dotThreshold) {
        _dots.add(points.first);
        _recognized = _firstValidInRegion([
          _classifyMixed,
          _classifyLineDot,
          _classifyLibycoBerberQ,
          _classifyLoop,
          _classifyK,
          _classifyDots,
        ]);
      } else if (points.length >= 2 && dragDistance >= _minDragDistance) {
        _commit(_Stroke(points));
      }
      _activePoints = null;
    }
  }

  void _commit(_Stroke stroke) {
    _strokes.add(stroke);
    _recognized = _firstValidInRegion([
      _classifyMixed,
      _classifyLineDot,
      _classifyLibycoBerberQ,
      _classifyLoop,
      _classifyAdrarSh,
      () => _classifyLibycoBerberRF(stroke),
      () => _classifyNeoTifinaghG(stroke),
      () => _classifyLibycoBerberS2(stroke),
      _classifyLibycoBerberK,
      () => _classifyLibycoBerberG(stroke),
      _classifyLibycoBerberZ1,
      _classifyLibycoBerberTt,
      () => _classifyG(stroke),
      () => _classifySh(stroke),
      _classifyZEmphatic,
      _classifyZ,
      _classifyF,
      _classifyL,
      _classifyTEmphatic,
      _classifyDEmphatic,
      () => _classifyZigzagStroke(stroke),
      () => _classifyLibycoBerberY(stroke),
      () => _classifyYi(stroke),
      () => _classifyLibycoBerberS3(stroke),
      () => _classifyM(stroke),
      _classifyLibycoBerberZ3,
      () => _classifyLibycoBerberM(stroke),
      () => _classifyLibycoBerberD(stroke),
      _classifyNeoTifinaghGw,
      () => _classifyNeoTifinaghW(stroke),
      () => _classifyD(stroke),
      _classifyZigzag,
      _classifyLibycoBerberH,
      _classifyLibycoBerberLW,
      () => _classifyLibycoBerberZ2(stroke),
      () => _classifyN(stroke),
      _classifyLibycoBerberTS4,
      _classifyNeoTifinaghH,
      _classifyNeoTifinaghKh,
      _classify,
      () => _classifyR(stroke),
    ]);
  }

  /// Whether [stroke] forms ⵔ: crosses itself exactly once ([_selfIntersections])
  /// and both its start and end points fall above the vertical center of
  /// its own bounding box — the same endpoint-position pattern as
  /// [_isMShaped]/[_isDShapedLb], applied to r's own loop-hangs-below-the-
  /// endpoints shape. Checked last in [_commit], as the fallback for any
  /// self-crossing stroke that didn't match a more specific shape earlier.
  _TifinaghLetter? _classifyR(_Stroke stroke) {
    if (_selfIntersections(stroke) != 1) return null;
    final bounds = _boundsOf(stroke.points);
    final above =
        stroke.start.dy < bounds.center.dy && stroke.end.dy < bounds.center.dy;
    return above ? _TifinaghLetter.yar : null;
  }

  /// Whether [stroke] forms ⵎ: its first and last points both fall in the
  /// right half of its own bounding box, and the straight line between
  /// them ([_isVertical], applied to the stroke's start/end) reads as
  /// vertical, it doesn't cross any other recent stroke
  /// ([_crossesOtherRecentStroke]), and it isn't
  /// [_isRightLeftRightLeftZigzag] — reused as-is for Libyco-Berber's own
  /// s¹ (see [_regionLabelOverrides]), which is a standalone single
  /// stroke, not one half of an intersecting pair like [_TifinaghLetter
  /// .yatLb]/[_TifinaghLetter.yas4Lb]. Checked after
  /// [_classifyZigzagStroke]/[_classifyYi] in [_commit] — this
  /// endpoint-location check is loose enough that a ⵢ, ⵉ, s², or s³
  /// zigzag can satisfy it too, so the more specific segment-count
  /// patterns take priority, and the explicit
  /// [_isRightLeftRightLeftZigzag] exclusion catches the s²/s³ case even
  /// if its own more specific classifier somehow misses it.
  _TifinaghLetter? _classifyM(_Stroke stroke) =>
      _isMShaped(stroke) &&
              _selfIntersections(stroke) == 0 &&
              !_crossesOtherRecentStroke(stroke) &&
              !_isRightLeftRightLeftZigzag(stroke)
          ? _TifinaghLetter.yam
          : null;

  bool _isMShaped(_Stroke stroke) {
    final bounds = _boundsOf(stroke.points);
    return bounds.width > _minMShapeBulge &&
        _isVertical(stroke) &&
        stroke.start.dx > bounds.center.dx &&
        stroke.end.dx > bounds.center.dx;
  }

  /// Same check as [_isMShaped], mirrored: both endpoints fall in the
  /// *left* half of the stroke's own bounding box instead of the right.
  bool _isMShapedMirrored(_Stroke stroke) {
    final bounds = _boundsOf(stroke.points);
    return bounds.width > _minMShapeBulge &&
        _isVertical(stroke) &&
        stroke.start.dx < bounds.center.dx &&
        stroke.end.dx < bounds.center.dx;
  }

  /// Whether [stroke] forms Libyco-Berber's m: the mirrored ⵎ shape
  /// ([_isMShapedMirrored]) — the horizontal mirror of Ahaggar's own m
  /// ([_classifyM]) — that doesn't cross any other recent stroke
  /// ([_crossesOtherRecentStroke]), since m is a standalone single
  /// stroke. Checked after [_classifyF] in [_commit], since ⴼ's 3-stroke
  /// pattern also uses a mirrored-ⵎ stroke as one of its two bulges and
  /// should claim it first when the full pattern is present.
  _TifinaghLetter? _classifyLibycoBerberM(_Stroke stroke) =>
      _isMShapedMirrored(stroke) &&
              _selfIntersections(stroke) == 0 &&
              !_crossesOtherRecentStroke(stroke)
          ? _TifinaghLetter.yamLb
          : null;

  /// Whether [stroke] forms Libyco-Berber's d: [_isMShaped]'s own check
  /// with the split axis rotated 90° — both endpoints fall in the
  /// *bottom* half of the stroke's own bounding box (instead of the
  /// right half), and the start/end chord reads as horizontal (instead
  /// of vertical). Unrelated to Ahaggar's own d ([_classifyD], a
  /// down-then-up vertical-direction split).
  bool _isDShapedLb(_Stroke stroke) {
    final bounds = _boundsOf(stroke.points);
    return bounds.height > _minMShapeBulge &&
        !_isVertical(stroke) &&
        stroke.start.dy > bounds.center.dy &&
        stroke.end.dy > bounds.center.dy;
  }

  /// Whether [stroke] forms Libyco-Berber's d: [_isDShapedLb] that
  /// doesn't cross any other recent stroke ([_crossesOtherRecentStroke])
  /// — d is a standalone single stroke, the same reasoning as
  /// [_classifyM]/[_classifyLibycoBerberM].
  _TifinaghLetter? _classifyLibycoBerberD(_Stroke stroke) =>
      _isDShapedLb(stroke) &&
              _selfIntersections(stroke) == 0 &&
              !_crossesOtherRecentStroke(stroke)
          ? _TifinaghLetter.yadLb
          : null;

  /// [_isDShapedLb] flipped vertically: both endpoints fall in the *top*
  /// half of the stroke's own bounding box instead of the bottom half —
  /// Neo-Tifinagh's w (ⵡ) is d (ⴷ) upside down.
  bool _isDShapedLbMirrored(_Stroke stroke) {
    final bounds = _boundsOf(stroke.points);
    return bounds.height > _minMShapeBulge &&
        !_isVertical(stroke) &&
        stroke.start.dy < bounds.center.dy &&
        stroke.end.dy < bounds.center.dy;
  }

  /// Whether [stroke] forms Neo-Tifinagh's w: [_isDShapedLbMirrored] that
  /// doesn't self-intersect and doesn't cross any other recent stroke
  /// ([_crossesOtherRecentStroke]) — w is a standalone single stroke, the
  /// same reasoning as [_classifyLibycoBerberD].
  _TifinaghLetter? _classifyNeoTifinaghW(_Stroke stroke) =>
      _isDShapedLbMirrored(stroke) &&
              _selfIntersections(stroke) == 0 &&
              !_crossesOtherRecentStroke(stroke)
          ? _TifinaghLetter.yawNt
          : null;

  /// Whether the most recent 2 strokes form Libyco-Berber's z³: the d
  /// shape ([_isDShapedLb], the same shape as [_TifinaghLetter.yadLb])
  /// crossed by a vertical line exactly once — unlike the ⵎ shape's own
  /// bulge ([_isMShapedMirrored], whose chord is vertical, so a crossing
  /// vertical line can double back through it), the d shape's bulge is a
  /// function of x (its chord is horizontal), so a vertical line through
  /// it can only ever cross it the one time, at the top of the arch.
  /// Checked ahead of [_classifyLibycoBerberD] in [_commit], since
  /// that classifier's own "doesn't cross anything" guard would otherwise
  /// leave this stroke unrecognized rather than reading it as z³. Can't
  /// be confused with [_classifyLibycoBerberTt]'s ṭ, even though that's
  /// also a 2-stroke intersecting pair checked nearby: ṭ requires its
  /// crossing partner to *not* be vertical, z³ requires the opposite, so
  /// the same pair of strokes can never satisfy both.
  _TifinaghLetter? _classifyLibycoBerberZ3() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final dShapes = recent.where(_isDShapedLb).toList();
    if (dShapes.length != 1) return null;
    final dShape = dShapes.single;
    final vertical = recent.firstWhere((s) => s != dShape);
    if (!_isVertical(vertical)) return null;
    return _crossings(dShape, vertical) == 1 ? _TifinaghLetter.yaz3Lb : null;
  }

  /// Whether the most recent 3 strokes form ⴼ: one ⵎ-shaped stroke
  /// ([_isMShaped]) positioned to the right of the horizontal line's own
  /// bounding-box center, one mirrored ⵎ-shaped stroke
  /// ([_isMShapedMirrored]) positioned to its left, and that horizontal
  /// line crossing each of them exactly once — a horizontal bar spanning
  /// both bulges, each on its matching side. Checked ahead of
  /// [_classifyL], [_classifyTEmphatic], and [_classifyDEmphatic], all of
  /// which also treat ⵎ-shaped strokes as plain verticals ([_isVertical]
  /// only cares about the overall start/end chord) and could otherwise
  /// misread a 3-stroke ⴼ first — most importantly [_classifyL]: since its
  /// crossing check ([_segmentsIntersect] on each vertical's bare
  /// start/end chord, not its actual zigzag path) is looser than
  /// [_crossings]' full-polyline check here, a horizontal bar drawn wide
  /// enough to pass both ⵎ shapes' own start/end x-positions (a completely
  /// natural way to draw it) would satisfy [_classifyL]'s "ascending
  /// diagonal crossing 2 verticals" pattern too.
  _TifinaghLetter? _classifyF() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final mRight = recent.where(_isMShaped).toList();
    final mLeft = recent.where(_isMShapedMirrored).toList();
    if (mRight.length != 1 || mLeft.length != 1) return null;
    final rest = recent
        .where((s) => !_isMShaped(s) && !_isMShapedMirrored(s))
        .toList();
    if (rest.length != 1 || _isVertical(rest.single)) return null;
    final horizontal = rest.single;
    final horizontalCenterX = _boundsOf(horizontal.points).center.dx;
    final onRight =
        _boundsOf(mRight.single.points).center.dx > horizontalCenterX;
    final onLeft =
        _boundsOf(mLeft.single.points).center.dx < horizontalCenterX;
    if (!onRight || !onLeft) return null;
    final crossesRight = _crossings(horizontal, mRight.single) == 1;
    final crossesLeft = _crossings(horizontal, mLeft.single) == 1;
    return crossesRight && crossesLeft ? _TifinaghLetter.yaf : null;
  }

  /// Whether the most recent 2 strokes form ⴹ: one satisfying the ⵎ shape
  /// ([_isMShaped]), the other any stroke whose actual path crosses it —
  /// using [_crossings] (the full polyline), not just start/end, since an
  /// ⵎ-shaped stroke is a zigzag, not a straight line.
  _TifinaghLetter? _classifyDEmphatic() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    if (recent.where(_isMShaped).length != 1) return null;
    final m = _isMShaped(recent[0]) ? recent[0] : recent[1];
    final other = _isMShaped(recent[0]) ? recent[1] : recent[0];
    return _crossings(m, other) > 0 ? _TifinaghLetter.yadd : null;
  }

  /// Whether the most recent 3 strokes form ⵟ: one satisfying the ⵎ shape
  /// ([_isMShaped]) crossed by a horizontal stroke (same [_crossings]
  /// check as ⴹ), which is in turn crossed by a vertical stroke (a plain
  /// start/end check, since both are straight lines).
  _TifinaghLetter? _classifyTEmphatic() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    if (recent.where(_isMShaped).length != 1) return null;
    final m = recent.firstWhere(_isMShaped);
    final rest = recent.where((s) => s != m).toList();
    final horizontals = rest.where((s) => !_isVertical(s)).toList();
    final verticals = rest.where(_isVertical).toList();
    if (horizontals.length != 1 || verticals.length != 1) return null;
    final horizontal = horizontals.first;
    final vertical = verticals.first;

    final mCrossesHorizontal = _crossings(m, horizontal) > 0;
    final verticalCrossesHorizontal = _segmentsIntersect(
        vertical.start, vertical.end, horizontal.start, horizontal.end);
    return mCrossesHorizontal && verticalCrossesHorizontal
        ? _TifinaghLetter.yatt
        : null;
  }

  /// Whether the most recent 3 strokes form ⵍ: 2 vertical lines plus a
  /// third stroke that intersects both, ascending left to right — it
  /// travels left to right ([_isLeftToRight]) while moving upward (not
  /// [_isGoingDown]) — and none of the 3 strokes self-intersects, since ⵍ
  /// never loops.
  _TifinaghLetter? _classifyL() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    if (recent.any((s) => _selfIntersections(s) != 0)) return null;
    final verticals = recent.where(_isVertical).toList();
    final diagonals = recent.where((s) => !_isVertical(s)).toList();
    if (verticals.length != 2 || diagonals.length != 1) return null;
    final diagonal = diagonals.first;

    final ascending = _isLeftToRight(diagonal) && !_isGoingDown(diagonal);
    if (!ascending) return null;

    final intersectsBoth = verticals.every((v) =>
        _segmentsIntersect(v.start, v.end, diagonal.start, diagonal.end));
    return intersectsBoth ? _TifinaghLetter.yal : null;
  }

  /// Whether [stroke] forms ⵛ: a single stroke that crosses itself
  /// exactly twice, with one crossing above and the other below the
  /// vertical center of the stroke's bounding box.
  _TifinaghLetter? _classifySh(_Stroke stroke) {
    final crossings = _selfIntersectionPoints(stroke);
    if (crossings.length != 2) return null;
    final centerY = _boundsOf(stroke.points).center.dy;
    final above = crossings.any((p) => p.dy < centerY);
    final below = crossings.any((p) => p.dy > centerY);
    return above && below ? _TifinaghLetter.yash : null;
  }

  /// Whether [stroke] forms ⴳ: a single stroke, split by horizontal
  /// direction change into exactly 3 segments, whose first segment moves
  /// up and whose last moves down (vertically), crossing itself exactly
  /// once. Checked ahead of the bare ⵔ self-intersection check, since
  /// this is the more specific of the two.
  _TifinaghLetter? _classifyG(_Stroke stroke) {
    final segments = _splitByHorizontalDirectionChange(stroke);
    if (segments.length != 3) return null;
    final first = segments.first;
    final last = segments.last;
    final firstGoesUp = first.last.dy < first.first.dy;
    final lastGoesDown = last.last.dy > last.first.dy;
    if (!firstGoesUp || !lastGoesDown) return null;
    return _selfIntersections(stroke) == 1 ? _TifinaghLetter.yag : null;
  }

  /// Whether [stroke] forms ⴸ: a single stroke, split (by vertical
  /// direction change) into exactly 2 segments, going down then up. Also
  /// requires no self-intersection, the same jitter guard as
  /// [_classifyLibycoBerberS3]: ⴸ never loops, so a stray self-crossing
  /// near a sharp turn shouldn't let it masquerade as one.
  _TifinaghLetter? _classifyD(_Stroke stroke) {
    if (_selfIntersections(stroke) != 0) return null;
    final seq = _verticalDirectionSequence(stroke);
    if (seq == null) return null;
    return seq[0] && !seq[1] ? _TifinaghLetter.yad : null;
  }

  /// The down-ness (true = down, false = up) of each of [stroke]'s
  /// vertical-direction segments, or null unless it splits into exactly
  /// 2 — since consecutive split segments always alternate direction,
  /// a 2-segment result is inherently an up-then-down or down-then-up
  /// sequence.
  List<bool>? _verticalDirectionSequence(_Stroke stroke) {
    final segments = _splitByVerticalDirectionChange(stroke);
    if (segments.length != 2) return null;
    return segments.map((seg) => seg.last.dy > seg.first.dy).toList();
  }

  /// Whether the most recent 3 strokes form ⵣ: one vertical line, plus 2
  /// non-vertical strokes each split (by vertical direction change) into
  /// exactly 2 segments, with one stroke going up-then-down and the other
  /// down-then-up.
  _TifinaghLetter? _classifyZ() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final verticals = recent.where(_isVertical).toList();
    final horizontals = recent.where((s) => !_isVertical(s)).toList();
    if (verticals.length != 1 || horizontals.length != 2) return null;

    final seqA = _verticalDirectionSequence(horizontals[0]);
    final seqB = _verticalDirectionSequence(horizontals[1]);
    if (seqA == null || seqB == null) return null;
    return seqA[0] != seqB[0] ? _TifinaghLetter.yaz : null;
  }

  /// Whether the most recent 4 strokes form Neo-Tifinagh's ẓ: [_classifyZ]'s
  /// own 3-stroke shape (1 vertical line, plus 2 non-vertical strokes each
  /// split into an up-then-down/down-then-up pair, starting in opposite
  /// directions), plus a 4th, plain non-vertical line — no such
  /// up/down-split sequence of its own — that crosses the vertical line
  /// and sits (by its own bounding-box x center) between the other two
  /// non-vertical strokes.
  _TifinaghLetter? _classifyZEmphatic() {
    if (_strokes.length < 4) return null;
    final recent = _strokes.sublist(_strokes.length - 4);
    final verticals = recent.where(_isVertical).toList();
    final nonVerticals = recent.where((s) => !_isVertical(s)).toList();
    if (verticals.length != 1 || nonVerticals.length != 3) return null;
    final vertical = verticals.single;

    final sequenced = <_Stroke>[];
    _Stroke? plain;
    for (final s in nonVerticals) {
      if (_verticalDirectionSequence(s) != null) {
        sequenced.add(s);
      } else {
        plain = s;
      }
    }
    if (sequenced.length != 2 || plain == null) return null;
    final seqA = _verticalDirectionSequence(sequenced[0])!;
    final seqB = _verticalDirectionSequence(sequenced[1])!;
    if (seqA[0] == seqB[0]) return null;

    if (_crossings(plain, vertical) == 0) return null;
    final plainCenterX = _boundsOf(plain.points).center.dx;
    final centerAX = _boundsOf(sequenced[0].points).center.dx;
    final centerBX = _boundsOf(sequenced[1].points).center.dx;
    final between = (plainCenterX - centerAX) * (plainCenterX - centerBX) <= 0;
    return between ? _TifinaghLetter.yazhNt : null;
  }

  /// Splits [stroke] wherever its vertical direction reverses (down vs
  /// up) — the vertical counterpart of
  /// [_splitByHorizontalDirectionChange], same
  /// `StrokeCutter.cutByVerticalDirectionChange` pattern from the
  /// shorthand project.
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

  /// Whether [stroke] forms ⵢ's own shape: a single zigzag, split by
  /// horizontal direction change into exactly 3 segments whose left/right
  /// sequence is left-right-left if the stroke goes down overall, or
  /// right-left-right if it goes up. Used both by [_classifyZigzagStroke]
  /// and as a negative guard in [_classifyN] — the same role
  /// [_isRightLeftRightLeftZigzag] plays for [_classifyM]/
  /// [_classifyLibycoBerberM]: [_classifyN]'s own vertical-chord check
  /// can't otherwise tell a zigzag (whose overall start/end chord often
  /// still reads as vertical) from a plain straight line.
  bool _isZigzagShaped(_Stroke stroke) {
    final segments = _splitByHorizontalDirectionChange(stroke);
    if (segments.length != 3) return false;
    final goingRight =
        segments.map((seg) => seg.last.dx > seg.first.dx).toList();
    final expected =
        _isGoingDown(stroke) ? [false, true, false] : [true, false, true];
    for (var i = 0; i < 3; i++) {
      if (goingRight[i] != expected[i]) return false;
    }
    return true;
  }

  /// Whether [stroke] forms ⵢ: [_isZigzagShaped], and it doesn't cross any
  /// other recent stroke ([_crossesOtherRecentStroke]) — ⵢ is a
  /// standalone single stroke, the same reasoning as [_classifyN]/
  /// [_classifyM].
  _TifinaghLetter? _classifyZigzagStroke(_Stroke stroke) =>
      _isZigzagShaped(stroke) &&
              _selfIntersections(stroke) == 0 &&
              !_crossesOtherRecentStroke(stroke)
          ? _TifinaghLetter.yay
          : null;

  /// Whether [stroke] forms Libyco-Berber's y: a single stroke, split by
  /// horizontal direction change into exactly 3 segments,
  /// right-left-right, while the stroke descends overall ([_isGoingDown])
  /// — the opposite pairing from [_classifyZigzagStroke]'s own
  /// right-left-right sequence, which requires the stroke to ascend
  /// instead (so the two never collide on the same drawn stroke).
  _TifinaghLetter? _classifyLibycoBerberY(_Stroke stroke) {
    if (_selfIntersections(stroke) != 0) return null;
    final segments = _splitByHorizontalDirectionChange(stroke);
    if (segments.length != 3) return null;
    final goingRight =
        segments.map((seg) => seg.last.dx > seg.first.dx).toList();
    const expected = [true, false, true];
    for (var i = 0; i < 3; i++) {
      if (goingRight[i] != expected[i]) return null;
    }
    return _isGoingDown(stroke) ? _TifinaghLetter.yayLb : null;
  }

  /// Whether [stroke] forms Libyco-Berber's s³: [_isRightLeftRightLeftZigzag]
  /// while the stroke descends overall ([_isGoingDown]) — the mirrored
  /// left/right sequence from [_classifyYi]'s own left-right-left-right
  /// (which only checks the last segment's descent, not the whole
  /// stroke). Explicitly requires no self-intersection too, since
  /// without it a stroke that picks up even one accidental self-crossing
  /// near a sharp turn (easy to get from mouse/touch jitter) would
  /// otherwise get claimed by s² first, since it's checked earlier in
  /// [_commit].
  _TifinaghLetter? _classifyLibycoBerberS3(_Stroke stroke) {
    if (!_isRightLeftRightLeftZigzag(stroke)) return null;
    if (_selfIntersections(stroke) != 0) return null;
    return _isGoingDown(stroke) ? _TifinaghLetter.yas3Lb : null;
  }

  /// Whether [stroke] forms ⵉ (Ghat's y): the same left-right-left zigzag
  /// as ⵢ's down-going form ([_classifyZigzagStroke]), with a 4th segment
  /// appended that continues the alternation (right) and also goes down —
  /// and, like ⵢ, it doesn't cross any other recent stroke
  /// ([_crossesOtherRecentStroke]), since it's a standalone single stroke
  /// too.
  _TifinaghLetter? _classifyYi(_Stroke stroke) {
    if (_selfIntersections(stroke) != 0) return null;
    final segments = _splitByHorizontalDirectionChange(stroke);
    if (segments.length != 4) return null;
    final goingRight =
        segments.map((seg) => seg.last.dx > seg.first.dx).toList();
    const expected = [false, true, false, true];
    for (var i = 0; i < 4; i++) {
      if (goingRight[i] != expected[i]) return null;
    }
    final lastGoesDown = segments.last.last.dy > segments.last.first.dy;
    return lastGoesDown && !_crossesOtherRecentStroke(stroke)
        ? _TifinaghLetter.yi
        : null;
  }

  /// Splits [stroke] wherever its horizontal direction reverses (left-to-
  /// right vs right-to-left) — ported from the `StrokeCutter
  /// .cutByHorizontalDirectionChange` pattern in the shorthand project's
  /// `stroke_direction.dart`: walk consecutive points, and whenever the
  /// sign of horizontal movement flips, close the current segment
  /// (re-seeding the next one with the pivot point) and start a new one.
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

  /// True if [s] travels left to right overall — unlike [_isVertical],
  /// this only looks at horizontal direction, regardless of whether the
  /// stroke reads as vertical, horizontal, or diagonal. [s] is split by
  /// horizontal direction change first, and the direction is read off the
  /// segment with the widest horizontal span, so a small reversal (hand
  /// jitter) doesn't flip the result.
  bool _isLeftToRight(_Stroke s) {
    final segments = _splitByHorizontalDirectionChange(s);
    if (segments.isEmpty) return s.end.dx > s.start.dx;
    final dominant = segments.reduce((a, b) =>
        (a.last.dx - a.first.dx).abs() > (b.last.dx - b.first.dx).abs()
            ? a
            : b);
    return dominant.last.dx > dominant.first.dx;
  }

  /// Whether the most recent 2 strokes form ⵋ: opposite horizontal travel
  /// direction — one left-to-right, the other right-to-left, whether each
  /// goes up or down doesn't matter — and they cross each other once or
  /// twice.
  _TifinaghLetter? _classifyZigzag() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    if (_isLeftToRight(recent[0]) == _isLeftToRight(recent[1])) return null;
    final crossings = _crossings(recent[0], recent[1]);
    return crossings == 1 || crossings == 2 ? _TifinaghLetter.yazz : null;
  }

  /// Whether [stroke] reads as diagonal — meaningfully both horizontal
  /// and vertical movement — unlike a plain vertical line ([_isVertical])
  /// or a strictly horizontal one (Neo-Tifinagh's own t crossbar, see
  /// [_classifyNeoTifinaghH]'s doc comment). The 0.25 threshold is a
  /// heuristic, same spirit as [_minMShapeBulge]: enough vertical
  /// movement that it can't be mistaken for hand jitter on an otherwise
  /// flat horizontal line.
  bool _isDiagonal(_Stroke stroke) {
    final dx = (stroke.end.dx - stroke.start.dx).abs();
    final dy = (stroke.end.dy - stroke.start.dy).abs();
    return dx > dy && dy > dx * 0.25;
  }

  /// Whether the most recent 2 strokes form Neo-Tifinagh's ḥ: one vertical
  /// line ([_isVertical]) crossed by one diagonal line ([_isDiagonal]),
  /// where the diagonal's own y-range doesn't reach into the vertical's
  /// own top quarter — i.e. splitting the vertical's y-range into 4 equal
  /// quarters, the diagonal only occupies the bottom 3. Checked ahead of
  /// the generic grid classifier ([_classify]) in [_commit], since that
  /// would otherwise read this same 1-vertical-plus-1-non-vertical pair as
  /// Neo-Tifinagh's own t ([_TifinaghLetter.yat]) — a plain vertical line
  /// crossed by a *strictly horizontal* one, which [_classify]'s
  /// [_matchesGrid] doesn't distinguish from a diagonal crossing line at
  /// all.
  _TifinaghLetter? _classifyNeoTifinaghH() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final verticals = recent.where(_isVertical).toList();
    final diagonals = recent.where(_isDiagonal).toList();
    if (verticals.length != 1 || diagonals.length != 1) return null;
    final vertical = verticals.single;
    final diagonal = diagonals.single;
    if (_crossings(vertical, diagonal) == 0) return null;

    final vBounds = _boundsOf(vertical.points);
    final dBounds = _boundsOf(diagonal.points);
    final topQuarterBottom = vBounds.top + vBounds.height / 4;
    return dBounds.top >= topQuarterBottom ? _TifinaghLetter.yahNt : null;
  }

  /// Whether the most recent 3 strokes form Neo-Tifinagh's kh: three
  /// strokes where at least one leans like an ascending "/" and at least
  /// one leans like a descending "\" (the third, nominally close to
  /// vertical, may lean either way too — only *at least* one of each is
  /// required), and every pair's bounding box overlaps in *both* its
  /// x-range and y-range (a containment check, not a literal path crossing
  /// — these strokes are drawn close together, and needn't actually cross
  /// paths the way [_classifyL]'s do). A "/" lean is [_isLeftToRight] xor
  /// [_isGoingDown] (the two ends disagree: moving right pairs with moving
  /// up, or moving left pairs with moving down); a "\" lean is the other
  /// way around, the two agreeing — reading the slope this way (not
  /// [_classifyL]'s stricter "drawn left to right") matters here since
  /// Tifinagh strokes are naturally drawn top to bottom, so a "/"-leaning
  /// stroke is just as often drawn top-right to bottom-left as
  /// bottom-left to top-right. Checked ahead of the generic grid
  /// classifier ([_classify]) in [_commit], since that would otherwise
  /// read a 1-vertical-plus-2-horizontal reading of this same stroke set
  /// as Neo-Tifinagh's own j ([_TifinaghLetter.yagn]).
  _TifinaghLetter? _classifyNeoTifinaghKh() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);

    final hasAscending =
        recent.any((s) => _isLeftToRight(s) != _isGoingDown(s));
    final hasDescending =
        recent.any((s) => _isLeftToRight(s) == _isGoingDown(s));
    if (!hasAscending || !hasDescending) return null;

    final bounds = recent.map((s) => _boundsOf(s.points)).toList();
    for (var i = 0; i < bounds.length; i++) {
      for (var j = i + 1; j < bounds.length; j++) {
        final a = bounds[i];
        final b = bounds[j];
        final xOverlap = a.left <= b.right && b.left <= a.right;
        final yOverlap = a.top <= b.bottom && b.top <= a.bottom;
        if (!xOverlap || !yOverlap) return null;
      }
    }
    return _TifinaghLetter.yakhNt;
  }

  /// Whether the most recent 2 strokes form Neo-Tifinagh's gw: one stroke
  /// reading as g ([_classifyLibycoBerberRF]'s self-crossing-loop-split-
  /// into-3-horizontal-segments shape, first segment going right — see
  /// [_TifinaghLetter.yafLb]), the other a second stroke actually shaped
  /// like w ([_isDShapedLbMirrored], the same shape as
  /// [_TifinaghLetter.yawNt], and not self-intersecting), positioned above
  /// and to the right of g's own single self-intersection point
  /// ([_selfIntersectionPoints]) — checked by the w stroke's own
  /// bounding-box center.
  _TifinaghLetter? _classifyNeoTifinaghGw() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final gShapes = recent
        .where((s) => _classifyLibycoBerberRF(s) == _TifinaghLetter.yafLb)
        .toList();
    if (gShapes.length != 1) return null;
    final g = gShapes.single;
    final w = recent.firstWhere((s) => s != g);
    if (!_isDShapedLbMirrored(w) || _selfIntersections(w) != 0) return null;

    final intersection = _selfIntersectionPoints(g).single;
    final wCenter = _boundsOf(w.points).center;
    final above = wCenter.dy < intersection.dy;
    final right = wCenter.dx > intersection.dx;
    return above && right ? _TifinaghLetter.yagwNt : null;
  }

  /// Whether the most recent dot and the most recent stroke form ⵑ: a
  /// vertical line with a dot below it, sharing the line's x center.
  _TifinaghLetter? _classifyLineDot() {
    if (_dots.isEmpty || _strokes.isEmpty) return null;
    final line = _strokes.last;
    if (!_isVertical(line)) return null;
    final dot = _dots.last;
    final lineMidX = (line.start.dx + line.end.dx) / 2;
    final lineMidY = (line.start.dy + line.end.dy) / 2;
    final xAligned = (dot.dx - lineMidX).abs() <= _dotRadius * 2;
    final dotBelowLine = dot.dy > lineMidY;
    return xAligned && dotBelowLine ? _TifinaghLetter.yang : null;
  }

  /// Whether the most recent 2 dots and the most recent stroke form
  /// Libyco-Berber's q/ɣ?: a horizontal line with one dot above it and
  /// one dot below it, both x-aligned with the line's own x center —
  /// [_classifyLineDot]'s vertical-line-plus-one-dot shape (ⵑ), mirrored
  /// to horizontal and with a second dot added on the other side.
  _TifinaghLetter? _classifyLibycoBerberQ() {
    if (_dots.length < 2 || _strokes.isEmpty) return null;
    final line = _strokes.last;
    if (_isVertical(line)) return null;
    final dots = _dots.sublist(_dots.length - 2);
    final lineMidX = (line.start.dx + line.end.dx) / 2;
    final lineMidY = (line.start.dy + line.end.dy) / 2;
    final aligned =
        dots.every((d) => (d.dx - lineMidX).abs() <= _dotRadius * 2);
    if (!aligned) return null;
    final above = dots.any((d) => d.dy < lineMidY);
    final below = dots.any((d) => d.dy > lineMidY);
    return above && below ? _TifinaghLetter.yaqLb : null;
  }

  /// Finds whichever of the last 2 strokes is a self-intersecting loop
  /// (as for ⵔ), then checks for a dot inside it (ⵙ), or, if the other of
  /// the last 2 strokes is a non-looping line, classifies by that line's
  /// orientation and crossing count: a vertical line crossing the loop
  /// exactly twice is ⵀ; a horizontal line crossing it exactly twice is
  /// Neo-Tifinagh's own b ([_TifinaghLetter.yabNt]); a line of either
  /// orientation crossing it exactly once is Neo-Tifinagh's ṛ or ṣ
  /// ([_TifinaghLetter.yarrNt]/[_TifinaghLetter.yassNt]), split by whether
  /// that line descends (ṛ) or ascends (ṣ) overall ([_isGoingDown]).
  _TifinaghLetter? _classifyLoop() {
    if (_strokes.isEmpty) return null;
    final last = _strokes.last;
    _Stroke? loop;
    _Stroke? line;
    if (_selfIntersections(last) == 1) {
      loop = last;
      if (_strokes.length >= 2) line = _strokes[_strokes.length - 2];
    } else if (_strokes.length >= 2) {
      final prev = _strokes[_strokes.length - 2];
      if (_selfIntersections(prev) == 1) {
        loop = prev;
        line = last;
      }
    }
    if (loop == null) return null;
    if (line != null && _selfIntersections(line) == 0) {
      final crossCount = _crossings(line, loop);
      if (crossCount == 2) {
        return _isVertical(line) ? _TifinaghLetter.yab : _TifinaghLetter.yabNt;
      }
      if (crossCount == 1) {
        return _isGoingDown(line)
            ? _TifinaghLetter.yarrNt
            : _TifinaghLetter.yassNt;
      }
    }
    if (_dots.isNotEmpty && _boundsOf(loop.points).contains(_dots.last)) {
      return _TifinaghLetter.yas;
    }
    return null;
  }

  /// Whether the most recent 2 strokes form Adrar's š (𐌚): each stroke is
  /// individually a self-intersecting loop (the same shape as ⵔ on its
  /// own), their bounding boxes' x-ranges overlap, and the two loops also
  /// cross each other. Checked ahead of [_classifyG] and the bare ⵔ
  /// self-intersection match in [_commit] — after the second loop is
  /// drawn, that stroke alone would otherwise satisfy the single-loop ⵔ
  /// check first, since this shape's precondition (2 self-intersecting
  /// strokes) is the more specific of the two.
  _TifinaghLetter? _classifyAdrarSh() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    if (_selfIntersections(recent[0]) != 1 ||
        _selfIntersections(recent[1]) != 1) {
      return null;
    }
    final bounds0 = _boundsOf(recent[0].points);
    final bounds1 = _boundsOf(recent[1].points);
    final xOverlap =
        bounds0.left <= bounds1.right && bounds1.left <= bounds0.right;
    if (!xOverlap) return null;
    return _crossings(recent[0], recent[1]) > 0
        ? _TifinaghLetter.yashDr
        : null;
  }

  /// Number of times [a] crosses [b] — dedup so a single real crossing,
  /// sampled across nearby points on either stroke, still counts once.
  int _crossings(_Stroke a, _Stroke b) {
    var count = 0;
    var lastI = -10, lastJ = -10;
    for (var i = 0; i < a.points.length - 1; i++) {
      for (var j = 0; j < b.points.length - 1; j++) {
        if (_segmentsIntersect(
            a.points[i], a.points[i + 1], b.points[j], b.points[j + 1])) {
          if ((i - lastI).abs() > 2 || (j - lastJ).abs() > 2) count++;
          lastI = i;
          lastJ = j;
        }
      }
    }
    return count;
  }

  /// Whether [stroke] crosses any other stroke among the most recent
  /// [count] (default 2) — used to guard standalone single-stroke
  /// Libyco-Berber shapes (m, z²) from matching when [stroke] is really
  /// one half of a different, intersecting multi-stroke letter (t/s⁴, ṭ,
  /// z¹, q/ɣ?).
  bool _crossesOtherRecentStroke(_Stroke stroke, {int count = 2}) {
    if (_strokes.length < count) return false;
    final recent = _strokes.sublist(_strokes.length - count);
    for (final other in recent) {
      if (identical(other, stroke)) continue;
      if (_crossings(stroke, other) > 0) return true;
    }
    return false;
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

  /// Number of times [stroke] crosses its own path.
  int _selfIntersections(_Stroke stroke) =>
      _selfIntersectionPoints(stroke).length;

  /// The location of each place [stroke] crosses its own path —
  /// non-adjacent segments (index gap of at least 2) that intersect,
  /// deduplicated so a single real loop, sampled across several nearby
  /// points, still yields one point.
  List<Offset> _selfIntersectionPoints(_Stroke stroke) {
    final points = stroke.points;
    final result = <Offset>[];
    var lastCrossing = -10;
    for (var i = 0; i < points.length - 1; i++) {
      for (var j = i + 2; j < points.length - 1; j++) {
        if (_segmentsIntersect(points[i], points[i + 1], points[j], points[j + 1])) {
          if (j - lastCrossing > 2) {
            final p = _intersectionPoint(
                points[i], points[i + 1], points[j], points[j + 1]);
            if (p != null) result.add(p);
          }
          lastCrossing = j;
        }
      }
    }
    return result;
  }

  /// Where segments (p1,p2) and (p3,p4) cross, or null if they're
  /// parallel — standard parametric line-line intersection.
  Offset? _intersectionPoint(Offset p1, Offset p2, Offset p3, Offset p4) {
    final denom =
        (p2.dx - p1.dx) * (p4.dy - p3.dy) - (p2.dy - p1.dy) * (p4.dx - p3.dx);
    if (denom == 0) return null;
    final t = ((p3.dx - p1.dx) * (p4.dy - p3.dy) -
            (p3.dy - p1.dy) * (p4.dx - p3.dx)) /
        denom;
    return Offset(p1.dx + t * (p2.dx - p1.dx), p1.dy + t * (p2.dy - p1.dy));
  }

  /// Whether the 2 most recent dots and the most recent stroke form ⴶ: two
  /// dots sharing a y center (a row), with a vertical line beneath them
  /// whose x center lines up with the midpoint between the dots.
  _TifinaghLetter? _classifyMixed() {
    if (_dots.length < 2 || _strokes.isEmpty) return null;
    final line = _strokes.last;
    if (!_isVertical(line)) return null;
    final dots = _dots.sublist(_dots.length - 2);
    final dotsYAligned = (dots[0].dy - dots[1].dy).abs() <= _dotRadius * 2;
    if (!dotsYAligned) return null;
    final dotsMidX = (dots[0].dx + dots[1].dx) / 2;
    final dotsMidY = (dots[0].dy + dots[1].dy) / 2;
    final lineMidX = (line.start.dx + line.end.dx) / 2;
    final lineMidY = (line.start.dy + line.end.dy) / 2;
    final lineCenteredUnderDots = (dotsMidX - lineMidX).abs() <= _dotRadius * 2;
    final dotsAboveLine = dotsMidY < lineMidY;
    return lineCenteredUnderDots && dotsAboveLine ? _TifinaghLetter.yaj : null;
  }

  _TifinaghLetter? _classify() {
    // Largest pattern (most strokes) first, so e.g. a completed ⵌ (2v+2h)
    // isn't mistakenly reported as its ⵜ (1v+1h) sub-pattern.
    final byStrokeCount = _TifinaghLetter.values
        .where((l) => l.verticals + l.horizontals > 0)
        .toList()
      ..sort((a, b) =>
          (b.verticals + b.horizontals).compareTo(a.verticals + a.horizontals));
    for (final letter in byStrokeCount) {
      if (_matchesGrid(letter.verticals, letter.horizontals)) return letter;
    }
    return null;
  }

  /// Whether the most recent 3 dots form ⴾ: two of them with overlapping
  /// x ranges (their circles overlap horizontally, like a column), and
  /// the third clear of that x range, to the right, with its y between
  /// the top and bottom of the aligning pair's own bounding box. Tries
  /// all 3 ways to pick which dot is the odd one out, since taps aren't
  /// necessarily drawn in an order that puts it last.
  _TifinaghLetter? _classifyK() {
    if (_dots.length < 3) return null;
    final recent = _dots.sublist(_dots.length - 3);
    for (var i = 0; i < 3; i++) {
      final third = recent[i];
      final pair = [for (var j = 0; j < 3; j++) if (j != i) recent[j]];
      final a = pair[0];
      final b = pair[1];
      final xRangesOverlap = (a.dx - b.dx).abs() <= _dotRadius * 2;
      if (!xRangesOverlap) continue;
      final pairRightEdge = (a.dx > b.dx ? a.dx : b.dx) + _dotRadius;
      final thirdLeftEdge = third.dx - _dotRadius;
      if (thirdLeftEdge <= pairRightEdge) continue;
      final pairTop = a.dy < b.dy ? a.dy : b.dy;
      final pairBottom = a.dy > b.dy ? a.dy : b.dy;
      if (third.dy > pairTop && third.dy < pairBottom) return _TifinaghLetter.yak;
    }
    return null;
  }

  _TifinaghLetter? _classifyDots() {
    // Largest group (most dots) first, so e.g. a completed ⵂ (4 dots)
    // isn't mistakenly reported as its ⵗ (3 dots) sub-pattern. Within the
    // same count, [_DotArrangement.cross] is checked before column/row.
    final byDotCount = _TifinaghLetter.values.where((l) => l.dots > 0).toList()
      ..sort((a, b) {
        final byCount = b.dots.compareTo(a.dots);
        if (byCount != 0) return byCount;
        final aCross = a.dotArrangement == _DotArrangement.cross ? 0 : 1;
        final bCross = b.dotArrangement == _DotArrangement.cross ? 0 : 1;
        return aCross.compareTo(bCross);
      });
    for (final letter in byDotCount) {
      final matches = switch (letter.dotArrangement) {
        _DotArrangement.column => _matchesColumnDots(letter.dots),
        _DotArrangement.row => _matchesRowDots(letter.dots),
        _DotArrangement.cross => _matchesCrossDots(letter.dots),
        _DotArrangement.crossCenter => _matchesCrossCenterDots(letter.dots),
      };
      if (matches) return letter;
    }
    return null;
  }

  bool _isVertical(_Stroke s) =>
      (s.end.dx - s.start.dx).abs() < (s.end.dy - s.start.dy).abs();

  /// Whether the most recent [count] dots, sorted top to bottom, form an
  /// unbroken vertical column — each dot's bounding circle (radius
  /// [_dotRadius]) intersects the next one's on the horizontal axis (x
  /// center), so they read as one grouped mark — and the dots actually
  /// span enough vertical distance to read as a column at all, rather
  /// than a horizontal row that happens to have small x increments
  /// between its (dy-sorted, effectively arbitrary-order) points too.
  bool _matchesColumnDots(int count) {
    if (_dots.length < count) return false;
    final recent = _dots.sublist(_dots.length - count);
    final sorted = [...recent]..sort((a, b) => a.dy.compareTo(b.dy));
    for (var i = 1; i < sorted.length; i++) {
      if ((sorted[i].dx - sorted[i - 1].dx).abs() > _dotRadius * 2) {
        return false;
      }
    }
    // A single dot (ⴰ/a) has nothing to span — sorted.last and
    // sorted.first are the same point, so the span check below would
    // always read as 0 and never match.
    return count == 1 || sorted.last.dy - sorted.first.dy > _dotRadius * 2;
  }

  /// Whether the most recent [count] dots, sorted left to right, form an
  /// unbroken horizontal row — each dot's bounding circle (radius
  /// [_dotRadius]) intersects the next one's on the vertical axis (y
  /// center), so they read as one grouped mark — and the dots actually
  /// span enough horizontal distance to read as a row at all, the
  /// same-reasoning counterpart of [_matchesColumnDots]'s span check.
  bool _matchesRowDots(int count) {
    if (_dots.length < count) return false;
    final recent = _dots.sublist(_dots.length - count);
    final sorted = [...recent]..sort((a, b) => a.dx.compareTo(b.dx));
    for (var i = 1; i < sorted.length; i++) {
      if ((sorted[i].dy - sorted[i - 1].dy).abs() > _dotRadius * 2) {
        return false;
      }
    }
    return sorted.last.dx - sorted.first.dx > _dotRadius * 2;
  }

  /// Whether the most recent [count] (4) dots split into a top row and a
  /// bottom row of 2 — sorted by y, the top 2 share a y center and are
  /// actually spread apart in x (a real row, not 2 dots stacked in the
  /// same column), the bottom 2 the same, and the two rows' y centers
  /// differ — the corners of a rectangle, whose diagonals read as the "X"
  /// of ⵆ.
  bool _matchesCrossDots(int count) {
    if (_dots.length < count) return false;
    return _isCrossDots(_dots.sublist(_dots.length - count));
  }

  /// Whether exactly these 4 dots split into a top row and a bottom row of
  /// 2 (see [_matchesCrossDots]). The x-spread checks are what rule out a
  /// plain 4-dot column (ⵂ) — sorted by y, its consecutive dots all share
  /// nearly the same x, so without them every straight column would also
  /// read as a (looser, same-dot-count) cross, and — since cross is
  /// checked ahead of column at equal dot counts, see [_classifyDots] —
  /// would always shadow ⵂ.
  bool _isCrossDots(List<Offset> dots) {
    final sorted = [...dots]..sort((a, b) => a.dy.compareTo(b.dy));
    final top = sorted.sublist(0, 2);
    final bottom = sorted.sublist(2);
    final topAligned = (top[0].dy - top[1].dy).abs() <= _dotRadius * 2;
    final bottomAligned = (bottom[0].dy - bottom[1].dy).abs() <= _dotRadius * 2;
    final rowsDiffer = (bottom[0].dy - top[0].dy).abs() > _dotRadius * 2;
    final topSpread = (top[0].dx - top[1].dx).abs() > _dotRadius * 2;
    final bottomSpread = (bottom[0].dx - bottom[1].dx).abs() > _dotRadius * 2;
    return topAligned && bottomAligned && rowsDiffer && topSpread && bottomSpread;
  }

  /// Whether the most recent [count] (5) dots split into a 4-dot cross
  /// (any one of the 5 excluded, see [_isCrossDots]) plus that excluded
  /// dot sitting inside the cross's bounding box while sharing neither an
  /// x nor a y range with any of the other 4 — the extra dot of ⵘ.
  bool _matchesCrossCenterDots(int count) {
    if (_dots.length < count) return false;
    final recent = _dots.sublist(_dots.length - count);
    for (var i = 0; i < recent.length; i++) {
      final center = recent[i];
      final outer = [
        for (var j = 0; j < recent.length; j++)
          if (j != i) recent[j]
      ];
      if (!_isCrossDots(outer)) continue;
      if (!_boundsOf(outer).contains(center)) continue;
      final unaligned = outer.every((o) =>
          (center.dx - o.dx).abs() > _dotRadius * 2 &&
          (center.dy - o.dy).abs() > _dotRadius * 2);
      if (unaligned) return true;
    }
    return false;
  }

  /// Whether the most recent 3 strokes are all horizontal and share a
  /// common x-range overlap — read as a stack of horizontal bars, like
  /// Libyco-Berber's h. Unlike [_matchesGrid], there's no vertical stroke
  /// to cross, so the x-overlap is what confirms they read as one mark
  /// rather than 3 unrelated horizontal strokes.
  _TifinaghLetter? _classifyLibycoBerberH() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    if (recent.any(_isVertical)) return null;
    final bounds = recent.map((s) => _boundsOf(s.points)).toList();
    final maxLeft = bounds.map((b) => b.left).reduce((a, b) => a > b ? a : b);
    final minRight = bounds.map((b) => b.right).reduce((a, b) => a < b ? a : b);
    return maxLeft <= minRight ? _TifinaghLetter.yahLb : null;
  }

  /// Whether the most recent 2 strokes form Libyco-Berber's l/w: two
  /// vertical lines, side by side rather than stacked (their y-ranges
  /// overlap), with neither crossing the other, and neither
  /// self-intersecting — l/w never loops, so a stray self-crossing near a
  /// sharp turn shouldn't let a stroke masquerade as one.
  _TifinaghLetter? _classifyLibycoBerberLW() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    if (recent.any((s) => !_isVertical(s))) return null;
    if (recent.any((s) => _selfIntersections(s) != 0)) return null;
    final bounds = recent.map((s) => _boundsOf(s.points)).toList();
    final yRangesOverlap =
        bounds[0].top <= bounds[1].bottom && bounds[1].top <= bounds[0].bottom;
    if (!yRangesOverlap) return null;
    return _crossings(recent[0], recent[1]) == 0 ? _TifinaghLetter.yalLb : null;
  }

  /// Whether [stroke] forms Libyco-Berber's z²: a single horizontal
  /// line — genuinely straight, with no direction reversal at all (split
  /// by horizontal direction change into exactly 1 segment) — that
  /// doesn't cross any other recent stroke ([_crossesOtherRecentStroke]).
  /// The straight-line requirement matters, not just [_isVertical]'s
  /// loose overall-chord check: without it, a self-crossing loop like r,
  /// f, or s² whose own more specific classifier happens to miss it (a
  /// self-intersection count that comes out wrong, say) would otherwise
  /// fall all the way through and get wrongly claimed here instead of
  /// staying unrecognized.
  _TifinaghLetter? _classifyLibycoBerberZ2(_Stroke stroke) =>
      _splitByHorizontalDirectionChange(stroke).length == 1 &&
              !_isVertical(stroke) &&
              !_crossesOtherRecentStroke(stroke)
          ? _TifinaghLetter.yaz2Lb
          : null;

  /// Whether [stroke] forms ⵏ: a single vertical line that doesn't cross
  /// any other recent stroke ([_crossesOtherRecentStroke]) — the
  /// straight-line counterpart of [_classifyLibycoBerberZ2], since
  /// several letters (t/s⁴, z¹, ṭ, z³) use a vertical line crossing
  /// something else too, and a plain reuse of the generic grid
  /// classifier wouldn't rule that out — and isn't [_isZigzagShaped]
  /// (ⵢ's own shape), since a zigzag's overall start/end chord often
  /// reads as vertical too even though it's not a straight line at all;
  /// checked ahead of this one in [_commit] regardless, so this guard is
  /// only a backstop for the case [_classifyZigzagStroke] itself misses.
  _TifinaghLetter? _classifyN(_Stroke stroke) =>
      _isVertical(stroke) &&
              !_crossesOtherRecentStroke(stroke) &&
              !_isZigzagShaped(stroke)
          ? _TifinaghLetter.yan
          : null;

  /// Whether [stroke] forms the r/f self-crossing-loop shape: exactly 1
  /// self-intersection ([_selfIntersections]), split (by horizontal
  /// direction change) into exactly 3 segments, with both the start and
  /// end points falling *below* the stroke's own self-intersection point
  /// ([_selfIntersectionPoints]) — the mirror image of [_classifyR]'s own
  /// endpoints-above-center rule, since r's loop hangs below its
  /// endpoints while g/f's hangs above them.
  bool _isGShaped(_Stroke stroke) {
    if (_selfIntersections(stroke) != 1) return false;
    if (_splitByHorizontalDirectionChange(stroke).length != 3) return false;
    final intersection = _selfIntersectionPoints(stroke).single;
    return stroke.start.dy > intersection.dy && stroke.end.dy > intersection.dy;
  }

  /// Whether [stroke] forms Libyco-Berber's r or f: [_isGShaped], split
  /// into left-right-left for r or right-left-right for f by which way the
  /// first segment goes. Unlike [_classifyG] (which checks the first/last
  /// segments' *vertical* direction) or the bare ⵔ self-intersection check
  /// (which doesn't check segments at all), neither of which reliably
  /// distinguishes this pair for Libyco-Berber's own letterforms.
  _TifinaghLetter? _classifyLibycoBerberRF(_Stroke stroke) {
    if (!_isGShaped(stroke)) return null;
    final segments = _splitByHorizontalDirectionChange(stroke);
    final firstGoesRight = segments.first.last.dx > segments.first.first.dx;
    return firstGoesRight ? _TifinaghLetter.yafLb : _TifinaghLetter.yarLb;
  }

  /// Whether [stroke] forms Neo-Tifinagh's g regardless of which way its
  /// first segment goes — unlike [_classifyLibycoBerberRF], whose f/r
  /// split depends on that direction because Libyco-Berber has a
  /// dedicated letter for each. Neo-Tifinagh has no letter reserved for
  /// the "first segment goes left" reading, so without this, that
  /// reading would fall through [_classifyLibycoBerberRF]'s disabled
  /// [_TifinaghLetter.yarLb] result and get wrongly claimed by Neo-
  /// Tifinagh's own generic r (any self-crossing loop, no segment/
  /// direction check) instead. Checked right after
  /// [_classifyLibycoBerberRF] in [_commit], so Libyco-Berber's own r/f
  /// distinction (already resolved there) is never overridden.
  _TifinaghLetter? _classifyNeoTifinaghG(_Stroke stroke) =>
      _isGShaped(stroke) ? _TifinaghLetter.yafLb : null;

  /// Whether [stroke] splits by horizontal direction change into exactly
  /// 4 segments, right-left-right-left — the segment/direction pattern
  /// shared by Libyco-Berber's s² ([_classifyLibycoBerberS2]) and s³
  /// ([_classifyLibycoBerberS3]), regardless of self-intersection or
  /// overall descent (each checks its own extra condition on top of
  /// this). Also used as a negative guard in
  /// [_classifyM]/[_classifyLibycoBerberM], whose much looser
  /// endpoint-position check would otherwise happily match a stroke
  /// that's really one of these two.
  bool _isRightLeftRightLeftZigzag(_Stroke stroke) {
    final segments = _splitByHorizontalDirectionChange(stroke);
    if (segments.length != 4) return false;
    final goingRight =
        segments.map((seg) => seg.last.dx > seg.first.dx).toList();
    const expected = [true, false, true, false];
    for (var i = 0; i < 4; i++) {
      if (goingRight[i] != expected[i]) return false;
    }
    return true;
  }

  /// Whether [stroke] forms Libyco-Berber's s²: [_isRightLeftRightLeftZigzag]
  /// plus a self-crossing loop (the same start as
  /// [_classifyLibycoBerberRF]'s f case, with one more segment appended),
  /// where the last segment itself reads as horizontal rather than
  /// vertical.
  _TifinaghLetter? _classifyLibycoBerberS2(_Stroke stroke) {
    if (!_isRightLeftRightLeftZigzag(stroke)) return null;
    if (_selfIntersections(stroke) != 1) return null;
    final segments = _splitByHorizontalDirectionChange(stroke);
    return _isSegmentHorizontal(segments.last)
        ? _TifinaghLetter.yas2Lb
        : null;
  }

  /// Whether [segment] reads as horizontal rather than vertical, by its
  /// own start/end chord — the opposite comparison from [_isVertical].
  bool _isSegmentHorizontal(List<Offset> segment) =>
      (segment.last.dx - segment.first.dx).abs() >=
      (segment.last.dy - segment.first.dy).abs();

  /// Whether [stroke] splits by horizontal direction change into exactly
  /// 2 segments — the first going left while also moving down (if
  /// [firstGoesDown]) or up (otherwise), the second going right while
  /// reading as horizontal rather than vertical. The shared shape check
  /// behind Libyco-Berber's g ([_classifyLibycoBerberG], firstGoesDown:
  /// false) and one of the two strokes that make up its k
  /// ([_classifyLibycoBerberK], firstGoesDown: true for the upper one).
  bool _isLibycoBerberGShaped(_Stroke stroke, {required bool firstGoesDown}) {
    final segments = _splitByHorizontalDirectionChange(stroke);
    if (segments.length != 2) return false;
    final first = segments.first;
    final second = segments.last;
    final firstGoesLeft = first.last.dx < first.first.dx;
    final firstVerticalMatches = firstGoesDown
        ? first.last.dy > first.first.dy
        : first.last.dy < first.first.dy;
    if (!firstGoesLeft || !firstVerticalMatches) return false;
    final secondGoesRight = second.last.dx > second.first.dx;
    return secondGoesRight && _isSegmentHorizontal(second);
  }

  /// Whether [stroke] forms Libyco-Berber's g: [_isLibycoBerberGShaped]
  /// with the first segment going up. Unrelated to Ahaggar's own g
  /// ([_classifyG]), a 3-segment self-crossing shape.
  _TifinaghLetter? _classifyLibycoBerberG(_Stroke stroke) =>
      _isLibycoBerberGShaped(stroke, firstGoesDown: false)
          ? _TifinaghLetter.yagLb
          : null;

  /// Whether the most recent 2 strokes form Libyco-Berber's k: g's own
  /// shape ([_isLibycoBerberGShaped], first segment up) plus a second
  /// stroke above it, shaped the same way but with the first segment
  /// going down instead.
  _TifinaghLetter? _classifyLibycoBerberK() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final lower = recent
        .where((s) => _isLibycoBerberGShaped(s, firstGoesDown: false))
        .toList();
    final upper = recent
        .where((s) => _isLibycoBerberGShaped(s, firstGoesDown: true))
        .toList();
    if (lower.length != 1 || upper.length != 1) return null;
    final upperCenterY = _boundsOf(upper.single.points).center.dy;
    final lowerCenterY = _boundsOf(lower.single.points).center.dy;
    return upperCenterY < lowerCenterY ? _TifinaghLetter.yakLb : null;
  }

  /// Whether the most recent 2 strokes form Libyco-Berber's t or s⁴: one
  /// vertical line crossing one horizontal line — the same shape as every
  /// Tuareg region's own t ([_TifinaghLetter.yat]) — with the crossing
  /// point falling in the horizontal line's own middle half (t) or its
  /// own leftmost quarter (s⁴). Checked ahead of the generic [_classify]
  /// grid match, which doesn't care where along the horizontal the
  /// crossing falls and so can't tell this pair apart on its own.
  _TifinaghLetter? _classifyLibycoBerberTS4() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final verticals = recent.where(_isVertical).toList();
    final horizontals = recent.where((s) => !_isVertical(s)).toList();
    if (verticals.length != 1 || horizontals.length != 1) return null;
    final vertical = verticals.single;
    final horizontal = horizontals.single;
    if (!_segmentsIntersect(
        vertical.start, vertical.end, horizontal.start, horizontal.end)) {
      return null;
    }
    final crossing = _intersectionPoint(
        vertical.start, vertical.end, horizontal.start, horizontal.end);
    if (crossing == null) return null;
    final left = horizontal.start.dx < horizontal.end.dx
        ? horizontal.start.dx
        : horizontal.end.dx;
    final right = horizontal.start.dx > horizontal.end.dx
        ? horizontal.start.dx
        : horizontal.end.dx;
    if (right == left) return null;
    final fraction = (crossing.dx - left) / (right - left);
    if (fraction < 0.25) return _TifinaghLetter.yas4Lb;
    if (fraction < 0.75) return _TifinaghLetter.yatLb;
    return null;
  }

  /// Whether [stroke] splits by horizontal direction change into exactly
  /// 2 segments, the first going right and the second going left — the
  /// zigzag half of Libyco-Berber's ṭ ([_classifyLibycoBerberTt]).
  bool _isLibycoBerberTtZigzag(_Stroke stroke) {
    final segments = _splitByHorizontalDirectionChange(stroke);
    if (segments.length != 2) return false;
    final first = segments.first;
    return first.last.dx > first.first.dx;
  }

  /// Whether the most recent 2 strokes form Libyco-Berber's ṭ: one
  /// horizontal line crossing a second line shaped like
  /// [_isLibycoBerberTtZigzag] (identified by that shape, rather than by
  /// [_isVertical], since the zigzag's own overall chord can itself read
  /// as vertical). Checked ahead of [_classifyM]/[_classifyLibycoBerberM]
  /// in [_commit], since the zigzag stroke on its own can also satisfy
  /// the plain (mirrored-)ⵎ endpoint check — m is that same shape with
  /// no intersecting line at all, so the more specific, intersection-
  /// requiring pattern here must win when both apply.
  _TifinaghLetter? _classifyLibycoBerberTt() {
    if (_strokes.length < 2) return null;
    final recent = _strokes.sublist(_strokes.length - 2);
    final zigzags = recent.where(_isLibycoBerberTtZigzag).toList();
    if (zigzags.length != 1) return null;
    final zigzag = zigzags.single;
    final horizontal = recent.firstWhere((s) => s != zigzag);
    if (_isVertical(horizontal)) return null;
    return _crossings(horizontal, zigzag) > 0 ? _TifinaghLetter.yattLb : null;
  }

  /// Whether the most recent 3 strokes form Libyco-Berber's z¹: two
  /// vertical lines, each crossed exactly once by one horizontal line,
  /// with one vertical falling left of the horizontal's own center and
  /// the other right of it. Unlike the generic grid match ([_matchesGrid],
  /// used by [_classify]), which only checks that each vertical crosses
  /// the horizontal somewhere, not where the two verticals fall relative
  /// to each other.
  _TifinaghLetter? _classifyLibycoBerberZ1() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final verticals = recent.where(_isVertical).toList();
    final horizontals = recent.where((s) => !_isVertical(s)).toList();
    if (verticals.length != 2 || horizontals.length != 1) return null;
    final horizontal = horizontals.single;
    if (verticals.any((v) => _crossings(v, horizontal) != 1)) return null;
    final horizontalCenterX = _boundsOf(horizontal.points).center.dx;
    final left = verticals
        .where((v) => _boundsOf(v.points).center.dx < horizontalCenterX);
    final right = verticals
        .where((v) => _boundsOf(v.points).center.dx > horizontalCenterX);
    return left.length == 1 && right.length == 1
        ? _TifinaghLetter.yaz1Lb
        : null;
  }

  /// Whether the most recent `verticals + horizontals` strokes split into
  /// exactly that many vertical/horizontal strokes, with every vertical
  /// stroke crossing every horizontal one (a "+" or "#"-style grid).
  bool _matchesGrid(int verticals, int horizontals) {
    final total = verticals + horizontals;
    if (_strokes.length < total) return false;
    final recent = _strokes.sublist(_strokes.length - total);
    final verticalStrokes = recent.where(_isVertical).toList();
    final horizontalStrokes =
        recent.where((s) => !_isVertical(s)).toList();
    if (verticalStrokes.length != verticals ||
        horizontalStrokes.length != horizontals) {
      return false;
    }
    for (final v in verticalStrokes) {
      for (final h in horizontalStrokes) {
        if (!_segmentsIntersect(v.start, v.end, h.start, h.end)) {
          return false;
        }
      }
    }
    return true;
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
    final dotPaint = Paint()
      ..color = const Color(0xFF1B2A4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    for (final stroke in _strokes) {
      _drawPath(canvas, stroke.points, paint);
    }
    for (final dot in _dots) {
      canvas.drawCircle(dot, _dotRadius, dotPaint);
    }
    if (_activePoints != null) {
      final previewPaint = Paint()
        ..color = paint.color.withValues(alpha: 0.5)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      _drawPath(canvas, _activePoints!, previewPaint);
    }

    final recognized = _recognized;
    final override = recognized == null
        ? null
        : _regionLabelOverrides[region]?[recognized];
    final glyph = override?.$1 ?? recognized?.glyph;
    final letterName = override?.$2 ?? recognized?.letterName;
    final sound = override?.$3 ?? recognized?.sound;
    final label = TextPainter(
      text: recognized != null
          ? TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              children: [
                const TextSpan(text: 'Recognized: '),
                TextSpan(
                  text: glyph,
                  style: const TextStyle(
                    fontFamily: 'NotoSansTifinagh',
                    fontSize: 22,
                  ),
                ),
                TextSpan(
                  text: '  ($letterName — "$sound")',
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

    // Libyco-Berber has no Unicode glyph, so its recognized letter is
    // drawn as its actual bundled letterform image instead, just above
    // the "Recognized: ..." line (which still shows the closest modern
    // equivalent's glyph as a stand-in via [glyph] above).
    final libycoBerberAsset =
        region == 'Libyco-Berber' ? _libycoBerberImages[recognized] : null;
    if (libycoBerberAsset != null) {
      _ensureLibycoBerberImage(libycoBerberAsset);
      final image = _libycoBerberImageCache[libycoBerberAsset];
      if (image != null) {
        const imageSize = 48.0;
        final dst = Rect.fromLTWH(24,
            size.height - 24 - label.height - imageSize - 8, imageSize, imageSize);
        final src =
            Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
        canvas.drawImageRect(image, src, dst, Paint());
      }
    }
  }
}

/// Builds the scene plus a direct reference to its [TifinaghLayer], so the
/// hosting page can call [TifinaghLayer.clear] from the Clear button.
(Scene, TifinaghLayer) buildTifinaghScene() {
  final layer = TifinaghLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
