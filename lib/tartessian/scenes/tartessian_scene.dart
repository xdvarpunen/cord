import 'package:flutter/material.dart';

import '../engine/scene.dart';

/// Cream, dot-grid paper background (Moleskine-style notebook page). Copied
/// from the tifi project's Tifinagh scene — a plain, script-agnostic
/// backdrop.
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

/// The dominant axis of a stroke's bounding box, used to tell a vertical
/// "bar" from a horizontal "rung" in the ladder signs (`o`, `sa`).
enum _Orientation { vertical, horizontal, other }

/// One freehand pen stroke: the polyline of points from pointer-down to
/// pointer-up.
class _Stroke {
  _Stroke(this.points);
  final List<Offset> points;
  Offset get start => points.first;
  Offset get end => points.last;
}

/// A Tartessian (Southwestern Paleohispanic) sign the recognizer can read.
///
/// Only signs with a built classifier live here; the full signary (for the
/// reference table) is in `data/tartessian_scripts.dart`. Signs are added one
/// at a time as their gesture is implemented — the same incremental approach
/// the tifi Tifinagh recognizer this is ported from uses.
enum _TartessianLetter {
  /// ka (g / k + a) — a single stroke that rises then falls: split by
  /// vertical direction change into exactly two segments, up then down (an
  /// `∧`-like peak). See [TartessianLayer._classifyKa].
  ka('ka', 'k / g + a', 'velar stop — a single stroke, up then down (∧)'),

  /// e — a single stroke that loops across itself (self-intersects at least
  /// once). See [TartessianLayer._classifyE].
  e('e', 'e', 'vowel — a single stroke that crosses itself (a loop)'),

  /// o — three strokes: one vertical bar crossed by two horizontal lines
  /// (the recognizer's first multi-stroke sign). See
  /// [TartessianLayer._classifyO].
  o('o', 'o', 'vowel — a vertical stroke crossed by two horizontals'),

  /// sa — the same vertical-bar "ladder" as [o], but with three crossing
  /// horizontal lines instead of two. See [TartessianLayer._classifySa].
  sa('sa', 'sa', 'sibilant — a vertical stroke crossed by three horizontals'),

  /// a — the [ka] peak (∧) with an extra ascending `/` line crossing it: two
  /// strokes, one up-then-down peak plus one rising line through it. See
  /// [TartessianLayer._classifyA].
  a('a', 'a', 'vowel — the ka peak (∧) crossed by an ascending line'),

  /// se — a single stroke of two peaks: up, down, up, down (∧∧); four
  /// vertical-direction segments. See [TartessianLayer._classifySe].
  se('se', 'se', 'sibilant — a single stroke: up, down, up, down (∧∧)'),

  /// ba (b / pa) — the horizontal twin of [se]: a single stroke zig-zagging
  /// left, right, left, right, left, right; six horizontal-direction
  /// segments. See [TartessianLayer._classifyBa].
  ba('ba', 'b / p + a', 'labial stop — a single stroke: left, right ×3'),

  /// ta (d / ta) — two crossing strokes forming an `X`: one ascending `/`
  /// line and one descending `\` line that intersect. See
  /// [TartessianLayer._classifyTa].
  ta('ta', 'd / t + a', 'dental stop — two crossing lines (X)'),

  /// ke (g / ke) — a vertical line crossed by a sideways wedge: a single
  /// stroke that splits horizontally (left then right) with both halves
  /// descending. See [TartessianLayer._classifyKe].
  ke('ke', 'k / g + e', 'velar stop — a vertical line crossed by a descending wedge'),

  /// i — two strokes: one splits vertically into down, up, down (three
  /// segments), and a descending line crosses its middle (up) segment. See
  /// [TartessianLayer._classifyI].
  i('i', 'i', 'vowel — a down-up-down stroke, its upstroke crossed by a descending line'),

  /// u — two strokes: a vertical line crossed by a descending line. The
  /// straight-line cousin of [ke], whose crossing stroke is a wedge. See
  /// [TartessianLayer._classifyU].
  u('u', 'u', 'vowel — a vertical line crossed by a descending line'),

  /// bu (b / pu) — five strokes: two vertical lines crossed by three ascending
  /// lines, each ascending line crossing both verticals. See
  /// [TartessianLayer._classifyBu].
  bu('bu', 'b / p + u', 'labial stop — two vertical lines crossed by three ascending lines'),

  /// te (d / te) — the same grid as [bu] but with only two ascending lines
  /// (four strokes). See [TartessianLayer._classifyTe].
  te('te', 'd / t + e', 'dental stop — two vertical lines crossed by two ascending lines'),

  /// ri — three strokes: a [ka] peak (∧), with a descending line crossing its
  /// up arm and an ascending line crossing its down arm. See
  /// [TartessianLayer._classifyRi].
  ri('ri', 'r + i', 'continuant — a ∧ peak: descending line on the up arm, ascending on the down arm'),

  /// be (b / pe) — a single non-self-crossing stroke that arches up from two
  /// low feet: both endpoints sit in the lower half of its bounding box and
  /// are offset diagonally (one up-and-left of the other). See
  /// [TartessianLayer._classifyBe].
  be('be', 'b / p + e', 'labial stop — a single arching stroke with two low, diagonally-set ends'),

  /// bi (b / pi) — two strokes: a vertical line crossed by a [ka] peak (∧)
  /// whose center rides above the vertical line's center. See
  /// [TartessianLayer._classifyBi].
  bi('bi', 'b / p + i', 'labial stop — a vertical line crossed by a ∧ peak riding above it'),

  /// ko (g / ko) — a single-stroke bowtie: four vertical runs up, down, up,
  /// down, the first down travelling down-right (`\`) and the last down-left
  /// (`/`) so the diagonals cross. Modelled on futhark's *dagaz* (ᛞ). See
  /// [TartessianLayer._classifyKo].
  ko('ko', 'k / g + o', 'velar stop — a single-stroke bowtie (⋈), like futhark dagaz'),

