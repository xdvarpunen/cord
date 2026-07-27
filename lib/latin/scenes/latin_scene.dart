import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/latin_letters.dart';
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
/// (see [LatinLayer._isCorner]). It's the one thing that tells the printed
/// right-angle shapes apart: an L's elbow rides at the [bottomLeft], where
/// Hangul's ㄱ — the bar-then-down corner that finishes a G — has it at the
/// [topRight].
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
/// vertically ([LatinLayer._verticalLegs]), [left]/[right] when
/// horizontally ([LatinLayer._horizontalLegs]).
///
/// Consecutive legs always alternate, so a pattern is really just "how
/// many legs, starting which way" — but spelling it out is what makes A's
/// up-down, C's left-right, P's right-left and B's right-left-right-left
/// read as the shapes they are.
enum _Leg { up, down, left, right }

/// The letters the recognizer can currently identify. Grows one entry at a
/// time as classifiers are built; [LatinLayer.recognizedNames] is kept in
/// step so the page's legend mutes whatever isn't in here yet.
enum _LatinLetter {
  a('A', 'a', 'ay', 'a'),
  b('B', 'b', 'bee', 'b'),
  c('C', 'c', 'see', 'k, s'),
  d('D', 'd', 'dee', 'd'),
  e('E', 'e', 'ee', 'e'),
  f('F', 'f', 'ef', 'f'),
  g('G', 'g', 'gee', 'g'),
  h('H', 'h', 'aitch', 'h'),
  i('I', 'i', 'eye', 'i'),
  j('J', 'j', 'jay', 'j'),
  k('K', 'k', 'kay', 'k'),
  l('L', 'l', 'el', 'l'),
  m('M', 'm', 'em', 'm'),
  n('N', 'n', 'en', 'n'),
  o('O', 'o', 'oh', 'o'),
  p('P', 'p', 'pee', 'p'),
  q('Q', 'q', 'cue', 'kw'),
  r('R', 'r', 'ar', 'r'),
  s('S', 's', 'ess', 's'),
  t('T', 't', 'tee', 't'),
  u('U', 'u', 'you', 'u'),
  v('V', 'v', 'vee', 'v'),
  w('W', 'w', 'double-u', 'w'),
  x('X', 'x', 'ex', 'ks'),
  y('Y', 'y', 'wy', 'y'),
  z('Z', 'z', 'zed', 'z'),
  sharpS('ß', 'ß', 'sharp s', 'ss'),
  ash('Æ', 'æ', 'ash', 'ae'),
  oSlash('Ø', 'ø', 'o-slash', 'oe'),

  // The marked letters. Each is its own letter with its own glyph, but none has
  // a classifier of its own: one classifier per mark reads them all, off a table
  // of which base each mark may sit over (see [LatinLayer._markedLetter]).
  aAcute('Á', 'á', 'a-acute', 'a'),
  eAcute('É', 'é', 'e-acute', 'e'),
  iAcute('Í', 'í', 'i-acute', 'i'),
  oAcute('Ó', 'ó', 'o-acute', 'o'),
  uAcute('Ú', 'ú', 'u-acute', 'u'),
  yAcute('Ý', 'ý', 'y-acute', 'y'),

  aGrave('À', 'à', 'a-grave', 'a'),
  eGrave('È', 'è', 'e-grave', 'e'),
  iGrave('Ì', 'ì', 'i-grave', 'i'),
  oGrave('Ò', 'ò', 'o-grave', 'o'),
  uGrave('Ù', 'ù', 'u-grave', 'u'),

  aCircumflex('Â', 'â', 'a-circumflex', 'a'),
  eCircumflex('Ê', 'ê', 'e-circumflex', 'e'),
  iCircumflex('Î', 'î', 'i-circumflex', 'i'),
  oCircumflex('Ô', 'ô', 'o-circumflex', 'o'),
  uCircumflex('Û', 'û', 'u-circumflex', 'u'),

  aTilde('Ã', 'ã', 'a-tilde', 'an'),
  nTilde('Ñ', 'ñ', 'n-tilde', 'ny'),
  oTilde('Õ', 'õ', 'o-tilde', 'on'),

  aDiaeresis('Ä', 'ä', 'a-diaeresis', 'ae'),
  eDiaeresis('Ë', 'ë', 'e-diaeresis', 'e'),
  iDiaeresis('Ï', 'ï', 'i-diaeresis', 'i'),
  oDiaeresis('Ö', 'ö', 'o-diaeresis', 'oe'),
  uDiaeresis('Ü', 'ü', 'u-diaeresis', 'ue'),
  yDiaeresis('Ÿ', 'ÿ', 'y-diaeresis', 'y'),

  aRing('Å', 'å', 'a-ring', 'aa'),

  // Marks that aren't above the letter, and letters of their own.
  cedilla('Ç', 'ç', 'cedilla', 's'),
  sCedilla('Ş', 'ş', 's-cedilla', 'sh'),
  eth('Ð', 'ð', 'eth', 'dh'),
  ethel('Œ', 'œ', 'ethel', 'oe'),
  thorn('Þ', 'þ', 'thorn', 'th'),

  // D-with-stroke: the same capital glyph as [eth], told apart only by which
  // alphabet is in play. See [LatinLayer._classifyDStroke].
  dStroke('Đ', 'đ', 'd-stroke', 'd'),

  // Latin Extended-A: the marks already read, over bases that hadn't taken them.
  cAcute('Ć', 'ć', 'c-acute', 'ch'),
  lAcute('Ĺ', 'ĺ', 'l-acute', 'l'),
  nAcute('Ń', 'ń', 'n-acute', 'ny'),
  rAcute('Ŕ', 'ŕ', 'r-acute', 'r'),
  sAcute('Ś', 'ś', 's-acute', 'sh'),
  zAcute('Ź', 'ź', 'z-acute', 'zh'),

  cCircumflex('Ĉ', 'ĉ', 'c-circumflex', 'ch'),
  gCircumflex('Ĝ', 'ĝ', 'g-circumflex', 'j'),
  hCircumflex('Ĥ', 'ĥ', 'h-circumflex', 'kh'),
  jCircumflex('Ĵ', 'ĵ', 'j-circumflex', 'zh'),
  sCircumflex('Ŝ', 'ŝ', 's-circumflex', 'sh'),
  wCircumflex('Ŵ', 'ŵ', 'w-circumflex', 'w'),
  yCircumflex('Ŷ', 'ŷ', 'y-circumflex', 'y'),

  uRing('Ů', 'ů', 'u-ring', 'oo'),

  // Caron — a V above.
  cCaron('Č', 'č', 'c-caron', 'ch'),
  dCaron('Ď', 'ď', 'd-caron', 'dy'),
  eCaron('Ě', 'ě', 'e-caron', 'ye'),
  lCaron('Ľ', 'ľ', 'l-caron', 'ly'),
  nCaron('Ň', 'ň', 'n-caron', 'ny'),
  rCaron('Ř', 'ř', 'r-caron', 'rzh'),
  sCaron('Š', 'š', 's-caron', 'sh'),
  tCaron('Ť', 'ť', 't-caron', 'ty'),
  zCaron('Ž', 'ž', 'z-caron', 'zh'),

  // Breve — read by the caron's own classifier, and deliberately not told apart
  // from it. The two are the same gesture, a V above the letter, differing only
  // in whether it comes to a point or turns across a span; but no alphabet has
  // both marks, and no base takes both. Romanian, Turkish and Esperanto own
  // these three and have no caron letter between them, where the caron's own
  // nine belong to alphabets with no breve. So the alphabet separates them, as
  // it does Ð from Đ, and the shape test doesn't have to. See [_caronOver].
  // Ogonek — two legs to and fro, hung across the letter's foot.
  aOgonek('Ą', 'ą', 'a-ogonek', 'on'),
  eOgonek('Ę', 'ę', 'e-ogonek', 'en'),
  iOgonek('Į', 'į', 'i-ogonek', 'ee'),
  uOgonek('Ų', 'ų', 'u-ogonek', 'uu'),

  aBreve('Ă', 'ă', 'a-breve', 'uh'),
  gBreve('Ğ', 'ğ', 'g-breve', 'gh'),
  uBreve('Ŭ', 'ŭ', 'u-breve', 'w'),

  // Dot above — a single tap.
  cDot('Ċ', 'ċ', 'c-dot', 'ch'),
  eDot('Ė', 'ė', 'e-dot', 'e'),
  gDot('Ġ', 'ġ', 'g-dot', 'j'),
  iDot('İ', 'i̇', 'i-dot', 'i'),
  zDot('Ż', 'ż', 'z-dot', 'zh'),

  // Middle dot — a tap inside L's own box.
  lMiddleDot('Ŀ', 'ŀ', 'l-middle-dot', 'l'),

  // Comma below — the acute's own line, hung under the letter instead.
  //
  // Romanian's two are named for the comma, Latvian's four for the cedilla,
  // and that follows Unicode rather than any difference in shape: Ģ Ķ Ļ Ņ are
  // "WITH CEDILLA" by name (U+0122, U+0136, U+013B, U+0145), a name inherited
  // from ISO 8859-4, but the Latvian glyph the standard specifies is a comma.
  // Ș and Ț were given code points of their own precisely because the older
  // Ş and Ţ carry a true cedilla, so all six hang under the letter here and
  // Turkish's Ş goes with Ç instead.
  sComma('Ș', 'ș', 's-comma', 'sh'),
  tComma('Ț', 'ț', 't-comma', 'ts'),
  gCedilla('Ģ', 'ģ', 'g-cedilla', 'gy'),
  kCedilla('Ķ', 'ķ', 'k-cedilla', 'ky'),
  lCedilla('Ļ', 'ļ', 'l-cedilla', 'ly'),
  nCedilla('Ņ', 'ņ', 'n-cedilla', 'ny'),

  // Macron — a flat bar above.
  aMacron('Ā', 'ā', 'a-macron', 'aa'),
  eMacron('Ē', 'ē', 'e-macron', 'ee'),
  iMacron('Ī', 'ī', 'i-macron', 'ii'),
  uMacron('Ū', 'ū', 'u-macron', 'uu'),

  // Double acute — two of them, side by side above.
  oDoubleAcute('Ő', 'ő', 'o-double-acute', 'eu'),
  uDoubleAcute('Ű', 'ű', 'u-double-acute', 'ue'),

  // H with a stroke: Maltese's, an H with a second bar above its own.
  hStroke('Ħ', 'ħ', 'h-stroke', 'h'),
  lStroke('Ł', 'ł', 'l-stroke', 'w');

  const _LatinLetter(this.capital, this.small, this.letterName, this.sound);

  final String capital;
  final String small;
  final String letterName;
  final String sound;
}

