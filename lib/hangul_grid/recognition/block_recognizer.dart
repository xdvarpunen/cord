/// Reads a whole Hangul syllable written as one block.
///
/// The other canvases ask you for one letter at a time. This one takes a
/// square with a finished syllable in it — 한, 곡, 값 — and works out which
/// strokes are the onset, which are the vowel, and which are the final.
///
/// ## How
///
/// Hangul arranges a block by the *vowel's* orientation, and there are only
/// six arrangements:
///
/// ```
///   가  onset | vowel        고  onset          과  onset | vowel
///                                -----             ------|
///   각  onset | vowel            vowel          괌  vowel |
///       -------------        곡  onset              ------------
///          final                 vowel                 final
///                                -----
///                                final
/// ```
///
/// So rather than segmenting first and classifying after, this proposes
/// *cuts* — every gap between strokes, along each axis, in each of the six
/// arrangements — and keeps the ones where every piece classifies as a real
/// letter of the right kind. Almost every wrong cut is thrown out by one of
/// two rules:
///
/// - **Category.** The first piece has to be a letter that can start a
///   syllable, the last a letter that can end one. ㅣ is neither, so a cut
///   that leaves a bare stem as the "final" dies immediately.
/// - **Orientation.** A side-by-side arrangement demands a vertical vowel
///   (ㅏ ㅓ ㅣ …), a stacked one demands a horizontal vowel (ㅗ ㅜ ㅡ), and a
///   wrapped one demands a wrapping vowel (ㅘ ㅚ ㅢ …). Reading 고 as if it
///   were 가 requires ㅗ to be a vertical vowel, and it is not.
///
/// What survives is scored: more pieces first — a spurious third piece would
/// have to classify as a valid final *and* leave the other two intact, which
/// almost never happens — and then by how cleanly the cut separates them.
library;

import 'dart:ui' show Offset, Rect;

import '../compose/jamo_tables.dart';
import '../scenes/jamo_scene.dart';

/// Vowels written as a tall stroke on the right of the onset: 가, 너, 비.
const kVerticalVowels = <String>{
  'ㅏ',
  'ㅐ',
  'ㅑ',
  'ㅒ',
  'ㅓ',
  'ㅔ',
  'ㅕ',
  'ㅖ',
  'ㅣ',
};

/// Vowels written as a wide stroke underneath the onset: 고, 부, 그.
const kHorizontalVowels = <String>{'ㅗ', 'ㅛ', 'ㅜ', 'ㅠ', 'ㅡ'};

/// Vowels that do both at once, wrapping the onset: 과, 외, 워, 의.
const kWrappingVowels = <String>{'ㅘ', 'ㅙ', 'ㅚ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅢ'};

/// How the pieces of a block are arranged.
enum BlockLayout {
  /// Onset and vowel side by side: 가.
  sideBySide,

  /// Side by side, over a final: 각.
  sideBySideFinal,

  /// Onset above the vowel: 고.
  stacked,

  /// Stacked, over a final: 곡.
  stackedFinal,

  /// The vowel wraps under and around the onset: 과.
  wrapped,

  /// Wrapped, over a final: 괌.
  wrappedFinal,

  /// Not a whole block — a single letter on its own, which is what you have
  /// while the block is still half written.
  partial;

  bool get hasFinal =>
      this == sideBySideFinal || this == stackedFinal || this == wrappedFinal;
}

/// What a block was read as.
class BlockReading {
  const BlockReading({
    required this.layout,
    required this.score,
    this.cho,
    this.jung,
    this.jong,
  });

  final BlockLayout layout;

  /// Higher is better. Only meaningful for comparing readings of the same
  /// block.
  final double score;

  /// The letters, as compatibility jamo.
  final String? cho;
  final String? jung;
  final String? jong;

  bool get isSyllable => cho != null && jung != null;

  /// The block as text: a precomposed syllable if it is a whole one, and
  /// otherwise the bare letter that has been written so far.
  String get text {
    final c = cho, v = jung;
    if (c != null && v != null) {
      return syllable(
        kChoseongIndex[c]!,
        kJungseongIndex[v]!,
        jong == null ? 0 : kJongseongIndex[jong]!,
      );
    }
    return c ?? v ?? '';
  }

