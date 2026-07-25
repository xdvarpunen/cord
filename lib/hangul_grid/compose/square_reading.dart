import 'hangul_composer.dart';
import 'jamo_tables.dart';

/// Turns a grid of read syllable squares into the blocks they spell.
///
/// Squares are read left to right and then down a row.
///
/// The rule that matters here, and the reason this is not just
/// `compose(everything)`: **a square is a syllable boundary.** Each one is
/// composed on its own, so a final written in one square can never be pulled
/// forward into the next. Writing 각 and then 아 gives 각아; run together as
/// one sequence of letters those six would compose to 가가, with the second
/// onset stolen back as the first square's final.
///
/// That is the opposite of the letter-per-box grid, where the whole page
/// *is* one sequence and stealing is exactly what should happen — see
/// `grid_reading.dart`.
///
/// [jamo] is one entry per square: the letters it was read as, or null for a
/// square that is empty *or* holds something unreadable. [written] says
/// which of those nulls actually have ink in them, which is what tells the
/// two apart.
/// Returns the blocks, and for each square the index of the block it
/// produced — null for a square that produced none. A page that prints a
/// square's reading under the square needs that mapping: blocks and squares
/// are not one to one, since an empty square can add a word break and an
/// unreadable one adds nothing.
({List<ComposedBlock> blocks, List<int?> blockOfSquare}) composeSquares({
  required List<List<String>?> jamo,
  required List<bool> written,
}) {
  final out = <ComposedBlock>[];
  final blockOfSquare = List<int?>.filled(jamo.length, null);
  var started = false;
  var gap = false;

  for (var i = 0; i < jamo.length; i++) {
    final letters = jamo[i];

    if (letters == null) {
      // An empty square between two words is a space — the same rule as the
      // letter grid. A square with ink that read as nothing is a mistake,
      // not a space: it is skipped without breaking the word.
      final isEmpty = i >= written.length || !written[i];
      if (isEmpty && started) gap = true;
      continue;
    }

    // Leading gaps are ignored, and a run of empty squares is one space:
    // how much of the page you left blank is not meant to be counted.
    if (gap) {
      out.addAll(compose([kWordBreak]).blocks);
      gap = false;
    }
    blockOfSquare[i] = out.length;
    out.addAll(compose(letters).blocks);
    started = true;
  }

  // A trailing gap is the rest of the page, not a word break.
  return (blocks: out, blockOfSquare: blockOfSquare);
}