/// Freehand recognition of printed (block) Latin-script capitals — all 26 of
/// A–Z, plus the Å, Ä and Ö that Finnish and Swedish add and the Ü that German
/// does:
///
/// - **A** — two strokes: a stroke that rises then falls (Λ, the letter's
///   two splayed legs), and a horizontal bar crossing each of those legs
///   exactly once (see [LatinLayer._classifyA]).
/// - **B** — two strokes: an upright stem standing to the left, and a
///   right-left-right-left stroke laid against it — the two bowls, each
///   joining the stem at both ends — meeting it 3 or 4 times (see
///   [LatinLayer._classifyB]).
/// - **C** — one stroke running left then back right, both its ends
///   finishing to the right of its own centre, and crossing neither its
///   own path nor anything else on the page (see
///   [LatinLayer._classifyC]).
/// - **D** — two strokes: an upright stem, and a bowl running right then
///   back left that crosses it twice, at the stem's top and at its *foot* —
///   B and P's shape without the join at the middle (see
///   [LatinLayer._classifyD]).
/// - **E** — four strokes: an upright stem standing to the left, and three
///   horizontal bars meeting it once each — one up at its top, one across
///   its middle, one down at its foot (see [LatinLayer._classifyE]).
/// - **F** — three strokes: E's own stem and E's own top two bars, with the
///   bottom one left off — so one bar up at the stem's top and one across
///   its middle, and nothing at its foot (see [LatinLayer._classifyF]).
/// - **G** — two strokes: C's own arc, finished by a ㄱ-shaped corner — elbow
///   at the top right — meeting the arc at one of its *terminals* rather than
///   partway along it (see [LatinLayer._classifyG]).
/// - **H** — three strokes: two upright stems and a horizontal bar crossing
///   each of them once, with the two crossings falling on opposite sides of
///   the bar's own centre (see [LatinLayer._classifyH]).
/// - **I** — one stroke: a plain upright line, crossing nothing at all (see
///   [LatinLayer._classifyI]). The loosest shape here by a wide margin, and
///   last of all in [LatinLayer._classify] for it — nearly every letter
///   above begins with a stem, so an unfinished one reads as an I until its
///   next stroke lands.
/// - **J** — one stroke: V's own falling-then-rising stroke drawn lopsided,
///   its left end below the middle of its own bounding box and its right end
///   above it — the stem coming down on the right, the hook curling up on the
///   left (see [LatinLayer._classifyJ]).
/// - **K** — two strokes: an upright stem, and an arm running left and then
///   right — in to meet the stem, then away again — hanging off the stem's
///   right and crossing it once or twice (see [LatinLayer._classifyK]).
///   The arm is C's arc with a stem laid against it, which is the whole of
///   what separates the two.
/// - **L** — one stroke: a right-angle bend with its elbow at the bottom
///   left, so the upright stands on the left and the foot runs right from it
///   — Hangul's ㄴ (see [LatinLayer._classifyL]).
/// - **M** — one stroke that rises, falls, rises and falls again — the two
///   peaks and the valley between them — crossing nothing, its own path
///   included (see [LatinLayer._classifyM]).
/// - **N** — one stroke of three vertical legs, its outer two upright stems
///   and the one between them a diagonal that *falls* to the right, and
///   crossing nothing at all (see [LatinLayer._classifyN]). That falling
///   diagonal is the only thing separating it from Cyrillic И, the same
///   letter with its diagonal rising instead.
/// - **O** — one stroke that crosses its own path exactly once — a closed
///   loop — and crosses nothing else on the page (see
///   [LatinLayer._classifyO]).
/// - **P** — D's own stem and bowl, with the stem standing clear *below* the bowl
///   but not above it (see [LatinLayer._classifyP]). It's a B with only the upper
///   of its two bowls, and whether the stem sticks out at each end is all that
///   separates it from D and Þ — see [LatinLayer._outerQuarter] for the table.
/// - **Q** — two strokes: an O's ring with a descending tail crossing it,
///   every crossing down in the ring's lower half (see
///   [LatinLayer._classifyQ]).
/// - **R** — two strokes: an upright stem, and Z's own shape to its right —
///   across the top of the bowl, home to the stem, then away down the leg —
///   meeting it 2 or 3 times on the way (see [LatinLayer._classifyR]).
/// - **S** — one stroke of three legs to and fro with its spine leaning `\`
///   ([LatinLayer._isSShaped]) — Z's own shape with that one leg leaning the
///   other way — crossing nothing at all (see [LatinLayer._classifyS]).
/// - **T** — two strokes: a horizontal bar with an upright stem hanging
///   below its *middle* ([LatinLayer._junctionSnap], see
///   [LatinLayer._classifyT]). Where along the bar the stem hangs is the
///   whole of the shape — hung off the bar's left end it is no Latin
///   letter at all.
/// - **U** — V's own falling-then-rising stroke, but turning across a real
///   share of its width at the bottom instead of converging to a point (see
///   [LatinLayer._classifyU] / [LatinLayer._turnWidth]).
/// - **V** — one stroke falling then rising, crossing nothing at all, with
///   *both* its ends up above the middle of its box — A's Λ upside down,
///   standing on its own without the stem that would make it a Y, rising on
///   both sides where J rises only on one, and coming to a point where U turns
///   across a span (see [LatinLayer._classifyV]).
/// - **W** — M's own stroke upside down: one stroke falling, rising, falling
///   and rising again — the two valleys and the peak between them —
///   crossing nothing at all (see [LatinLayer._classifyW]).
/// - **X** — two strokes crossing once, one rising to the right and one
///   falling, read off their endpoints alone (see
///   [LatinLayer._classifyX]).
/// - **Y** — two strokes: a V — one stroke falling then rising — with an
///   upright stem hanging below its vertex rather than off either arm (see
///   [LatinLayer._classifyY]). The V is A's Λ upside down.
/// - **Z** — one stroke of three legs to and fro with its diagonal leaning `/`
///   ([LatinLayer._isZShaped]) — the top bar, the diagonal, then the bottom
///   bar — crossing nothing at all (see [LatinLayer._classifyZ]).
/// - **Æ** — three strokes: a body carrying both letters' uprights at once — up
///   A's left leg, then down and away as an L — and two horizontal bars across
///   it, the lower crossing both uprights and the upper meeting the body
///   somewhere. At least three crossings in all (see
///   [LatinLayer._classifyAe] / [LatinLayer._aeBody]).
/// - **Ø** — two strokes: an O's ring with a straight line rising to the right
///   slashed through it, crossing it once on each side of the ring's own middle,
///   so at least twice in all (see [LatinLayer._classifyOSlash]).
/// - **ß** — two strokes: an upright stem on the left, and the very stroke B is
///   built from laid against it, but meeting it exactly *once*, up in the stem's
///   top third (see [LatinLayer._classifySharpS]). B's bowls each join the stem
///   at both ends; ß's leave it at the top and never return.
/// - **Ç** — two strokes: C's own arc with a cedilla hung off it, a stroke of
///   three legs to and fro crossing the arc down in its bottom third and carrying
///   on below it (see [LatinLayer._classifyCedilla]). The one mark here that
///   isn't above its letter, and it needs no notion of *below*: it is located by
///   where it crosses what it marks.
/// - **Ð** — three strokes: a D, with a horizontal bar crossing its stem across
///   the middle third (see [LatinLayer._classifyEth]).
/// - **Þ** — the stem and bowl again, with *both* crossings in the stem's middle
///   third — neither at its top nor at its foot, where D and P take theirs (see
///   [LatinLayer._classifyThorn]).
/// - **Œ** — three strokes: the O's bowl as C's own arc, an upright run down
///   through its middle crossing it twice, and a horizontal bar off that
///   upright's middle third meeting nothing else (see
///   [LatinLayer._classifyEthel]). One bar rather than E's three — an improvised
///   Œ rather than a faithful one.
/// - **Å** — an A with a ring above it: a loop sitting clear above the A's own
///   bounding box and within its run of widths (see
///   [LatinLayer._classifyARing]). The only letter here whose mark is a stroke
///   rather than a tap.
/// - **Ä**, **Ö**, **Ü** — an A, an O or a U with a diaeresis above it: a pair of
///   taps sitting clear above the letter's own bounding box and within its run of
///   widths (see [LatinLayer._hasDiaeresisOver]). The only letters here built
///   from taps rather than drags, and the reason taps are captured at all. One
///   mark over three letters, written by Finnish, Swedish and German alike.
///
/// Stroke direction is deliberately not checked, and neither is stroke
/// order. A C written top-to-bottom and one written bottom-to-top are the
/// same letter to any reader, so the shape tests work off where a stroke's
/// ends and turns land rather than off which way the hand travelled; E's
/// four strokes, F's and H's three, and B's, P's, R's, K's, T's, X's and
/// Y's two all sort themselves by their own shape rather than by when they
/// arrived, and O doesn't care which way round the loop was swept.
///
/// A, M, N, W and Y are all read off the same primitive — cut the stroke
/// wherever it reverses along one axis and look at the run of legs that
/// leaves ([LatinLayer._verticalLegs]) — and differ only in their pattern:
/// up-down for A's Λ, down-up for Y's V, up-down-up-down for M's two peaks,
/// that inverted for W's two valleys, and three alternating legs for N. Each
/// pattern is its own letter and no other's, whichever way the hand went, so
/// this one cut does the work of six shape tests. B, C, D, K, P, R, S and Z cut
/// the same way horizontally instead ([LatinLayer._horizontalLegs]), which is
/// why any of them can be a curly shape and still be read off a run of legs:
/// right-left-right-left for B's pair of bowls, right-left for the single
/// bowl D and P share, and left-right for the arc that is C on its own and K's
/// arm when a stem stands beside it.
///
/// The three-leg shapes — R's bowl-and-leg, Z, S — are the exception, and can't
/// be spelled out that way at all. Reversing a stroke reverses the order of its
/// legs *and* flips each one's direction, and on an odd number of legs those
/// two don't cancel: a Z drawn bottom-up leaves exactly the run of legs an S
/// drawn top-down leaves. So [LatinLayer._isThreeLegged] asks instead which way
/// the middle leg *leans* — `/` for Z and R's body, `\` for S — reading it as a
/// line rather than as a direction, the same measurement that separates N from
/// Cyrillic И.
///
/// Where a run of legs leaves two shapes alike, a second measurement divides
/// them, and it is always the same kind: locate the crossings and ask where along
/// the stem they land. E and F divide the stem's thirds between them, three bars
/// against two; D, P and Þ divide it by whether the stem stands clear of the bowl
/// at each end (see [LatinLayer._outerQuarter]). Which is why
/// [LatinLayer._bowlCrossings] hands back measurements rather than a verdict.
///
/// N needs one thing more than its run of legs, upright outer legs, because
/// a circle drawn not quite closed also falls, rises and falls — entering
/// and leaving on its own right-hand side — and only the stems tell the two
/// apart.
///
/// Two strokes meeting and one stroke crossing itself are counted
/// differently on purpose. T's stem running into its bar is a T-junction —
/// whether the pen overshoots by a pixel or stops a pixel short is noise,
/// so [LatinLayer._contacts] counts runs of near-contact
/// ([LatinLayer._touchTolerance]). A loop genuinely crosses its own path,
/// so [LatinLayer._selfIntersections] counts real segment intersections and
/// an unclosed circle is correctly not an O.
///
/// Recognition is live and non-destructive — it re-reads the most recently
/// completed stroke(s) after every stroke, and everything drawn stays on
/// the page whether or not it matched.
class LatinLayer extends Layer {
  /// A press-and-release shorter than this is a tap, not a drag — a dot rather
  /// than a stroke. Ä's and Ö's diaereses are the only things built from them,
  /// and they're why taps are kept at all.
  static const double _tapThreshold = 5;

  /// How large a tapped dot is drawn. Nothing measures against it; it's only so
  /// a tap leaves something on the page to see.
  static const double _dotRadius = 5;

  /// Shortest drag that counts as a deliberate stroke rather than a slipped
  /// tap. Between this and [_tapThreshold] a press-and-release is read as
  /// neither, and leaves no mark.
  static const double _minDragDistance = 8;

  /// How much taller than wide a stroke must be to read as vertical. A
  /// plain `|dy| > |dx|` would accept a 45°-ish diagonal, which belongs to
  /// a different letter (A's own splayed legs, for one).
  static const double _verticalRatio = 2;

  /// The same margin the other way round. Deliberately equal to
  /// [_verticalRatio]: a line slanted enough to be ambiguous should match
  /// neither orientation, rather than falling to whichever check happens
  /// to run first.
  static const double _horizontalRatio = 2;

  /// How far a stroke may bow off its own straight start-to-end chord and
  /// still read as a straight line: the larger of [_minStraightSlack] and
  /// this fraction of the chord's length. It's what keeps a curve or a
  /// hook from passing for E's stem or one of its bars.
  static const double _straightTolerance = 0.12;
  static const double _minStraightSlack = 6;

  /// How close two strokes must come to count as touching (see [_touches]).
  /// T's stem meets its bar in a junction rather than a crossing, so a
  /// strict segment-intersection test would turn on whether the hand
  /// happened to overshoot by a pixel — a stem stopping just short of the
  /// bar is the same letter to any reader.
  static const double _touchTolerance = 22;

  /// Where along the bar T's stem may hang and still count as hanging from
  /// its middle, as a distance from the bar's centre given as a fraction of
  /// the bar's width (see [_classifyT]). A stem out at either end of the
  /// bar is no Latin letter, so it should match nothing rather than fall
  /// through to T.
  static const double _junctionSnap = 0.25;

  /// The least a corner's bounding box may span on each axis. Below this the
  /// "corner" is really a near-horizontal or near-vertical kink, where which
  /// box corner the elbow sits in is noise.
  static const double _minCornerLeg = 15;

  /// How far the elbow may sit from its bounding-box corner, as a fraction of
  /// the box, and still commit to that corner. Two axis-aligned legs put the
  /// elbow *at* the corner, so this only absorbs the rounding of a
  /// hand-drawn bend — it's not enough slack to let a bottom-left elbow pass
  /// for a top-right one. It's also what rejects a smooth quarter arc bending
  /// an L's way, whose deepest point sits a quarter of the way along the box
  /// rather than in its corner: a bend has to actually be squared off to read
  /// as a letter.
  static const double _cornerSnap = 0.2;

  /// How much of a falling-then-rising stroke's height, measured up from its
  /// foot, counts as the turn at the bottom — the band [_turnWidth] measures
  /// across to tell a U from a V. The lower half of the letter.
  static const double _bottomBand = 0.5;

  /// How much of its own width that turn must span for the stroke to read as a
  /// U rather than a V.
  ///
  /// A V whose two ends are level spans *exactly* half its width in this band,
  /// whatever its proportions and even with its apex off to one side: halving
  /// the height halves whatever horizontal convergence is left. But level ends
  /// are what makes that exact, and a V drawn with one arm reaching higher than
  /// the other reads wider — the shorter arm is further along by the time the
  /// band starts, so it has converged more and the span it leaves is a larger
  /// share of a box whose width the two ends still set. A third of the height
  /// between the ends already brings it to about 0.62.
  ///
  /// Hence 0.7 rather than something just clear of a half. A U turns across
  /// 0.83 of its width even with its arms splayed, and the whole of it when they
  /// stand plumb, so there is still room either side.
  ///
  /// A narrower [_bottomBand] would need less of a margin here, since close to
  /// the foot a V's arms have converged almost to the apex however uneven they
  /// are — it measures the turn itself rather than the letter's overall taper.
  static const double _minTurnWidth = 0.7;

  /// How much of a stem must stand clear of its bowl to count as sticking out —
  /// a quarter of the stem's own height, at either end.
  ///
  /// This one number separates D, P and Þ, and it does it by asking the only
  /// question that really tells them apart: does the stem stick out above the
  /// bowl, and does it stick out below?
  ///
  /// | | above | below | |
  /// |---|---|---|---|
  /// | D | no | no | the bowl reaches both ends |
  /// | P | no | yes | the bowl sits at the top |
  /// | Þ | yes | yes | the bowl sits in the middle |
  /// | — | yes | no | a bowl hung at the foot: no letter here |
  ///
  /// A partition of the two overhangs, so no drawing answers two of them and
  /// their order in [_classify] doesn't matter. It replaced a scheme of thirds
  /// and sixths that was neither: measured that way a P whose bowl started a
  /// sixth of the way down — which is nothing, on a hand-drawn letter — was
  /// claimed by Þ before P was ever asked.
  ///
  /// A quarter is what makes both robust. P and D may fall short of the stem's
  /// ends by up to a quarter, which is all the slack a hand needs, and Þ's bowl
  /// still has the stem's middle half to sit in, which is about what print gives
  /// it.
  static const double _outerQuarter = 0.25;

  /// How far a stroke must double back vertically before that counts as
  /// changing direction rather than as the hand wobbling (see
  /// [_verticalLegs]). Without it every tremor along a long stem would
  /// split off a leg of its own, and A's two legs would come out as a
  /// dozen.
  static const double _directionSlack = 6;

  /// How far one stroke must sit clear of another to count as being on its
  /// left or its right. A bowl centred on a stem is a different shape, so
  /// it should match nothing rather than fall through on whichever side
  /// happened to win by a pixel.
  static const double _minSideOffset = 6;

  /// Which letters the recognizer supports, matched against [LetterRow.name].
  /// Kept in step with [_LatinLetter] — used by [LatinPage] to mute the letters
  /// that can't be drawn yet rather than listing them as if they could.
  ///
  /// Which letters may be reported, matched against [LetterRow.name]. Kept in
  /// step with [_LatinLetter] — used by [LatinPage] to mute the letters an
  /// alphabet lists but the recognizer can't draw.
  ///
  /// Every letter of every alphabet — nothing in any legend is muted any more.
  /// The set is kept rather than dropped so a letter can be taken back out, or a
  /// new one staged, without the page having to change.
  static const recognizedNames = {
    'ay', 'bee', 'see', 'dee', 'ee', 'ef', 'gee', 'aitch', 'eye', 'jay', 'kay',
    'el', 'em', 'en', 'oh', 'pee', 'cue', 'ar', 'ess', 'tee', 'you', 'vee',
    'double-u', 'ex', 'wy', 'zed',
    'ash', 'o-slash', 'sharp s',
    'a-acute', 'e-acute', 'i-acute', 'o-acute', 'u-acute', 'y-acute',
    'a-grave', 'e-grave', 'i-grave', 'o-grave', 'u-grave',
    'a-circumflex', 'e-circumflex', 'i-circumflex', 'o-circumflex',
    'u-circumflex',
    'a-tilde', 'n-tilde', 'o-tilde',
    'a-diaeresis', 'e-diaeresis', 'i-diaeresis', 'o-diaeresis', 'u-diaeresis',
    'y-diaeresis',
    'a-ring', 'cedilla', 'eth', 'ethel', 'thorn',
    // Latin Extended-A.
    'd-stroke',
    'c-acute', 'l-acute', 'n-acute', 'r-acute', 's-acute', 'z-acute',
    'c-circumflex', 'g-circumflex', 'h-circumflex', 'j-circumflex',
    's-circumflex', 'w-circumflex', 'y-circumflex',
    'u-ring',
    'c-caron', 'd-caron', 'e-caron', 'l-caron', 'n-caron', 'r-caron',
    's-caron', 't-caron', 'z-caron', 'a-breve', 'g-breve', 'u-breve',
    'a-ogonek', 'e-ogonek', 'i-ogonek', 'u-ogonek',
    'c-dot', 'e-dot', 'g-dot', 'i-dot', 'z-dot',
    'l-middle-dot',
    's-comma', 't-comma', 'g-cedilla', 'k-cedilla', 'l-cedilla', 'n-cedilla',
    'a-macron', 'e-macron', 'i-macron', 'u-macron',
    'o-double-acute', 'u-double-acute',
    'h-stroke', 'l-stroke', 's-cedilla',
  };

  final List<_Stroke> _strokes = [];
  final List<Offset> _dots = [];
  _LatinLetter? _recognized;
  List<Offset>? _activePoints;
  Alphabet _alphabet = Alphabet.english;

  /// Which alphabet's letters may be reported. The shape tests are the same
  /// either way — this only decides which of their answers counts, so a drawing
  /// the chosen alphabet has no letter for falls through to whatever the next
  /// classifier makes of it (see [_classify]).
  ///
  /// Setting it re-reads whatever is already on the page, so switching mid-
  /// drawing settles the readout there and then rather than waiting for another
  /// stroke.
  Alphabet get alphabet => _alphabet;

  set alphabet(Alphabet value) {
    if (value == _alphabet) return;
    _alphabet = value;
    if (_strokes.isNotEmpty) _recognized = _classify();
  }

