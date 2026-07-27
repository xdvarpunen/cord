import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/greek_letters.dart';
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
/// (see [GreekLayer._isCorner]). It's the one thing that tells the printed
/// right-angle shapes apart: Γ's elbow rides at the [topLeft], where the
/// corner that finishes a three-stroke Ε has it at the [bottomLeft], and Π's
/// arch is a [topLeft] and a [topRight] joined by one bar.
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
/// axis at a time: [up]/[down] when it's cut wherever it reverses vertically
/// ([GreekLayer._verticalLegs]), [left]/[right] when horizontally
/// ([GreekLayer._horizontalLegs]).
///
/// Consecutive legs always alternate, so a pattern is really just "how many
/// legs, starting which way" — but spelling it out is what makes Λ's up-down,
/// Μ's up-down-up-down and Σ's left-right-left-right read as the shapes they
/// are.
enum _Leg { up, down, left, right }

/// The letters the recognizer can identify. [GreekLayer.recognizedNames] is
/// kept in step so the page's legend mutes whatever isn't in here.
enum _GreekLetter {
  alpha('Α', 'α', 'alpha', 'a'),
  beta('Β', 'β', 'beta', 'b'),
  gamma('Γ', 'γ', 'gamma', 'g'),
  delta('Δ', 'δ', 'delta', 'd'),
  epsilon('Ε', 'ε', 'epsilon', 'e'),
  zeta('Ζ', 'ζ', 'zeta', 'z'),
  eta('Η', 'η', 'eta', 'ee'),
  theta('Θ', 'θ', 'theta', 'th'),
  iota('Ι', 'ι', 'iota', 'i'),
  kappa('Κ', 'κ', 'kappa', 'k'),
  lambda('Λ', 'λ', 'lambda', 'l'),
  mu('Μ', 'μ', 'mu', 'm'),
  nu('Ν', 'ν', 'nu', 'n'),
  xi('Ξ', 'ξ', 'xi', 'ks'),
  omicron('Ο', 'ο', 'omicron', 'o'),
  pi('Π', 'π', 'pi', 'p'),
  rho('Ρ', 'ρ', 'rho', 'r'),
  sigma('Σ', 'σ', 'sigma', 's'),
  tau('Τ', 'τ', 'tau', 't'),
  upsilon('Υ', 'υ', 'upsilon', 'u'),
  phi('Φ', 'φ', 'phi', 'ph'),
  chi('Χ', 'χ', 'chi', 'kh'),
  psi('Ψ', 'ψ', 'psi', 'ps'),
  omega('Ω', 'ω', 'omega', 'oh'),

  // The two archaic letters, which cost no shape of their own: a digamma is
  // drawn exactly as an F is — the stem and top two bars of an Ε — and a koppa
  // is an Ο with a stem hung under it.
  digamma('Ϝ', 'ϝ', 'digamma', 'w'),
  koppa('Ϙ', 'ϙ', 'koppa', 'k');

  const _GreekLetter(this.capital, this.small, this.letterName, this.sound);

  final String capital;
  final String small;
  final String letterName;
  final String sound;
}

/// Freehand recognition of printed (block) Greek capitals — all 24 of Α–Ω, and
/// the archaic Ϝ and Ϙ besides:
///
/// - **Α** (alpha) — two strokes: a stroke that rises then falls (Λ, the
///   letter's two splayed legs), and a horizontal bar crossing each of those
///   legs exactly once (see [GreekLayer._classifyAlpha]).
/// - **Β** (beta) — two strokes: an upright stem standing to the left, and a
///   right-left-right-left stroke laid against it — the two bowls, each joining
///   the stem at both ends — meeting it 3 or 4 times (see
///   [GreekLayer._classifyBeta]).
/// - **Γ** (gamma) — a right-angle corner with a horizontal top bar and a
///   vertical leg hanging off its *left* end, i.e. the elbow at the top-left.
///   Drawn either as one bent stroke (see [GreekLayer._classifyGamma] /
///   [GreekLayer._isCorner]) or as a separate bar and leg (see
///   [GreekLayer._classifyGammaTwoStroke]).
/// - **Δ** (delta) — two strokes: Λ's own rise and fall, and a straight base
///   **closing** it into a triangle, its two ends landing on the Λ's two feet
///   (see [GreekLayer._classifyDelta]). That is the whole of what tells it from
///   Α, whose bar crosses the legs partway up instead.
/// - **Ε** (epsilon) — four strokes: an upright stem standing to the left, and
///   three horizontal bars meeting it once each — one up at its top, one across
///   its middle, one down at its foot. Or three, the stem and bottom bar drawn
///   as one bottom-left corner with the other two bars on it (see
///   [GreekLayer._classifyEpsilon]).
/// - **Ζ** (zeta) — one stroke of three legs to and fro with the diagonal
///   between them leaning `/` — the top bar, the diagonal, then the bottom bar
///   — crossing nothing at all (see [GreekLayer._classifyZeta]).
/// - **Η** (eta) — three strokes: two upright stems and a horizontal bar
///   crossing each of them once, the two crossings on opposite sides of the
///   bar's own centre and both **below** the stems' top quarter (see
///   [GreekLayer._classifyEta]). Where along the stems the bar lands is what
///   separates it from a three-stroke Π.
/// - **Θ** (theta) — two strokes: an Ο's ring with a horizontal bar run through
///   its middle, crossing it once on each side (see
///   [GreekLayer._classifyTheta]).
/// - **Ι** (iota) — one stroke: a plain upright line, crossing nothing at all
///   (see [GreekLayer._classifyIota]). The loosest shape here by a wide margin,
///   and last of all in [GreekLayer._classify] for it.
/// - **Κ** (kappa) — two strokes: an upright stem, and an arm running left and
///   then right — in to meet the stem, then away again — hanging off the stem's
///   right and crossing it once or twice (see [GreekLayer._classifyKappa]).
/// - **Λ** (lambda) — one stroke that rises then falls, crossing nothing: Α's
///   own Λ standing on its own, without the bar (see
///   [GreekLayer._classifyLambda]). Cyrillic Л is read exactly this way, and is
///   where this one comes from.
/// - **Μ** (mu) — one stroke that rises, falls, rises and falls again — the two
///   peaks and the valley between them — crossing nothing, its own path
///   included (see [GreekLayer._classifyMu]).
/// - **Ν** (nu) — one stroke of three vertical legs, its outer two upright
///   stems and the one between them a diagonal that *falls* to the right,
///   crossing nothing at all (see [GreekLayer._classifyNu]).
/// - **Ξ** (xi) — three horizontal bars stacked clear of one another and of
///   everything else on the page (see [GreekLayer._classifyXi]). Standing free
///   is what tells them from Ε's three, which all meet a stem.
/// - **Ο** (omicron) — one stroke that crosses its own path exactly once — a
///   closed loop — and crosses nothing else (see
///   [GreekLayer._classifyOmicron]).
/// - **Π** (pi) — one stroke bent into two squared corners sharing a top bar: a
///   Γ's elbow joined to its mirror, so the bar runs across the top and a leg
///   hangs down from either end of it (see [GreekLayer._classifyPi] /
///   [GreekLayer._isArch]). Or three strokes, that same bar with the two legs
///   drawn separately (see [GreekLayer._classifyPiThreeStroke]).
/// - **Ρ** (rho) — two strokes: an upright stem and a bowl running right then
///   back left that crosses it twice, the stem standing clear **below** the bowl
///   but not above it (see [GreekLayer._classifyRho]).
/// - **Σ** (sigma) — one stroke of four legs to and fro — in along the top bar,
///   out to the fold, back in, out along the bottom bar — crossing nothing at
///   all (see [GreekLayer._classifySigma]). It is Β's pair of bowls **mirrored**,
///   and the mirroring is what keeps the two apart.
/// - **Τ** (tau) — two strokes: a horizontal bar with an upright stem hanging
///   below its *middle* ([GreekLayer._junctionSnap], see
///   [GreekLayer._classifyTau]).
/// - **Υ** (upsilon) — two strokes: a V — one stroke falling then rising — with
///   an upright stem hanging **below** its vertex (see
///   [GreekLayer._classifyUpsilon]).
/// - **Φ** (phi) — two strokes: an Ο's ring, run through by an upright stem
///   that crosses it twice and stands clear above it and below (see
///   [GreekLayer._classifyPhi]).
/// - **Χ** (chi) — two strokes crossing once, one rising to the right and one
///   falling, read off their endpoints alone (see
///   [GreekLayer._classifyChi]).
/// - **Ψ** (psi) — Υ's own two strokes, with the stem carried on **up past** the
///   V's vertex instead of stopping at it (see [GreekLayer._classifyPsi]).
/// - **Ω** (omega) — one stroke rising and falling like a Λ, but bowed, and
///   finished at each end by a flat foot turning **outward** (see
///   [GreekLayer._classifyOmega] / [GreekLayer._hasFeet]). Those two feet are
///   the whole of what makes it a horseshoe rather than a Λ.
/// - **Ϝ** (digamma) — three strokes: an upright stem standing on the left of
///   the letter, with two arms off its right, one meeting it in its top third
///   and one across its middle. An arm is a flat bar or a **ㄱ**, out to the
///   right and then hooking down (see [GreekLayer._classifyDigamma] /
///   [GreekLayer._isDigammaArm]). Ε's own shape with the bottom bar left off,
///   and the letter Latin took its F from.
/// - **Ϙ** (koppa) — two strokes: an Ο's ring with an upright stem hung under
///   it, meeting it at its foot and hanging clear below (see
///   [GreekLayer._classifyKoppa]).
///
/// Stroke direction is deliberately not checked, and neither is stroke order. A
/// Γ written top-right → left → down and one written bottom-left → up → right
/// are the same letter to any reader, so the shape tests work off where a
/// stroke's ends and turns land rather than off which way the hand travelled;
/// Ε's four strokes, Η's and Ξ's and Ϝ's three, and Α's, Β's, Δ's, Θ's, Κ's,
/// Ρ's, Τ's, Υ's, Φ's, Χ's and Ψ's two all sort themselves by their own shape
/// rather than by when they arrived, and Ο doesn't care which way round the
/// loop was swept.
///
/// **Fourteen of these letters are read by Latin's own classifiers**, carried
/// over from the sibling `latin` project because they *are* the same shape: Α
/// from A, Β from B, Ε from E, Ζ from Z, Η from H, Ι from I, Κ from K, Μ from M,
/// Ν from N, Ο from O, Ρ from P, Τ from T, Υ from Y and Χ from X. That is no
/// coincidence — Latin took them from here. Five more come from `cyrillic`,
/// which took them from here too: Γ is Г, Λ is Л, Π is П, Φ is Ф, and Δ is Д's
/// arrangement with the base's feet taken off. So when a shape test changes in
/// one of the three projects it is worth checking the others.
///
/// Α, Λ, Μ, Ν, Υ, Ψ and Ω are all read off the same primitive — cut the stroke
/// wherever it reverses along one axis and look at the run of legs that leaves
/// ([GreekLayer._verticalLegs]) — and differ only in their pattern and in what
/// is asked of the legs: up-down for Α's and Λ's and Ω's rise and fall, down-up
/// for Υ's and Ψ's V, up-down-up-down for Μ's two peaks, and three alternating
/// legs for Ν. Β, Ζ, Κ, Ρ and Σ cut the same way horizontally instead
/// ([GreekLayer._horizontalLegs]), which is why any of them can be a curly shape
/// and still be read off a run of legs: right-left-right-left for Β's pair of
/// bowls, that same run mirrored for Σ's pair of folds, right-left for Ρ's
/// single bowl, left-right for Κ's arm.
///
/// The three-leg shapes — Ζ, and Ν's own — are the exception, and can't be
/// spelled out that way at all. Reversing a stroke reverses the order of its
/// legs *and* flips each one's direction, and on an odd number of legs those two
/// don't cancel: a Ζ drawn bottom-up leaves exactly the run of legs an S drawn
/// top-down leaves. So [GreekLayer._isThreeLegged] asks instead which way the
/// middle leg *leans*, reading it as a line rather than as a direction.
///
/// Where a run of legs leaves two shapes alike, a second measurement divides
/// them, and it is always the same kind: locate the crossings and ask where
/// along the stem they land. Ε and Ϝ divide the stem's thirds between them,
/// three bars against two; Η and a three-stroke Π divide it by whether the bar
/// lands at the stems' tops or across their middles; Ρ asks whether the stem
/// stands clear of its bowl at each end. Which is why
/// [GreekLayer._bowlCrossings] hands back measurements rather than a verdict.
///
/// Two strokes meeting and one stroke crossing itself are counted differently on
/// purpose. Τ's stem running into its bar is a T-junction — whether the pen
/// overshoots by a pixel or stops a pixel short is noise, so
/// [GreekLayer._contacts] counts runs of near-contact
/// ([GreekLayer._touchTolerance]). A loop genuinely crosses its own path, so
/// [GreekLayer._selfIntersections] counts real segment intersections and an
/// unclosed circle is correctly not an Ο.
///
/// Recognition is live and non-destructive — it re-reads the most recently
/// completed stroke(s) after every stroke, and everything drawn stays on the
/// page whether or not it matched.
class GreekLayer extends Layer {
  /// How far the pen must get from where it went down for the stroke to count as
  /// a deliberate one rather than a slipped tap. Nothing here is built from taps
  /// — no Greek capital in these three alphabets carries a dot — so a
  /// press-and-release that never gets this far simply leaves no mark. (The
  /// tonos and the dialytika will want taps back; see TODO.md, and `cyrillic`
  /// and `latin` both still capture them.)
  ///
  /// Measured as the **furthest** any point of the stroke reaches from its
  /// start, not as the distance from its start to its end. That difference
  /// matters here in a way it doesn't in the sibling projects: a closed shape
  /// finishes where it began, so its start-to-end distance is *zero*. Read that
  /// way, a Δ rounded in one stroke and closed at the corner — and an Ο closed
  /// exactly rather than overshot — were thrown away whole, as slipped taps,
  /// before any classifier saw them. Nothing was drawn and nothing was reported,
  /// which is the most confusing failure a drawing app has.
  static const double _minDragDistance = 8;