  /// ku (g / ku) — the [ko] bowtie crossed by a vertical line (two strokes).
  /// See [TartessianLayer._classifyKu].
  ku('ku', 'k / g + u', 'velar stop — the ko bowtie crossed by a vertical line'),

  /// ti (d / ti) — two strokes: an [e]-style self-crossing loop and a vertical
  /// line passing through it, crossing the loop twice (entering and leaving).
  /// See [TartessianLayer._classifyTi].
  ti('ti', 'd / t + i', 'dental stop — an e loop with a vertical line crossing it twice'),

  /// ki (g / ki) — the [ti] loop-and-bar, but the vertical line drops a long
  /// tail below the loop: at least a third of the bar's height sits below its
  /// lower crossing with the loop. See [TartessianLayer._classifyKi].
  ki('ki', 'k / g + i', 'velar stop — a ti loop whose vertical line drops a long tail below it'),

  /// bo (b / po) — four strokes: two vertical bars crossed by two horizontal
  /// lines (each crossing both bars), one horizontal in the top third and the
  /// other in the bottom third of the shape's bounding box. See
  /// [TartessianLayer._classifyBo].
  bo('bo', 'b / p + o', 'labial stop — two vertical bars with a horizontal crossbar near the top and one near the bottom'),

  /// to (d / to) — two strokes, each going up-and-down (a ∧/V), that cross each
  /// other exactly twice. See [TartessianLayer._classifyTo].
  to('to', 'd / t + o', 'dental stop — two up-and-down strokes that cross each other twice'),

  /// tu (d / tu) — a single stroke closed triangle: a [ka]-like peak whose
  /// bottom line returns to close the shape, so its start and end nearly meet
  /// and it does not cross itself. See [TartessianLayer._classifyTu].
  tu('tu', 'd / t + u', 'dental stop — a single-stroke closed triangle (a ka peak closed by a bottom line)');

  const _TartessianLetter(this.sign, this.sound, this.description);

  /// Latin transliteration, matched against [TartessianSign.transliteration].
  final String sign;
  final String sound;
  final String description;
}

/// Freehand recognition of Tartessian signs, drawn on a [GameCanvas].
///
/// The recognition toolkit — stroke capture, splitting a stroke by vertical
/// direction change, self-intersection counting — is ported from the tifi
/// project's `TifinaghLayer`; only the per-sign classifiers differ. Signs so
/// far:
///
/// - **ka** (`k / g + a`) — a single stroke split by vertical direction
///   change into exactly two segments, going up then down (an `∧` peak),
///   with no self-crossing. See [_classifyKa].
/// - **e** — a single stroke that crosses itself at least once (a loop). See
///   [_classifyE].
/// - **o** / **sa** — multi-stroke "ladder" signs: one vertical bar crossed by
///   two (`o`) or three (`sa`) horizontal lines. These read the whole stroke
///   set, not just the latest stroke. See [_classifyO], [_classifySa].
/// - **a** — the `ka` peak (∧) plus an ascending `/` line crossing it (two
///   strokes). Reads the whole stroke set. See [_classifyA].
/// - **se** — one stroke of two peaks (up, down, up, down; ∧∧). See
///   [_classifySe].
/// - **ba** (`b / pa`) — one stroke zig-zagging horizontally (left, right ×3);
///   the horizontal twin of `se`. See [_classifyBa].
/// - **ta** (`d / ta`) — two crossing lines forming an `X`: an ascending and a
///   descending line that intersect (two strokes). See [_classifyTa].
/// - **ke** (`g / ke`) — a vertical line crossed by a sideways wedge: one
///   stroke splitting horizontally (left then right), both halves descending
///   (two strokes). See [_classifyKe].
/// - **i** — a down-up-down stroke whose middle upstroke is crossed by a
///   descending line (two strokes). See [_classifyI].
/// - **u** — a vertical line crossed by a descending line (two strokes); the
///   straight-line cousin of `ke`. See [_classifyU].
/// - **bu** (`b / pu`) / **te** (`d / te`) — two vertical bars crossed by
///   three (`bu`) or two (`te`) ascending lines, each line crossing both bars.
///   Read the whole stroke set. See [_classifyBu], [_classifyTe].
/// - **ri** — a `∧` peak with a descending line crossing its up arm and an
///   ascending line crossing its down arm (three strokes). See [_classifyRi].
/// - **be** (`b / pe`) — one non-self-crossing stroke arching up from two low,
///   diagonally-offset endpoints. Checked last, as a loose geometric shape.
///   See [_classifyBe].
/// - **bi** (`b / pi`) — a vertical line crossed by a `∧` peak whose center
///   rides above the line's center (two strokes). See [_classifyBi].
/// - **ko** (`g / ko`) — a single-stroke bowtie (⋈): up, down-right, up,
///   down-left, modelled on futhark dagaz. Checked before `e`/`se`. See
///   [_classifyKo].
/// - **ku** (`g / ku`) — the `ko` bowtie crossed by a vertical line (two
///   strokes). See [_classifyKu].
/// - **ti** (`d / ti`) — an `e`-style self-crossing loop with a vertical line
///   passing through it, crossing the loop twice (two strokes). See
///   [_classifyTi].
/// - **ki** (`g / ki`) — the `ti` loop-and-bar, but the vertical line drops a
///   long tail below the loop (at least a third of the bar sits below its
///   lower crossing). Checked before `ti`. See [_classifyKi].
/// - **bo** (`b / po`) — two vertical bars crossed by two horizontal lines
///   (each crossing both bars), one horizontal in the top third and one in the
///   bottom third of the bounding box (four strokes). See [_classifyBo].
/// - **to** (`d / to`) — two strokes, each going up-and-down (a `∧`/`V`), that
///   cross each other exactly twice. See [_classifyTo].
/// - **tu** (`d / tu`) — a single-stroke closed triangle: a `ka`-like peak
///   closed by a bottom line, so its ends nearly meet and it does not cross
///   itself. See [_classifyTu].
///
/// Recognition is live: each completed stroke re-runs the classifiers, so the
/// readout updates as you draw. Strokes that match nothing are still drawn,
/// just reported as unrecognized.
class TartessianLayer extends Layer {
  /// Below this pointer-travel distance a gesture is a tap, not a drag — no
  /// tap-based (dot) signs exist yet, so taps are ignored.
  static const double _dotThreshold = 5;