  /// The capital currently being reported, or null if the drawing matches
  /// no letter. The letters themselves are private ([_LatinLetter]); this
  /// exposes just enough of the result for tests to assert on what a given
  /// sequence of strokes recognizes as.
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
        // A dot re-reads the page just as a stroke does, so the A already
        // sitting there turns into an Ä the moment its second dot lands.
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
  /// Only ever called from [_commit], with the just-drawn stroke already
  /// appended — which is what lets the single-stroke classifiers read
  /// [_strokes.last] outright.
  ///
  /// A letter the current [alphabet] hasn't got is passed over rather than
  /// returned, and the next classifier gets its turn on the same drawing — so
  /// in [Alphabet.latin], which has no U, a U's own stroke falls through to the
  /// V that Latin would have written for it, and in [Alphabet.english], which
  /// has no Á, an acute over an A falls through to the plain A.
  ///
  /// O and I come last, in that order, and have to. O asks for nothing but a
  /// single self-crossing, and a one-stroke letter picks one of those up
  /// whenever the hand closes a join it didn't have to. I is looser again — a
  /// bare upright, which is the *first* stroke of E, F, H, B, P, R, T and K
  /// alike. So every letter with a shape of its own gets first refusal, then O,
  /// then I. A new classifier goes above them, never below.
  _LatinLetter? _classify() {
    // Dots alone are no letter, and a tap can reach here with nothing drawn —
    // which the single-stroke classifiers, reading [_strokes.last] outright,
    // would take badly.
    if (_strokes.isEmpty) return null;
    for (final classifier in [
      // The marked letters, all ahead of their bases: take the mark away and the
      // base is exactly what is left, so every one of these would otherwise be
      // read as the letter it is built on.
      //
      // The ring comes before the tilde, the two being the only pair among them
      // that can answer each other's mark: a ring swept up from its foot leaves
      // the same three legs a tilde does. Otherwise the six are disjoint — a
      // straight line is not a Λ, a Λ is not three legs, rising is not falling,
      // and taps are not strokes at all.
      _classifyRing,
      _classifyTilde,
      // Ahead of the acute for clarity rather than need — two marks are the more
      // particular claim, and the acute declines a doubled one anyway.
      _classifyDoubleAcute,
      _classifyAcute,
      _classifyGrave,
      // The caron and the circumflex are one shape inverted — a V above against a
      // Λ above — so [_hasLegs] tells them apart and their order is free.
      _classifyCaron,
      _classifyCircumflex,
      // Two dots before one: the diaeresis reads the last *pair* of dots and this
      // reads the last dot alone, so a pair above the letter has to be offered as a
      // diaeresis first or a lone dot would answer for it.
      _classifyDiaeresis,
      _classifyDotAbove,
      _classifyMiddleDot,
      // The only mark that hangs below its letter. It shares the acute's shape and
      // is told from it by nothing but that, so it can sit anywhere among these.
      _classifyCommaBelow,
      _classifyOgonek,
      // A bar above. It can sit here, ahead of T and E and the rest whose own bars
      // it resembles, only because it asks to hover clear of the letter where
      // theirs meet it — see _classifyMacron.
      _classifyMacron,
      // Ahead of A, whose up-down its body answers as readily as a Λ does: the
      // body with either of its bars across it is an A to that test.
      _classifyAe,
      // Ahead of H and F both, which it contains: drop either of Ħ's bars and an H
      // is what's left, and three of its strokes are an upright with two bars,
      // which is an F.
      _classifyHStroke,
      _classifyE,
      // Ahead of I and of T, both of which E's own pieces would otherwise
      // answer on the way. F is E's stem and E's top two bars, so drawing
      // an E reads as an F on its third stroke and settles on E with its
      // fourth — which is the live readout doing its job, not a clash.
      _classifyF,
      _classifyH,
      // Ahead of D and B: drop Ð's bar and a D is exactly what's left.
      //
      // Đ follows it because the two are the *same capital glyph* — a D with a bar
      // through the stem — and only their lowercase differs. No shape test can
      // separate them, and none needs to: no alphabet has both, so the eth is
      // offered first and passed over where Ð isn't a letter, and Đ answers for
      // Croatian.
      _classifyEth,
      _classifyDStroke,
      // B and R need no ordering against the rest: B's pair of bowls arrives as
      // one four-leg stroke and R's bowl-and-leg as a three-leg one, where D, P
      // and Þ all take a two-leg bowl, so each turns the others' away on the run
      // of legs alone.
      _classifyB,
      // Beside B rather than before or after it: the two share _isDoubleBowl and
      // divide its crossings, B taking 3 or 4 and ß exactly 1, so neither can
      // claim the other's drawing whichever order they sit in.
      _classifySharpS,
      // D, P and Þ share the single bowl and partition it between them, on
      // whether the stem stands clear above it and below (see _outerQuarter), so
      // their order among themselves doesn't matter either.
      _classifyD,
      _classifyP,
      _classifyThorn,
      _classifyR,
      // Ahead of C, which is K's arm standing on its own: only the stem
      // beside it says otherwise, so a K put after C would be read as the
      // arc it contains.
      // Ahead of K, for the off-centre seam — see _classifyEthel.
      _classifyEthel,
      _classifyK,
      // Ahead of C, whose arc it is built on: G's spur meets that arc at its
      // tip rather than crossing it, so C's "crosses nothing else" test would
      // otherwise let a finished G through as the arc it contains.
      _classifyG,
      // Beside G, the other letter built on C's arc — the two can't be confused,
      // G's spur meeting the arc at a tip where the cedilla crosses it low down.
      _classifyCedilla,
      // Ø and Q need no ordering between them, and are disjoint twice over: Q
      // wants every crossing down in the ring's lower half where Ø wants one
      // above it, and Q's tail falls to the right where Ø's slash rises.
      _classifyOSlash,
      _classifyQ,
      _classifyA,
      // Ahead of V, which is Y's own V without the stem.
      _classifyY,
      _classifyT,
      // Above both X and L, and X is the reason it can't simply sit beside L:
      // an L's stroke slants down to the right taken end to end, and the bar
      // through it rises, so the pair is two opposite slants crossing once.
      _classifyLStroke,
      // After T, which it would otherwise claim: no hand draws a bar
      // exactly level or a stem exactly plumb, and a pair leaning by a
      // pixel each reads as two opposite slants that cross. It's the
      // loosest of the two-stroke shapes and sits last among them for that
      // reason.
      _classifyX,
      // M and W need no ordering between them, nor against anything else
      // single-stroke: four alternating legs starting upward is the one, four
      // starting downward is the other, and nothing else here has four.
      _classifyM,
      _classifyW,
      _classifyN,
      _classifyL,
      // A mark over a letter this alphabet hasn't got: report the letter under
      // it. Below every letter with a mark of its own, so only an alphabet that
      // refused them all gets here — but *above* the tail of loose one-stroke
      // letters, because several marks are those letters' own shapes. A caron is
      // a V, a ring is an O, and a mark drawn over a letter an alphabet lacks
      // would otherwise be read as the letter the mark itself looks like rather
      // than as the letter it sits on. That is only safe because this fires on a
      // mark-above-a-base *pair*: a lone V is one stroke and no pair, so V keeps
      // every drawing that is really a V.
      _classifyMarkedBase,
      // Both ahead of V, which asks for a falling-then-rising stroke and
      // nothing more: every J and every U is a V so far as that test can tell.
      // J is lopsided where V is even, U turns across a span where V comes to a
      // point, and V is left as the last word on the shape.
      _classifyJ,
      _classifyU,
      _classifyV,
      _classifyZ,
      _classifyS,
      // Last of the letters with a shape of their own: one stroke and
      // nothing else on the page, which is looser than anything above. A
      // half-drawn letter whose bowl is an arc would otherwise be claimed
      // as a C before the letter it's really part of gets a look.
      _classifyC,
      // Looser than anything above, and in this order between themselves — see
      // the note on this method.
      _classifyO,
      _classifyI,
    ]) {
      final letter = classifier();
      if (letter != null && _alphabet.letters.contains(letter.capital)) {
        return letter;
      }
    }
    return null;
  }

  /// Whether the last two strokes form A (see [_isA]).
  _LatinLetter? _classifyA() =>
      _strokes.length >= 2 &&
              _isA(_strokes[_strokes.length - 2], _strokes.last)
          ? _LatinLetter.a
          : null;

  /// Whether [a] and [b] between them form an A: a stroke that rises then falls
  /// — Λ, the letter's two splayed legs — plus a straight horizontal bar
  /// crossing each of those legs exactly once. Checking the two legs separately
  /// rather than counting two crossings against the whole Λ is what rules out a
  /// bar that clips one leg twice and misses the other. Either order works.
  ///
  /// Taken as a pair rather than read off the end of [_strokes], because Å needs
  /// the same question asked of a pair that isn't the last two — its ring may
  /// have been drawn after them.
  bool _isA(_Stroke a, _Stroke b) {
    final _Stroke apex;
    final _Stroke bar;
    if (_isBar(a) && _hasLegs(b, const [_Leg.up, _Leg.down])) {
      bar = a;
      apex = b;
    } else if (_isBar(b) && _hasLegs(a, const [_Leg.up, _Leg.down])) {
      bar = b;
      apex = a;
    } else {
      return false;
    }
    for (final leg in _verticalLegs(apex)) {
      if (_crossings(bar, leg) != 1) return false;
    }
    return true;
  }

  /// Which of the letters a mark may sit over [strokes] make, or null if they
  /// make none of them.
  ///
  /// Only the bases that take a mark are here, dispatched on how many strokes
  /// each is written in: C, I, L, N, O, S, U and Z in one; A, D, G, R, T and Y in
  /// two; E in four. It's the counterpart of [_classify] for the letter *under* a
  /// mark, and it's why those fifteen have list-taking predicates ([_isI], [_isA],
  /// [_isE] and the rest) beside their classifiers — a classifier reads off the
  /// end of [_strokes], a predicate takes what it's given, and a mark has to be
  /// set aside.
  ///
  /// Within each size the order mirrors [_classify]'s, loosest last, since the
  /// same shapes overlap here in the same ways: I is a bare upright and O a bare
  /// loop, so both come after everything built on them.
  _LatinLetter? _baseOf(List<_Stroke> strokes) {
    switch (strokes.length) {
      case 1:
        final only = strokes.single;
        if (_isL(only)) return _LatinLetter.l;
        if (_isN(only)) return _LatinLetter.n;
        if (_isZ(only)) return _LatinLetter.z;
        if (_isS(only)) return _LatinLetter.s;
        if (_isW(only)) return _LatinLetter.w;
        if (_isJ(only)) return _LatinLetter.j;
        if (_isU(only)) return _LatinLetter.u;
        if (_isC(only)) return _LatinLetter.c;
        if (_isO(only)) return _LatinLetter.o;
        if (_isI(only)) return _LatinLetter.i;
        return null;
      case 2:
        final a = strokes.first;
        final b = strokes.last;
        if (_isD(a, b)) return _LatinLetter.d;
        if (_isR(a, b)) return _LatinLetter.r;
        if (_isK(a, b)) return _LatinLetter.k;
        if (_isG(a, b)) return _LatinLetter.g;
        if (_isA(a, b)) return _LatinLetter.a;
        if (_isY(a, b)) return _LatinLetter.y;
        if (_isT(a, b)) return _LatinLetter.t;
        return null;
      case 3:
        if (_isH(strokes)) return _LatinLetter.h;
        // E written as an L with two bars — three strokes, so a mark over one
        // has to find it here as well as in the four-stroke case below.
        if (_isE(strokes)) return _LatinLetter.e;
        return null;
      case 4:
        return _isE(strokes) ? _LatinLetter.e : null;
      default:
        return null;
    }
  }

  /// The letter a stroke mark makes, if the last few strokes are one of [over]'s
  /// bases with a stroke satisfying [isMark] sitting clear above it — or null.
  ///
  /// This is what keeps a mark from costing a classifier per letter. One call
  /// reads a whole mark: [over] says which base it may sit over and what each
  /// pairing spells, and [_baseOf] does the reading underneath. Adding a mark is
  /// a predicate and a table; adding a letter to a mark already read is one line
  /// of that table.
  ///
  /// Every base size is tried, since the mark is a stroke of its own and so
  /// competes for the run of strokes a base is read from. Within each size the
  /// mark may be any of them, so it can be drawn before or after the base — it
  /// is found by sitting above the rest ([_sitsAbove]), not by its position in
  /// the run.
  _LatinLetter? _markedLetter(
          bool Function(_Stroke) isMark, Map<_LatinLetter, _LatinLetter> over,
          {bool clearOfBase = false}) =>
      _markedWith(isMark, over, _sitsAbove, clearOfBase: clearOfBase);

  /// The same again, for a mark made of **two** strokes rather than one.
  ///
  /// Only the double acute needs it, being simply two acutes. Both have to satisfy
  /// [isMark] and both have to sit clear above the letter; which two of the recent
  /// strokes they are is found by trying every pair, so they may be drawn in
  /// either order and before or after the letter like any other mark.
  _LatinLetter? _markedTwice(
      bool Function(_Stroke) isMark, Map<_LatinLetter, _LatinLetter> over) {
    for (final size in const [1, 2, 3, 4]) {
      if (_strokes.length < size + 2) continue;
      final recent = _strokes.sublist(_strokes.length - size - 2);
      for (var i = 0; i < recent.length; i++) {
        if (!isMark(recent[i])) continue;
        for (var j = i + 1; j < recent.length; j++) {
          if (!isMark(recent[j])) continue;
          final rest = [
            for (var k = 0; k < recent.length; k++)
              if (k != i && k != j) recent[k],
          ];
          final bounds = _boundsOf([for (final s in rest) ...s.points]);
          if (!_sitsAbove(recent[i].points, bounds)) continue;
          if (!_sitsAbove(recent[j].points, bounds)) continue;
          final base = _baseOf(rest);
          final letter = base == null ? null : over[base];
          if (letter != null) return letter;
        }
      }
    }
    return null;
  }

  /// The same, for a mark hung *below* its letter rather than above it.
  ///
  /// The two differ in one line — which way the mark has to clear the letter — so
  /// they share [_markedWith] and differ only in the placement test they hand it.
  _LatinLetter? _markedBelow(
          bool Function(_Stroke) isMark,
          Map<_LatinLetter, _LatinLetter> over) =>
      _markedWith(isMark, over, _sitsBelow);

  /// A mark hung *across* the foot of its letter, as the ogonek is — the third
  /// placement, beside [_markedLetter]'s above and [_markedBelow]'s below.
  ///
  /// The other two locate a mark by where it sits *relative to* the letter's box,
  /// which works only for a mark that stands clear of it. This one is attached:
  /// it crosses the letter once, low down, and carries on past the foot. So the
  /// box can only be asked the loose question — is the mark centred on it
  /// ([_centred]) — and [_hangsAcross] does the locating against the strokes
  /// themselves.
  ///
  /// The same geometry [_classifyCedilla] reads for Ç and Ş, and the reason that
  /// letter needed a classifier of its own where this doesn't: a cedilla goes on
  /// two bases whose own tests get in the way, where an ogonek's four — A E I U —
  /// are all in [_baseOf] already.
  _LatinLetter? _markedAcross(
          bool Function(_Stroke) isMark,
          Map<_LatinLetter, _LatinLetter> over) =>
      _markedWith(isMark, over, _centred, across: true);

  /// [clearOfBase] additionally asks that the mark not come within
  /// [_touchTolerance] of the letter anywhere — that it *hovers*.
  ///
  /// Only the macron needs it, and it needs it badly: a bar over an upright is a
  /// T and it is also Ī, and nothing in the two shapes separates them. The gap
  /// does. T asks [_touches] of its bar and stem, so between them the two readings
  /// divide every such drawing at [_touchTolerance] — a bar near enough to touch
  /// is a T, one that hovers is a macron — and neither has to be tried before the
  /// other for it to work.
  _LatinLetter? _markedWith(
      bool Function(_Stroke) isMark,
      Map<_LatinLetter, _LatinLetter> over,
      bool Function(List<Offset>, Rect) placed,
      {bool clearOfBase = false, bool across = false}) {
    for (final size in const [1, 2, 3, 4]) {
      if (_strokes.length < size + 1) continue;
      final recent = _strokes.sublist(_strokes.length - size - 1);
      for (var i = 0; i < recent.length; i++) {
        final mark = recent[i];
        if (!isMark(mark)) continue;
        final rest = [
          for (var j = 0; j < recent.length; j++)
            if (j != i) recent[j],
        ];
        final bounds = _boundsOf([for (final s in rest) ...s.points]);
        if (!placed(mark.points, bounds)) continue;
        if (clearOfBase && rest.any((s) => _touches(mark, s))) continue;
        if (across && !_hangsAcross(mark, rest)) continue;
        if (across) _attached = mark;
        final base = _baseOf(rest);
        _attached = null;
        final letter = base == null ? null : over[base];
        if (letter != null) return letter;
      }
    }
    return null;
  }