  /// How much taller than wide a stroke must be to read as vertical. A plain
  /// `|dy| > |dx|` would accept a 45°-ish diagonal, which belongs to a
  /// different letter (Λ's own splayed legs, for one).
  static const double _verticalRatio = 2;

  /// The same margin the other way round. Deliberately equal to
  /// [_verticalRatio]: a line slanted enough to be ambiguous should match
  /// neither orientation, rather than falling to whichever check happens to run
  /// first.
  static const double _horizontalRatio = 2;

  /// How far a stroke may bow off its own straight start-to-end chord and still
  /// read as a straight line: the larger of [_minStraightSlack] and this
  /// fraction of the chord's length. It's what keeps a curve or a hook from
  /// passing for Ε's stem or one of its bars.
  static const double _straightTolerance = 0.12;
  static const double _minStraightSlack = 6;

  /// How close two strokes must come to count as touching (see [_touches]). Τ's
  /// stem meets its bar in a junction rather than a crossing, so a strict
  /// segment-intersection test would turn on whether the hand happened to
  /// overshoot by a pixel — a stem stopping just short of the bar is the same
  /// letter to any reader. It is also what closes Δ's triangle: the base's ends
  /// have to arrive at the Λ's feet, not through them.
  static const double _touchTolerance = 22;

  /// Where along the bar Τ's stem may hang and still count as hanging from its
  /// middle, as a distance from the bar's centre given as a fraction of the
  /// bar's width (see [_classifyTau]). This one number also hands the bar's left
  /// quarter to a two-stroke Γ, whose leg drops from that end instead — the two
  /// letters are the same pair of strokes and this is what divides them.
  static const double _junctionSnap = 0.25;

  /// The least a corner's bounding box may span on each axis. Below this the
  /// "corner" is really a near-horizontal or near-vertical kink, where which box
  /// corner the elbow sits in is noise.
  static const double _minCornerLeg = 15;

  /// How far the elbow may sit from its bounding-box corner, as a fraction of
  /// the box, and still commit to that corner. Two axis-aligned legs put the
  /// elbow *at* the corner, so this only absorbs the rounding of a hand-drawn
  /// bend — it's not enough slack to let a top-left elbow pass for a bottom-left
  /// one. It's also what rejects a smooth quarter arc bending Γ's way, whose
  /// deepest point sits a quarter of the way along the box rather than in its
  /// corner: a bend has to actually be squared off to read as a letter.
  static const double _cornerSnap = 0.2;

  /// How much of a stem must stand clear of a bowl, or a bar fall short of the
  /// stem's top, to count as being at one end rather than across the middle — a
  /// quarter of the stem's own height.
  ///
  /// It does two jobs, and they are the same job. It is what makes Ρ a Ρ: the
  /// bowl sits at the top, the stem sticking out below it and not above. And it
  /// is what divides Η from a three-stroke Π, which are the same three strokes —
  /// a bar and two stems — arranged the same way: Π's bar lands in the stems'
  /// top quarter, Η's across their middles. A partition, so neither can claim
  /// the other's drawing and their order in [_classify] doesn't matter.
  static const double _outerQuarter = 0.25;

  /// How far a stroke must double back vertically before that counts as
  /// changing direction rather than as the hand wobbling (see [_verticalLegs]).
  /// Without it every tremor along a long stem would split off a leg of its own,
  /// and Λ's two legs would come out as a dozen.
  static const double _directionSlack = 6;

  /// How far one stroke must sit clear of another to count as being on its left
  /// or its right. A bowl centred on a stem is a different shape (that is a Φ,
  /// not a Ρ), so it should match nothing rather than fall through on whichever
  /// side happened to win by a pixel.
  static const double _minSideOffset = 6;

  /// How much of Ω's own path, measured back from each end, is read as its foot
  /// (see [_hasFeet]). Long enough that a hand's flick reads as flat, short
  /// enough that it is still the foot and not the bowl above it.
  static const double _footRun = 18;

  /// Which letters may be reported, matched against [LetterRow.name]. Kept in
  /// step with [_GreekLetter] — used by [GreekPage] to mute the letters an
  /// alphabet lists but the recognizer can't draw.
  ///
  /// Every letter of all three alphabets is here, so nothing in any legend is
  /// muted. The set is kept rather than dropped so a letter can be taken back
  /// out, or a new one staged, without the page having to change.
  static const recognizedNames = {
    'alpha', 'beta', 'gamma', 'delta', 'epsilon', 'zeta', 'eta', 'theta',
    'iota', 'kappa', 'lambda', 'mu', 'nu', 'xi', 'omicron', 'pi', 'rho',
    'sigma', 'tau', 'upsilon', 'phi', 'chi', 'psi', 'omega',
    'digamma', 'koppa',
  };

  final List<_Stroke> _strokes = [];
  _GreekLetter? _recognized;
  List<Offset>? _activePoints;
  Alphabet _alphabet = Alphabet.greek;

  /// Which alphabet's letters may be reported. The shape tests are the same
  /// either way — this only decides which of their answers counts, so a drawing
  /// the chosen alphabet has no letter for falls through to whatever the next
  /// classifier makes of it (see [_classify]).
  ///
  /// Setting it re-reads whatever is already on the page, so switching
  /// mid-drawing settles the readout there and then rather than waiting for
  /// another stroke.
  Alphabet get alphabet => _alphabet;

  set alphabet(Alphabet value) {
    if (value == _alphabet) return;
    _alphabet = value;
    if (_strokes.isNotEmpty) _recognized = _classify();
  }

