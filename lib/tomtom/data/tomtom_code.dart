// Tom-Tom code data and decoder, ported from the `shorthand` project's
// `TomtomCodeDecoder` (git history) and self-contained under `lib/tomtom/` —
// it shares nothing with the other script features.
//
// Each letter is a run of 1–4 near-vertical strokes drawn either upward
// (ascending) or downward (descending); a horizontal stroke separates
// letters.

/// One drawn mark, as classified by [TomtomLayer]: a vertical stroke drawn
/// upward or downward, or a horizontal stroke that separates letters.
enum TomtomStroke { ascending, descending, space }

/// One row of the reference table: a character and the run of up/down strokes
/// that spells it.
class TomtomEntry {
  const TomtomEntry(this.char, this.pattern);

  final String char;
  final List<TomtomStroke> pattern;

  /// The pattern as up/down arrows, e.g. `↑↓↑`.
  String get arrows => pattern
      .map((s) => s == TomtomStroke.ascending ? '↑' : '↓')
      .join();
}

/// The Tom-Tom alphabet A–Z, each an ordered run of ascending / descending
/// strokes.
const tomtomAlphabet = <TomtomEntry>[
  TomtomEntry('A', [TomtomStroke.ascending]),
  TomtomEntry('B', [TomtomStroke.ascending, TomtomStroke.ascending]),
  TomtomEntry('C',
      [TomtomStroke.ascending, TomtomStroke.ascending, TomtomStroke.ascending]),
  TomtomEntry('D', [
    TomtomStroke.ascending,
    TomtomStroke.ascending,
    TomtomStroke.ascending,
    TomtomStroke.ascending
  ]),
  TomtomEntry('E', [TomtomStroke.ascending, TomtomStroke.descending]),
  TomtomEntry('F',
      [TomtomStroke.ascending, TomtomStroke.ascending, TomtomStroke.descending]),
  TomtomEntry('G', [
    TomtomStroke.ascending,
    TomtomStroke.ascending,
    TomtomStroke.ascending,
    TomtomStroke.descending
  ]),
  TomtomEntry('H',
      [TomtomStroke.ascending, TomtomStroke.descending, TomtomStroke.descending]),
  TomtomEntry('I', [
    TomtomStroke.ascending,
    TomtomStroke.descending,
    TomtomStroke.descending,
    TomtomStroke.descending
  ]),
  TomtomEntry('J', [TomtomStroke.descending, TomtomStroke.ascending]),
  TomtomEntry('K', [
    TomtomStroke.descending,
    TomtomStroke.descending,
    TomtomStroke.ascending
  ]),
  TomtomEntry('L', [
    TomtomStroke.descending,
    TomtomStroke.descending,
    TomtomStroke.descending,
    TomtomStroke.ascending
  ]),
  TomtomEntry('M', [
    TomtomStroke.descending,
    TomtomStroke.ascending,
    TomtomStroke.ascending
  ]),
  TomtomEntry('N', [
    TomtomStroke.descending,
    TomtomStroke.ascending,
    TomtomStroke.ascending,
    TomtomStroke.ascending
  ]),
  TomtomEntry('O',
      [TomtomStroke.ascending, TomtomStroke.descending, TomtomStroke.ascending]),
  TomtomEntry('P', [
    TomtomStroke.ascending,
    TomtomStroke.ascending,
    TomtomStroke.descending,
    TomtomStroke.ascending
  ]),
  TomtomEntry('Q', [
    TomtomStroke.ascending,
    TomtomStroke.descending,
    TomtomStroke.descending,
    TomtomStroke.ascending
  ]),
  TomtomEntry('R', [
    TomtomStroke.ascending,
    TomtomStroke.descending,
    TomtomStroke.ascending,
    TomtomStroke.ascending
  ]),
  TomtomEntry('S', [
    TomtomStroke.descending,
    TomtomStroke.ascending,
    TomtomStroke.ascending
  ]),
  TomtomEntry('T', [
    TomtomStroke.descending,
    TomtomStroke.descending,
    TomtomStroke.ascending,
    TomtomStroke.descending
  ]),
  TomtomEntry('U', [
    TomtomStroke.descending,
    TomtomStroke.ascending,
    TomtomStroke.ascending,
    TomtomStroke.descending
  ]),
  TomtomEntry('V', [
    TomtomStroke.descending,
    TomtomStroke.ascending,
    TomtomStroke.descending,
    TomtomStroke.descending
  ]),
  TomtomEntry('W', [
    TomtomStroke.ascending,
    TomtomStroke.ascending,
    TomtomStroke.descending,
    TomtomStroke.descending
  ]),
  TomtomEntry('X', [
    TomtomStroke.descending,
    TomtomStroke.descending,
    TomtomStroke.ascending,
    TomtomStroke.ascending
  ]),
  TomtomEntry('Y', [
    TomtomStroke.descending,
    TomtomStroke.ascending,
    TomtomStroke.descending,
    TomtomStroke.ascending
  ]),
  TomtomEntry('Z', [
    TomtomStroke.ascending,
    TomtomStroke.descending,
    TomtomStroke.ascending,
    TomtomStroke.descending
  ]),
];

bool _patternsEqual(List<TomtomStroke> a, List<TomtomStroke> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Decodes a stream of drawn strokes into text. Strokes accumulate into a
/// letter until a [TomtomStroke.space] flushes the run against the alphabet;
/// each space also emits a literal space in the output. Ported from
/// `TomtomCodeDecoder.interpret`.
String decodeTomtom(List<TomtomStroke> symbols) {
  final text = StringBuffer();
  final group = <TomtomStroke>[];

  for (var i = 0; i < symbols.length; i++) {
    final symbol = symbols[i];
    if (symbol != TomtomStroke.space) {
      group.add(symbol);
    }
    if (symbol == TomtomStroke.space || i == symbols.length - 1) {
      if (group.isNotEmpty) {
        for (final entry in tomtomAlphabet) {
          if (_patternsEqual(group, entry.pattern)) {
            text.write(entry.char);
            break;
          }
        }
      }
      group.clear();
      if (symbol == TomtomStroke.space) {
        text.write(' ');
      }
    }
  }
  return text.toString();
}