  /// Á É Í Ó Ú Ý — a straight line rising to the right, above the letter.
  ///
  /// The mark is [_isSlash], the very predicate Ø's slash uses: an acute and a
  /// Ø's slash are the same shape, told apart only by where they sit — one clear
  /// above a letter, the other across a ring.
  _LatinLetter? _classifyAcute() => _markedLetter(_isSlash, _acuteOver);

  /// À È Ì Ò Ù — the acute's own line falling to the right instead.
  _LatinLetter? _classifyGrave() =>
      _markedLetter((s) => _isStraight(s) && _isDescending(s), _graveOver);

  /// Â Ê Î Ô Û — a Λ above the letter, A's own apex in miniature.
  _LatinLetter? _classifyCircumflex() => _markedLetter(
      (s) => _hasLegs(s, const [_Leg.up, _Leg.down]), _circumflexOver);

  /// Ã Ñ Õ — three legs to and fro above the letter.
  ///
  /// That is the run of legs N is read from, which is why a tilde alone is no N:
  /// its outer legs are short slants where N's are upright stems.
  _LatinLetter? _classifyTilde() => _markedLetter(
      (s) => _hasLegs(s, const [_Leg.up, _Leg.down, _Leg.up]), _tildeOver);

  /// Č Ď Ě Ľ Ň Ř Š Ť Ž — a V above the letter, the circumflex's Λ inverted.
  ///
  /// The mark is [_isVee], the very predicate Y's own V and U's turn are built on.
  /// A caron is small, and small is where this gets thin: [_verticalLegs] wants
  /// [_directionSlack] of doubling back before it will see a reversal at all, so a
  /// caron much under a dozen pixels tall reads as one leg and isn't found. Drawn
  /// at a size the eye would call a caron it is comfortable.
  ///
  /// A breve is this same V turning across a span rather than coming to a point —
  /// [_turnWidth]'s distinction, exactly as U is told from V — and is deliberately
  /// not read here. See TODO.md: at mark size the threshold that separates those
  /// two letters doesn't separate the marks.
  _LatinLetter? _classifyCaron() =>
      _markedWith(_isVee, _caronOver, _sitsAboveOrWithin);

  /// Where a caron is allowed to sit: **above** the letter as every other mark
  /// above is, or **within** its bounding box.
  ///
  /// The second is Slovak's Ľ, where the caron isn't a wedge over the letter at
  /// all but a raised stroke tucked against the upright, inside the L's own box.
  /// Czech writes Ď and Ť the same way, and for the same reason: the letters are
  /// tall already and there is no room above. That the box has room *inside* is
  /// what makes it possible — see Ŀ, a dot in the same empty middle.
  ///
  /// Within is the strict test of the two, asking every point of the mark to
  /// fall inside the letter's box, which is why letting the caron use it costs
  /// nothing elsewhere: a V that is part of a letter — Y's own, U's — is as wide
  /// as the letter it belongs to and never fits inside a sibling stroke's box.
  bool _sitsAboveOrWithin(List<Offset> mark, Rect bounds) =>
      _sitsAbove(mark, bounds) || _sitsWithin(mark, bounds);

  bool _sitsWithin(List<Offset> mark, Rect bounds) {
    for (final point in mark) {
      if (!bounds.contains(point)) return false;
    }
    return true;
  }

  /// Ċ Ė Ġ İ Ż — a single tap above the letter.
  ///
  /// After the diaeresis in [_classify], and that ordering is the whole of what
  /// separates one dot from two: this reads the last dot alone, so a pair above the
  /// letter is claimed as a diaeresis first and only a lone dot reaches here. It
  /// follows that the two can't be told apart by counting — see the note on
  /// [_dots] being read whole where strokes are read by the last few.
  _LatinLetter? _classifyDotAbove() {
    if (_dots.isEmpty) return null;
    for (final size in const [1, 2, 3, 4]) {
      if (_strokes.length < size) continue;
      final rest = _strokes.sublist(_strokes.length - size);
      final bounds = _boundsOf([for (final s in rest) ...s.points]);
      if (!_sitsAbove([_dots.last], bounds)) continue;
      final base = _baseOf(rest);
      final letter = base == null ? null : _dotAboveOver[base];
      if (letter != null) return letter;
    }
    return null;
  }

  /// Ő Ű — simply two acutes, side by side above the letter.
  ///
  /// The only mark here made of two strokes, which is the whole of what makes it
  /// its own classifier rather than a row in [_acuteOver]. It reads the same
  /// [_isSlash] the acute does, twice.
  ///
  /// Hungarian's own, and it needs no ordering against the acute: with two marks
  /// on the page the acute's own reading leaves the *other* acute among the base's
  /// strokes, and no base is a lone slanted line, so it declines of its own accord.
  _LatinLetter? _classifyDoubleAcute() =>
      _markedTwice(_isSlash, _doubleAcuteOver);

  /// Ā Ē Ī Ū — a flat bar hovering clear above the letter.
  ///
  /// The one mark whose shape isn't merely *like* a letter's part but *is* one: a
  /// bar over an upright is a T, and a bar over an upright is also Ī. Nothing in
  /// the two shapes tells them apart.
  ///
  /// The gap does, which is what `clearOfBase` is for. A T's bar meets its stem —
  /// [_classifyT] asks [_touches] of them — where a macron hovers. So the two
  /// divide every such drawing between them at [_touchTolerance], and neither
  /// needs to be tried before the other. Ordering would have been the cheaper fix
  /// and the wrong one: it would have made a macron drawn *before* its letter read
  /// as the bare letter, since then the base's own strokes are the last ones on
  /// the page and the base classifier answers first.
  _LatinLetter? _classifyMacron() =>
      _markedLetter(_isBar, _macronOver, clearOfBase: true);

  /// Ș Ț — a straight line rising to the right, hung clear *below* the letter and
  /// centred on it.
  ///
  /// The very shape the acute is, and Ø's slash before it — [_isSlash] reads all
  /// three. Where it sits is the whole of the difference: above the letter it's an
  /// acute, across a ring it's Ø's bar, below the letter it's a comma. Three
  /// letters' worth of meaning out of one gesture and three placements.
  ///
  /// Romanian's Ș and Ț, and Latvian's Ģ Ķ Ļ Ņ. The first mark here to hang under
  /// its letter, which is what [_sitsBelow] and [_markedBelow] exist for; the
  /// ogonek wants the same machinery when its turn comes.
  ///
  /// Latvian's four are "WITH CEDILLA" by their Unicode names, inherited from
  /// ISO 8859-4, but the glyph the standard specifies for Latvian is this comma —
  /// so they belong here and not with [_classifyCedilla], which reads the true
  /// attached cedilla of Ç and Ş. (In lowercase ģ the comma goes *above* the g,
  /// the descender leaving no room beneath. This recognizer draws capitals, so
  /// that never arises.) Romanian and Latvian can share one table because their
  /// bases are disjoint: Latvian has S and T but neither Ș nor Ț, so an S with a
  /// comma under it is turned away by the alphabet and falls through.
  _LatinLetter? _classifyCommaBelow() =>
      _markedBelow(_isSlash, _commaBelowOver);

  /// Ą Ę Į Ų — an ogonek: a stroke of **two** legs to and fro
  /// ([_isOgonek]), hung across the letter's foot, crossing it once and carrying
  /// on below.
  ///
  /// Polish's and Lithuanian's, and the last mark the alphabets here wanted.
  ///
  /// It shares the cedilla's placement and not the comma below's, though all
  /// three hang under the letter: an ogonek is **attached**, where a comma hangs
  /// free. That is what keeps it and the comma apart, and it does the work on its
  /// own — the two shapes differ as well (two legs against a straight line), so
  /// neither ordering nor an alphabet argument is needed here. Compare the breve,
  /// where the shapes really were the same and the alphabet had to settle it.
  ///
  /// Its four bases were all in [_baseOf] already, so this is [_markedAcross], a
  /// predicate and a table — where Ç and Ş, on the same geometry, each needed a
  /// classifier because their bases' own tests refuse a letter that is crossed.
  _LatinLetter? _classifyOgonek() => _markedAcross(_isOgonek, _ogonekOver);

  /// Whether [s] is an ogonek: two legs, out to the left and back to the right.
  ///
  /// Spelled out with [_hasSideLegs], which is safe on an **even** number of legs
  /// — reversing a two-leg stroke reverses the legs' order and flips each
  /// direction, and those cancel, so left-right stays left-right whichever end
  /// the hand set off from. On three legs it would not; see [_isThreeLegged].
  bool _isOgonek(_Stroke s) =>
      _hasSideLegs(s, const [_Leg.left, _Leg.right]);

  /// Ŀ — a tap *inside* L's own bounding box.
  ///
  /// The one mark here that is neither above its letter nor crossing it. An L's box
  /// is mostly empty — the upright down its left, the foot along its bottom — and
  /// the dot goes in that empty middle, which is why being inside the box is enough
  /// to place it.
  ///
  /// Disjoint from [_classifyDotAbove] by that very fact: a dot inside the box is
  /// not above it.
  _LatinLetter? _classifyMiddleDot() {
    if (_dots.isEmpty || _strokes.isEmpty) return null;
    final letter = _strokes.last;
    if (!_isL(letter)) return null;
    return _boundsOf(letter.points).contains(_dots.last)
        ? _LatinLetter.lMiddleDot
        : null;
  }

  /// Å — a ring above the letter, [_isLoop] being the mark.
  ///
  /// Ahead of the tilde in [_classify]: a ring swept from its foot upward leaves
  /// the same three legs a tilde does, so a ring that closes is read as the ring
  /// it is rather than as a tilde that didn't.
  _LatinLetter? _classifyRing() => _markedLetter(_isLoop, _ringOver);

  /// Ä Ë Ï Ö Ü Ÿ — a pair of taps above the letter.
  ///
  /// The one mark not made of a stroke, so it doesn't go through [_markedLetter]:
  /// the dots don't compete for the run of strokes the base is read from, and the
  /// base is simply the last few of them.
  ///
  /// One mark over six letters, and Finnish, Swedish, German, French, Dutch,
  /// Catalan and Albanian all write some of it. Which of the six the chosen
  /// [alphabet] admits is the only thing separating what a reading means; the
  /// shapes themselves are shared.
  _LatinLetter? _classifyDiaeresis() {
    if (_dots.length < 2) return null;
    for (final size in const [1, 2, 3, 4]) {
      if (_strokes.length < size) continue;
      final rest = _strokes.sublist(_strokes.length - size);
      final bounds = _boundsOf([for (final s in rest) ...s.points]);
      if (!_sitsAbove(_dots.sublist(_dots.length - 2), bounds)) continue;
      final base = _baseOf(rest);
      final letter = base == null ? null : _diaeresisOver[base];
      if (letter != null) return letter;
    }
    return null;
  }

  static const _acuteOver = {
    _LatinLetter.a: _LatinLetter.aAcute,
    _LatinLetter.c: _LatinLetter.cAcute,
    _LatinLetter.e: _LatinLetter.eAcute,
    _LatinLetter.i: _LatinLetter.iAcute,
    _LatinLetter.l: _LatinLetter.lAcute,
    _LatinLetter.n: _LatinLetter.nAcute,
    _LatinLetter.o: _LatinLetter.oAcute,
    _LatinLetter.r: _LatinLetter.rAcute,
    _LatinLetter.s: _LatinLetter.sAcute,
    _LatinLetter.u: _LatinLetter.uAcute,
    _LatinLetter.y: _LatinLetter.yAcute,
    _LatinLetter.z: _LatinLetter.zAcute,
  };

  static const _graveOver = {
    _LatinLetter.a: _LatinLetter.aGrave,
    _LatinLetter.e: _LatinLetter.eGrave,
    _LatinLetter.i: _LatinLetter.iGrave,
    _LatinLetter.o: _LatinLetter.oGrave,
    _LatinLetter.u: _LatinLetter.uGrave,
  };

  static const _circumflexOver = {
    _LatinLetter.a: _LatinLetter.aCircumflex,
    _LatinLetter.c: _LatinLetter.cCircumflex,
    _LatinLetter.e: _LatinLetter.eCircumflex,
    _LatinLetter.g: _LatinLetter.gCircumflex,
    _LatinLetter.h: _LatinLetter.hCircumflex,
    _LatinLetter.i: _LatinLetter.iCircumflex,
    _LatinLetter.j: _LatinLetter.jCircumflex,
    _LatinLetter.o: _LatinLetter.oCircumflex,
    _LatinLetter.s: _LatinLetter.sCircumflex,
    _LatinLetter.u: _LatinLetter.uCircumflex,
    _LatinLetter.w: _LatinLetter.wCircumflex,
    _LatinLetter.y: _LatinLetter.yCircumflex,
  };

  static const _caronOver = {
    _LatinLetter.c: _LatinLetter.cCaron,
    _LatinLetter.d: _LatinLetter.dCaron,
    _LatinLetter.e: _LatinLetter.eCaron,
    _LatinLetter.l: _LatinLetter.lCaron,
    _LatinLetter.n: _LatinLetter.nCaron,
    _LatinLetter.r: _LatinLetter.rCaron,
    _LatinLetter.s: _LatinLetter.sCaron,
    _LatinLetter.t: _LatinLetter.tCaron,
    _LatinLetter.z: _LatinLetter.zCaron,
    // The breve, which this table reads as a caron on purpose. Its three bases
    // are disjoint from the nine above, so nothing here can collide even before
    // the alphabet has its say — no letter in this map answers to two marks.
    _LatinLetter.a: _LatinLetter.aBreve,
    _LatinLetter.g: _LatinLetter.gBreve,
    _LatinLetter.u: _LatinLetter.uBreve,
  };

  static const _dotAboveOver = {
    _LatinLetter.c: _LatinLetter.cDot,
    _LatinLetter.e: _LatinLetter.eDot,
    _LatinLetter.g: _LatinLetter.gDot,
    _LatinLetter.i: _LatinLetter.iDot,
    _LatinLetter.z: _LatinLetter.zDot,
  };

  static const _tildeOver = {
    _LatinLetter.a: _LatinLetter.aTilde,
    _LatinLetter.n: _LatinLetter.nTilde,
    _LatinLetter.o: _LatinLetter.oTilde,
  };

  static const _diaeresisOver = {
    _LatinLetter.a: _LatinLetter.aDiaeresis,
    _LatinLetter.e: _LatinLetter.eDiaeresis,
    _LatinLetter.i: _LatinLetter.iDiaeresis,
    _LatinLetter.o: _LatinLetter.oDiaeresis,
    _LatinLetter.u: _LatinLetter.uDiaeresis,
    _LatinLetter.y: _LatinLetter.yDiaeresis,
  };

  static const _ringOver = {
    _LatinLetter.a: _LatinLetter.aRing,
    _LatinLetter.u: _LatinLetter.uRing,
  };

  static const _ogonekOver = {
    _LatinLetter.a: _LatinLetter.aOgonek,
    _LatinLetter.e: _LatinLetter.eOgonek,
    _LatinLetter.i: _LatinLetter.iOgonek,
    _LatinLetter.u: _LatinLetter.uOgonek,
  };

  static const _commaBelowOver = {
    _LatinLetter.s: _LatinLetter.sComma,
    _LatinLetter.t: _LatinLetter.tComma,
    _LatinLetter.g: _LatinLetter.gCedilla,
    _LatinLetter.k: _LatinLetter.kCedilla,
    _LatinLetter.l: _LatinLetter.lCedilla,
    _LatinLetter.n: _LatinLetter.nCedilla,
  };

  static const _doubleAcuteOver = {
    _LatinLetter.o: _LatinLetter.oDoubleAcute,
    _LatinLetter.u: _LatinLetter.uDoubleAcute,
  };

  /// No Ō here: nothing among the alphabets wants one, and a row nothing lists is
  /// dead weight. Add it with the alphabet that needs it.
  static const _macronOver = {
    _LatinLetter.a: _LatinLetter.aMacron,
    _LatinLetter.e: _LatinLetter.eMacron,
    _LatinLetter.i: _LatinLetter.iMacron,
    _LatinLetter.u: _LatinLetter.uMacron,
  };