  /// The letters in writing order, which is what feeds the composer.
  List<String> get jamo => [
        if (cho != null) cho!,
        if (jung != null) jung!,
        if (jong != null) ...?_finalJamo,
      ];

  /// A two-letter final was written as two letters, so it is reported as
  /// two — that is what you drew, and it is what the composer merges back.
  List<String>? get _finalJamo {
    final j = jong;
    if (j == null) return null;
    final split = kJongSplit[j];
    return split == null ? [j] : [split.$1, split.$2];
  }
}

/// The size a piece is scaled to before it is classified.
///
/// The classifiers' tolerances are absolute pixel distances tuned for a
/// letter drawn a couple of hundred pixels tall, so every piece is scaled —
/// uniformly, to keep its proportions — until its longer side is this. A
/// letter is then the size the classifiers expect no matter how large the
/// block was or how small a corner of it the letter occupies.
const double _pieceExtent = 260;

/// Where a scaled piece is placed in the reference box.
const Offset _pieceCentre = Offset(200, 200);

/// A piece smaller than this fraction of the block is a slip of the pen, not
/// a letter. Without it, scaling would blow a 2px smudge up into a stroke.
const double _minPieceExtent = 0.06;

/// How much two pieces may overlap along the axis that separates them,
/// as a fraction of the block. Handwriting is not tidy; a vowel's tick can
/// dip below the line a final starts on.
const double _maxOverlap = 0.28;

/// Above this many strokes the block is assumed to be a scribble rather than
/// a syllable. The most elaborate real block — 뷁 — is about twelve.
const int _maxStrokes = 14;

