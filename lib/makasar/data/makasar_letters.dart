/// The Makasar script (also "Old Makassarese", *ukiri' jangang-jangang* /
/// "bird script") — the abugida used for Makassarese in South Sulawesi
/// from the 17th to the 19th century, per Wikipedia's "Makasar script"
/// article and Unicode's Makasar block (U+11EE0–U+11EF8).
///
/// Every consonant carries an inherent `a`; the four vowel signs
/// ([makasarVowelSigns]) replace it. There is no virama, so final
/// consonants simply go unwritten.
///
/// [MakasarLetter.shape] describes how the letterform decomposes into the
/// script's handful of building blocks, read off the letterforms in the
/// bundled Noto Serif Makasar font (`assets/makasar`) — this is what
/// [MakasarLayer] recognizes, so the two are written to match:
///
/// - a **wedge**, `Λ` — an upside-down V, the script's core element. The
///   letters differ first by how many wedges sit side by side (1, 2 or 3).
/// - a **chevron**, `V` — a wedge turned upside down.
/// - a **bowl**, `U` — a tall, narrow chevron, drawn under a wedge like a
///   descender.
/// - a **bar**, `—` — a horizontal line, usually closing a shape off at
///   the bottom.
/// - a **stem**, `|` — a vertical line.
class MakasarLetter {
  const MakasarLetter(this.glyph, this.name, this.ipa, this.image, this.shape);

  /// The Unicode glyph, rendered in `NotoSerifMakasar`.
  final String glyph;

  /// The letter's name, which is also its transliteration: every consonant
  /// is named for itself plus the inherent vowel (`ka`, `ga`, …).
  final String name;

  /// The consonant's sound in IPA — without the inherent `a`.
  final String ipa;

  /// The letterform as drawn, for [GlyphImage] — see it for why the font
  /// glyph alone isn't enough.
  final String image;

  /// How the letterform decomposes into the building blocks above (see the
  /// class doc).
  final String shape;
}

const makasarLetters = [
  MakasarLetter('\u{11EE0}', 'ka', 'k', 'mak_ka',
      'a sweep right then back left + a line below'),
  MakasarLetter('\u{11EE1}', 'ga', 'ɡ', 'mak_ga', '2 wedges + a wedge below'),
  MakasarLetter('\u{11EE2}', 'nga', 'ŋ', 'mak_nga',
      'wedge + a chevron below its right arm'),
  // Also transliterated fa.
  MakasarLetter('\u{11EE3}', 'pa', 'p', 'mak_pa',
      '2 wedges, the second dropping only slightly'),
  MakasarLetter('\u{11EE4}', 'ba', 'b', 'mak_ba', '2 wedges + a chevron below'),
  MakasarLetter(
      '\u{11EE5}', 'ma', 'm', 'mak_ma', '2 wedges + a barred wedge below'),
  MakasarLetter('\u{11EE6}', 'ta', 't', 'mak_ta',
      'wedge + a bowl on its right arm, crossing once'),
  MakasarLetter(
      '\u{11EE7}', 'da', 'd', 'mak_da', 'left-right-left-right over a base'),
  MakasarLetter('\u{11EE8}', 'na', 'n', 'mak_na', 'a single wedge'),
  MakasarLetter('\u{11EE9}', 'ca', 'tʃ', 'mak_ca', 'wedge + 2 bowls below'),
  MakasarLetter(
      '\u{11EEA}', 'ja', 'dʒ', 'mak_ja', '2 wedges, arms crossing once'),
  MakasarLetter(
      '\u{11EEB}', 'nya', 'ɲ', 'mak_nya', '3 wedges, arms crossing twice'),
  MakasarLetter('\u{11EEC}', 'ya', 'j', 'mak_ya',
      '3 wedges crossing + an ascending line below'),
  MakasarLetter('\u{11EED}', 'ra', 'r', 'mak_ra',
      'a stem hooking back + a chevron below'),
  MakasarLetter('\u{11EEE}', 'la', 'l', 'mak_la',
      'one stroke doubling back twice, base first'),
  // Unicode names this letter VA (U+11EEF MAKASAR LETTER VA); Wikipedia's
  // letter table transliterates it wa, which is what it's called here.
  MakasarLetter('\u{11EEF}', 'wa', 'w', 'mak_wa',
      '2 rightward strokes over a shared base'),
  MakasarLetter('\u{11EF0}', 'sa', 's', 'mak_sa',
      'left, right, then a long drop back left'),
  // Also read ha.
  MakasarLetter(
      '\u{11EF1}', 'a', 'ʔ', 'mak_a', 'one stroke sweeping sideways 5 times'),
];

/// The letters by name, for looking one up from a [LontaraLetter]'s
/// [LontaraLetter.makasarName] — the two scripts' listings both name the
/// letter the other lines up with.
final makasarLettersByName = {
  for (final letter in makasarLetters) letter.name: letter,
};

/// The four vowel signs, which replace a consonant's inherent `a`. Each is
/// a mark attached to the consonant rather than a letter of its own — a
/// dot above or below for `i`/`u`, a hook in front of or behind the letter
/// for `e`/`o`. Names are the Makassarese ones given by Wikipedia.
class MakasarVowelSign {
  const MakasarVowelSign(
      this.glyph, this.vowel, this.name, this.image, this.placement);
  final String glyph;
  final String vowel;
  final String name;

  /// The mark drawn on a dotted circle — the `sign_*` images, which are the
  /// same four marks Lontara uses, so both scripts' tables share them
  /// (as Wikipedia's own tables do).
  final String image;
  final String placement;
}

const makasarVowelSigns = [
  MakasarVowelSign('\u{11EF3}', 'i', "tittiʼ i rate", 'sign_i', 'dot above'),
  MakasarVowelSign('\u{11EF4}', 'u', "tittiʼ i rawa", 'sign_u', 'dot below'),
  MakasarVowelSign(
      '\u{11EF5}', 'e', "anaʼ ri olo", 'sign_e', 'hook in front (left)'),
  MakasarVowelSign(
      '\u{11EF6}', 'o', "anaʼ ri boko", 'sign_o', 'hook behind (right)'),
];

/// The script's remaining signs: a repeater plus its two punctuation
/// marks. Text itself is written *scriptio continua* — no spaces between
/// words.
class MakasarSign {
  const MakasarSign(this.glyph, this.name, this.image, this.use);
  final String glyph;
  final String name;

  /// The sign as drawn, or null where the article has no image of it —
  /// which is only angka.
  final String? image;
  final String use;
}

const makasarOtherSigns = [
  // Not punctuation: angka stands in for a repeated initial consonant, so
  // a run of syllables starting with the same consonant can be written
  // once and then repeated, with the vowel signs carrying on as usual.
  MakasarSign('\u{11EF2}', 'angka', null, 'repeats the previous consonant'),
  MakasarSign('\u{11EF7}', 'passimbang', 'mak_passimbang',
      'separates sections/phrases'),
  MakasarSign('\u{11EF8}', 'end of section', 'mak_endtext', 'closes a passage'),
];