  /// Every base, mapped to itself — what [_classifyMarkedBase] reads a mark's
  /// letter through when the mark itself is to be thrown away.
  static const _bareOver = {
    _LatinLetter.a: _LatinLetter.a,
    _LatinLetter.c: _LatinLetter.c,
    _LatinLetter.d: _LatinLetter.d,
    _LatinLetter.e: _LatinLetter.e,
    _LatinLetter.g: _LatinLetter.g,
    _LatinLetter.h: _LatinLetter.h,
    _LatinLetter.i: _LatinLetter.i,
    _LatinLetter.j: _LatinLetter.j,
    _LatinLetter.k: _LatinLetter.k,
    _LatinLetter.l: _LatinLetter.l,
    _LatinLetter.n: _LatinLetter.n,
    _LatinLetter.o: _LatinLetter.o,
    _LatinLetter.r: _LatinLetter.r,
    _LatinLetter.s: _LatinLetter.s,
    _LatinLetter.t: _LatinLetter.t,
    _LatinLetter.u: _LatinLetter.u,
    _LatinLetter.w: _LatinLetter.w,
    _LatinLetter.y: _LatinLetter.y,
    _LatinLetter.z: _LatinLetter.z,
  };

  /// The letter *under* a mark, for an alphabet that hasn't got the marked one —
  /// so an Á drawn under [Alphabet.english] reads A, the accent passed over.
  ///
  /// The diaeresis never needed this. Its dots are taps, so they don't compete
  /// for the run of strokes a base is read from, and the base classifiers saw a
  /// plain A under Ä's dots all along. A stroke mark does compete: with an acute
  /// on the page, [_classifyA]'s last two strokes are the bar and the accent, and
  /// no A among them. So the base has to be looked for a second time with the
  /// mark deliberately set aside.
  ///
  /// Last but for O and I in [_classify], so that every letter with a mark of its
  /// own is offered first and only an alphabet that refused them all gets here.
  /// Ahead of O and I, though, because a ring drawn last would otherwise be read
  /// as the O it is on its own, and reporting the A beneath it is nearer the
  /// truth.
  _LatinLetter? _classifyMarkedBase() {
    for (final isMark in [
      _isLoop,
      (_Stroke s) => _hasLegs(s, const [_Leg.up, _Leg.down, _Leg.up]),
      _isSlash,
      (_Stroke s) => _isStraight(s) && _isDescending(s),
      _isVee,
      (_Stroke s) => _hasLegs(s, const [_Leg.up, _Leg.down]),
    ]) {
      final bare = _markedLetter(isMark, _bareOver);
      if (bare != null) return bare;
    }
    // The macron, which asks the same hovering of itself here as it does there —
    // otherwise a T's own bar would be set aside and its stem reported as an I.
    final bare = _markedLetter(_isBar, _bareOver, clearOfBase: true);
    if (bare != null) return bare;
    // And the caron tucked *inside* the letter's box, Slovak's Ľ, so the same
    // drawing under English reads L.
    final within = _markedWith(_isVee, _bareOver, _sitsWithin);
    if (within != null) return within;
    // And the double acute, so an Ő in English reads O.
    final twice = _markedTwice(_isSlash, _bareOver);
    if (twice != null) return twice;
    // And the one that hangs below, so a Ș in English reads S as an Á reads A.
    return _markedBelow(_isSlash, _bareOver) ??
        _markedAcross(_isOgonek, _bareOver);
  }

  /// Whether [mark] sits clear above [bounds], centred over it — where every
  /// mark here goes.
  ///
  /// Clear above is asked of every point: a mark that dips into the letter is no
  /// mark. But *where* along the letter is asked of the mark's own centre only,
  /// and against a [bounds] widened by [_touchTolerance], because a mark is
  /// often wider than what it sits on. An I's box has no width at all, and a
  /// tilde is broader than most letters — demanding every point fall inside the
  /// letter's run of widths would put Í and Ñ out of reach while barely
  /// tightening anything.
  bool _sitsAbove(List<Offset> mark, Rect bounds) {
    var left = double.infinity;
    var right = double.negativeInfinity;
    for (final point in mark) {
      if (point.dy >= bounds.top) return false;
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
    }
    return _centredOver(left, right, bounds);
  }

  /// [_sitsAbove] turned upside down: every point of [mark] clear *below*
  /// [bounds], and the mark centred on it the same way.
  ///
  /// The first mark here to hang under its letter rather than over it, and the
  /// only difference is which edge is cleared — so the two share [_centredOver]
  /// and the same tolerance.
  /// Placement for a mark that *crosses* its letter rather than standing clear
  /// of it: only that the mark is centred on the letter. There is no edge for it
  /// to clear, being attached — [_hangsAcross] does the rest.
  bool _centred(List<Offset> mark, Rect bounds) {
    var left = double.infinity;
    var right = double.negativeInfinity;
    for (final point in mark) {
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
    }
    return _centredOver(left, right, bounds);
  }

  /// Whether [mark] is hung across the foot of [base]: crossing it **once or
  /// twice**, down in the letter's bottom third, and carrying on below it rather
  /// than curling back up inside.
  ///
  /// Twice as well as once, because the mark turns: a hand that sets off from
  /// inside the letter crosses on the way out, and one that sets off outside and
  /// dips back in crosses on the way out *and* the way in. Both are the same
  /// mark. What is refused is a mark that never meets the letter, and one that
  /// crosses it three times or more — that is a stroke woven through the letter,
  /// not hung off it.
  ///
  /// The crossings are counted across the letter's strokes together, not each in
  /// turn — an ogonek under an A meets one of its legs and not the other, and an
  /// E's stem and bottom bar are two strokes meeting at the very corner the mark
  /// is hung from.
  ///
  /// **Every** crossing has to be low, not merely one, exactly as Q asks of its
  /// tail: one low crossing and one high is a stroke laid through the letter.
  bool _hangsAcross(_Stroke mark, List<_Stroke> base) {
    final crossings = [
      for (final stroke in base) ..._crossingPoints(mark, stroke),
    ];
    if (crossings.isEmpty || crossings.length > 2) return false;
    final bounds = _boundsOf([for (final stroke in base) ...stroke.points]);
    for (final at in crossings) {
      if ((at.dy - bounds.top) / bounds.height <= 2 / 3) return false;
    }
    return _boundsOf(mark.points).bottom > bounds.bottom;
  }

  bool _sitsBelow(List<Offset> mark, Rect bounds) {
    var left = double.infinity;
    var right = double.negativeInfinity;
    for (final point in mark) {
      if (point.dy <= bounds.bottom) return false;
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
    }
    return _centredOver(left, right, bounds);
  }

  /// Whether a mark spanning [left] to [right] is centred on [bounds] — its own
  /// middle within the letter's run of widths, widened by [_touchTolerance].
  ///
  /// Only the mark's centre is asked about, because a mark is often wider than
  /// what it sits on: an I's box has no width at all, and a tilde is broader than
  /// most letters.
  bool _centredOver(double left, double right, Rect bounds) {
    final centre = (left + right) / 2;
    return centre >= bounds.left - _touchTolerance &&
        centre <= bounds.right + _touchTolerance;
  }

  /// Whether the last two strokes form B: an upright stem, and a
  /// right-left-right-left stroke laid against it, meeting it 3 or 4
  /// times. Each bowl joins the stem at both ends, which would be 4
  /// meetings; where a bowl's foot and the next one's head arrive at the
  /// same spot they read as one, hence 3. The stem stands to the left of
  /// the bowls ([_minSideOffset]), so they hang off it rather than
  /// straddle it. Either stroke order.
  _LatinLetter? _classifyB() {
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
        ? _LatinLetter.b
        : null;
  }

  /// Whether [s] runs right, back left, right again and left again — B's
  /// pair of bowls in one stroke, out to the right and home to the stem
  /// twice over.
  ///
  /// Nothing is asked about the stroke crossing its own path, deliberately, and
  /// unlike [_isBowl]. Two bowls drawn in one go meet in the middle, and whether
  /// a given hand closes that join into a crossing or stops just shy of it isn't
  /// the difference between one letter and another. ß leans on that.
  bool _isDoubleBowl(_Stroke s) => _hasSideLegs(
      s, const [_Leg.right, _Leg.left, _Leg.right, _Leg.left]);

  /// Whether the last two strokes form ß: an upright stem standing to the left,
  /// and the very stroke B is built from laid against it — but meeting it
  /// exactly *once*, up in the stem's top third where the bowls set off.
  /// Either stroke order.
  ///
  /// That one meeting is the whole of what separates ß from B. B's two bowls
  /// each join the stem at both ends, which is 3 or 4 crossings; ß's leave the
  /// stem at the top and never return, the lower one running out open to the
  /// left. So the two letters share [_isDoubleBowl] and divide the crossings
  /// between them, exactly as B, P and D divide the stem.
  ///
  /// The bowls may cross their own path as much as they like — see
  /// [_isDoubleBowl].
  _LatinLetter? _classifySharpS() {
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

    final crossings = _crossingPoints(bowls, stem);
    if (crossings.length != 1) return null;

    final bounds = _boundsOf(stem.points);
    if (bounds.center.dx > _boundsOf(bowls.points).center.dx - _minSideOffset) {
      return null;
    }
    // Up at the stem's top, where the bowls set off from it — not away down its
    // length, which is a shape no letter here claims.
    final along = (crossings.single.dy - bounds.top) / bounds.height;
    return along < 1 / 3 ? _LatinLetter.sharpS : null;
  }

  /// Whether the last two strokes form P: the stem-and-bowl pair D and Þ share
  /// with it, with the stem standing clear **below** the bowl but not above it.
  /// Either stroke order.
  _LatinLetter? _classifyP() {
    if (_strokes.length < 2) return null;
    final bowl =
        _bowlCrossings(_strokes[_strokes.length - 2], _strokes.last);
    if (bowl == null) return null;
    return bowl.above < _outerQuarter && bowl.below >= _outerQuarter
        ? _LatinLetter.p
        : null;
  }

  /// Whether the last two strokes form D: the same stem and bowl, with the stem
  /// standing clear at **neither** end — the bowl reaching its top and its foot,
  /// so it meets the upright at its two ends and nowhere between. Either stroke
  /// order.
  _LatinLetter? _classifyD() =>
      _strokes.length >= 2 &&
              _isD(_strokes[_strokes.length - 2], _strokes.last)
          ? _LatinLetter.d
          : null;

  /// Whether [a] and [b] between them form D (see [_classifyD]). Taken as a pair
  /// rather than read off the end of [_strokes], so Ð can set its bar aside and
  /// ask about the two left over.
  bool _isD(_Stroke a, _Stroke b) {
    final bowl = _bowlCrossings(a, b);
    return bowl != null &&
        bowl.above < _outerQuarter &&
        bowl.below < _outerQuarter;
  }

  /// Whether the last two strokes form Þ: the same stem and bowl, with the stem
  /// standing clear at **both** ends. Either stroke order.
  _LatinLetter? _classifyThorn() {
    if (_strokes.length < 2) return null;
    final bowl =
        _bowlCrossings(_strokes[_strokes.length - 2], _strokes.last);
    if (bowl == null) return null;
    return bowl.above >= _outerQuarter && bowl.below >= _outerQuarter
        ? _LatinLetter.thorn
        : null;
  }