  /// The capital currently being reported, or null if the drawing matches no
  /// letter. The letters themselves are private ([_GreekLetter]); this exposes
  /// just enough of the result for tests to assert on what a given sequence of
  /// strokes recognizes as.
  String? get recognizedGlyph => _recognized?.capital;

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
      if (points.length >= 2 && _reach(points) >= _minDragDistance) {
        _commit(_Stroke(points));
      }
      _activePoints = null;
    }
  }

  /// The furthest [points] gets from where it started — how far the pen actually
  /// reached, which is what [_minDragDistance] is asking about. See the note
  /// there for why the distance from the first point to the *last* one won't do.
  double _reach(List<Offset> points) {
    var furthest = 0.0;
    for (final point in points) {
      furthest = math.max(furthest, (point - points.first).distance);
    }
    return furthest;
  }

  void _commit(_Stroke stroke) {
    _strokes.add(stroke);
    _recognized = _classify();
  }

  /// Recognizes the current [_strokes] as one letter, most-strokes-first so a
  /// finished letter isn't reported as the simpler shape it contains.
  ///
  /// Only ever called from [_commit], with the just-drawn stroke already
  /// appended — which is what lets the single-stroke classifiers read
  /// [_strokes.last] outright.
  ///
  /// A letter the current [alphabet] hasn't got is passed over rather than
  /// returned, and the next classifier gets its turn on the same drawing — so in
  /// [Alphabet.oldAttic], which has no Ω, an omega's own stroke falls through to
  /// the Λ that shares its rise and fall, and Athens before 403 BC would have
  /// written an Ο for the sound anyway.
  ///
  /// Ο and Ι come last, in that order, and have to. Ο asks for nothing but a
  /// single self-crossing, and a one-stroke letter picks one of those up
  /// whenever the hand closes a join it didn't have to. Ι is looser again — a
  /// bare upright, which is the *first* stroke of Β, Ε, Η, Κ, Ρ, Τ, Φ, Ψ and Ϝ
  /// alike. So every letter with a shape of its own gets first refusal, then Ο,
  /// then Ι. A new classifier goes above them, never below.
  _GreekLetter? _classify() {
    if (_strokes.isEmpty) return null;
    for (final classifier in [
      // Four strokes, or three.
      _classifyEpsilon,
      // Ahead of Ι and of Τ, both of which Ε's own pieces would otherwise answer
      // on the way. Ϝ is Ε's stem and Ε's top two bars, so drawing an Ε reads as
      // a digamma on its third stroke and settles on Ε with its fourth — which
      // is the live readout doing its job, not a clash. (In the Greek and Old
      // Attic alphabets, which have no Ϝ, it reads as nothing until the fourth
      // bar lands.)
      _classifyDigamma,
      // Η and a three-stroke Π are the same bar and two stems, and partition
      // each other on where the bar lands along them (see [_outerQuarter]), so
      // their order between themselves doesn't matter.
      _classifyEta,
      _classifyPiThreeStroke,
      // Three bars standing free. Ahead of nothing in particular — Ε's three
      // bars all meet a stem, and these must touch nothing at all.
      _classifyXi,
      // Two strokes. Β's pair of bowls arrives as one four-leg stroke and Ρ's
      // single bowl as a two-leg one, so neither can claim the other.
      _classifyBeta,
      _classifyRho,
      // Both a ring with a stem: Φ's runs through the ring and out at both ends,
      // Ϙ's hangs under it. Disjoint, and Φ is asked first as the tighter claim.
      _classifyPhi,
      _classifyKoppa,
      _classifyTheta,
      _classifyKappa,
      // Ahead of Α, whose bar its base answers: a Δ closed at the feet crosses
      // each leg exactly once too, and only *where* says otherwise.
      _classifyDelta,
      _classifyAlpha,
      // Ahead of Υ, which is this very pair with the stem stopping at the
      // vertex instead of carrying on past it.
      _classifyPsi,
      _classifyUpsilon,
      _classifyTau,
      _classifyGammaTwoStroke,
      // After Τ, which it would otherwise claim: no hand draws a bar exactly
      // level or a stem exactly plumb, and a pair leaning by a pixel each reads
      // as two opposite slants that cross. It's the loosest of the two-stroke
      // shapes and sits last among them for that reason.
      _classifyChi,
      // One stroke. Μ and Σ need no ordering between them, nor against anything
      // else here: four alternating legs read vertically is the one, four read
      // horizontally is the other, and nothing else has four.
      _classifyMu,
      _classifySigma,
      _classifyNu,
      // A Δ drawn without lifting the pen.
      //
      // **Before Ο, and that is what keeps Ο simple.** A closed triangle crosses
      // its own path exactly as a ring does — being a closed shape is the one
      // thing the two have in common — so if Ο were asked first it would take
      // every one-stroke Δ on the page. Asked in this order, Ο needs to know
      // nothing about triangles: a stroke that closes on itself and that nothing
      // above has claimed is an Ο, full stop.
      //
      // Before Ω as well: a triangle finished along its base leaves a flat
      // terminal running outward at either end, which is exactly what _hasFeet
      // reads.
      _classifyDeltaOneStroke,
      // Ahead of Λ and of Π, both of which are a stroke rising and falling with
      // its two ends below its middle. Ω's feet are the whole difference, and
      // asking for them is the most particular claim of the three.
      _classifyOmega,
      _classifyPi,
      _classifyGamma,
      _classifyZeta,
      // Loose: the rise and fall with nothing else asked of it, which is what Α
      // and Δ and Ω are all built on. After every one of them.
      _classifyLambda,
      // Looser than anything above, and in this order between themselves — see
      // the note on this method.
      _classifyOmicron,
      _classifyIota,
    ]) {
      final letter = classifier();
      if (letter != null && _alphabet.letters.contains(letter.capital)) {
        return letter;
      }
    }
    return null;
  }

  // ── Α, Δ, Λ: the rise and fall, and what is hung on it ──────────────────────

  /// Whether the last two strokes form Α: a stroke that rises then falls — Λ,
  /// the letter's two splayed legs — plus a straight horizontal bar crossing
  /// each of those legs exactly once. Checking the two legs separately rather
  /// than counting two crossings against the whole Λ is what rules out a bar
  /// that clips one leg twice and misses the other. Either stroke order.
  _GreekLetter? _classifyAlpha() {
    final pair = _apexAndBar();
    if (pair == null) return null;
    for (final leg in _verticalLegs(pair.apex)) {
      if (_crossings(pair.bar, leg) != 1) return null;
    }
    return _GreekLetter.alpha;
  }

  /// Whether the last two strokes form Δ: the same Λ and the same straight bar,
  /// but with the bar **closing** the shape into a triangle — **both of the Λ's
  /// feet landing on the base**, within [_touchTolerance] of it.
  ///
  /// That is the whole of what separates Δ from Α, and it has to be asked by
  /// where the strokes *meet* rather than by counting crossings. A base drawn
  /// foot to foot meets each leg at its very end, which is one crossing per leg
  /// — exactly what [_classifyAlpha] asks for — so counting would call every Δ
  /// an Α. Α's bar crosses the legs partway up, well clear of the feet; Δ's runs
  /// under them.
  ///
  /// **The question is asked of the feet, not of the base's ends**, and that is
  /// the second thing this had to get right. Asking the base's two terminals to
  /// land near the Λ's two terminals reads a Δ drawn to size and nothing else: a
  /// hand very often runs the base out past both corners, and then its ends are
  /// nowhere near the feet while the letter is perfectly good. Measured this way
  /// round the overshoot costs nothing — a base that runs past the feet still
  /// passes under them — and a base drawn a little short or a little low or
  /// slightly sloped is fine too. Turning it round fixed four ways of drawing a
  /// Δ that used to read as **Α** or as nothing at all.
  ///
  /// Proximity rather than intersection for the same reason: a base laid a
  /// couple of pixels below the feet crosses neither leg, and is the same
  /// letter.
  ///
  /// What it gives away is that an Α with its bar dropped to within
  /// [_touchTolerance] of the feet reads as Δ. That drawing is a triangle, so
  /// this is the right answer rather than a cost.
  ///
  /// Ahead of Α in [_classify] for the reason above. Either stroke order.
  ///
  /// Two strokes. For a Δ drawn without lifting the pen see
  /// [_classifyDeltaOneStroke].
  _GreekLetter? _classifyDelta() {
    final pair = _apexAndBar();
    if (pair == null) return null;
    for (final foot in [pair.apex.start, pair.apex.end]) {
      if (_distanceTo(foot, pair.bar) > _touchTolerance) return null;
    }
    return _GreekLetter.delta;
  }

  /// Whether the last stroke is a Δ drawn without lifting the pen: round the
  /// triangle in one go.
  ///
  /// Three measurements, and between them they say "triangle" without ever
  /// having to decide whether the hand closed the shape:
  ///
  /// 1. **Two vertical legs, up then down** — up one side to the apex and down
  ///    the other. The base is flat and adds no vertical leg of its own.
  /// 2. **Two horizontal legs** — out along two sides that lean the same way,
  ///    then back along the third.
  /// 3. **The horizontal reversal sits in the bottom quarter** of the stroke's
  ///    own box ([_outerQuarter]) — it is a corner of the base.
  ///
  /// The third is the whole of what separates a triangle from a **circle**, and
  /// it is worth saying why it is measured against the bottom quarter rather
  /// than against the middle. A circle rounded in one stroke also gives two
  /// vertical legs and two horizontal ones; what it doesn't give is a horizontal
  /// extreme down at the foot. A circle's leftmost and rightmost points sit at
  /// exactly its own vertical middle — so "below the middle" is a knife-edge
  /// that a hand's wobble decides, where "in the bottom quarter" leaves both
  /// shapes room. A triangle's reversal lands at very nearly 1.0.
  ///
  /// **The run of legs is not asked about, only counted**, and that is not
  /// laziness. Going round a triangle clockwise gives right-left; going round it
  /// anticlockwise gives left-right. Both are the same letter, and on two legs
  /// the pattern is preserved under reversal, so it genuinely records which way
  /// round the hand went and nothing else. (Compare [_isThreeLegged], where an
  /// odd count makes the pattern say *less* than it appears to.)
  ///
  /// Crossing itself is allowed — a closed triangle does, exactly as a ring
  /// does — but crossing another stroke isn't.
  ///
  /// It sits above Ω and Λ in [_classify], and above Ο. Λ and Ω both want the
  /// same rise and fall; and a triangle finished along its base leaves a flat
  /// terminal running outward at each end, which is [_hasFeet]'s whole test, so
  /// without this a one-stroke Δ read as **Ω**.
  _GreekLetter? _classifyDeltaOneStroke() {
    final stroke = _strokes.last;
    if (!_hasLegs(stroke, const [_Leg.up, _Leg.down])) return null;
    if (_crossesAnotherStroke(stroke)) return null;
    final legs = _horizontalLegs(stroke);
    if (legs.length != 2) return null;

    final bounds = _boundsOf(stroke.points);
    if (bounds.height == 0) return null;
    // Where the stroke turns back on itself horizontally — a corner of the base.
    final turn = legs.first.end;
    final along = (turn.dy - bounds.top) / bounds.height;
    return along > 1 - _outerQuarter ? _GreekLetter.delta : null;
  }

  /// The last two strokes sorted into a Λ and a straight bar, or null if they
  /// are not that pair — what Α and Δ are both built on, and the reason they can
  /// be told apart by one question afterwards. Either stroke order.
  ({_Stroke apex, _Stroke bar})? _apexAndBar() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    if (_isBar(a) && _hasLegs(b, const [_Leg.up, _Leg.down])) {
      return (apex: b, bar: a);
    }
    if (_isBar(b) && _hasLegs(a, const [_Leg.up, _Leg.down])) {
      return (apex: a, bar: b);
    }
    return null;
  }

  /// Whether the last stroke is Λ: one stroke rising then falling, and crossing
  /// no other stroke on the page — Α's own Λ standing on its own, without the
  /// bar.
  ///
  /// Cyrillic Л is read by this very test, and this is where it came from: Л is
  /// a Greek lambda that grew a foot in print and kept the same gesture in hand.
  ///
  /// A loose test, and deliberately so: it's the same rise and fall Α asks of
  /// its legs, with only the bar taken away. It sits after Α, Δ, Ω and Π in
  /// [_classify] for that reason, all four being that stroke with something more
  /// asked of it.
  _GreekLetter? _classifyLambda() =>
      _hasLegs(_strokes.last, const [_Leg.up, _Leg.down]) &&
              !_crossesAnotherStroke(_strokes.last)
          ? _GreekLetter.lambda
          : null;

  /// Whether the last stroke is Ω: the rise and fall Λ is read from, finished at
  /// each end by a flat foot turning outward ([_hasFeet]), and crossing nothing.
  ///
  /// The feet are the whole letter. Everything else about an Ω agrees with a Λ —
  /// one stroke, up then down, both ends below its own middle — and a bowed Λ is
  /// still a Λ. What a horseshoe has that a Λ hasn't is that it narrows below
  /// the bowl and then splays out again, and the cheapest place to read that is
  /// at the two terminals: an Ω ends flat and outward where a Λ ends steep.
  ///
  /// Ahead of Λ in [_classify], and ahead of Π, whose arch is the same rise and
  /// fall squared off instead of bowed.
  _GreekLetter? _classifyOmega() =>
      _hasLegs(_strokes.last, const [_Leg.up, _Leg.down]) &&
              _crossesNothing(_strokes.last) &&
              _hasFeet(_strokes.last)
          ? _GreekLetter.omega
          : null;

  /// Whether [s] finishes at both ends in a flat foot turning outward — Ω's two
  /// feet, and nothing else here has them.
  ///
  /// Each foot is the last [_footRun] of path measured back from a terminal. It
  /// has to run flat ([_isHorizontal]) and it has to run *outward*: the terminal
  /// itself further from the stroke's own vertical centre line than the point
  /// where the foot joins the bowl above it. Both terminals must also sit in the
  /// lower half of the stroke's box, so a shape with its feet in the air is not
  /// one of these.
  ///
  /// Measuring outward-ness against the joint rather than against the bowl's
  /// widest point is what makes this cheap and robust. The letter's real
  /// signature is a waist — narrow below the bowl, wide again at the ground —
  /// and the foot is exactly the piece that crosses from one to the other.
  bool _hasFeet(_Stroke s) {
    final bounds = _boundsOf(s.points);
    final middle = bounds.center.dy;
    if (s.start.dy <= middle || s.end.dy <= middle) return false;

    final centre = bounds.center.dx;
    for (final fromStart in const [true, false]) {
      final foot = _terminalPiece(s, fromStart: fromStart);
      if (foot == null || !_isHorizontal(foot)) return false;
      final tip = foot.start;
      final joint = foot.end;
      if ((tip.dx - centre).abs() <=
          (joint.dx - centre).abs() + _minSideOffset) {
        return false;
      }
    }
    return true;
  }

  /// The last [_footRun] of [s]'s own path, measured back from one of its
  /// terminals — or null if the whole stroke is shorter than that.
  ///
  /// The piece is returned terminal-first, so [_Stroke.start] is the tip and
  /// [_Stroke.end] is where it joins the rest of the stroke, whichever end of
  /// the drawing it came from.
  _Stroke? _terminalPiece(_Stroke s, {required bool fromStart}) {
    final points = fromStart ? s.points : s.points.reversed.toList();
    final piece = <Offset>[points.first];
    var run = 0.0;
    for (var i = 1; i < points.length; i++) {
      run += (points[i] - points[i - 1]).distance;
      piece.add(points[i]);
      if (run >= _footRun) return _Stroke(piece);
    }
    return null;
  }

  // ── Γ and Π: the squared corners ────────────────────────────────────────────

  /// Whether the last stroke is a one-stroke Γ: a single right-angle bend with
  /// its elbow at the top-left, so the bar runs right from it and the leg drops
  /// down from it (see [_isCorner]).
  ///
  /// Cyrillic Г is read by this very test. Both are the same letter, and this is
  /// the older of the two.
  _GreekLetter? _classifyGamma() =>
      _isCorner(_strokes.last, elbow: _Corner.topLeft)
          ? _GreekLetter.gamma
          : null;

  /// Whether the last two strokes are a two-stroke Γ: a horizontal bar and a
  /// vertical leg that touch, with the leg hanging off the bar's **left** end
  /// ([_junctionSnap]) and dropping below it — the same elbow-at-the-top-left
  /// shape [_classifyGamma] looks for, with the pen lifted between the two legs.
  /// Either stroke order.
  ///
  /// This and [_classifyTau] are the same two strokes measured the same way, and
  /// they divide the bar between them: a leg in its left quarter is a Γ, one in
  /// its middle half is a Τ. The remaining quarter is that corner mirrored and
  /// belongs to neither, which is why the band is stated as a distance from the
  /// bar's centre rather than as "not Γ's end".
  _GreekLetter? _classifyGammaTwoStroke() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke bar;
    final _Stroke leg;
    if (_isBar(a) && _isStem(b)) {
      bar = a;
      leg = b;
    } else if (_isBar(b) && _isStem(a)) {
      bar = b;
      leg = a;
    } else {
      return null;
    }
    if (!_touches(bar, leg)) return null;

    final barBounds = _boundsOf(bar.points);
    final legBounds = _boundsOf(leg.points);
    if (legBounds.center.dx > barBounds.left + barBounds.width * _junctionSnap) {
      return null;
    }
    return legBounds.center.dy > barBounds.center.dy + _minSideOffset
        ? _GreekLetter.gamma
        : null;
  }

  /// Whether the last stroke is a one-stroke Π: an arch — two squared corners
  /// sharing a top bar ([_isArch]) — crossing no other stroke on the page.
  ///
  /// Cyrillic П is read by this very test.
  _GreekLetter? _classifyPi() =>
      _isArch(_strokes.last) && !_crossesAnotherStroke(_strokes.last)
          ? _GreekLetter.pi
          : null;

  /// Whether the last three strokes are a three-stroke Π: that same top bar with
  /// its two legs drawn separately — a horizontal bar and two upright stems,
  /// each meeting the bar in its own **top quarter** ([_outerQuarter]), hanging
  /// below it, and standing on opposite sides of the bar's centre. Stroke order
  /// doesn't matter; the three sort themselves by orientation.
  ///
  /// This is Η's own arrangement — one bar, two stems, one on each side —
  /// measured in the one place the two letters differ: Π's bar sits at the tops
  /// of its legs where Η's crosses their middles. A partition, so neither can
  /// claim the other's drawing and their order in [_classify] is free.
  ///
  /// Where the bar meets each stem is found by nearest approach ([_touches],
  /// [_nearestPointTo]) rather than by intersection, because in this letter it
  /// is a junction and not a crossing: a hand that stops its leg on the bar
  /// leaves nothing for a segment-intersection test to find. Η can ask for real
  /// crossings because its bar genuinely runs through.
  _GreekLetter? _classifyPiThreeStroke() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final bars = recent.where(_isBar).toList();
    final stems = recent.where(_isStem).toList();
    if (bars.length != 1 || stems.length != 2) return null;
    final bar = bars.single;
    final barBounds = _boundsOf(bar.points);

    var left = 0, right = 0;
    for (final stem in stems) {
      if (!_touches(stem, bar)) return null;
      final stemBounds = _boundsOf(stem.points);
      // The leg hangs below the bar rather than standing through it.
      if (stemBounds.center.dy <= barBounds.center.dy + _minSideOffset) {
        return null;
      }
      final at = _nearestPointTo(stem, bar);
      final along = (at.dy - stemBounds.top) / stemBounds.height;
      if (along >= _outerQuarter) return null;
      if (stemBounds.center.dx < barBounds.center.dx - _minSideOffset) left++;
      if (stemBounds.center.dx > barBounds.center.dx + _minSideOffset) right++;
    }
    return left == 1 && right == 1 ? _GreekLetter.pi : null;
  }

  // ── Ε, Ϝ, Η, Ξ: the stem and its bars ───────────────────────────────────────

  /// Whether the last four strokes form Ε: an upright stem, and three horizontal
  /// bars meeting it once each — one up in its top third, one across its middle
  /// third, one down in its bottom third — all three reaching away to the stem's
  /// right ([_minSideOffset]). Or three strokes, the stem and bottom bar drawn
  /// as one bottom-left corner with the other two bars on it.
  ///
  /// Where along the stem the bars land is the whole letter: three bars bunched
  /// at the top is no more an Ε than one bar is, so the crossings are located and
  /// sorted into thirds rather than merely counted. Stroke order doesn't matter.
  _GreekLetter? _classifyEpsilon() {
    for (final size in const [4, 3]) {
      if (_strokes.length < size) continue;
      if (_isEpsilon(_strokes.sublist(_strokes.length - size))) {
        return _GreekLetter.epsilon;
      }
    }
    return null;
  }

  /// Whether [strokes] form Ε, in either of the two ways a hand writes it.
  ///
  /// **Four strokes**: a stem and three bars, one to each third of it.
  /// **Three**: the stem and the bottom bar drawn as a single bottom-left
  /// corner, with the other two bars on it — the same letter with one pen lift
  /// fewer.
  ///
  /// The two forms can't be confused, a corner being a bend where a stem is
  /// straight, and neither can be confused with Ϝ: a digamma wants a *stem* with
  /// two bars and nothing at its foot, where the three-stroke Ε's foot is the
  /// corner's own.
  bool _isEpsilon(List<_Stroke> strokes) =>
      _isEpsilonFromStem(strokes) || _isEpsilonFromCorner(strokes);

  bool _isEpsilonFromStem(List<_Stroke> strokes) {
    if (strokes.length != 4) return false;
    final stems = strokes.where(_isStem).toList();
    final bars = strokes.where(_isBar).toList();
    if (stems.length != 1 || bars.length != 3) return false;
    final stem = stems.single;
    final bounds = _boundsOf(stem.points);
    final stemCentre = bounds.center.dx;

    var top = 0, middle = 0, bottom = 0;
    for (final bar in bars) {
      final crossings = _crossingPoints(bar, stem);
      if (crossings.length != 1) return false;
      if (_boundsOf(bar.points).center.dx < stemCentre + _minSideOffset) {
        return false;
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
    return top == 1 && middle == 1 && bottom == 1;
  }

  /// Ε written in three strokes: a bottom-left corner — the stem and the bottom
  /// bar in one — with a bar across its top third and another across its middle.
  ///
  /// The bars are measured against the corner's own bounding box rather than
  /// against a stem picked out of it, since that box *is* its upright: as tall,
  /// and with its left edge down the upright. Nothing has to find the elbow.
  ///
  /// A bar reaching the bottom third would be a bar laid on the corner's own
  /// foot, which is no Ε — so unlike the four-stroke form, which counts one bar
  /// to each third, this one refuses that third outright.
  bool _isEpsilonFromCorner(List<_Stroke> strokes) {
    if (strokes.length != 3) return false;
    final corners =
        strokes.where((s) => _isCorner(s, elbow: _Corner.bottomLeft)).toList();
    final bars = strokes.where(_isBar).toList();
    if (corners.length != 1 || bars.length != 2) return false;
    final corner = corners.single;
    final bounds = _boundsOf(corner.points);

    var top = 0, middle = 0;
    for (final bar in bars) {
      final crossings = _crossingPoints(bar, corner);
      if (crossings.length != 1) return false;
      if (_boundsOf(bar.points).center.dx < bounds.left + _minSideOffset) {
        return false;
      }
      final along = (crossings.single.dy - bounds.top) / bounds.height;
      if (along < 1 / 3) {
        top++;
      } else if (along <= 2 / 3) {
        middle++;
      } else {
        return false;
      }
    }
    return top == 1 && middle == 1;
  }

  /// Whether the last three strokes — or the last two — form Ϝ. See [_isDigamma]
  /// for the two ways a hand writes it.
  ///
  /// In three: an upright stem, and two horizontal bars meeting it once each —
  /// one up in its top third, one across its middle third — both reaching away
  /// to the stem's right ([_minSideOffset]), and nothing down at its foot.
  ///
  /// This is [_classifyEpsilon]'s own test with the bottom bar left off, and the
  /// thirds are what make the difference legible: two bars bunched at the top is
  /// no more a digamma than one bar is.
  ///
  /// The letter Latin's F is descended from, and drawn the same way still — so
  /// this classifier is `latin`'s `_classifyF`, carried back to where the shape
  /// started.
  _GreekLetter? _classifyDigamma() {
    if (_strokes.length < 3) return null;
    return _isDigamma(_strokes.sublist(_strokes.length - 3))
        ? _GreekLetter.digamma
        : null;
  }

  /// Whether [strokes] — three of them — form Ϝ: an upright stem with two arms
  /// hung off its right, one meeting it in its top third and one across its
  /// middle, and nothing at its foot. The stem stands on the **left** of the
  /// letter's own bounding box.
  ///
  /// **An arm is a plain bar or a ㄱ** ([_isDigammaArm]) — Hangul's own, and
  /// unturned: out to the right and then down. That is how the archaic letter is
  /// written, its arms hooking downward at their tips rather than ending flat.
  /// Either shape is read wherever an arm is wanted, so a digamma with one arm
  /// hooked and one flat is read as readily as one with both.
  ///
  /// Note the ㄱ is **not** mirrored here, where Γ's own corner is, and the two
  /// are a single [_Corner] value apart. Γ is a bar running right from the top of
  /// a *stem* — ㄱ turned over, elbow at the top-**left**. A digamma's arm is a
  /// bar running right and then turning down at its far end — ㄱ as it stands,
  /// elbow at the top-**right**. Same letter of Hangul, opposite handedness, and
  /// worth keeping straight.
  ///
  /// Thirds are what make the letter legible: two arms bunched at the top is no
  /// more a digamma than one arm is, and an arm down at the foot is Ε's third
  /// bar. This is [_classifyEpsilon]'s own measurement with the bottom bar left
  /// off — the letter Latin's F is descended from, and drawn the same way still.
  bool _isDigamma(List<_Stroke> strokes) {
    if (strokes.length != 3) return false;
    final stems = strokes.where(_isStem).toList();
    if (stems.length != 1) return false;
    final stem = stems.single;
    final arms = [
      for (final stroke in strokes)
        if (!identical(stroke, stem)) stroke,
    ];
    final stemBounds = _boundsOf(stem.points);

    // The stem stands to the left of the letter's own middle. Every other
    // measurement here is taken *against* the stem, so without this the whole
    // shape could be mirrored and still answer — and a stem on the right with
    // its arms reaching left is no digamma.
    final letter = _boundsOf([for (final stroke in strokes) ...stroke.points]);
    if (stemBounds.center.dx >= letter.center.dx) return false;

    var top = 0, middle = 0;
    for (final arm in arms) {
      if (!_isDigammaArm(arm)) return false;
      final along = _barAlong(arm, stem);
      if (along == null) return false;
      if (_boundsOf(arm.points).center.dx <
          stemBounds.center.dx + _minSideOffset) {
        return false;
      }
      if (along < 1 / 3) {
        top++;
      } else if (along <= 2 / 3) {
        middle++;
      } else {
        // An arm down at the stem's foot is Ε's third bar, not a digamma's
        // second.
        return false;
      }
    }
    return top == 1 && middle == 1;
  }

  /// One of Ϝ's arms: a plain bar, or **ㄱ** — out to the right and then turning
  /// down ([_Corner.topRight]).
  ///
  /// The two can't be confused: [_isBar] wants a straight line and [_isCorner]
  /// refuses one outright, a line having no elbow. So an arm is sorted by its own
  /// shape rather than by which arm it is.
  bool _isDigammaArm(_Stroke s) =>
      _isBar(s) || _isCorner(s, elbow: _Corner.topRight);

  /// Where [bar] meets [body], as a fraction of [body]'s own height — 0 at its
  /// top, 1 at its foot — or null if the two don't meet in exactly one place.
  ///
  /// **Meeting, not crossing**, and that is the point of having it. A hand that
  /// draws an upright and then starts each bar *beside* it, rather than
  /// back-tracking over it, leaves a T-junction and no intersection at all — and
  /// a bar two pixels clear of the stem used to make the whole letter read as
  /// nothing. With an upright already on the page that is a very easy way to
  /// draw, which makes it a poor thing to fail on.
  ///
  /// It is the same judgement [_classifyPiThreeStroke] already makes about a Π's
  /// bar landing on its legs, lifted out so Ϝ can make it too.
  double? _barAlong(_Stroke bar, _Stroke body) {
    if (_contacts(bar, body) != 1) return null;
    final bounds = _boundsOf(body.points);
    if (bounds.height == 0) return null;
    return (_nearestPointTo(bar, body).dy - bounds.top) / bounds.height;
  }

  /// Whether the last three strokes form Η: two upright stems and a horizontal
  /// bar crossing each of them exactly once, with the two crossings falling on
  /// opposite sides of the bar's own centre ([_minSideOffset]) and both clear of
  /// the stems' top quarter ([_outerQuarter]).
  ///
  /// Where along the bar the stems land is most of the shape. Both stems on the
  /// same side of its centre is a bar with a tail, not an Η, so the crossing
  /// points are located ([_crossingPoints]) rather than merely counted.
  ///
  /// Where along the *stems* the bar lands is the rest of it, and that is what
  /// keeps Η and a three-stroke Π apart — the same three strokes arranged the
  /// same way, differing only in whether the bar rides at the legs' tops or
  /// across their middles. See [_classifyPiThreeStroke].
  ///
  /// Stroke order doesn't matter: the three sort themselves by orientation.
  _GreekLetter? _classifyEta() {
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
      final bounds = _boundsOf(stem.points);
      final along = (at.dy - bounds.top) / bounds.height;
      if (along < _outerQuarter) return null;
      if (at.dx < centre - _minSideOffset) left++;
      if (at.dx > centre + _minSideOffset) right++;
    }
    return left == 1 && right == 1 ? _GreekLetter.eta : null;
  }

  /// Whether the last three strokes form Ξ: three horizontal bars stacked clear
  /// of one another, and touching nothing else on the page. Stroke order doesn't
  /// matter — the three are sorted by height, not by when they arrived.
  ///
  /// **Standing free is the letter.** Ε has three bars too, and a stem they all
  /// meet; a digamma has two and a stem. So what makes these three a Ξ is that
  /// they meet nothing — not each other, and not whatever else is on the page.
  /// Asking [_touches] rather than [_crossings] is deliberate: a bar that stops
  /// a pixel short of a stem has still met it, and the drawing is still an Ε
  /// being written.
  ///
  /// The bars must also overlap each other horizontally, so that three bars
  /// scattered across the page aren't read as a letter, and stand clear of one
  /// another vertically ([_touchTolerance]) — which they do by that same
  /// no-touching rule, since parallel bars near enough to touch are near enough
  /// to be one stroke redrawn.
  _GreekLetter? _classifyXi() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    if (recent.any((s) => !_isBar(s))) return null;
    for (final bar in recent) {
      if (_crossesAnotherStroke(bar)) return null;
      for (final other in _strokes) {
        if (identical(other, bar)) continue;
        if (_touches(bar, other)) return null;
      }
    }
    // Stacked over one another rather than strewn about: every pair's run of
    // widths has to overlap.
    for (var i = 0; i < recent.length; i++) {
      final a = _boundsOf(recent[i].points);
      for (var j = i + 1; j < recent.length; j++) {
        final b = _boundsOf(recent[j].points);
        if (a.right < b.left || b.right < a.left) return null;
      }
    }
    return _GreekLetter.xi;
  }

  // ── Β, Ρ, Κ: the stem with something laid against it ────────────────────────

  /// Whether the last two strokes form Β: an upright stem, and a
  /// right-left-right-left stroke laid against it, meeting it 3 or 4 times. Each
  /// bowl joins the stem at both ends, which would be 4 meetings; where a bowl's
  /// foot and the next one's head arrive at the same spot they read as one,
  /// hence 3. The stem stands to the left of the bowls ([_minSideOffset]), so
  /// they hang off it rather than straddle it. Either stroke order.
  _GreekLetter? _classifyBeta() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke stem;
    final _Stroke bowls;
    if (_isStem(a) && _isDoubleBowl(b)) {
      stem = a;
      bowls = b;
    } else if (_isStem(b) && _isDoubleBowl(a)) {
      stem = b;
      bowls = a;
    } else {
      return null;
    }

    final meetings = _crossings(bowls, stem);
    if (meetings < 3 || meetings > 4) return null;
    return _boundsOf(stem.points).center.dx <
            _boundsOf(bowls.points).center.dx - _minSideOffset
        ? _GreekLetter.beta
        : null;
  }

  /// Whether [s] runs right, back left, right again and left again — Β's pair of
  /// bowls in one stroke, out to the right and home to the stem twice over, and
  /// Σ's pair of folds when no stem stands beside it.
  ///
  /// Nothing is asked about the stroke crossing its own path here; Σ asks it
  /// separately. Two bowls drawn in one go meet in the middle, and whether a
  /// given hand closes that join into a crossing isn't the difference between
  /// one letter and another.
  bool _isDoubleBowl(_Stroke s) =>
      _hasSideLegs(s, const [_Leg.right, _Leg.left, _Leg.right, _Leg.left]);

  /// Whether the last two strokes form Ρ: an upright stem and a bowl running
  /// right then back left that crosses it twice, with the stem standing clear
  /// **below** the bowl but not above it — the bowl sitting at the top. Either
  /// stroke order.
  ///
  /// Latin's P is read by this very test, and the letter is the same letter: P
  /// is a rho that changed its sound and not its shape.
  _GreekLetter? _classifyRho() {
    if (_strokes.length < 2) return null;
    final bowl = _bowlCrossings(_strokes[_strokes.length - 2], _strokes.last);
    if (bowl == null) return null;
    return bowl.above < _outerQuarter && bowl.below >= _outerQuarter
        ? _GreekLetter.rho
        : null;
  }

  /// How much of the stem a bowl leaves clear [above] it and [below] it, as
  /// fractions of the stem's own height — or null if [a] and [b] aren't a
  /// stem-and-bowl pair at all.
  ///
  /// The pair is an upright with a bowl running right then back left that
  /// crosses it exactly twice and hangs off its right ([_minSideOffset]). Only
  /// the crossings' heights say where the bowl sits, so this locates them
  /// ([_crossingPoints]) and leaves the reading to the caller — the same
  /// division of labour [_classifyEpsilon] and [_classifyDigamma] make over the
  /// thirds of their stem.
  ///
  /// Latin gets three letters out of this measurement (D, P and Þ, told apart by
  /// whether the stem sticks out at each end); Greek wants only the one, so only
  /// the top-hung reading has a letter here. A bowl reaching both ends of the
  /// stem, or sitting in its middle, is no Greek capital and reads as nothing.
  ({_Stroke stem, double above, double below})? _bowlCrossings(
      _Stroke a, _Stroke b) {
    final _Stroke stem;
    final _Stroke bowl;
    if (_isStem(a) && _isBowl(b)) {
      stem = a;
      bowl = b;
    } else if (_isStem(b) && _isBowl(a)) {
      stem = b;
      bowl = a;
    } else {
      return null;
    }

    final crossings = _crossingPoints(bowl, stem);
    if (crossings.length != 2) return null;

    final bounds = _boundsOf(stem.points);
    if (bounds.center.dx > _boundsOf(bowl.points).center.dx - _minSideOffset) {
      return null;
    }
    final along = [
      for (final at in crossings) (at.dy - bounds.top) / bounds.height,
    ]..sort();
    return (stem: stem, above: along.first, below: 1 - along.last);
  }

  /// Whether [s] is Ρ's bowl: out to the right and back left again, never
  /// crossing itself — half of [_isDoubleBowl], and [_isInwardArm] mirrored.
  bool _isBowl(_Stroke s) =>
      _hasSideLegs(s, const [_Leg.right, _Leg.left]) &&
      _selfIntersections(s) == 0;

  /// Whether the last two strokes form Κ: an upright stem, and an arm running
  /// left and then right — in to meet the stem, then away again — hanging off
  /// the stem's right and crossing it once or twice. Once where the arm turns on
  /// the stem, twice where it carries past and comes back. Either stroke order.
  _GreekLetter? _classifyKappa() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke stem;
    final _Stroke arm;
    if (_isStem(a) && _isInwardArm(b)) {
      stem = a;
      arm = b;
    } else if (_isStem(b) && _isInwardArm(a)) {
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
    return meetings >= 1 && meetings <= 2 ? _GreekLetter.kappa : null;
  }

  /// Whether [s] runs left and then right — Κ's arm, and the mirror of
  /// [_isBowl]'s right-then-left.
  bool _isInwardArm(_Stroke s) => _hasSideLegs(s, const [_Leg.left, _Leg.right]);

  // ── Θ, Φ, Ϙ, Ο: the ring and what is put through it ─────────────────────────

  /// Whether the last two strokes form Θ: an Ο's ring ([_isLoop]) with a
  /// horizontal bar inside it. Either stroke order.
  ///
  /// That is the whole test, and it is deliberately the whole test. **Nothing
  /// else here is a ring with a bar in it**, so once those two strokes are on the
  /// page there is nothing left to decide, and every further question is a way of
  /// refusing a theta somebody meant to draw.
  ///
  /// In particular it does **not** ask the bar to cross the ring, and that is
  /// what makes it work on a real drawing. A theta's bar is *contained* by its
  /// ring — a hand draws it from inside one side to inside the other, because
  /// that is what the letter looks like — so it very often crosses nothing at
  /// all. Counting crossings read those thetas as **nothing**, or, with the ring
  /// drawn last, as **Ο**: the bar had touched nothing, so the ring was a plain
  /// loop and [_classifyOmicron] took it. Both were live bugs.
  ///
  /// Nor does it ask the bar to sit at the waist, to be centred, or to reach
  /// across a given share of the ring. Each of those turned away a drawing that
  /// was plainly a theta, and none of them was telling it from anything.
  ///
  /// Being inside is asked of the bar's **centre**, which is what lets it
  /// overshoot the ring on both sides — a hand does — while a bar merely lying
  /// alongside the ring is still turned away.
  ///
  /// Above [_classifyOmicron] in [_classify], which it must be: with the bar
  /// crossing nothing, the ring is a plain loop and Ο would answer first.
  _GreekLetter? _classifyTheta() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke ring;
    final _Stroke bar;
    if (_isLoop(a) && _isBar(b)) {
      ring = a;
      bar = b;
    } else if (_isLoop(b) && _isBar(a)) {
      ring = b;
      bar = a;
    } else {
      return null;
    }
    return _boundsOf(ring.points).contains(_boundsOf(bar.points).center)
        ? _GreekLetter.theta
        : null;
  }

  /// Whether the last two strokes form Φ: an Ο's ring run through by an upright
  /// stem that crosses it at least twice — in at the top, out at the foot — and
  /// stands clear of it at **both** ends. Either stroke order.
  ///
  /// Cyrillic Ф is read this way, and the two are the same letter.
  ///
  /// At least twice, not exactly: a ring closes by overlapping itself, so a stem
  /// passing through where the two ends cross picks up a third meeting it didn't
  /// ask for.
  ///
  /// The stem must be centred on the ring ([_junctionSnap] of its width) and
  /// stick out above and below it ([_minSideOffset]). Both clauses earn their
  /// keep. Centring is what makes this a Φ rather than a Ρ — a bowl hung off the
  /// stem's right is the other letter — and the overhangs are what make it a Φ
  /// rather than a Ϙ, whose stem hangs below the ring and never rises above it.
  _GreekLetter? _classifyPhi() {
    final pair = _ringAndStem();
    if (pair == null) return null;
    final ring = _boundsOf(pair.ring.points);
    final stem = _boundsOf(pair.stem.points);
    if ((stem.center.dx - ring.center.dx).abs() > ring.width * _junctionSnap) {
      return null;
    }
    if (stem.top > ring.top - _minSideOffset) return null;
    if (stem.bottom < ring.bottom + _minSideOffset) return null;
    return _crossings(pair.stem, pair.ring) >= 2 ? _GreekLetter.phi : null;
  }

  /// Whether the last two strokes form Ϙ: an Ο's ring with an upright stem hung
  /// **under** it — meeting it at the ring's foot and carrying on clear below.
  /// Either stroke order.
  ///
  /// Φ and Ϙ are the same two strokes and are told apart by where the stem sits:
  /// through the ring and out at both ends for the one, below it for the other.
  /// Neither can answer the other's drawing, so their order in [_classify] is
  /// free — Φ is asked first only because it is the tighter claim.
  ///
  /// The stem is asked to *touch* the ring rather than cross it, since a koppa's
  /// tail hangs off the foot and a hand may well stop where it meets. Its top
  /// must sit at or below the ring's own middle, and its bottom clear of the
  /// ring's foot.
  _GreekLetter? _classifyKoppa() {
    final pair = _ringAndStem();
    if (pair == null) return null;
    if (!_touches(pair.stem, pair.ring)) return null;
    final ring = _boundsOf(pair.ring.points);
    final stem = _boundsOf(pair.stem.points);
    if ((stem.center.dx - ring.center.dx).abs() > ring.width * _junctionSnap) {
      return null;
    }
    if (stem.top < ring.center.dy) return null;
    return stem.bottom > ring.bottom + _minSideOffset
        ? _GreekLetter.koppa
        : null;
  }

  /// The last two strokes sorted into a ring and an upright stem, or null if
  /// they are not that pair — what Φ and Ϙ are both built on. Either stroke
  /// order.
  ({_Stroke ring, _Stroke stem})? _ringAndStem() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    if (_isLoop(a) && _isStem(b)) return (ring: a, stem: b);
    if (_isLoop(b) && _isStem(a)) return (ring: b, stem: a);
    return null;
  }

  /// Whether the last stroke is Ο: a single stroke that crosses its own path
  /// exactly once — the crossing is what makes it a closed loop rather than an
  /// open arc — and that crosses no other stroke on the page, since a loop
  /// tangled with something else is part of a bigger letter (a Θ, a Φ, a Ϙ), not
  /// an Ο.
  ///
  /// This is the loosest test here but one, which is why [_classify] only
  /// reaches it once every letter with a shape of its own has declined.
  _GreekLetter? _classifyOmicron() =>
      _isLoop(_strokes.last) && !_crossesAnotherStroke(_strokes.last)
          ? _GreekLetter.omicron
          : null;

  /// Whether [s] closes into a ring rather than staying an open arc: **it
  /// crosses its own path, or its two ends meet** ([_touchTolerance]).
  ///
  /// A stroke that crosses itself is the whole idea, and the first clause says
  /// so plainly. Two things had to be added to it, and both were found by
  /// drawing circles rather than by reasoning about them.
  ///
  /// **The count is `>= 1`, not `== 1`.** A stroke that comes back round and
  /// wanders across its own opening pass crosses it *twice* — out and back — as
  /// readily as once. Held to exactly one crossing, a circle drawn with a
  /// generous overlap read as **nothing**, and one with a very generous overlap
  /// read as **Ζ**. Asking merely that it cross itself is both simpler and
  /// right; a stroke that crosses itself several times is still a ring, and
  /// [_classifyOmicron]'s own "crosses nothing else" clause is what keeps a
  /// scribble out.
  ///
  /// **Ends meeting counts too**, and this clause cannot be dropped however much
  /// one would like to. A hand closing a circle does not reliably cross its own
  /// path at all: it comes back round and *stops*. Close it exactly and the
  /// final segment meets the opening one end to end, where the crossing test
  /// turns on the sign of a quantity that is arithmetically zero; overshoot
  /// along the same arc and the second pass merely retraces the first, which is
  /// collinear and deliberately no crossing; drift slightly inward as you close
  /// and the second pass spirals inside the first, never touching it. All three
  /// are ordinary ways to draw an Ο and all three cross nothing.
  ///
  /// Read by self-crossing alone those registered as **nothing at all**, and
  /// took Θ, Φ and Ϙ with them — none of which can be read without first
  /// agreeing there is a ring on the page.
  ///
  /// Ends-meeting is the same judgement the rest of this file makes everywhere a
  /// pen either overshoots or stops short: Τ's stem on its bar, a Δ's base under
  /// its feet, a Ϙ's tail on its ring. The ring was the one place it wasn't
  /// being made.
  ///
  /// It stays honest about an arc. A C, an Ω and Ρ's bowl all leave their two
  /// ends far further apart than this, and a circle abandoned with a real gap in
  /// it still isn't a ring — a test pins that.
  bool _isLoop(_Stroke s) =>
      _selfIntersections(s) >= 1 ||
      (s.end - s.start).distance <= _touchTolerance;

  // ── Υ, Ψ, Τ, Χ ──────────────────────────────────────────────────────────────

  /// Whether the last two strokes form Υ: a V — one stroke falling then rising —
  /// with an upright stem hanging **below** its vertex. Either stroke order.
  ///
  /// The stem has to hang from the vertex rather than off either arm
  /// ([_junctionSnap], measured against the V's own width), and it must stay
  /// below it: a stem carried on up past the vertex, into the V's own opening,
  /// is a Ψ. That is a partition of the same pair of strokes (see
  /// [_classifyPsi]), so their order in [_classify] doesn't matter.
  _GreekLetter? _classifyUpsilon() {
    final pair = _veeAndStem();
    if (pair == null) return null;
    final stem = _boundsOf(pair.stem.points);
    if (stem.top < pair.vertex.dy - _minSideOffset) return null;
    return stem.center.dy > pair.vertex.dy ? _GreekLetter.upsilon : null;
  }

  /// Whether the last two strokes form Ψ: Υ's own V and stem, with the stem
  /// carried on **up past** the V's vertex so that it stands inside the letter's
  /// opening as well as below it. Either stroke order.
  ///
  /// The V is psi's two upper arms and the stem is its spine, which in print
  /// runs the whole height of the letter. So the one thing to measure is how far
  /// up the stem reaches: past the vertex by [_minSideOffset] is a Ψ, stopping
  /// at it is a Υ.
  ///
  /// Ahead of Υ in [_classify] for clarity rather than need — the two partition
  /// this pair of strokes between them and neither can claim the other's
  /// drawing.
  _GreekLetter? _classifyPsi() {
    final pair = _veeAndStem();
    if (pair == null) return null;
    final stem = _boundsOf(pair.stem.points);
    if (stem.top >= pair.vertex.dy - _minSideOffset) return null;
    return stem.bottom > pair.vertex.dy ? _GreekLetter.psi : null;
  }

  /// The last two strokes sorted into a V and an upright stem hung from the V's
  /// vertex, with that vertex located — or null if they aren't that pair.
  ///
  /// The vertex is the V's lowest point, where its two arms meet, and the one
  /// place along the V a stem may hang from ([_junctionSnap]). Υ and Ψ share all
  /// of this and differ only in how far up the stem goes.
  ({_Stroke vee, _Stroke stem, Offset vertex})? _veeAndStem() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke vee;
    final _Stroke stem;
    if (_isVee(a) && _isStem(b)) {
      vee = a;
      stem = b;
    } else if (_isVee(b) && _isStem(a)) {
      vee = b;
      stem = a;
    } else {
      return null;
    }
    if (_contacts(stem, vee) != 1) return null;

    var vertex = vee.points.first;
    for (final point in vee.points) {
      if (point.dy > vertex.dy) vertex = point;
    }
    final veeBounds = _boundsOf(vee.points);
    final stemCentre = _boundsOf(stem.points).center;
    if ((stemCentre.dx - vertex.dx).abs() > veeBounds.width * _junctionSnap) {
      return null;
    }
    return (vee: vee, stem: stem, vertex: vertex);
  }

  /// Whether [s] is Υ's V: one stroke falling then rising — Λ turned upside
  /// down.
  bool _isVee(_Stroke s) => _hasLegs(s, const [_Leg.down, _Leg.up]);

  /// Whether the last two strokes form Τ: a horizontal bar and an upright stem
  /// that touch, with the stem hanging below the bar's *middle*
  /// ([_junctionSnap]). Either stroke order.
  ///
  /// The band is stated as a distance from the bar's centre rather than as "away
  /// from its ends", because a stem out at the bar's left end is a two-stroke Γ
  /// and one at its right end is no Greek letter at all — so the two readings
  /// divide the bar between them and the remaining quarter falls to nothing.
  _GreekLetter? _classifyTau() {
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
        ? _GreekLetter.tau
        : null;
  }

  /// Whether the last two strokes form Χ: two strokes crossing once, one rising
  /// to the right and one falling. Slant is read off the two endpoints alone, so
  /// a hand-drawn stroke that wanders on the way still counts as whichever way
  /// it ended up going. Either stroke order.
  ///
  /// Both strokes must also reach across the letter, with an end clear either
  /// side of the pair's own vertical middle. That is what keeps an upright out:
  /// no hand draws one exactly plumb, and a stem leaning by a pixel reads as
  /// rising or falling like anything else — so a Τ's stem, beside its bar, would
  /// otherwise arrive here as one of two opposite slants that cross.
  _GreekLetter? _classifyChi() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final rising = [a, b].where(_isAscending).length;
    final falling = [a, b].where(_isDescending).length;
    if (rising != 1 || falling != 1) return null;
    if (_crossings(a, b) != 1) return null;

    final middle = _boundsOf([...a.points, ...b.points]).center.dx;
    for (final stroke in [a, b]) {
      final ends = [stroke.start.dx, stroke.end.dx];
      if (ends.every((x) => x > middle - _minSideOffset) ||
          ends.every((x) => x < middle + _minSideOffset)) {
        return null;
      }
    }
    return _GreekLetter.chi;
  }

  // ── Μ, Ν, Σ, Ζ, Ι: the one-stroke letters ───────────────────────────────────

  /// Whether the last stroke is Μ: one stroke rising, falling, rising and
  /// falling again — the two peaks and the valley between them — and crossing
  /// nothing, its own path included.
  ///
  /// Inverting the pattern would give Latin's W, which is no Greek letter, so
  /// nothing here claims it.
  _GreekLetter? _classifyMu() =>
      _hasLegs(_strokes.last,
                  const [_Leg.up, _Leg.down, _Leg.up, _Leg.down]) &&
              _crossesNothing(_strokes.last)
          ? _GreekLetter.mu
          : null;

  /// Whether the last stroke is Σ: Μ's four legs turned on their side — one
  /// stroke running to and fro four times ([_isDoubleFold]) — and crossing
  /// nothing at all.
  ///
  /// **Σ is Β's pair of bowls mirrored**, and that is worth stating because the
  /// two are so nearly the same stroke. Β's bowls set off *away* from the stem
  /// and come home twice: right-left-right-left. Σ sets off from the top bar's
  /// far end and folds inward: left-right-left-right. The letter's two leftmost
  /// points are the ends of its bars and its fold sits between them, to their
  /// right — which is Μ's valley between two peaks, rotated a quarter turn.
  ///
  /// So the two patterns are genuinely different and neither can answer the
  /// other, which means a Β drawn bowls-first reads as *nothing* until its stem
  /// lands rather than as a sigma. Getting this the other way round would have
  /// cost exactly that.
  ///
  /// Four legs is an even count, so spelling the pattern out is safe: reversing
  /// the stroke reverses the order of its legs and flips each one's direction,
  /// and on an even count those cancel. A Σ drawn from the bottom up reads as
  /// the same run of legs. (On three legs they would not — see
  /// [_isThreeLegged].)
  _GreekLetter? _classifySigma() =>
      _isDoubleFold(_strokes.last) && _crossesNothing(_strokes.last)
          ? _GreekLetter.sigma
          : null;

  /// Whether [s] runs left, back right, left again and right again — Σ's two
  /// folds, and [_isDoubleBowl] mirrored.
  bool _isDoubleFold(_Stroke s) =>
      _hasSideLegs(s, const [_Leg.left, _Leg.right, _Leg.left, _Leg.right]);

  /// Whether the last stroke is Ν: one stroke of three vertical legs, its outer
  /// two upright stems and the one between them a diagonal that falls to the
  /// right, crossing nothing at all.
  ///
  /// The middle leg's slant is asked about rather than the run of legs'
  /// direction, and that is what makes the test indifferent to which way the
  /// hand went. Drawn up-down-up the legs read up, down, up; drawn from the
  /// other end they read down, up, down — but the diagonal between them is the
  /// same line either way, and [_isDescending] reads a line rather than a
  /// direction. Cyrillic И is this very shape with that diagonal rising instead.
  ///
  /// The stems are what make this Ν rather than merely something that falls,
  /// rises and falls: a circle drawn not quite closed does that too, entering
  /// and leaving on its right-hand side, and only the stems tell the two apart.
  _GreekLetter? _classifyNu() {
    final legs = _verticalLegs(_strokes.last);
    if (legs.length != 3) return null;
    if (!_isStem(legs.first) || !_isStem(legs.last)) return null;
    if (!_isDescending(legs[1])) return null;
    return _crossesNothing(_strokes.last) ? _GreekLetter.nu : null;
  }

  /// Whether the last stroke is Ζ: three legs to and fro with the diagonal
  /// between them leaning `/` — the top bar, the diagonal, then the bottom bar —
  /// crossing nothing at all.
  ///
  /// Latin's Z is this letter, borrowed whole; Greek is where it came from.
  _GreekLetter? _classifyZeta() =>
      _isThreeLegged(_strokes.last, leaning: _Leg.up) &&
              _crossesNothing(_strokes.last)
          ? _GreekLetter.zeta
          : null;

  /// Whether [s] runs to and fro across exactly three legs ([_horizontalLegs])
  /// with its middle one leaning the way [leaning] says — [_Leg.up] for a `/`.
  ///
  /// The middle leg's *slant* is what's asked about, not the run of legs'
  /// directions, and that is what makes the test indifferent to which way the
  /// hand went — which for a three-leg shape it has to be. Reversing a stroke
  /// both reverses the order of its legs and flips each one's direction, and on
  /// an odd number of legs those two do not cancel: a Ζ drawn bottom-up leaves
  /// right-left-right turned into left-right-left, which is the run of legs a
  /// mirrored Ζ drawn top-down leaves. So the pattern alone cannot say which of
  /// the two it is — it only says which way the hand set off. The diagonal
  /// between the two bars is the same line either way, and [_isAscending] reads
  /// a line rather than a direction.
  bool _isThreeLegged(_Stroke s, {required _Leg leaning}) {
    final legs = _horizontalLegs(s);
    if (legs.length != 3) return false;
    return leaning == _Leg.up ? _isAscending(legs[1]) : _isDescending(legs[1]);
  }

  /// Whether the last stroke is Ι: a plain upright line, crossing nothing at
  /// all.
  ///
  /// The loosest test here by a wide margin, and last of all in [_classify] for
  /// it. Β, Ε, Η, Κ, Ρ, Τ, Φ, Ψ and Ϝ all begin with this very stroke, so an
  /// unfinished one of those genuinely *is* an Ι so far as the page can tell —
  /// the readout says so until the next stroke lands and settles it. That's the
  /// live readout doing its job, not a shape test being wrong.
  ///
  /// Crossing nothing is what keeps it from claiming the stem of a letter
  /// already drawn around it: Η's second stem meets its bar, Τ's meets its own,
  /// and neither falls through to here.
  _GreekLetter? _classifyIota() =>
      _isStem(_strokes.last) && _crossesNothing(_strokes.last)
          ? _GreekLetter.iota
          : null;

  // ── Shape primitives ────────────────────────────────────────────────────────

  /// Whether [stroke] crosses neither its own path nor any other stroke on the
  /// page — what makes a shape a letter in its own right rather than one piece
  /// of a bigger, tangled one.
  bool _crossesNothing(_Stroke stroke) =>
      _selfIntersections(stroke) == 0 && !_crossesAnotherStroke(stroke);

  /// Whether [stroke] crosses any other stroke on the page. [stroke] is expected
  /// to already be in [_strokes], so it's skipped by identity.
  bool _crossesAnotherStroke(_Stroke stroke) {
    for (final other in _strokes) {
      if (identical(other, stroke)) continue;
      if (_crossings(stroke, other) > 0) return true;
    }
    return false;
  }

  /// Whether [s] ends up to the right of and above where it started, or the
  /// reverse — a `/`. Screen y runs downward, so a rising stroke's run and drop
  /// have opposite signs; the test is direction-agnostic, since swapping both
  /// ends leaves the product's sign alone. A stroke that ends level with or
  /// directly under where it began is neither this nor [_isDescending].
  bool _isAscending(_Stroke s) =>
      (s.end.dx - s.start.dx) * (s.end.dy - s.start.dy) < 0;

  /// [_isAscending]'s mirror — a `\`.
  bool _isDescending(_Stroke s) =>
      (s.end.dx - s.start.dx) * (s.end.dy - s.start.dy) > 0;

  /// Whether [stroke] is a single right-angle corner — one horizontal leg and
  /// one vertical leg meeting at an elbow — with that elbow in the [elbow]
  /// corner of the stroke's own bounding box.
  ///
  /// The test is: the box genuinely spans both axes ([_minCornerLeg]); the whole
  /// stroke isn't straight (a line has no elbow); the point furthest off the
  /// start→end chord — the elbow — falls in the stroke's middle with a straight
  /// leg either side of it, which is what tells a right-angle corner from a
  /// smooth arc bending the same way; those two legs run one across and one
  /// down; and the elbow lands within [_cornerSnap] of the requested box corner.
  ///
  /// Which way the hand travelled doesn't come into it. A Γ written left-then-
  /// down and one written up-then-right are the same letter to any reader, so
  /// the elbow is located in the stroke's own bounding box rather than by stroke
  /// order.
  bool _isCorner(_Stroke stroke, {required _Corner elbow}) {
    final points = stroke.points;
    if (points.length < 5) return false;
    final bounds = _boundsOf(points);
    if (bounds.width < _minCornerLeg || bounds.height < _minCornerLeg) {
      return false;
    }
    if (_isStraight(stroke)) return false;

    final chord = stroke.end - stroke.start;
    final length = chord.distance;
    if (length == 0) return false;

    // The elbow is the point furthest off the start→end chord; both legs either
    // side of it must themselves be straight for this to be a corner and not a
    // curve.
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
    final squared = (_isHorizontal(first) && _isVertical(second)) ||
        (_isVertical(first) && _isHorizontal(second));
    if (!squared) return false;

    final corner = elbow.of(bounds);
    return (points[index].dx - corner.dx).abs() <=
            bounds.width * _cornerSnap &&
        (points[index].dy - corner.dy).abs() <= bounds.height * _cornerSnap;
  }

  /// Whether [stroke] is a pair of squared corners sharing a middle leg: cut
  /// where it first passes the middle of its own bounding box horizontally, its
  /// left-hand piece is a corner with its elbow at [left] and its right-hand
  /// piece one with its elbow at [right].
  ///
  /// Cutting at the middle is what leaves one corner in each piece. A shape built
  /// this way stands its outer legs at either extreme of its box, so the middle
  /// is only ever reached along the leg between them.
  ///
  /// Which piece the hand drew first says nothing about the letter, so the pieces
  /// are sorted by where they sit rather than by when they arrived.
  bool _isTwoCorners(_Stroke stroke,
      {required _Corner left, required _Corner right}) {
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
    return _isCorner(leftPiece, elbow: left) &&
        _isCorner(rightPiece, elbow: right);
  }

  /// Whether [stroke] is Π's arch: two squared corners sharing a top bar — a Γ's
  /// elbow joined to its mirror — so the bar runs across the top and a leg hangs
  /// down from either end of it.
  ///
  /// On a Λ the same cut lands on the apex, and the two pieces are straight
  /// diagonals — which [_isCorner] refuses outright, since a line has no elbow.
  /// That is the whole of what separates the two letters, and it needs to be,
  /// because everything else about them agrees: both are one stroke that rises
  /// and falls with its two ends below its middle. A smoothly rounded ∩ — which
  /// is most of an Ω — is turned away by the same [_cornerSnap] that stops an arc
  /// passing for Γ: a bend has to be squared off to read as a letter.
  bool _isArch(_Stroke stroke) =>
      _isTwoCorners(stroke, left: _Corner.topLeft, right: _Corner.topRight);

  /// The point along [stroke]'s own path that comes nearest [other] — where the
  /// two meet, when they do.
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

  /// Whether [s] is a plain flat line — Α's crossbar, and each of Ε's three.
  bool _isBar(_Stroke s) => _isHorizontal(s) && _isStraight(s);

  /// Whether [s] is a plain upright line — Ε's and Β's spine.
  bool _isStem(_Stroke s) => _isVertical(s) && _isStraight(s);

  /// Whether [stroke] rises and falls in exactly the pattern [expected] spells
  /// out, one entry per leg (see [_verticalLegs]).
  bool _hasLegs(_Stroke stroke, List<_Leg> expected) => _matches(
      _verticalLegs(stroke),
      expected,
      (leg) => leg.end.dy > leg.start.dy ? _Leg.down : _Leg.up);

  /// [_hasLegs] turned on its side: whether [stroke] runs to and fro in exactly
  /// the pattern [expected] spells out (see [_horizontalLegs]).
  bool _hasSideLegs(_Stroke stroke, List<_Leg> expected) => _matches(
      _horizontalLegs(stroke),
      expected,
      (leg) => leg.end.dx > leg.start.dx ? _Leg.right : _Leg.left);

  bool _matches(List<_Stroke> legs, List<_Leg> expected,
      _Leg Function(_Stroke) directionOf) {
    if (legs.length != expected.length) return false;
    for (var i = 0; i < legs.length; i++) {
      if (directionOf(legs[i]) != expected[i]) return false;
    }
    return true;
  }

  /// Cuts [stroke] wherever it genuinely reverses vertically — Λ's apex, where
  /// its two legs meet.
  List<_Stroke> _verticalLegs(_Stroke stroke) =>
      _splitAtReversals(stroke, (point) => point.dy);

  /// The same cut turned on its side, wherever [stroke] reverses horizontally —
  /// Κ's turn back, and Σ's three.
  List<_Stroke> _horizontalLegs(_Stroke stroke) =>
      _splitAtReversals(stroke, (point) => point.dx);

  /// Cuts [stroke] wherever the coordinate [along] reads off each point reverses
  /// direction, and returns the pieces in the order they were drawn.
  ///
  /// A reversal only counts once the stroke has doubled back [_directionSlack]
  /// from the furthest point it had reached — otherwise the hand's tremor along
  /// a long stem would shred it into legs. The cut falls at that furthest point,
  /// which is where the eye sees the turn.
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
      final furtherOn =
          rising ? at > along(points[turn]) : at < along(points[turn]);
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

  /// Whether [s] runs top-to-bottom (or bottom-to-top) steeply enough to read as
  /// a vertical rather than a diagonal — see [_verticalRatio].
  bool _isVertical(_Stroke s) {
    final dx = (s.end.dx - s.start.dx).abs();
    final dy = (s.end.dy - s.start.dy).abs();
    return dy > dx * _verticalRatio;
  }

  /// Whether [s] runs flat enough to read as a horizontal rather than a diagonal
  /// — [_isVertical]'s mirror image, see [_horizontalRatio].
  bool _isHorizontal(_Stroke s) {
    final dx = (s.end.dx - s.start.dx).abs();
    final dy = (s.end.dy - s.start.dy).abs();
    return dx > dy * _horizontalRatio;
  }

  /// Whether every point of [s] stays within [_straightTolerance] of the
  /// straight chord from its start to its end — i.e. the stroke is a line and
  /// not a curve, hook, or zigzag that merely ends up where a line would have.
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

  /// Whether [a] and [b] come within [_touchTolerance] of each other anywhere
  /// along their lengths — a crossing counts too, since a crossing's closest
  /// approach is zero.
  bool _touches(_Stroke a, _Stroke b) => _contacts(a, b) > 0;

  /// How many separate places along [a] come within [_touchTolerance] of [b]:
  /// consecutive near points are one meeting, so a stem that runs into a bar and
  /// stops counts once however many of its samples land inside the tolerance,
  /// while one that leaves and comes back counts twice.
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

  /// The shortest distance from [point] to [stroke]'s own path.
  double _distanceTo(Offset point, _Stroke stroke) {
    var nearest = double.infinity;
    for (var i = 1; i < stroke.points.length; i++) {
      nearest = math.min(nearest,
          _pointSegmentDistance(point, stroke.points[i - 1], stroke.points[i]));
    }
    return nearest;
  }

  /// Shortest distance from [p] to the segment [a]–[b] — measured to the nearest
  /// endpoint when the perpendicular foot falls outside the segment, so a stem
  /// alongside (but past the end of) a bar doesn't read as touching it.
  double _pointSegmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  /// How many times [a] genuinely crosses [b].
  int _crossings(_Stroke a, _Stroke b) => _crossingPoints(a, b).length;

  /// Where [a] crosses [b] — segment intersections, deduplicated so one crossing
  /// sampled across a few neighbouring segments still counts once. Works off the
  /// sampled path rather than a start-to-end chord, so it locates a crossing
  /// against a curved stroke (Β's bowls) as readily as against a straight one
  /// (Ε's stem).
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

  /// How many times [stroke] crosses its own path — non-adjacent segments (an
  /// index gap of at least 2, so a sharp turn isn't read as a crossing) that
  /// intersect, deduplicated the same way [_crossings] is.
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

  /// Where the lines through [p1]–[p2] and [p3]–[p4] meet, or null if they're
  /// parallel. Only asked for after [_segmentsIntersect] has confirmed the two
  /// segments really do cross, so the meeting point lies on both.
  Offset? _intersectionPoint(Offset p1, Offset p2, Offset p3, Offset p4) {
    final denominator =
        (p2.dx - p1.dx) * (p4.dy - p3.dy) - (p2.dy - p1.dy) * (p4.dx - p3.dx);
    if (denominator == 0) return null;
    final t = ((p3.dx - p1.dx) * (p4.dy - p3.dy) -
            (p3.dy - p1.dy) * (p4.dx - p3.dx)) /
        denominator;
    return Offset(p1.dx + t * (p2.dx - p1.dx), p1.dy + t * (p2.dy - p1.dy));
  }

  /// Whether the segments [p1]–[p2] and [p3]–[p4] cross: each segment has the
  /// other's endpoints on opposite sides.
  ///
  /// A point landing exactly *on* the other segment still counts. Strokes arrive
  /// as sampled points, so a bar crossing a stem lands on one of the stem's own
  /// samples often enough to matter — demanding both sides be strictly opposite
  /// would drop that crossing entirely and, with it, the letter. Whichever
  /// neighbouring segment also registers the same touch is folded away by
  /// [_crossingPoints]' own dedup.
  ///
  /// Two collinear segments are the exception: that's a stroke retracing its own
  /// path, which runs alongside where it came from rather than through it, so
  /// it's no crossing.
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

/// Builds the scene plus a direct reference to its [GreekLayer], so the hosting
/// page can call [GreekLayer.clear] from the Clear button.
(Scene, GreekLayer) buildGreekScene() {
  final layer = GreekLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
