/// The Sinhala Illakkam (ඉලක්කම්) — the older numerals, and the ones the Lith
/// digits eventually replaced.
///
/// They have **no zero and no place value**. Instead of writing a number by
/// the position of its digits, the system gives every unit, every ten, and
/// then a hundred and a thousand its own symbol, and a number is written by
/// setting those side by side: 123 is the symbol for 100, then 20, then 3.
/// Which is why there is no zero to write — nothing stands in for an absent
/// column, because there are no columns.
///
/// These live well away from the rest of Sinhala in Unicode, in the Sinhala
/// Archaic Numbers block (U+111E1–U+111F4) rather than the Sinhala block, and
/// outside the Basic Multilingual Plane — so each glyph is a surrogate pair in
/// a Dart string, and `length` counts two per symbol. Yaldevi carries all
/// twenty; see assets/sinhala/FONT_NOTE.txt.
library;

/// One Illakkam symbol.
class IllakkamNumeral {
  const IllakkamNumeral(this.glyph, this.value, this.name);

  /// The symbol, from the Sinhala Archaic Numbers block.
  final String glyph;

  /// What it stands for on its own.
  final int value;

  /// The Sinhala name of the number, romanized.
  final String name;
}

/// The units, 1 to 9 — the same names as the Lith digits carry.
const illakkamUnits = [
  IllakkamNumeral('𑇡', 1, 'eka'),
  IllakkamNumeral('𑇢', 2, 'deka'),
  IllakkamNumeral('𑇣', 3, 'tuna'),
  IllakkamNumeral('𑇤', 4, 'hatara'),
  IllakkamNumeral('𑇥', 5, 'paha'),
  IllakkamNumeral('𑇦', 6, 'haya'),
  IllakkamNumeral('𑇧', 7, 'hata'),
  IllakkamNumeral('𑇨', 8, 'aṭa'),
  IllakkamNumeral('𑇩', 9, 'navaya'),
];

/// The tens, each with a symbol of its own rather than being built from a
/// unit — this is what having no place value costs.
const illakkamTens = [
  IllakkamNumeral('𑇪', 10, 'dahaya'),
  IllakkamNumeral('𑇫', 20, 'vissa'),
  IllakkamNumeral('𑇬', 30, 'tiha'),
  IllakkamNumeral('𑇭', 40, 'hataliha'),
  IllakkamNumeral('𑇮', 50, 'panaha'),
  IllakkamNumeral('𑇯', 60, 'heṭa'),
  IllakkamNumeral('𑇰', 70, 'hættǣva'),
  IllakkamNumeral('𑇱', 80, 'asūva'),
  IllakkamNumeral('𑇲', 90, 'anūva'),
];

/// A hundred and a thousand, where the symbols stop. Larger numbers are
/// written by repeating and combining these.
const illakkamHundreds = [
  IllakkamNumeral('𑇳', 100, 'siyaya'),
  IllakkamNumeral('𑇴', 1000, 'dahasa'),
];

/// Every Illakkam symbol, in value order.
const illakkamNumerals = [
  ...illakkamUnits,
  ...illakkamTens,
  ...illakkamHundreds,
];