  /// Whether the last three strokes form Ð: a D, with a horizontal bar crossing
  /// its stem across the middle third. Stroke order doesn't matter — whichever of
  /// the three is the bar is found by trying each in turn and asking [_isD] of
  /// the other two.
  ///
  /// Ahead of D and B in [_classify]. Drop the bar and a D is exactly what is
  /// left, so an eth drawn bar-first ends with the D's own two strokes and would
  /// be read as one.
  ///
  /// Nothing is asked about the bar reaching the bowl. In the letter it juts out
  /// to the stem's left and stops, but a hand that carries it on across is
  /// writing the same eth.
  _LatinLetter? _classifyEth() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    for (var i = 0; i < recent.length; i++) {
      final bar = recent[i];
      if (!_isBar(bar)) continue;
      final rest = [
        for (var j = 0; j < recent.length; j++)
          if (j != i) recent[j],
      ];
      if (!_isD(rest.first, rest.last)) continue;
      final stem = _bowlCrossings(rest.first, rest.last)!.stem;

      final crossings = _crossingPoints(bar, stem);
      if (crossings.length != 1) continue;
      final bounds = _boundsOf(stem.points);
      final along = (crossings.single.dy - bounds.top) / bounds.height;
      if (along < 1 / 3 || along > 2 / 3) continue;
      return _LatinLetter.eth;
    }
    return null;
  }

  /// How much of the stem a bowl leaves clear [above] it and [below] it, as
  /// fractions of the stem's own height — or null if [a] and [b] aren't a
  /// stem-and-bowl pair at all.
  ///
  /// Those two overhangs are the whole of what tells D, P and Þ apart, so they
  /// are what this hands back rather than the raw crossing heights (see
  /// [_outerQuarter]). The stem comes with them because Ð needs it.
  ///
  /// The pair is an upright with a bowl running right then back left that
  /// crosses it exactly twice and hangs off its right ([_minSideOffset]),
  /// which is P and D both. Only the crossings' heights tell those two
  /// apart, so this locates them ([_crossingPoints]) and leaves the reading
  /// to the callers — the same division of labour [_classifyE] and
  /// [_classifyF] make over the thirds of their stem.
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
    return (
      stem: stem,
      above: along.first,
      below: 1 - along.last,
    );
  }

  /// Whether [s] is P's bowl: out to the right and back left again, never
  /// crossing itself — [_isArc] mirrored, and half of [_isDoubleBowl].
  bool _isBowl(_Stroke s) =>
      _hasSideLegs(s, const [_Leg.right, _Leg.left]) &&
      _selfIntersections(s) == 0;

  /// Whether the last two strokes form R: an upright stem, and a stroke to
  /// its right ([_minSideOffset]) running right, back left and right again —
  /// across the top of the bowl, home to the stem, then away down the leg —
  /// meeting the stem 2 or 3 times on the way. Either stroke order.
  ///
  /// The bowl joins the stem at its top and again at its waist, which would
  /// be 2 meetings, and the leg may set off from the stem as well, hence 3.
  /// The run of legs is what separates R from B, which is the same idea with
  /// a second bowl in place of the leg, and from P, which is the bowl with
  /// no leg at all.
  _LatinLetter? _classifyR() =>
      _strokes.length >= 2 &&
              _isR(_strokes[_strokes.length - 2], _strokes.last)
          ? _LatinLetter.r
          : null;

  /// Whether [a] and [b] between them form R (see [_classifyR]). Taken as a pair,
  /// for [_baseOf]'s sake.
  bool _isR(_Stroke a, _Stroke b) {
    final _Stroke stem;
    final _Stroke body;
    if (_isStem(a) && _isZShaped(b)) {
      stem = a;
      body = b;
    } else if (_isStem(b) && _isZShaped(a)) {
      stem = b;
      body = a;
    } else {
      return false;
    }

    final meetings = _crossings(body, stem);
    if (meetings < 2 || meetings > 3) return false;
    return _boundsOf(body.points).center.dx >
        _boundsOf(stem.points).center.dx + _minSideOffset;
  }

  /// Whether [s] is Z's shape — three legs to and fro with the middle one
  /// leaning `/` — which is also R's bowl-and-leg when a stem stands against
  /// it, and Z on its own when nothing does.
  bool _isZShaped(_Stroke s) => _isThreeLegged(s, leaning: _Leg.up);

  /// Whether [s] is S's shape: Z's three legs with the middle one leaning the
  /// other way, `\`.
  bool _isSShaped(_Stroke s) => _isThreeLegged(s, leaning: _Leg.down);

  /// Whether [s] runs to and fro across exactly three legs
  /// ([_horizontalLegs]) with its middle one leaning the way [leaning] says —
  /// [_Leg.up] for a `/`, [_Leg.down] for a `\`.
  ///
  /// The middle leg's *slant* is what's asked about, not the run of legs'
  /// directions, and that is what makes the test indifferent to which way the
  /// hand went — which for a three-leg shape it has to be. Reversing a stroke
  /// both reverses the order of its legs and flips each one's direction, and
  /// on an odd number of legs those two do not cancel: a Z drawn bottom-up
  /// leaves right-left-right turned into left-right-left, which is the run of
  /// legs an S drawn top-down leaves. So the pattern alone cannot tell Z from
  /// S at all — it only says which way the hand set off. The diagonal between
  /// the two bars is the same line either way, and [_isAscending] reads a line
  /// rather than a direction.
  ///
  /// (The two-and four-leg shapes have no such trouble. An even number of legs
  /// reversed does cancel, which is why [_isBowl], [_isVee], [_isDoubleBowl]
  /// and M's and W's patterns can be spelled out directly and still hold
  /// whichever end the hand started from.)
  bool _isThreeLegged(_Stroke s, {required _Leg leaning}) {
    final legs = _horizontalLegs(s);
    if (legs.length != 3) return false;
    return leaning == _Leg.up
        ? _isAscending(legs[1])
        : _isDescending(legs[1]);
  }

  /// Whether the last two strokes form K: an upright stem, and an arm
  /// running left and then right — in to meet the stem, then away again —
  /// hanging off the stem's right and crossing it once or twice. Once where
  /// the arm turns on the stem, twice where it carries past and comes back.
  /// Either stroke order.
  ///
  /// The arm is exactly C's arc, and a stem standing to its left is the
  /// whole of the difference — which is why [_classify] tries K first.
  _LatinLetter? _classifyK() {
    if (_strokes.length < 2) return null;
    return _isK(_strokes[_strokes.length - 2], _strokes.last)
        ? _LatinLetter.k
        : null;
  }

  /// [_classifyK]'s shape test, taking the two strokes it is given rather than
  /// reading them off the end — so a mark can be set aside and Ķ read from what
  /// is left. See [_baseOf].
  bool _isK(_Stroke a, _Stroke b) {
    final _Stroke stem;
    final _Stroke arm;
    if (_isStem(a) && _isInwardArm(b)) {
      stem = a;
      arm = b;
    } else if (_isStem(b) && _isInwardArm(a)) {
      stem = b;
      arm = a;
    } else {
      return false;
    }
    if (_boundsOf(stem.points).center.dx >
        _boundsOf(arm.points).center.dx - _minSideOffset) {
      return false;
    }
    final meetings = _crossings(arm, stem);
    return meetings >= 1 && meetings <= 2;
  }

  /// Whether [s] runs left and then right — K's arm, and the mirror of
  /// [_isBowl]'s right-then-left.
  bool _isInwardArm(_Stroke s) =>
      _hasSideLegs(s, const [_Leg.left, _Leg.right]);

  /// Whether the last two strokes form G: C's own arc, finished by a
  /// ㄱ-shaped corner — elbow at the top right ([_Corner.topRight]) — that
  /// meets the arc at one of its *terminals* rather than partway along it.
  /// Either stroke order.
  ///
  /// That corner is the spur and crossbar in one: run up from the arc's lower
  /// end and then left, and the turn lands at the top right of its own box —
  /// the same corner a bar drawn rightward and then down would leave, so it
  /// reads the same whichever way the hand went (see [_isCorner]).
  ///
  /// Meeting the arc at a terminal is what makes this a G rather than a C with
  /// something laid across it. The junction is the point along the spur that
  /// comes nearest the arc ([_nearestPointTo]), and it has to land within
  /// [_touchTolerance] of one of the arc's two ends.
  ///
  /// Ahead of C in [_classify]: the spur meets the arc at its tip rather than
  /// crossing it, so C's "crosses nothing else" test would let a finished G
  /// through as the arc it contains.
  _LatinLetter? _classifyG() =>
      _strokes.length >= 2 &&
              _isG(_strokes[_strokes.length - 2], _strokes.last)
          ? _LatinLetter.g
          : null;

  /// Whether [a] and [b] between them form G (see [_classifyG]). Taken as a pair
  /// rather than read off the end of [_strokes], so a mark can be set aside and
  /// the two left over asked about (see [_baseOf]).
  bool _isG(_Stroke a, _Stroke b) {
    final _Stroke arc;
    final _Stroke spur;
    if (_isArc(a) && _isGSpur(b)) {
      arc = a;
      spur = b;
    } else if (_isArc(b) && _isGSpur(a)) {
      arc = b;
      spur = a;
    } else {
      return false;
    }
    if (!_touches(spur, arc)) return false;

    // A bar must also lie *inside* the bowl — a G's crossbar reaches back into
    // the arc, never out past it. The elbow form needs no such rule, being
    // shape enough on its own; the bar is one stroke and gives less away.
    //
    // Without it the letter is claimed by things that were never G. An ogonek is
    // an arc by [_isArc]'s test — a short stroke out and back with both ends to
    // the right of its own middle — so an A with an ogonek is an arc and a bar,
    // and its bar's end lands within [_touchTolerance] of the mark's tip. That
    // read as G until this went in.
    if (!_isCorner(spur, elbow: _Corner.topRight)) {
      final within = _boundsOf(arc.points).inflate(_touchTolerance);
      final bar = _boundsOf(spur.points);
      if (!within.contains(bar.topLeft) || !within.contains(bar.bottomRight)) {
        return false;
      }
    }

    final junction = _nearestPointTo(spur, arc);
    for (final terminal in [arc.start, arc.end]) {
      if ((junction - terminal).distance <= _touchTolerance) return true;
    }
    return false;
  }

  /// What a G hangs off the end of its arc: either the ㄱ corner a printed G
  /// turns down at its tip, or a plain **horizontal bar** — two ways a hand
  /// finishes the letter, and the same letter either way.
  ///
  /// The bar form is the loose one, being one stroke rather than two, but it
  /// gives nothing else away. It has to *meet the arc at one of its terminals*
  /// ([_isG] asks that), which is what keeps it off the macron — that mark must
  /// hover clear of what it marks — and off C, whose arc must touch nothing.
  bool _isGSpur(_Stroke s) =>
      _isCorner(s, elbow: _Corner.topRight) || _isBar(s);

  /// Whether the last stroke is L: a single right-angle bend with its elbow at
  /// the bottom left, so the upright stands on the left and the foot runs
  /// right from it — Hangul's ㄴ (see [_isCorner]).
  ///
  /// One stroke only. A hand that lifts the pen between the upright and the
  /// foot has drawn the same letter, but that pair is not claimed here yet.
  _LatinLetter? _classifyL() =>
      _isL(_strokes.last) ? _LatinLetter.l : null;

  /// Whether the last two strokes form Ł: an L, with a line rising to the right
  /// ([_isSlash]) crossing it exactly once. Either stroke order.
  ///
  /// Polish's own, and the fourth letter here whose mark **crosses** what it
  /// marks rather than sitting clear of it — after Ð, Ħ and the cedilla. Like
  /// those three it gets a classifier of its own rather than a place in
  /// [_markedLetter], which finds its mark by [_sitsAbove] and would never look
  /// at a stroke laid through the letter.
  ///
  /// [_isL] can be asked for the letter directly, unlike [_isC] and [_isS] under
  /// the cedilla: an L is a corner and nothing more, with no clause about
  /// crossing nothing to get in the way.
  ///
  /// Crossing **once** is not on its own enough, and this is the one thing here
  /// worth knowing: an L is an upright *and a foot*, and a bar laid low across
  /// the foot alone crosses exactly once too. That drawing is no Ł. So the
  /// crossing is located as well as counted, and asked to fall in the L's upper
  /// two thirds — through the upright, where a hand puts it, and clear of the
  /// foot along the bottom.
  ///
  /// Above L in [_classify]: with the bar drawn first the L is the last stroke,
  /// and [_classifyL] reads off the end.
  ///
  /// Above X too, though nothing turns on that today — an L slants down to the
  /// right taken end to end, the bar rises, and the two cross once, which is X's
  /// whole test. As it happens Polish has no X and no other alphabet has Ł, so
  /// the alphabet would separate them anyway. The order is here so the reading
  /// doesn't rest on that accident.
  _LatinLetter? _classifyLStroke() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke body;
    final _Stroke bar;
    if (_isL(a) && _isSlash(b)) {
      body = a;
      bar = b;
    } else if (_isL(b) && _isSlash(a)) {
      body = b;
      bar = a;
    } else {
      return null;
    }

    final crossings = _crossingPoints(bar, body);
    if (crossings.length != 1) return null;
    final bounds = _boundsOf(body.points);
    final along = (crossings.single.dy - bounds.top) / bounds.height;
    return along <= 2 / 3 ? _LatinLetter.lStroke : null;
  }

  /// Whether [s] on its own is L (see [_classifyL]).
  bool _isL(_Stroke s) => _isCorner(s, elbow: _Corner.bottomLeft);

  /// Whether the last stroke is J: V's own falling-then-rising stroke
  /// ([_isVee]), but lopsided — its **left** end below the middle of its own
  /// bounding box and its **right** end above it, which is the stem coming
  /// down on the right and the hook curling up on the left. Crossing nothing
  /// at all.
  ///
  /// A V rises to the top on both sides, so both its ends sit above that
  /// middle; only one of J's does. The two ends are picked out by which is
  /// further left rather than by which was drawn first, so a J written
  /// stem-first and one written hook-first read alike.
  ///
  /// Ahead of V in [_classify], which asks for the falling-then-rising stroke
  /// and nothing more: every J is a V so far as that test can tell.
  ///
  /// The hook does have to rise — by [_directionSlack] at least, or
  /// [_verticalLegs] never cuts the stroke in two and there is no V here to
  /// begin with. A J squared off into a right angle, with a foot that runs flat
  /// left and never comes back up, is not claimed.
  _LatinLetter? _classifyJ() =>
      _isJ(_strokes.last) ? _LatinLetter.j : null;

  /// Whether [s] on its own is J (see [_classifyJ]).
  bool _isJ(_Stroke s) {
    if (!_isVee(s) || !_crossesNothing(s)) return false;

    final leftFirst = s.start.dx < s.end.dx;
    final left = leftFirst ? s.start : s.end;
    final right = leftFirst ? s.end : s.start;
    final middle = _boundsOf(s.points).center.dy;
    return left.dy > middle && right.dy < middle;
  }

  /// Whether the last stroke is U: V's own falling-then-rising stroke
  /// ([_isVee]), turning across a real share of its width at the bottom
  /// ([_turnWidth]) rather than converging to a point. Crossing nothing at all.
  ///
  /// Ahead of V in [_classify], which asks for the falling-then-rising stroke
  /// and nothing more: every U is a V so far as that test can tell.
  _LatinLetter? _classifyU() =>
      _isU(_strokes.last) ? _LatinLetter.u : null;

  /// Whether [s] on its own is U (see [_classifyU]).
  bool _isU(_Stroke s) =>
      _isVee(s) && _crossesNothing(s) && _turnWidth(s) >= _minTurnWidth;

  /// How wide [s]'s turn at the bottom is, as a fraction of its own bounding
  /// box's width: the horizontal span of the points lying in the box's lower
  /// [_bottomBand].
  ///
  /// This is the one measurement separating U from V, and it reads a shape
  /// rather than a path — so it doesn't care which way round the hand drew it,
  /// nor whether the U was turned square or round.
  double _turnWidth(_Stroke s) {
    final bounds = _boundsOf(s.points);
    if (bounds.width == 0 || bounds.height == 0) return 0;
    final band = bounds.bottom - bounds.height * _bottomBand;

    var left = double.infinity;
    var right = double.negativeInfinity;
    for (final point in s.points) {
      if (point.dy < band) continue;
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
    }
    return left > right ? 0 : (right - left) / bounds.width;
  }

  /// Whether the last stroke is V: one stroke falling then rising ([_isVee]),
  /// crossing nothing at all — A's Λ upside down, standing on its own.
  ///
  /// After Y in [_classify], which is this very shape with a stem hung below
  /// its vertex, and after J, which is it drawn lopsided: a V that has a stem
  /// under it is read as the Y it is, and one whose left arm never comes back
  /// up as the J.
  _LatinLetter? _classifyV() =>
      _isVee(_strokes.last) && _crossesNothing(_strokes.last)
          ? _LatinLetter.v
          : null;

  /// Whether the last stroke is Z: three legs to and fro with the diagonal
  /// between them leaning `/` ([_isZShaped]) — the top bar, the diagonal, then
  /// the bottom bar — crossing nothing at all.
  ///
  /// After R in [_classify], which is this very shape with a stem laid against
  /// it: drawing an R body-first reads as a Z until the stem lands, which is
  /// the live readout doing its job.
  _LatinLetter? _classifyZ() =>
      _isZ(_strokes.last) ? _LatinLetter.z : null;

  /// Whether [s] on its own is Z (see [_classifyZ]).
  bool _isZ(_Stroke s) => _isZShaped(s) && _crossesNothing(s);

  /// Whether the last stroke is S: Z's own three legs with the spine between
  /// them leaning the other way, `\` ([_isSShaped]), crossing nothing at all.
  _LatinLetter? _classifyS() =>
      _isS(_strokes.last) ? _LatinLetter.s : null;

  /// Whether [s] on its own is S (see [_classifyS]).
  bool _isS(_Stroke s) => _isSShaped(s) && _crossesNothing(s);

  /// Whether the last two strokes form Ø: an O's ring ([_isLoop]) with a
  /// straight line rising to the right slashed through it, crossing it once on
  /// each side of the ring's own middle — so at least twice in all. Either
  /// stroke order.
  ///
  /// At least, not exactly: a ring closes by overlapping itself, and a slash
  /// passing through where the two ends cross picks up a third meeting it didn't
  /// ask for. Twice is the shape; more than that is the same shape drawn by a
  /// hand. Which is why the two crossings are asked for as one on each side
  /// rather than as a count — the count can run over, the sides can't.
  ///
  /// One on each side is also what makes Ø and Q disjoint without either having
  /// to know about the other: Q wants every crossing down in the ring's lower
  /// half, Ø wants one above that same line, so no drawing can answer both. The
  /// slants settle it a second time over, Q's tail falling where Ø's slash rises.
  ///
  /// [_isAscending] reads the line rather than the travel, so it doesn't matter
  /// which end of the slash the hand set off from.
  _LatinLetter? _classifyOSlash() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke ring;
    final _Stroke slash;
    if (_isLoop(a) && _isSlash(b)) {
      ring = a;
      slash = b;
    } else if (_isLoop(b) && _isSlash(a)) {
      ring = b;
      slash = a;
    } else {
      return null;
    }

    final crossings = _crossingPoints(slash, ring);
    if (crossings.length < 2) return null;
    final middle = _boundsOf(ring.points).center.dy;
    final above = crossings.where((at) => at.dy < middle).length;
    return above >= 1 && crossings.length - above >= 1
        ? _LatinLetter.oSlash
        : null;
  }

  /// Whether [s] is Ø's slash: a straight line rising to the right.
  bool _isSlash(_Stroke s) => _isStraight(s) && _isAscending(s);

  /// Whether the last two strokes form Q: an O's ring ([_isLoop]) with a
  /// descending tail crossing it, every crossing down in the ring's lower
  /// half. Either stroke order.
  ///
  /// *Every* crossing, not merely one: a tail slashed clean through the ring
  /// crosses it low down as well as high up, and that shape is no Q. Asking
  /// where the crossings fall rather than counting them is also what lets the
  /// tail be drawn either wholly outside the ring (one crossing, on its way
  /// in) or from within it and out again (two, both low) — a hand does both,
  /// and they are the same letter.
  ///
  /// The crossings are measured against the ring's own bounding box, so where
  /// on the page the Q was drawn, and how big, don't come into it. Nothing is
  /// asked about which side of the ring the tail leaves from: bottom-right is
  /// where a printed Q puts it, but a hand that hangs it straight below or
  /// off to the left has still drawn a Q and not another letter.
  ///
  /// Ahead of X in [_classify]: a ring's two ends usually finish near one
  /// another and off to one side, which reads as a slant like anything else,
  /// so a ring and a tail can arrive there as two opposite slants that cross.
  _LatinLetter? _classifyQ() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    final _Stroke ring;
    final _Stroke tail;
    if (_isLoop(a) && _isDescending(b)) {
      ring = a;
      tail = b;
    } else if (_isLoop(b) && _isDescending(a)) {
      ring = b;
      tail = a;
    } else {
      return null;
    }

    final crossings = _crossingPoints(tail, ring);
    if (crossings.isEmpty) return null;
    final middle = _boundsOf(ring.points).center.dy;
    for (final at in crossings) {
      if (at.dy <= middle) return null;
    }
    return _LatinLetter.q;
  }

  /// Whether the last three strokes form F: an upright stem, and two
  /// horizontal bars meeting it once each — one up in its top third, one
  /// across its middle third — both reaching away to the stem's right
  /// ([_minSideOffset]), and nothing down at its foot.
  ///
  /// This is [_classifyE]'s own test with the bottom bar left off, and the
  /// thirds are what make the difference legible: two bars bunched at the
  /// top is no more an F than one bar is.
  _LatinLetter? _classifyF() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final stems = recent.where(_isStem).toList();
    final bars = recent.where(_isBar).toList();
    if (stems.length != 1 || bars.length != 2) return null;
    final stem = stems.single;
    final bounds = _boundsOf(stem.points);
    final stemCentre = bounds.center.dx;

    var top = 0, middle = 0;
    for (final bar in bars) {
      final crossings = _crossingPoints(bar, stem);
      if (crossings.length != 1) return null;
      if (_boundsOf(bar.points).center.dx < stemCentre + _minSideOffset) {
        return null;
      }
      final along = (crossings.single.dy - bounds.top) / bounds.height;
      if (along < 1 / 3) {
        top++;
      } else if (along <= 2 / 3) {
        middle++;
      } else {
        // A bar down at the stem's foot is E's third, not F's second.
        return null;
      }
    }
    return top == 1 && middle == 1 ? _LatinLetter.f : null;
  }

  /// Whether the last three strokes form H: two upright stems and a
  /// horizontal bar crossing each of them exactly once, with the two
  /// crossings falling on opposite sides of the bar's own centre
  /// ([_minSideOffset]).
  ///
  /// Where along the bar the stems land is the whole shape. Both stems on
  /// the same side of its centre is a bar with a tail, not an H, so the
  /// crossing points are located ([_crossingPoints]) rather than merely
  /// counted. Stroke order doesn't matter: the three sort themselves by
  /// orientation.
  _LatinLetter? _classifyH() =>
      _strokes.length >= 3 && _isH(_strokes.sublist(_strokes.length - 3))
          ? _LatinLetter.h
          : null;

  /// Whether the last four strokes form Ħ: an H with a second horizontal bar above
  /// its own, that one crossing both uprights too. Stroke order doesn't matter —
  /// the four sort themselves by shape.
  ///
  /// Maltese's. Not a mark over an H but a letter of its own, in the manner of Ð
  /// and Ø: the extra bar crosses the letter rather than hovering over it, so
  /// there is nothing for [_markedLetter] to find.
  ///
  /// Ahead of both H and F in [_classify], each of which it contains. Drop either
  /// bar and an H is exactly what is left; and three of its strokes are one
  /// upright with two bars across it, which is an F to that test.
  ///
  /// Which bar is which isn't asked — only that they stand clear of each other
  /// ([_minSideOffset]). Both cross both uprights, so there is nothing to tell
  /// them apart by and nothing that needs telling.
  _LatinLetter? _classifyHStroke() {
    if (_strokes.length < 4) return null;
    final recent = _strokes.sublist(_strokes.length - 4);
    final stems = recent.where(_isStem).toList();
    final bars = recent.where(_isBar).toList();
    if (stems.length != 2 || bars.length != 2) return null;

    for (final bar in bars) {
      for (final stem in stems) {
        if (_crossings(bar, stem) != 1) return null;
      }
    }
    final heights = [for (final bar in bars) _boundsOf(bar.points).center.dy];
    return (heights.first - heights.last).abs() > _minSideOffset
        ? _LatinLetter.hStroke
        : null;
  }

  /// Whether [strokes] — three of them — form H (see [_classifyH]). Taken as a
  /// list, for [_baseOf]'s sake.
  bool _isH(List<_Stroke> strokes) {
    final stems = strokes.where(_isStem).toList();
    final bars = strokes.where(_isBar).toList();
    if (stems.length != 2 || bars.length != 1) return false;
    final bar = bars.single;

    final centre = _boundsOf(bar.points).center.dx;
    var left = 0, right = 0;
    for (final stem in stems) {
      final crossings = _crossingPoints(bar, stem);
      if (crossings.length != 1) return false;
      final at = crossings.single;
      if (at.dx < centre - _minSideOffset) left++;
      if (at.dx > centre + _minSideOffset) right++;
    }
    return left == 1 && right == 1;
  }

  /// Whether the last two strokes form Y: a V — one stroke falling then
  /// rising — with an upright stem hanging below its vertex. Either stroke
  /// order.
  ///
  /// The stem has to hang from the vertex rather than off either arm
  /// ([_junctionSnap], measured against the V's own width), and below it
  /// rather than up inside the V. Nothing else is asked of the pair, because
  /// nothing else here is a falling-then-rising stroke: the V is A's Λ upside
  /// down, and the A tests already record that a Λ inverted matches no
  /// letter.
  _LatinLetter? _classifyY() =>
      _strokes.length >= 2 &&
              _isY(_strokes[_strokes.length - 2], _strokes.last)
          ? _LatinLetter.y
          : null;

  /// Whether [a] and [b] between them form Y (see [_classifyY]). Taken as a pair
  /// rather than read off the end of [_strokes], so a mark above can be set
  /// aside and the two left over asked about (see [_baseOf]).
  bool _isY(_Stroke a, _Stroke b) {
    final _Stroke vee;
    final _Stroke stem;
    if (_isVee(a) && _isStem(b)) {
      vee = a;
      stem = b;
    } else if (_isVee(b) && _isStem(a)) {
      vee = b;
      stem = a;
    } else {
      return false;
    }
    if (_contacts(stem, vee) != 1) return false;

    // The vertex is the V's lowest point — where its two arms meet, and the
    // one place the stem may hang from.
    var vertex = vee.points.first;
    for (final point in vee.points) {
      if (point.dy > vertex.dy) vertex = point;
    }
    final veeBounds = _boundsOf(vee.points);
    final stemCentre = _boundsOf(stem.points).center;
    if ((stemCentre.dx - vertex.dx).abs() > veeBounds.width * _junctionSnap) {
      return false;
    }
    return stemCentre.dy > vertex.dy;
  }

  /// Whether [s] is Y's V: one stroke falling then rising — A's Λ turned
  /// upside down.
  bool _isVee(_Stroke s) => _hasLegs(s, const [_Leg.down, _Leg.up]);

  /// Whether the last stroke is M: one stroke rising, falling, rising and
  /// falling again — the two peaks and the valley between them — and
  /// crossing nothing, its own path included.
  _LatinLetter? _classifyM() =>
      _hasLegs(_strokes.last,
                  const [_Leg.up, _Leg.down, _Leg.up, _Leg.down]) &&
              _crossesNothing(_strokes.last)
          ? _LatinLetter.m
          : null;

  /// Whether the last stroke is W: M's own four legs upside down — falling,
  /// rising, falling and rising again, the two valleys and the peak between
  /// them — and crossing nothing, its own path included.
  ///
  /// Inverting the pattern is enough to separate the two, and it stays
  /// enough whichever way the hand went. Reversing a stroke both reverses
  /// its run of legs and flips each leg's direction, and those two undo each
  /// other on an alternating run: an M drawn from its far end still reads
  /// up-down-up-down, and a W still reads down-up-down-up.
  _LatinLetter? _classifyW() =>
      _isW(_strokes.last) ? _LatinLetter.w : null;

  /// Whether [s] on its own is W (see [_classifyW]).
  bool _isW(_Stroke s) =>
      _hasLegs(s, const [_Leg.down, _Leg.up, _Leg.down, _Leg.up]) &&
      _crossesNothing(s);

  /// Whether the last stroke is N: one stroke of three vertical legs, its
  /// outer two upright stems and the one between them a diagonal that falls
  /// to the right, crossing nothing at all.
  ///
  /// The middle leg's slant is asked about rather than the run of legs'
  /// direction, and that is what makes the test indifferent to which way the
  /// hand went. Drawn up-down-up the legs read up, down, up; drawn from the
  /// other end they read down, up, down — but the diagonal between them is
  /// the same line either way, and [_isDescending] reads a line rather than
  /// a direction. Cyrillic И is this very shape with that diagonal rising
  /// instead.
  ///
  /// The stems are what make this N rather than merely something that falls,
  /// rises and falls: a circle drawn not quite closed does that too,
  /// entering and leaving on its right-hand side, and only the stems tell
  /// the two apart.
  _LatinLetter? _classifyN() =>
      _isN(_strokes.last) ? _LatinLetter.n : null;

  /// Whether [s] on its own is N (see [_classifyN]).
  bool _isN(_Stroke s) {
    final legs = _verticalLegs(s);
    if (legs.length != 3) return false;
    if (!_isStem(legs.first) || !_isStem(legs.last)) return false;
    if (!_isDescending(legs[1])) return false;
    return _crossesNothing(s);
  }

  /// Whether [stroke] crosses neither its own path nor any other stroke on
  /// the page — what makes a shape a letter in its own right rather than one
  /// piece of a bigger, tangled one.
  bool _crossesNothing(_Stroke stroke) =>
      _selfIntersections(stroke) == 0 && !_crossesAnotherStroke(stroke);

  /// Whether the last two strokes form T: a horizontal bar and an upright
  /// stem that touch, with the stem hanging below the bar's *middle*
  /// ([_junctionSnap]). Either stroke order.
  ///
  /// The band is stated as a distance from the bar's centre rather than as
  /// "away from its ends", because a stem out at either end of the bar is
  /// no Latin letter and should fall through to nothing rather than to
  /// this one.
  _LatinLetter? _classifyT() =>
      _strokes.length >= 2 &&
              _isT(_strokes[_strokes.length - 2], _strokes.last)
          ? _LatinLetter.t
          : null;

  /// Whether [a] and [b] between them form T (see [_classifyT]). Taken as a pair,
  /// for [_baseOf]'s sake.
  bool _isT(_Stroke a, _Stroke b) {
    final _Stroke bar;
    final _Stroke stem;
    if (_isBar(a) && _isStem(b)) {
      bar = a;
      stem = b;
    } else if (_isBar(b) && _isStem(a)) {
      bar = b;
      stem = a;
    } else {
      return false;
    }
    if (!_touches(bar, stem)) return false;

    final barBounds = _boundsOf(bar.points);
    final stemBounds = _boundsOf(stem.points);
    if ((stemBounds.center.dx - barBounds.center.dx).abs() >
        barBounds.width * _junctionSnap) {
      return false;
    }
    // Below the bar, not through it: a stem centred on the bar is a cross.
    return stemBounds.center.dy > barBounds.center.dy + _minSideOffset;
  }

  /// Whether the last two strokes form X: two strokes crossing once, one
  /// rising to the right and one falling. Slant is read off the two
  /// endpoints alone, so a hand-drawn stroke that wanders on the way still
  /// counts as whichever way it ended up going. Either stroke order.
  ///
  /// Both strokes must also reach across the letter, with an end clear
  /// either side of the pair's own vertical middle. That is what keeps an
  /// upright out: no hand draws one exactly plumb, and a stem leaning by a
  /// pixel reads as rising or falling like anything else — so a T's stem,
  /// beside its bar, would otherwise arrive here as one of two opposite
  /// slants that cross. A stem stays on its own side of the middle where an
  /// X's arms cross it.
  _LatinLetter? _classifyX() {
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
    return _LatinLetter.x;
  }

  /// Whether [s] ends up to the right of and above where it started, or the
  /// reverse — a `/`. Screen y runs downward, so a rising stroke's run and
  /// drop have opposite signs; the test is direction-agnostic, since
  /// swapping both ends leaves the product's sign alone. A stroke that ends
  /// level with or directly under where it began is neither this nor
  /// [_isDescending].
  bool _isAscending(_Stroke s) =>
      (s.end.dx - s.start.dx) * (s.end.dy - s.start.dy) < 0;

  /// [_isAscending]'s mirror — a `\`.
  bool _isDescending(_Stroke s) =>
      (s.end.dx - s.start.dx) * (s.end.dy - s.start.dy) > 0;

  /// Whether the last stroke is O: a single stroke that crosses its own
  /// path exactly once — the crossing is what makes it a closed loop rather
  /// than an open arc — and that crosses no other stroke on the page, since
  /// a loop tangled with something else is part of a bigger letter, not an
  /// O.
  ///
  /// This is the loosest test here, which is why [_classify] only reaches
  /// it once every letter with a shape of its own has declined.
  _LatinLetter? _classifyO() =>
      _isO(_strokes.last) ? _LatinLetter.o : null;

  /// Whether [s] on its own is O (see [_classifyO]).
  bool _isO(_Stroke s) => _isLoop(s) && !_crossesAnotherStroke(s);

  /// Whether [s] closes into a loop: one crossing of its own path, which is
  /// what makes a stroke a ring rather than an open arc.
  bool _isLoop(_Stroke s) => _selfIntersections(s) == 1;

  /// Whether the last stroke is I: a plain upright line, crossing nothing at
  /// all.
  ///
  /// The loosest test here by a wide margin, and last of all in [_classify]
  /// for it. E, F, H, B, P, R, T and K all begin with this very stroke, so
  /// an unfinished one of those genuinely *is* an I so far as the page can
  /// tell — the readout says so until the next stroke lands and settles it.
  /// That's the live readout doing its job, not a shape test being wrong.
  ///
  /// Crossing nothing is what keeps it from claiming the stem of a letter
  /// already drawn around it: H's second stem meets its bar, T's meets its
  /// own, and neither falls through to here.
  _LatinLetter? _classifyI() =>
      _isI(_strokes.last) ? _LatinLetter.i : null;

  /// Whether [s] on its own is I (see [_classifyI]).
  bool _isI(_Stroke s) => _isStem(s) && _crossesNothing(s);

  /// Whether the last four strokes form E: an upright stem, and three
  /// horizontal bars meeting it once each — one up in its top third, one
  /// across its middle third, one down in its bottom third — all three
  /// reaching away to the stem's right ([_minSideOffset]).
  ///
  /// Where along the stem the bars land is the whole letter: three bars
  /// bunched at the top is no more an E than one bar is, so the crossings
  /// are located and sorted into thirds rather than merely counted.
  /// Stroke order doesn't matter.
  _LatinLetter? _classifyE() {
    for (final size in const [4, 3]) {
      if (_strokes.length < size) continue;
      if (_isE(_strokes.sublist(_strokes.length - size))) return _LatinLetter.e;
    }
    return null;
  }

  /// Whether [strokes] form E (see [_classifyE]), in either of the two ways a
  /// hand writes it. Taken as a list rather than read off the end of [_strokes],
  /// so a mark above can be set aside and what's left asked about (see
  /// [_baseOf]).
  ///
  /// **Four strokes**: a stem and three bars, one to each third of it.
  /// **Three**: the stem and the bottom bar drawn as a single **L**, with the
  /// other two bars on it — the same letter with one pen lift fewer.
  ///
  /// The two forms can't be confused, an L being a corner where a stem is
  /// straight, and neither can be confused with F: F wants a *stem* with two
  /// bars and nothing at its foot, where the three-stroke E's foot is the L's own.
  bool _isE(List<_Stroke> strokes) =>
      _isEFromStem(strokes) || _isEFromCorner(strokes);

  bool _isEFromStem(List<_Stroke> strokes) {
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

  /// E written in three strokes: an **L** — the stem and the bottom bar in one —
  /// with a bar across its top third and another across its middle.
  ///
  /// The bars are measured against the L's own bounding box rather than against
  /// a stem picked out of it, since an L's box *is* its upright: as tall, and
  /// with its left edge down the upright. Nothing has to find the elbow.
  ///
  /// A bar reaching the bottom third would be a bar laid on the L's own foot,
  /// which is no E — so unlike the four-stroke form, which counts one bar to
  /// each third, this one refuses that third outright.
  bool _isEFromCorner(List<_Stroke> strokes) {
    if (strokes.length != 3) return false;
    final corners = strokes.where(_isL).toList();
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

  /// Whether the last three strokes form Æ: the body, then two horizontal bars
  /// across it. Stroke order doesn't matter — the three sort themselves by
  /// shape, and the two bars by which of them sits higher.
  ///
  /// The body is one stroke carrying both letters' uprights at once ([_aeBody]):
  /// A's own left leg rising to the right, and an L — down the shared upright and
  /// away along the foot. Which of the two the hand draws first doesn't matter.
  ///
  /// The lower bar is A's crossbar and E's middle bar in one, so it has to cross
  /// the rise *and* the L. The upper bar is E's top bar, and need only meet the
  /// body somewhere — where it lands it may catch one upright or both, which is
  /// a matter of hand rather than of letter.
  ///
  /// Those two demands put at least three crossings on the page between them,
  /// two from the lower bar and one from the upper. The bars must also stand
  /// clear of each other ([_minSideOffset]): two at the same height is no Æ, and
  /// which of them was the top one shouldn't turn on a pixel.
  ///
  /// Ahead of A in [_classify]. The body answers [_hasLegs]'s up-down as readily
  /// as a Λ does, so the body with either bar across it is an A to that test.
  _LatinLetter? _classifyAe() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final bodies = recent.where((s) => _aeBody(s) != null).toList();
    final bars = recent.where(_isBar).toList();
    if (bodies.length != 1 || bars.length != 2) return null;
    final body = _aeBody(bodies.single)!;

    final heights = [for (final bar in bars) _boundsOf(bar.points).center.dy];
    if ((heights.first - heights.last).abs() <= _minSideOffset) return null;
    final upper = heights.first < heights.last ? bars.first : bars.last;
    final lower = heights.first < heights.last ? bars.last : bars.first;

    // The lower bar is A's crossbar and E's middle bar at once, so it crosses
    // both of the body's uprights; the upper one need only reach the body.
    if (_crossings(lower, body.rise) < 1) return null;
    if (_crossings(lower, body.el) < 1) return null;
    if (_crossings(upper, bodies.single) < 1) return null;
    return _LatinLetter.ash;
  }

  /// Æ's two halves — its [rise] and its [el] — if [s] is the letter's body, or
  /// null if it isn't.
  ///
  /// The body is one stroke that rises and falls, cut vertically into those two
  /// legs: one of them A's own left leg leaning to the right ([_isAscending]),
  /// the other an L — a bottom-left corner, down the shared upright and away
  /// along the foot.
  ///
  /// Which leg is which turns on where the hand set off, so both readings are
  /// tried. Set off from the bottom-left and the rise comes first; set off from
  /// the end of the foot and it comes last. The run of legs is no help in telling
  /// those apart — reversing a two-leg stroke leaves up-down as up-down — so what
  /// each leg *is* has to be asked directly.
  ({_Stroke rise, _Stroke el})? _aeBody(_Stroke s) {
    if (!_hasLegs(s, const [_Leg.up, _Leg.down])) return null;
    final legs = _verticalLegs(s);
    if (_isAscending(legs.first) &&
        _isCorner(legs.last, elbow: _Corner.bottomLeft)) {
      return (rise: legs.first, el: legs.last);
    }
    if (_isAscending(legs.last) &&
        _isCorner(legs.first, elbow: _Corner.bottomLeft)) {
      return (rise: legs.last, el: legs.first);
    }
    return null;
  }

  /// Whether the last stroke is C: one stroke out to the left and back
  /// right again, its opening facing right ([_isArc]), crossing neither
  /// its own path nor any other stroke on the page.
  ///
  /// Loose, and placed last in [_classify] for that reason — the bowls of
  /// a B, of a D and of a P are all this shape mirrored, and a hand that
  /// draws one the other way round has drawn a C.
  _LatinLetter? _classifyC() =>
      _isC(_strokes.last) ? _LatinLetter.c : null;

  /// Whether [s] on its own is C (see [_classifyC]).
  bool _isC(_Stroke s) => _isArc(s) && !_crossesAnotherStroke(s);

  /// Whether the last three strokes form Đ — the same drawing [_classifyEth]
  /// reads, offered again for the alphabets that call it D-with-stroke rather than
  /// eth.
  ///
  /// In capitals the two letters are one glyph: a D with a bar through the stem.
  /// Only the lowercase tells them apart, ð's curved ascender against đ's barred
  /// d, and this recognizer draws capitals. So there is nothing to measure — the
  /// alphabet decides. Icelandic and Faroese have Ð and not Đ; Croatian has Đ and
  /// not Ð; none has both, so [_classify] offers eth first and this catches what
  /// that leaves.
  _LatinLetter? _classifyDStroke() =>
      _classifyEth() != null ? _LatinLetter.dStroke : null;

  /// Whether the last three strokes form Œ: the O's bowl as C's own left-then-
  /// right arc, an upright run down through its middle crossing it twice, and a
  /// horizontal bar off that upright's middle third. Stroke order doesn't matter
  /// — the three sort themselves by shape.
  ///
  /// The upright is the letter's seam, where the O gives way to the E, and it is
  /// what the crossing counts turn on: **twice** through the bowl, once with the
  /// bar. The bar meets the upright and nothing else, so it must miss the bowl
  /// altogether — an E's bar reaching left across the O would be a different
  /// drawing.
  ///
  /// One bar, not E's three. This is an improvised Œ rather than a faithful one.
  ///
  /// Ahead of K in [_classify], though not because a Œ drawn true would be taken
  /// for one: K asks for its arm clear to the stem's *right*, and a seam through
  /// the bowl's middle is on neither side of it. The order earns its keep at the
  /// edges. The seam is allowed anywhere within a quarter of the bowl's width of
  /// that middle, and one at the near edge of that leeway is far enough left for
  /// K to claim the pair — so a Œ drawn a little off-centre needs Œ asked first.
  _LatinLetter? _classifyEthel() {
    if (_strokes.length < 3) return null;
    final recent = _strokes.sublist(_strokes.length - 3);
    final bowls = recent.where(_isInwardArm).toList();
    final seams = recent.where(_isStem).toList();
    final bars = recent.where(_isBar).toList();
    if (bowls.length != 1 || seams.length != 1 || bars.length != 1) return null;
    final bowl = bowls.single;
    final seam = seams.single;
    final bar = bars.single;

    if (_crossings(seam, bowl) != 2) return null;
    // The bar meets the seam once, and the bowl not at all.
    if (_crossings(bar, seam) != 1) return null;
    if (_crossings(bar, bowl) != 0) return null;

    // The seam runs down the bowl's middle rather than clipping one of its arms.
    final bowlBounds = _boundsOf(bowl.points);
    if ((_boundsOf(seam.points).center.dx - bowlBounds.center.dx).abs() >
        bowlBounds.width * _junctionSnap) {
      return null;
    }
    // And the bar comes off the seam's middle third.
    final seamBounds = _boundsOf(seam.points);
    final at = _crossingPoints(bar, seam).single;
    final along = (at.dy - seamBounds.top) / seamBounds.height;
    return along >= 1 / 3 && along <= 2 / 3 ? _LatinLetter.ethel : null;
  }

  /// Whether the last two strokes form Ç or Ş: C's own arc or an S, with a
  /// cedilla hung off it — a stroke of three legs to and fro ([_isCedillaTail])
  /// crossing the letter down in its bottom third and carrying on below it.
  /// Either stroke order.
  ///
  /// The mark here that isn't above its letter, and it needs no notion of
  /// *below* to find: it crosses the letter, low down, and hangs past the foot.
  /// So where the marks in [_markedLetter] are located by [_sitsAbove], this one
  /// is located by where it meets what it marks.
  ///
  /// That is the whole of what separates a true cedilla from the comma below,
  /// and the separation is real rather than typographic: Turkish's Ş carries a
  /// cedilla, attached, where Romanian's Ș carries a comma that hangs free, and
  /// Unicode gave Ș a code point of its own to say so. Latvian's Ģ Ķ Ļ Ņ are
  /// named for the cedilla but drawn with the comma, so they go through
  /// [_classifyCommaBelow] with Ș and Ț.
  ///
  /// Ahead of C in [_classify] — though C would turn a marked arc away anyway,
  /// asking as it does that its arc cross nothing else. Ahead of S for the same
  /// reason it must be: with the tail drawn last, [_classifyS] would read the
  /// tail alone. Before the cedilla was read, a Ç drawn on the page was no
  /// letter at all.
  _LatinLetter? _classifyCedilla() {
    if (_strokes.length < 2) return null;
    final a = _strokes[_strokes.length - 2];
    final b = _strokes.last;
    for (final (body, tail, letter) in [
      (a, b, _cedillaOn(a)),
      (b, a, _cedillaOn(b)),
    ]) {
      if (letter == null || !_isCedillaTail(tail)) continue;
      if (_cedillaHangsFrom(body, tail)) return letter;
    }
    return null;
  }

  /// Which letter [s] would be with a cedilla hung off it, or null if it is
  /// neither shape that takes one.
  ///
  /// The bare shapes, [_isArc] and [_isSShaped], and not [_isC] and [_isS] —
  /// because both of those go on to ask that the letter cross **nothing**, and
  /// a cedilla crosses it. That clause is why a Ç was no letter at all before
  /// its own classifier existed, and an Ş would be none now.
  ///
  /// The two are disjoint on their ends alone: [_isArc] asks that both of them
  /// stand right of the stroke's centre, where an S finishes back at the left.
  _LatinLetter? _cedillaOn(_Stroke s) => _isArc(s)
      ? _LatinLetter.cedilla
      : _isSShaped(s)
          ? _LatinLetter.sCedilla
          : null;

  /// Whether [tail] is hung off [body] as a cedilla is: crossing it down in its
  /// bottom third, and carrying on past its foot rather than curling back up
  /// inside it.
  ///
  /// That second test is also what tells the two strokes apart when both are
  /// three-legged, as they are for Ş — a tail hangs below the S, so reading the
  /// pair the other way round puts the "tail" above the "body"'s foot and fails.
  bool _cedillaHangsFrom(_Stroke body, _Stroke tail) {
    final crossings = _crossingPoints(tail, body);
    if (crossings.isEmpty) return false;
    final bounds = _boundsOf(body.points);
    for (final at in crossings) {
      if ((at.dy - bounds.top) / bounds.height <= 2 / 3) return false;
    }
    return _boundsOf(tail.points).bottom > bounds.bottom;
  }

  /// Whether [s] is a cedilla's tail: a stroke of three legs to and fro.
  ///
  /// Which way it sets off isn't asked, and can't usefully be — three legs
  /// reversed read as their own mirror (see [_isThreeLegged]). Nor is the middle
  /// leg's lean, which for a mark this small is a matter of hand. So it is the
  /// leg count alone, and what keeps that from claiming a Z or an S is that
  /// those cross nothing where this must cross the arc.
  bool _isCedillaTail(_Stroke s) => _horizontalLegs(s).length == 3;

  /// Whether [s] is C's arc: out to the left and back right again, never
  /// crossing itself, with both its ends standing to the right of its own
  /// bounding box's centre — the opening facing right.
  ///
  /// Only where the two ends land is asked about, deliberately. How the
  /// arc rises and falls on the way is a matter of hand: the terminals of
  /// a printed C curl back toward the opening, so it goes up over the top,
  /// down the back and up again into the foot — three vertical legs, not
  /// the one a plain crescent would leave.
  bool _isArc(_Stroke s) {
    if (!_isInwardArm(s) || _selfIntersections(s) != 0) return false;
    final centre = _boundsOf(s.points).center.dx;
    return s.start.dx > centre && s.end.dx > centre;
  }

  /// Whether [stroke] crosses any other stroke on the page. [stroke] is
  /// expected to already be in [_strokes] (it's the just-committed one),
  /// so it's skipped by identity.
  bool _crossesAnotherStroke(_Stroke stroke) {
    for (final other in _strokes) {
      if (identical(other, stroke)) continue;
      if (identical(other, _attached)) continue;
      if (_crossings(stroke, other) > 0) return true;
    }
    return false;
  }

  /// A mark hung *across* its letter, set aside for as long as that letter is
  /// being read — see [_markedAcross].
  ///
  /// [_crossesAnotherStroke] walks every stroke on the page, so a letter with a
  /// mark attached to it does cross something, and the shapes that ask to cross
  /// nothing — I, U, C, S, J, Z, O — refuse it. Every other mark stands clear of
  /// its letter and never met this; an ogonek is attached by definition, and
  /// without this an Į and a Ų read as nothing while Ą and Ę were fine, A and E
  /// asking no such question.
  ///
  /// It is the same clause that made Ç and Ş need classifiers of their own, met
  /// a third time. Here it can be answered in general rather than per letter,
  /// because [_markedAcross] knows which stroke is the mark: it is not another
  /// stroke, as far as the letter it is hung on is concerned.
  _Stroke? _attached;

  /// Whether [stroke] is a single right-angle corner — one horizontal leg and
  /// one vertical leg meeting at an elbow — with that elbow in the [elbow]
  /// corner of the stroke's own bounding box.
  ///
  /// The test is: the box genuinely spans both axes ([_minCornerLeg]); the
  /// whole stroke isn't straight (a line has no elbow); the point furthest off
  /// the start→end chord — the elbow — falls in the stroke's middle with a
  /// straight leg either side of it, which is what tells a right-angle corner
  /// from a smooth arc bending the same way; those two legs run one across and
  /// one down; and the elbow lands within [_cornerSnap] of the requested box
  /// corner.
  ///
  /// Which way the hand travelled doesn't come into it. An L written down-then-
  /// right and one written right-then-up are the same letter to any reader, so
  /// the elbow is located in the stroke's own bounding box rather than by
  /// stroke order — and that is also why a G's finishing spur reads as the same
  /// [_Corner.topRight] whether it was drawn bar-then-down or up-then-left.
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

    // The elbow is the point furthest off the start→end chord; both legs
    // either side of it must themselves be straight for this to be a corner
    // and not a curve.
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

  /// The point along [stroke]'s own path that comes nearest [other] — where
  /// the two meet, when they do.
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

  /// Whether [s] is a plain flat line — A's crossbar, and each of E's
  /// three.
  bool _isBar(_Stroke s) => _isHorizontal(s) && _isStraight(s);

  /// Whether [s] is a plain upright line — E's and B's spine.
  bool _isStem(_Stroke s) => _isVertical(s) && _isStraight(s);

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

  /// Cuts [stroke] wherever it genuinely reverses vertically — A's apex,
  /// where its two legs meet.
  List<_Stroke> _verticalLegs(_Stroke stroke) =>
      _splitAtReversals(stroke, (point) => point.dy);

  /// The same cut turned on its side, wherever [stroke] reverses
  /// horizontally — C's turn back, and B's two.
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
  /// [b]: consecutive near points are one meeting, so a stem that runs into
  /// a bar and stops counts once however many of its samples land inside
  /// the tolerance, while one that leaves and comes back counts twice.
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

  /// Shortest distance from [p] to the segment [a]–[b] — measured to the
  /// nearest endpoint when the perpendicular foot falls outside the
  /// segment, so a stem alongside (but past the end of) a bar doesn't read
  /// as touching it.
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

  /// Where [a] crosses [b] — segment intersections, deduplicated so one
  /// crossing sampled across a few neighbouring segments still counts
  /// once. Works off the sampled path rather than a start-to-end chord, so
  /// it locates a crossing against a curved stroke (B's bowls) as readily
  /// as against a straight one (E's stem).
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
  /// they're parallel. Only asked for after [_segmentsIntersect] has
  /// confirmed the two segments really do cross, so the meeting point lies
  /// on both.
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
  /// touch is folded away by [_crossingPoints]' own dedup.
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

/// Builds the scene plus a direct reference to its [LatinLayer], so the
/// hosting page can call [LatinLayer.clear] from the Clear button.
(Scene, LatinLayer) buildLatinScene() {
  final layer = LatinLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
