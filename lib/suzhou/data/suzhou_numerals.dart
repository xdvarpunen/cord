/// One digit of the Suzhou numeral system (蘇州碼子, also *huāmǎ* / Hangzhou
/// numerals).
///
/// Suzhou numerals are the only surviving descendant of the Chinese rod
/// numerals still in everyday use — historically on market stalls, ledgers and
/// hand-written receipts. The digits split into two families: **1–3** are
/// simply that many vertical bars (a direct rod-numeral survival), while
/// **4–9** are cursive, run-together forms of the ordinary Chinese numerals.
///
/// Unlike a script with no encoding, every digit here *has* a Unicode
/// codepoint (U+3007, U+3021–U+3029), so the reference table can show the real
/// [glyph] alongside the value. [recognized] flags the digits [SuzhouLayer]
/// can already read freehand.
class SuzhouNumeral {
  const SuzhouNumeral(
    this.glyph,
    this.value,
    this.codepoint,
    this.category, {
    this.recognized = false,
  });

  /// The digit itself, e.g. `〡`.
  final String glyph;

  /// The number it stands for, as written in the readout.
  final int value;

  /// Unicode codepoint label, e.g. `U+3021` — shown in the reference table
  /// because several of these glyphs render only in a CJK-capable font.
  final String codepoint;

  /// Which family the digit belongs to — groups the reference table.
  final String category;

  /// Whether [SuzhouLayer] has a classifier for this digit yet.
  final bool recognized;
}

/// The ten digits, grouped by [SuzhouNumeral.category].
///
/// Deliberately *excluded*: the standard Chinese ideographs 一二三, which
/// Suzhou notation borrows for 1–3 when two bar-digits would otherwise run
/// together ambiguously (`〢一` for 21, since `〢〡` reads as 3), and the
/// magnitude characters 十百千万 used on the second line of the two-line
/// notation. This app recognizes the numeral forms only, not CJK ideographs.
const suzhouNumerals = <SuzhouNumeral>[
  SuzhouNumeral('〇', 0, 'U+3007', 'Zero', recognized: true),

  // Rod-numeral survivals: N vertical bars for N.
  SuzhouNumeral('〡', 1, 'U+3021', 'Vertical bars', recognized: true),
  SuzhouNumeral('〢', 2, 'U+3022', 'Vertical bars', recognized: true),
  SuzhouNumeral('〣', 3, 'U+3023', 'Vertical bars', recognized: true),

  // Cursive forms of 四五六七八九.
  SuzhouNumeral('〤', 4, 'U+3024', 'Cursive digits', recognized: true),
  SuzhouNumeral('〥', 5, 'U+3025', 'Cursive digits', recognized: true),
  SuzhouNumeral('〦', 6, 'U+3026', 'Cursive digits', recognized: true),
  SuzhouNumeral('〧', 7, 'U+3027', 'Cursive digits', recognized: true),
  SuzhouNumeral('〨', 8, 'U+3028', 'Cursive digits', recognized: true),
  SuzhouNumeral('〩', 9, 'U+3029', 'Cursive digits', recognized: true),
];

/// The distinct categories, in table order.
const suzhouCategories = <String>[
  'Zero',
  'Vertical bars',
  'Cursive digits',
];