/// Reads the strokes in one block, in coordinates local to it.
///
/// [blockSize] is the square's side, used to judge what is too small to be a
/// letter and how far apart two pieces are. Returns null if nothing sensible
/// can be read.
BlockReading? recognizeBlock(
  List<List<Offset>> strokes, {
  required double blockSize,
}) {
  if (strokes.isEmpty || strokes.length > _maxStrokes) return null;

  final bounds = [for (final s in strokes) _boundsOf(s)];
  final n = strokes.length;
  final byX = List.generate(n, (i) => i)
    ..sort((a, b) => bounds[a].center.dx.compareTo(bounds[b].center.dx));
  final byY = List.generate(n, (i) => i)
    ..sort((a, b) => bounds[a].center.dy.compareTo(bounds[b].center.dy));

  // Classifying is the expensive part and the same group of strokes comes up
  // under many different cuts, so each group is only ever read once.
  final cache = <String, String?>{};
  String? read(List<int> piece) {
    if (piece.isEmpty) return null;
    final key = (piece.toList()..sort()).join(',');
    return cache.putIfAbsent(key, () {
      final rect = _unionOf([for (final i in piece) bounds[i]]);
      final extent = rect.longestSide;
      if (extent < blockSize * _minPieceExtent) return null;
      return recognizeJamo(_scaled([for (final i in piece) strokes[i]], rect));
    });
  }

  Rect boundsOfPiece(List<int> piece) =>
      _unionOf([for (final i in piece) bounds[i]]);

  BlockReading? best;
  void consider(BlockReading? candidate) {
    if (candidate == null) return;
    if (best == null || candidate.score > best!.score) best = candidate;
  }

  /// Validates one proposed cut.
  BlockReading? propose({
    required BlockLayout layout,
    required List<int> cho,
    required List<int> jung,
    List<int>? jong,
    required double gap,
  }) {
    if (gap < -_maxOverlap) return null;

    final onset = read(cho);
    if (onset == null || !kChoseongIndex.containsKey(onset)) return null;

    final vowel = read(jung);
    if (vowel == null) return null;
    final allowed = switch (layout) {
      BlockLayout.sideBySide || BlockLayout.sideBySideFinal => kVerticalVowels,
      BlockLayout.stacked || BlockLayout.stackedFinal => kHorizontalVowels,
      BlockLayout.wrapped || BlockLayout.wrappedFinal => kWrappingVowels,
      BlockLayout.partial => const <String>{},
    };
    if (!allowed.contains(vowel)) return null;

    String? coda;
    if (jong != null) {
      coda = read(jong);
      if (coda == null || !kJongseongIndex.containsKey(coda)) return null;
    }

    final pieces = jong == null ? 2 : 3;
    return BlockReading(
      layout: layout,
      cho: onset,
      jung: vowel,
      jong: coda,
      score: pieces * 10 + gap,
    );
  }

  /// The same, with the final written as two letters — 값, 닭, 앉.
  BlockReading? proposeCluster({
    required BlockLayout layout,
    required List<int> cho,
    required List<int> jung,
    required List<int> jongLeft,
    required List<int> jongRight,
    required double gap,
  }) {
    if (gap < -_maxOverlap) return null;

    final left = read(jongLeft);
    final right = read(jongRight);
    if (left == null || right == null) return null;
    final merged = kJongMerge[left + right];
    if (merged == null) return null;

    final onset = read(cho);
    if (onset == null || !kChoseongIndex.containsKey(onset)) return null;
    final vowel = read(jung);
    if (vowel == null) return null;
    final allowed = switch (layout) {
      BlockLayout.sideBySideFinal => kVerticalVowels,
      BlockLayout.stackedFinal => kHorizontalVowels,
      BlockLayout.wrappedFinal => kWrappingVowels,
      _ => const <String>{},
    };
    if (!allowed.contains(vowel)) return null;

    return BlockReading(
      layout: layout,
      cho: onset,
      jung: vowel,
      jong: merged,
      // A two-letter final is four pieces of evidence agreeing, so it
      // outranks the three-piece reading of the same strokes.
      score: 4 * 10 + gap,
    );
  }

  double gapX(List<int> a, List<int> b) =>
      (boundsOfPiece(b).left - boundsOfPiece(a).right) / blockSize;
  double gapY(List<int> a, List<int> b) =>
      (boundsOfPiece(b).top - boundsOfPiece(a).bottom) / blockSize;

  /// Every way of cutting the coda off the bottom and splitting the rest,
  /// shared by the three layouts that have a final.
  void withFinal(
    BlockLayout layout,
    void Function(List<int> above, List<int> coda, double gap) body,
  ) {
    for (var cut = 1; cut < n; cut++) {
      final above = byY.sublist(0, cut);
      final coda = byY.sublist(cut);
      if (above.length < 2) continue;
      body(above, coda, gapY(above, coda));
    }
  }

  /// Splits a final into its two letters, left and right, and offers both
  /// the single-letter and the two-letter reading.
  void offerFinal({
    required BlockLayout layout,
    required List<int> cho,
    required List<int> jung,
    required List<int> coda,
    required double gap,
  }) {
    consider(propose(
      layout: layout,
      cho: cho,
      jung: jung,
      jong: coda,
      gap: gap,
    ));
    if (coda.length < 2) return;
    final codaByX = coda.toList()
      ..sort((a, b) => bounds[a].center.dx.compareTo(bounds[b].center.dx));
    for (var cut = 1; cut < codaByX.length; cut++) {
      consider(proposeCluster(
        layout: layout,
        cho: cho,
        jung: jung,
        jongLeft: codaByX.sublist(0, cut),
        jongRight: codaByX.sublist(cut),
        gap: gap,
      ));
    }
  }

  // 가 — onset and vowel side by side.
  for (var cut = 1; cut < n; cut++) {
    final left = byX.sublist(0, cut);
    final right = byX.sublist(cut);
    consider(propose(
      layout: BlockLayout.sideBySide,
      cho: left,
      jung: right,
      gap: gapX(left, right),
    ));
  }

  // 고 — onset above the vowel.
  for (var cut = 1; cut < n; cut++) {
    final top = byY.sublist(0, cut);
    final bottom = byY.sublist(cut);
    consider(propose(
      layout: BlockLayout.stacked,
      cho: top,
      jung: bottom,
      gap: gapY(top, bottom),
    ));
  }

  // 각 — side by side, over a final.
  withFinal(BlockLayout.sideBySideFinal, (above, coda, gap) {
    final aboveByX = above.toList()
      ..sort((a, b) => bounds[a].center.dx.compareTo(bounds[b].center.dx));
    for (var cut = 1; cut < aboveByX.length; cut++) {
      final left = aboveByX.sublist(0, cut);
      final right = aboveByX.sublist(cut);
      offerFinal(
        layout: BlockLayout.sideBySideFinal,
        cho: left,
        jung: right,
        coda: coda,
        gap: _min(gap, gapX(left, right)),
      );
    }
  });

  // 곡 — stacked, over a final.
  for (var c1 = 1; c1 < n - 1; c1++) {
    for (var c2 = c1 + 1; c2 < n; c2++) {
      final top = byY.sublist(0, c1);
      final middle = byY.sublist(c1, c2);
      final coda = byY.sublist(c2);
      offerFinal(
        layout: BlockLayout.stackedFinal,
        cho: top,
        jung: middle,
        coda: coda,
        gap: _min(gapY(top, middle), gapY(middle, coda)),
      );
    }
  }

  /// 과 — the onset sits top-left and the vowel wraps under and around it.
  /// The cut is two-stage: peel off the right-hand column, then take the top
  /// of what is left as the onset. The rest of the left column belongs to
  /// the vowel, which is what makes the vowel's shape an L.
  void wrappedIn(
      List<int> pool, BlockLayout layout, List<int>? coda, double codaGap) {
    if (pool.length < 3) return;
    final poolByX = pool.toList()
      ..sort((a, b) => bounds[a].center.dx.compareTo(bounds[b].center.dx));
    for (var cutX = 1; cutX < poolByX.length; cutX++) {
      final left = poolByX.sublist(0, cutX);
      final right = poolByX.sublist(cutX);
      if (left.length < 2) continue;
      final leftByY = left.toList()
        ..sort((a, b) => bounds[a].center.dy.compareTo(bounds[b].center.dy));
      for (var cutY = 1; cutY < leftByY.length; cutY++) {
        final onset = leftByY.sublist(0, cutY);
        final under = leftByY.sublist(cutY);
        final vowel = [...under, ...right];
        final gap = _min(gapY(onset, under), gapX(left, right));
        if (coda == null) {
          consider(propose(
            layout: layout,
            cho: onset,
            jung: vowel,
            gap: gap,
          ));
        } else {
          offerFinal(
            layout: layout,
            cho: onset,
            jung: vowel,
            coda: coda,
            gap: _min(gap, codaGap),
          );
        }
      }
    }
  }

  wrappedIn(List.generate(n, (i) => i), BlockLayout.wrapped, null, 0);
  withFinal(BlockLayout.wrappedFinal, (above, coda, gap) {
    wrappedIn(above, BlockLayout.wrappedFinal, coda, gap);
  });

  // Nothing whole was found, so report the single letter the block holds —
  // which is what it holds while you are still part way through writing it.
  if (best == null) {
    final whole = read(List.generate(n, (i) => i));
    if (whole == null) return null;
    final isVowel = kJungseongIndex.containsKey(whole);
    return BlockReading(
      layout: BlockLayout.partial,
      cho: isVowel ? null : whole,
      jung: isVowel ? whole : null,
      score: 0,
    );
  }
  return best;
}

double _min(double a, double b) => a < b ? a : b;

/// Scales a piece uniformly to [_pieceExtent] and centres it, so the
/// classifiers see it at the size they were tuned for. Uniform, because
/// stretching a bounding box to a square would turn ㅁ into ㅂ's proportions
/// and a flat ㅡ into nonsense.
List<List<Offset>> _scaled(List<List<Offset>> piece, Rect rect) {
  final extent = rect.longestSide;
  if (extent <= 0) return piece;
  final scale = _pieceExtent / extent;
  final centre = rect.center;
  return [
    for (final stroke in piece)
      [for (final p in stroke) (p - centre) * scale + _pieceCentre],
  ];
}

Rect _boundsOf(List<Offset> points) {
  var minX = points.first.dx, maxX = minX;
  var minY = points.first.dy, maxY = minY;
  for (final p in points) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

Rect _unionOf(List<Rect> rects) {
  var out = rects.first;
  for (final r in rects.skip(1)) {
    out = out.expandToInclude(r);
  }
  return out;
}
