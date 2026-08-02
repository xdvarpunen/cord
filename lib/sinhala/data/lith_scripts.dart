/// One row of the Sinhala Lith numeral reference table.
///
/// The Lith numerals (ලිත් ඉලක්කම් — the astrological / almanac digits) are a
/// decimal, place-value system *with* a zero placeholder — the same way we
/// write numbers with Western digits, just with different glyphs. This is
/// what distinguishes them from the older Sinhala Illakkam (ඉලක්කම්), which
/// has no zero and no place value (dedicated symbols for 10, 20, … 100, 1000)
/// — that non-zero system is a separate, later addition.
///
/// Unlike the tifi project's Libyco-Berber letters, every Lith digit has its
/// own Unicode codepoint in the Sinhala block (U+0DE6–U+0DEF), so it renders
/// straight from a font — no bundled letterform images needed.
class LithDigit {
  const LithDigit(this.glyph, this.value, this.name, this.shape);

  /// The digit's Unicode glyph (U+0DE6 + [value]).
  final String glyph;

  /// The decimal value 0–9.
  final int value;

  /// The Sinhala name of the number (romanized), e.g. "paha" for 5.
  final String name;

  /// A short hint describing how the glyph is drawn — the same shape cue the
  /// recognizer keys on (see [SinhalaLithLayer]).
  final String shape;
}

/// The ten Sinhala Lith digits, in value order.
const lithDigits = [
  LithDigit('෦', 0, 'binduva', 'Tall, narrow stroke with a small hook at the top'),
  LithDigit('෧', 1, 'eka', 'A single compact coil'),
  LithDigit('෨', 2, 'deka', 'Two coils side by side'),
  LithDigit('෩', 3, 'thuna', 'The two coils of 2, plus a tail rising to the right'),
  LithDigit('෪', 4, 'hathara', 'A coil with a steep diagonal slash to the top-right'),
  LithDigit('෫', 5, 'paha', 'A tall cursive S/ε curve with a loop low down'),
  LithDigit('෬', 6, 'haya', 'A wide, sideways loop with an inner curl'),
  LithDigit('෭', 7, 'hata', 'An open hooked curve (no closed loop)'),
  LithDigit('෮', 8, 'ata', 'A loop low down with a stroke rising above it'),
  LithDigit('෯', 9, 'navaya', 'A compound of several coils — the most elaborate'),
];