  /// A drag must travel at least this far to be committed as a stroke, so a
  /// near-stationary jitter isn't mistaken for a line.
  static const double _minDragDistance = 8;

  final List<_Stroke> _strokes = [];
  _TartessianLetter? _recognized;
  List<Offset>? _activePoints;

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
      if (dragDistance >= _dotThreshold &&
          points.length >= 2 &&
          dragDistance >= _minDragDistance) {
        _commit(_Stroke(points));
      }
      _activePoints = null;
    }
  }

  void _commit(_Stroke stroke) {
    _strokes.add(stroke);
    // Single-stroke signs only apply when the canvas holds exactly one stroke,
    // so the last stroke of a multi-stroke sign (e.g. bi's peak) isn't grabbed
    // by a single-stroke classifier (e.g. ka) before the whole-set classifiers
    // run. Multi-stroke classifiers read the whole stroke set.
    final single = _strokes.length == 1;
    _recognized = _firstValid([
      // ko (bowtie) is a specific self-crossing up-down-up-down, so it comes
      // before se (the plain up-down-up-down).
      if (single) () => _classifyKo(stroke),
      // tu is a specific closed shape (a triangle); it precedes the open peaks
      // (ka, se, …) and the loose arch (be), which it would otherwise resemble.
      if (single) () => _classifyTu(stroke),
      if (single) () => _classifyKa(stroke),
      if (single) () => _classifySe(stroke),
      if (single) () => _classifyBa(stroke),
      // be is a loose single-stroke shape, so it comes after the specific ones.
      if (single) () => _classifyBe(stroke),
      () => _classifyO(),
      () => _classifySa(),
      () => _classifyBu(),
      // bo (horizontal crossbars) comes before te (ascending crossbars); a
      // near-flat crossbar could otherwise read as a shallow ascending line.
      () => _classifyBo(),
      () => _classifyTe(),
      () => _classifyRi(),
      // to is two up-and-down strokes crossing twice; it precedes bi, whose
      // straight bar a tall reversing stroke could otherwise impersonate.
      () => _classifyTo(),
      () => _classifyBi(),
      () => _classifyKu(),
      // ki is the ti loop-and-bar with a long tail below the loop, so it is
      // tried before the plain ti (which claims the short-tailed rest).
      () => _classifyKi(),
      // ti pairs a self-crossing loop with a vertical bar; it comes after ku
      // (whose bowtie also self-crosses) but before the plainer vertical
      // crossings (u/ke/ta), whose endpoint tests a loop could otherwise pass.
      () => _classifyTi(),
      () => _classifyA(),
      () => _classifyI(),
      () => _classifyKe(),
      () => _classifyU(),
      () => _classifyTa(),
      // e matches any self-crossing single stroke, so it is the final fallback
      // — every more specific self-crossing sign (ko, …) gets first refusal.
      if (single) () => _classifyE(stroke),
    ]);
  }

  /// Tries each classifier in order, returning the first non-null result.
  _TartessianLetter? _firstValid(
      List<_TartessianLetter? Function()> classifiers) {
    for (final classify in classifiers) {
      final result = classify();
      if (result != null) return result;
    }
    return null;
  }

  /// Whether [stroke] forms **ka**: a single stroke split (by vertical
  /// direction change) into exactly two segments, going up then down — the
  /// mirror of the tifi recognizer's own down-then-up `ⴸ` check. Rejects any
  /// self-crossing stroke, so a loop drawn near a sharp turn can't masquerade
  /// as the peak.
  _TartessianLetter? _classifyKa(_Stroke stroke) =>
      _isKaPeak(stroke) ? _TartessianLetter.ka : null;

  /// Whether [stroke] is the ka "peak": no self-crossing, split by vertical
  /// direction into exactly two segments going up then down (an `∧`). Shared
  /// by [_classifyKa] and [_classifyA] (whose peak is the same shape).
  bool _isKaPeak(_Stroke stroke) {
    if (_selfIntersections(stroke) != 0) return false;
    // Vertical segments; true = down. Up-then-down is exactly [false, true].
    final seq = _directionSequence(stroke, horizontal: false);
    return seq.length == 2 && !seq[0] && seq[1];
  }

  /// Whether [stroke] forms **se**: a single stroke of two peaks — up, down,
  /// up, down. Vertical segments alternate, so four of them starting upward is
  /// exactly `[false, true, false, true]` (∧∧). No self-crossing.
  _TartessianLetter? _classifySe(_Stroke stroke) {
    if (_selfIntersections(stroke) != 0) return null;
    final seq = _directionSequence(stroke, horizontal: false);
    return _isAlternating(seq, length: 4, firstIsPositive: false)
        ? _TartessianLetter.se
        : null;
  }

  /// Whether [stroke] forms **ko** (`g / ko`): the bowtie. See
  /// [_isDagazBowtie].
  _TartessianLetter? _classifyKo(_Stroke stroke) =>
      _isDagazBowtie(stroke) ? _TartessianLetter.ko : null;

  /// Whether [stroke] is the dagaz bowtie (⋈): four vertical segments up, down,
  /// up, down (as [se]), but with the first down segment descending down-right
  /// (`\`) and the last descending down-left (`/`), so the diagonals cross.
  /// Ported from futhark's *dagaz* classifier. Shared by [_classifyKo] and
  /// [_classifyKu].
  bool _isDagazBowtie(_Stroke stroke) {
    final segments = _splitByDirectionChange(stroke, horizontal: false);
    if (segments.length != 4) return false;
    final seq = segments.map((s) => s.last.dy > s.first.dy).toList();
    if (!_isAlternating(seq, length: 4, firstIsPositive: false)) return false;
    return _segmentDescends(segments[1]) && !_segmentDescends(segments[3]);
  }

  /// Whether a segment reads as descending (`\`): its horizontal and vertical
  /// travel agree in sign (both increase or both decrease) — down-right or
  /// up-left. The opposite (`/`) is ascending. Read straight off the endpoints,
  /// since a direction-split segment has one vertical direction.
  bool _segmentDescends(List<Offset> seg) =>
      (seg.last.dx > seg.first.dx) == (seg.last.dy > seg.first.dy);

  /// Whether [stroke] forms **ba** (`b / pa`): a single stroke zig-zagging
  /// left, right, left, right, left, right — the horizontal twin of [se].
  /// Horizontal segments alternate, so six of them starting leftward is
  /// `[false, true] × 3`. No self-crossing.
  _TartessianLetter? _classifyBa(_Stroke stroke) {
    if (_selfIntersections(stroke) != 0) return null;
    final seq = _directionSequence(stroke, horizontal: true);
    return _isAlternating(seq, length: 6, firstIsPositive: false)
        ? _TartessianLetter.ba
        : null;
  }

  /// Whether [stroke] forms **be** (`b / pe`): a single stroke that does not
  /// cross itself, whose start and end both sit in the lower half of its
  /// bounding box and are offset diagonally — one endpoint up-and-left of the
  /// other (the start-to-end run has matching-sign dx and dy). So the stroke
  /// arches up between two low feet.
  _TartessianLetter? _classifyBe(_Stroke stroke) {
    if (_selfIntersections(stroke) != 0) return null;
    var minY = stroke.points.first.dy;
    var maxY = minY;
    for (final p in stroke.points) {
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final centerY = (minY + maxY) / 2;
    final start = stroke.start;
    final end = stroke.end;
    // Both ends in the lower half of the bounding box.
    if (start.dy <= centerY || end.dy <= centerY) return null;
    // Ends offset diagonally: one is up-and-left of the other.
    final diagonal = (end.dx - start.dx) * (end.dy - start.dy) > 0;
    return diagonal ? _TartessianLetter.be : null;
  }

  /// Whether [seq] has exactly [length] entries and strictly alternates
  /// starting from [firstIsPositive]. Split segments always alternate, so this
  /// only really tests the length and the starting direction.
  bool _isAlternating(List<bool> seq,
      {required int length, required bool firstIsPositive}) {
    if (seq.length != length) return false;
    for (var i = 0; i < length; i++) {
      final expected = (i.isEven) == firstIsPositive;
      if (seq[i] != expected) return false;
    }
    return true;
  }

  /// Whether the whole stroke set forms **a**: exactly two strokes — the [ka]
  /// peak (∧) and an ascending `/` line that crosses it. Either draw order is
  /// accepted, so the peak and the line can be tried in both roles. The
  /// crossing line must be a straight, non-self-crossing stroke, so a
  /// self-crossing loop (the [ti] sign) is never read as `a`'s line — the
  /// peak's own no-self-cross is already enforced by [_isKaPeak].
  _TartessianLetter? _classifyA() {
    if (_strokes.length != 2) return null;
    for (var i = 0; i < 2; i++) {
      final peak = _strokes[i];
      final line = _strokes[1 - i];
      if (_selfIntersections(line) != 0) continue;
      if (_isKaPeak(peak) &&
          _isAscendingLine(line) &&
          _strokesCross(line, peak)) {
        return _TartessianLetter.a;
      }
    }
    return null;
  }

  /// Whether the whole stroke set forms **ta** (`d / ta`): exactly two crossing
  /// lines forming an `X` — one ascending `/` and one descending `\` that
  /// intersect. Either draw order is accepted. Distinct from [_classifyA],
  /// whose two strokes include a `∧` peak rather than two straight diagonals.
  /// Neither stroke may cross itself, so a self-crossing loop (the [ti] sign)
  /// is never read as one of the `X`'s diagonals.
  _TartessianLetter? _classifyTa() {
    if (_strokes.length != 2) return null;
    final first = _strokes[0];
    final second = _strokes[1];
    if (_selfIntersections(first) != 0 || _selfIntersections(second) != 0) {
      return null;
    }
    final oneWay = _isAscendingLine(first) && _isDescendingLine(second);
    final otherWay = _isAscendingLine(second) && _isDescendingLine(first);
    if ((oneWay || otherWay) && _strokesCross(first, second)) {
      return _TartessianLetter.ta;
    }
    return null;
  }

  /// Whether the whole stroke set forms **i**: exactly two strokes — one
  /// splitting vertically into down, up, down (three segments), the other a
  /// descending line that crosses that middle (up) segment. Ordered before
  /// [_classifyU]/[_classifyKe]/[_classifyTa]; a real one of those can't reach
  /// here, as none produces a three-segment down-up-down stroke.
  _TartessianLetter? _classifyI() {
    if (_strokes.length != 2) return null;
    for (var i = 0; i < 2; i++) {
      final zigzag = _strokes[i];
      final line = _strokes[1 - i];
      if (!_isDescendingLine(line)) continue;
      final segments = _splitByDirectionChange(zigzag, horizontal: false);
      if (segments.length != 3) continue;
      // Vertical directions: true = down. Down, up, down is [true, false, true].
      final seq = segments.map((s) => s.last.dy > s.first.dy).toList();
      if (!_isAlternating(seq, length: 3, firstIsPositive: true)) continue;
      // The line must cross the middle (up) segment specifically.
      if (_strokesCross(line, _Stroke(segments[1]))) return _TartessianLetter.i;
    }
    return null;
  }

  /// Whether the whole stroke set forms **u**: exactly two strokes — a vertical
  /// bar crossed by a descending line. The straight-line cousin of [_classifyKe]
  /// (a wedge), so it runs after `ke` — a real wedge also reads as a descending
  /// line by its endpoints — and before [_classifyTa].
  _TartessianLetter? _classifyU() {
    if (_strokes.length != 2) return null;
    final first = _strokes[0];
    final second = _strokes[1];
    // Neither stroke may cross itself: a self-crossing loop (the [ti] sign)
    // must not be read as u's straight descending line, even though its
    // endpoints can happen to slope like one.
    if (_selfIntersections(first) != 0 || _selfIntersections(second) != 0) {
      return null;
    }
    final oneWay = _orientation(first) == _Orientation.vertical &&
        _isDescendingLine(second);
    final otherWay = _orientation(second) == _Orientation.vertical &&
        _isDescendingLine(first);
    if ((oneWay || otherWay) && _strokesCross(first, second)) {
      return _TartessianLetter.u;
    }
    return null;
  }

  /// Whether the whole stroke set forms **ke** (`g / ke`): exactly two strokes
  /// — a vertical bar and a descending sideways wedge — that cross. Ordered
  /// before [_classifyTa] because a crude endpoint test could otherwise read
  /// the bar-plus-wedge as two diagonals; a real `ta` can't reach here (its
  /// diagonals aren't a two-segment wedge, and neither is vertical).
  _TartessianLetter? _classifyKe() {
    if (_strokes.length != 2) return null;
    final first = _strokes[0];
    final second = _strokes[1];
    final oneWay = _orientation(first) == _Orientation.vertical &&
        _isDescendingWedge(second);
    final otherWay = _orientation(second) == _Orientation.vertical &&
        _isDescendingWedge(first);
    if ((oneWay || otherWay) && _strokesCross(first, second)) {
      return _TartessianLetter.ke;
    }
    return null;
  }

  /// Whether [stroke] is a sideways wedge that descends throughout: it splits
  /// horizontally into exactly two segments (one leftward, one rightward) and
  /// both travel downward (screen y increases). Combined with a crossing
  /// vertical bar this is the `ke` sign.
  bool _isDescendingWedge(_Stroke stroke) {
    final segments = _splitByDirectionChange(stroke, horizontal: true);
    if (segments.length != 2) return false;
    return segments.every((seg) => seg.last.dy > seg.first.dy);
  }

  /// Whether [stroke] rises left-to-right (a `/` slope): its rightmost point
  /// sits higher on screen (smaller y) than its leftmost. Judged by geometry,
  /// not draw direction, so it holds whichever way the line was drawn.
  bool _isAscendingLine(_Stroke stroke) {
    final (left, right) = _horizontalExtremes(stroke);
    return right.dy < left.dy;
  }

  /// Whether [stroke] falls left-to-right (a `\` slope): the mirror of
  /// [_isAscendingLine], with its rightmost point lower (larger y).
  bool _isDescendingLine(_Stroke stroke) {
    final (left, right) = _horizontalExtremes(stroke);
    return right.dy > left.dy;
  }

  /// [stroke]'s leftmost and rightmost points, by x.
  (Offset, Offset) _horizontalExtremes(_Stroke stroke) {
    var left = stroke.points.first;
    var right = stroke.points.first;
    for (final p in stroke.points) {
      if (p.dx < left.dx) left = p;
      if (p.dx > right.dx) right = p;
    }
    return (left, right);
  }

  /// Whether [stroke] forms **tu** (`d / tu`): a single-stroke **closed
  /// triangle** — a [ka]-like peak whose bottom line returns to close the
  /// shape. It does not cross itself, its start and end nearly meet (the
  /// closure), and the apex rises above the two low, near-meeting ends. The
  /// closure is what tells it apart from the *open* single-stroke shapes it
  /// otherwise resembles — [ka]/[se] (open peaks) and [be] (a loose arch from
  /// two spread-apart feet) — so it is ordered before them.
  ///
  /// Uses endpoint geometry, not direction-segment counts, so hand tremor
  /// (which shatters the vertical/horizontal splits) doesn't matter.
  _TartessianLetter? _classifyTu(_Stroke stroke) {
    if (_selfIntersections(stroke) != 0) return null;
    var minX = stroke.points.first.dx, maxX = minX;
    var minY = stroke.points.first.dy, maxY = minY;
    for (final p in stroke.points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final width = maxX - minX;
    final height = maxY - minY;
    final span = width > height ? width : height;
    if (span == 0) return null;
    final start = stroke.start;
    final end = stroke.end;
    // Closed: the two ends nearly meet (unlike be's spread-apart feet).
    if ((end - start).distance > 0.35 * span) return null;
    // Those near-meeting ends sit low, and the apex rises above them.
    final centerY = minY + height / 2;
    if (start.dy < centerY || end.dy < centerY) return null;
    return _TartessianLetter.tu;
  }

  /// Whether [stroke] forms **e**: a single stroke that crosses its own path
  /// exactly once (a simple loop). Checked last, as the catch-all self-crossing
  /// shape, so specific self-crossing signs (ko, …) match first.
  _TartessianLetter? _classifyE(_Stroke stroke) =>
      _selfIntersections(stroke) == 1 ? _TartessianLetter.e : null;

  /// Whether the whole stroke set forms **o**: a vertical bar crossed by
  /// exactly two horizontal lines.
  _TartessianLetter? _classifyO() =>
      _ladderRungCount() == 2 ? _TartessianLetter.o : null;

  /// Whether the whole stroke set forms **sa**: the same ladder as [o] but
  /// with three crossing horizontals.
  _TartessianLetter? _classifySa() =>
      _ladderRungCount() == 3 ? _TartessianLetter.sa : null;

  /// Whether the whole stroke set forms **bu** (`b / pu`): two vertical bars
  /// crossed by exactly three ascending lines.
  _TartessianLetter? _classifyBu() =>
      _ladderAscendingCount() == 3 ? _TartessianLetter.bu : null;

  /// Whether the whole stroke set forms **te** (`d / te`): the same grid as
  /// [bu] but with exactly two ascending lines.
  _TartessianLetter? _classifyTe() =>
      _ladderAscendingCount() == 2 ? _TartessianLetter.te : null;

  /// Whether the whole stroke set forms **bo** (`b / po`): exactly four
  /// strokes — two vertical bars crossed by two horizontal lines (each crossing
  /// both bars) — with the horizontals spread apart, one in the top third and
  /// the other in the bottom third of the whole shape's bounding box (neither
  /// in the middle), and no stroke crossing itself. The horizontal crossbars
  /// (not the ascending ones of [te]) are what set it apart from the [te] grid.
  _TartessianLetter? _classifyBo() {
    if (_strokes.length != 4) return null;
    if (_strokes.any((s) => _selfIntersections(s) != 0)) return null;
    final verticals =
        _strokes.where((s) => _orientation(s) == _Orientation.vertical).toList();
    final horizontals = _strokes
        .where((s) => _orientation(s) == _Orientation.horizontal)
        .toList();
    // Exactly two vertical bars and two horizontal lines, nothing else.
    if (verticals.length != 2 || horizontals.length != 2) return null;
    // Every horizontal must cross both bars.
    for (final h in horizontals) {
      if (!verticals.every((v) => _strokesCross(h, v))) return null;
    }
    // One horizontal in the top third, the other in the bottom third of the
    // whole shape's vertical extent — spread apart, not bunched ("below" is
    // larger screen y).
    var minY = _strokes.first.points.first.dy, maxY = minY;
    for (final s in _strokes) {
      for (final p in s.points) {
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    final third = (maxY - minY) / 3;
    final ys = horizontals.map((h) => _centerOf(h).dy).toList();
    final higher = ys.reduce((a, b) => a < b ? a : b);
    final lower = ys.reduce((a, b) => a > b ? a : b);
    return (higher <= minY + third && lower >= maxY - third)
        ? _TartessianLetter.bo
        : null;
  }

  /// Whether the whole stroke set forms **to** (`d / to`): exactly two strokes,
  /// each going up-and-down (its vertical-direction split has at least two
  /// segments — a `∧`/`V`, not a straight bar), that cross each other exactly
  /// twice. Ordered before [_classifyBi]: bi needs one stroke to be a straight
  /// vertical bar, whereas both of to's strokes reverse, so to claims the
  /// two-reversing-strokes case and never steals a real bi (whose bar has a
  /// single vertical segment).
  _TartessianLetter? _classifyTo() {
    if (_strokes.length != 2) return null;
    final a = _strokes[0];
    final b = _strokes[1];
    // Both strokes must reverse vertically (go up and down).
    if (_splitByDirectionChange(a, horizontal: false).length < 2) return null;
    if (_splitByDirectionChange(b, horizontal: false).length < 2) return null;
    // …and cross each other exactly twice.
    return _crossingCount(a, b) == 2 ? _TartessianLetter.to : null;
  }

  /// The number of ascending `/` lines when the whole scene is exactly two
  /// vertical bars crossed by some ascending lines — every non-vertical stroke
  /// an ascending line, each crossing both bars — or null otherwise. `bu` is
  /// three such lines, `te` two. Distinct from [_ladderRungCount], which wants
  /// one bar and horizontal rungs.
  int? _ladderAscendingCount() {
    if (_strokes.length < 4) return null;
    final verticals =
        _strokes.where((s) => _orientation(s) == _Orientation.vertical);
    if (verticals.length != 2) return null;
    final lines =
        _strokes.where((s) => _orientation(s) != _Orientation.vertical);
    if (lines.isEmpty) return null;
    for (final line in lines) {
      if (!_isAscendingLine(line)) return null;
      if (!verticals.every((v) => _strokesCross(line, v))) return null;
    }
    return lines.length;
  }

  /// Whether the whole stroke set forms **ri**: exactly three strokes — a [ka]
  /// peak (∧) plus a descending line crossing its up arm and an ascending line
  /// crossing its down arm. The two crossing lines are tried in both roles.
  _TartessianLetter? _classifyRi() {
    if (_strokes.length != 3) return null;
    for (var p = 0; p < 3; p++) {
      final peak = _strokes[p];
      if (!_isKaPeak(peak)) continue;
      final segments = _splitByDirectionChange(peak, horizontal: false);
      if (segments.length != 2) continue;
      // A ka peak goes up then down, so segment 0 is the up arm, 1 the down arm.
      final upArm = _Stroke(segments[0]);
      final downArm = _Stroke(segments[1]);
      final others = [for (var k = 0; k < 3; k++) if (k != p) _strokes[k]];
      final a = others[0];
      final b = others[1];
      final aOnUp = _isDescendingLine(a) &&
          _strokesCross(a, upArm) &&
          _isAscendingLine(b) &&
          _strokesCross(b, downArm);
      final bOnUp = _isDescendingLine(b) &&
          _strokesCross(b, upArm) &&
          _isAscendingLine(a) &&
          _strokesCross(a, downArm);
      if (aOnUp || bOnUp) return _TartessianLetter.ri;
    }
    return null;
  }

  /// Whether the whole stroke set forms **bi** (`b / pi`): exactly two strokes
  /// — a vertical bar crossed by a [ka] peak (∧) whose bounding-box center sits
  /// above the bar's. Ordered before [_classifyA]/[_classifyU] so the peak's
  /// crossing bar isn't first read as a plain ascending/descending line; a real
  /// `a`/`u` has no vertical-oriented stroke paired with a genuine peak.
  _TartessianLetter? _classifyBi() {
    if (_strokes.length != 2) return null;
    for (var i = 0; i < 2; i++) {
      final bar = _strokes[i];
      final peak = _strokes[1 - i];
      if (_orientation(bar) != _Orientation.vertical) continue;
      if (!_isKaPeak(peak)) continue;
      if (!_strokesCross(peak, bar)) continue;
      if (_centerOf(peak).dy < _centerOf(bar).dy) return _TartessianLetter.bi;
    }
    return null;
  }

  /// Whether the whole stroke set forms **ku** (`g / ku`): exactly two strokes
  /// — the [_isDagazBowtie] bowtie crossed by a vertical bar. Ordered before
  /// the plainer two-stroke crossings ([_classifyU] etc.), whose line/peak
  /// checks a bowtie could otherwise satisfy by endpoints.
  _TartessianLetter? _classifyKu() {
    if (_strokes.length != 2) return null;
    for (var i = 0; i < 2; i++) {
      final bowtie = _strokes[i];
      final bar = _strokes[1 - i];
      if (_isDagazBowtie(bowtie) &&
          _orientation(bar) == _Orientation.vertical &&
          _strokesCross(bowtie, bar)) {
        return _TartessianLetter.ku;
      }
    }
    return null;
  }

  /// Whether the whole stroke set forms **ki** (`g / ki`): the same
  /// loop-and-bar as [_classifyTi], but the vertical bar drops a long tail
  /// below the loop — at least a third of the bar's height sits below its lower
  /// crossing with the loop. Ordered before [_classifyTi], which claims the
  /// short-tailed remainder.
  _TartessianLetter? _classifyKi() {
    if (_strokes.length != 2) return null;
    for (var i = 0; i < 2; i++) {
      final loop = _strokes[i];
      final bar = _strokes[1 - i];
      if (!_isLoopThroughBar(loop, bar)) continue;
      final crossings = _crossingPoints(bar, loop);
      if (crossings.isEmpty) continue;
      var barTop = bar.points.first.dy, barBottom = barTop;
      for (final p in bar.points) {
        if (p.dy < barTop) barTop = p.dy;
        if (p.dy > barBottom) barBottom = p.dy;
      }
      var lowerCrossY = crossings.first.dy;
      for (final c in crossings) {
        if (c.dy > lowerCrossY) lowerCrossY = c.dy;
      }
      // "Below" is larger screen y; the tail beneath the lower crossing must be
      // at least a third of the bar's full height.
      if (barBottom - lowerCrossY >= (barBottom - barTop) / 3) {
        return _TartessianLetter.ki;
      }
    }
    return null;
  }

  /// Whether the whole stroke set forms **ti** (`d / ti`): exactly two strokes
  /// — an [e]-style self-crossing loop (one self-intersection) and a vertical
  /// bar that passes through it, crossing the loop exactly twice (entering and
  /// leaving). Either draw order is accepted. The loop's self-crossing keeps it
  /// clear of the plainer vertical crossings ([u]/[ke]/[ta], whose strokes
  /// never self-cross); ordered after [_classifyKu], whose bowtie self-crosses
  /// too, and after [_classifyKi], which claims the long-tailed variant.
  _TartessianLetter? _classifyTi() {
    if (_strokes.length != 2) return null;
    for (var i = 0; i < 2; i++) {
      final loop = _strokes[i];
      final bar = _strokes[1 - i];
      if (_isLoopThroughBar(loop, bar)) return _TartessianLetter.ti;
    }
    return null;
  }

  /// Whether [loop] is an [e]-style self-crossing loop (one self-intersection)
  /// and [bar] a vertical stroke that passes through it, crossing the loop
  /// exactly twice — the shape shared by [ti] and [ki].
  bool _isLoopThroughBar(_Stroke loop, _Stroke bar) =>
      _selfIntersections(loop) == 1 &&
      _orientation(bar) == _Orientation.vertical &&
      _crossingCount(bar, loop) == 2;

  /// The number of distinct places [a] crosses [b], scanning along [a] and
  /// deduplicating consecutive segments so one geometric crossing sampled
  /// across neighbouring points still counts once (the two-stroke analogue of
  /// [_selfIntersections]). Used by [_classifyTi] to require the bar to pass
  /// through the loop exactly twice.
  int _crossingCount(_Stroke a, _Stroke b) {
    var count = 0;
    var lastCrossing = -10;
    for (var i = 0; i < a.points.length - 1; i++) {
      var crossedHere = false;
      for (var j = 0; j < b.points.length - 1; j++) {
        if (_segmentsIntersect(
            a.points[i], a.points[i + 1], b.points[j], b.points[j + 1])) {
          crossedHere = true;
          break;
        }
      }
      if (crossedHere) {
        if (i - lastCrossing > 2) count++;
        lastCrossing = i;
      }
    }
    return count;
  }

  /// Every point where a segment of [a] meets a segment of [b]. Not
  /// deduplicated — dense sampling can yield several points per geometric
  /// crossing — so use it only for aggregates (e.g. the lowest crossing's y in
  /// [_classifyKi]), not to count crossings (use [_crossingCount] for that).
  List<Offset> _crossingPoints(_Stroke a, _Stroke b) {
    final points = <Offset>[];
    for (var i = 0; i < a.points.length - 1; i++) {
      for (var j = 0; j < b.points.length - 1; j++) {
        final p = _segmentIntersectionPoint(
            a.points[i], a.points[i + 1], b.points[j], b.points[j + 1]);
        if (p != null) points.add(p);
      }
    }
    return points;
  }

  /// The point where segment p1-p2 meets segment p3-p4, or null if they don't
  /// cross (or are parallel). The line-line intersection of the two segments,
  /// clamped to both by the 0..1 parameter tests.
  Offset? _segmentIntersectionPoint(Offset p1, Offset p2, Offset p3, Offset p4) {
    final r = p2 - p1;
    final s = p4 - p3;
    final denom = r.dx * s.dy - r.dy * s.dx;
    if (denom == 0) return null;
    final qp = p3 - p1;
    final t = (qp.dx * s.dy - qp.dy * s.dx) / denom;
    final u = (qp.dx * r.dy - qp.dy * r.dx) / denom;
    if (t < 0 || t > 1 || u < 0 || u > 1) return null;
    return p1 + r * t;
  }

  /// The number of horizontal "rung" strokes when the whole scene is exactly
  /// one vertical bar crossed by some horizontal lines (and nothing else), or
  /// null when the strokes aren't that ladder shape. `o` is two rungs, `sa`
  /// three.
  int? _ladderRungCount() {
    if (_strokes.length < 3) return null;
    final verticals =
        _strokes.where((s) => _orientation(s) == _Orientation.vertical);
    final horizontals =
        _strokes.where((s) => _orientation(s) == _Orientation.horizontal);
    // Exactly one vertical, and every other stroke a horizontal (no diagonals).
    if (verticals.length != 1) return null;
    if (verticals.length + horizontals.length != _strokes.length) return null;
    final bar = verticals.first;
    if (!horizontals.every((h) => _strokesCross(h, bar))) return null;
    return horizontals.length;
  }

  /// Whether any segment of [a] crosses any segment of [b].
  bool _strokesCross(_Stroke a, _Stroke b) {
    for (var i = 0; i < a.points.length - 1; i++) {
      for (var j = 0; j < b.points.length - 1; j++) {
        if (_segmentsIntersect(
            a.points[i], a.points[i + 1], b.points[j], b.points[j + 1])) {
          return true;
        }
      }
    }
    return false;
  }

  /// Classifies [stroke] as predominantly vertical, horizontal, or neither,
  /// from the aspect ratio of its bounding box. The dominant axis must lead
  /// the other by at least 1.5x, so a diagonal scrawl is [_Orientation.other]
  /// and won't be mistaken for a bar or a rung.
  _Orientation _orientation(_Stroke stroke) {
    var minX = stroke.points.first.dx, maxX = minX;
    var minY = stroke.points.first.dy, maxY = minY;
    for (final p in stroke.points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final width = maxX - minX;
    final height = maxY - minY;
    if (height > width * 1.5) return _Orientation.vertical;
    if (width > height * 1.5) return _Orientation.horizontal;
    return _Orientation.other;
  }

  /// The centre of [stroke]'s bounding box.
  Offset _centerOf(_Stroke stroke) {
    var minX = stroke.points.first.dx, maxX = minX;
    var minY = stroke.points.first.dy, maxY = minY;
    for (final p in stroke.points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Offset((minX + maxX) / 2, (minY + maxY) / 2);
  }

  /// The direction of each of [stroke]'s segments along one axis. With
  /// [horizontal] false the axis is vertical and `true` means down (screen y
  /// increases); with [horizontal] true the axis is horizontal and `true`
  /// means right (x increases). Consecutive segments always alternate, so the
  /// list is fully determined by its length and first element.
  List<bool> _directionSequence(_Stroke stroke, {required bool horizontal}) {
    double axis(Offset o) => horizontal ? o.dx : o.dy;
    return _splitByDirectionChange(stroke, horizontal: horizontal)
        .map((seg) => axis(seg.last) > axis(seg.first))
        .toList();
  }

  /// Splits [stroke] wherever its movement reverses along one axis — the
  /// horizontal axis (left vs right) when [horizontal], else the vertical axis
  /// (up vs down).
  List<List<Offset>> _splitByDirectionChange(_Stroke stroke,
      {required bool horizontal}) {
    final points = stroke.points;
    final segments = <List<Offset>>[];
    if (points.length < 2) return segments;

    double axis(Offset o) => horizontal ? o.dx : o.dy;
    var current = <Offset>[points[0]];
    bool? positive;
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final isPositive = axis(curr) > axis(prev);
      if (positive != null && isPositive != positive) {
        segments.add(current);
        current = <Offset>[prev];
      }
      current.add(curr);
      positive = isPositive;
    }
    segments.add(current);
    return segments;
  }

  /// How many times [stroke] crosses its own path — non-adjacent segments
  /// (index gap of at least two) that intersect, deduplicated so one real
  /// loop sampled across nearby points still counts once.
  int _selfIntersections(_Stroke stroke) {
    final points = stroke.points;
    var count = 0;
    var lastCrossing = -10;
    for (var i = 0; i < points.length - 1; i++) {
      for (var j = i + 2; j < points.length - 1; j++) {
        if (_segmentsIntersect(
            points[i], points[i + 1], points[j], points[j + 1])) {
          if (j - lastCrossing > 2) count++;
          lastCrossing = j;
        }
      }
    }
    return count;
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
      ..color = const Color(0xFF3A1E12)
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
                  text: recognized.sign,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                TextSpan(text: '  ("${recognized.sound}")'),
              ],
            )
          : const TextSpan(
              text: 'Draw a sign below to see it recognized',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

/// Builds the scene plus a direct reference to its [TartessianLayer], so the
/// hosting page can call [TartessianLayer.clear] from the Clear button.
(Scene, TartessianLayer) buildTartessianScene() {
  final layer = TartessianLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
