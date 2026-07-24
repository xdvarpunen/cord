/// One Hebrew letter: its glyph, its name, and an approximate sound value.
///
/// The full alef-bet is listed so the on-page legend can show the whole
/// alphabet for reference, with the letters the recognizer can't draw yet
/// shown muted (see `HebrewLayer.recognizedNames`). Letters are matched
/// against the legend by [name] rather than [sound], since several Hebrew
/// letters share a romanized sound (tet and tav are both 't').
class LetterRow {
  const LetterRow(this.glyph, this.name, this.sound);

  final String glyph;

  /// The letter's name (e.g. 'bet' for ב), used as its stable key.
  final String name;

  /// A rough romanized sound value, for the legend label.
  final String sound;
}

/// The 22 letters of the Hebrew alphabet, in alphabetical order.
const letterRows = [
  LetterRow('א', 'alef', "'"),
  LetterRow('ב', 'bet', 'b/v'),
  LetterRow('ג', 'gimel', 'g'),
  LetterRow('ד', 'dalet', 'd'),
  LetterRow('ה', 'he', 'h'),
  LetterRow('ו', 'vav', 'v/w'),
  LetterRow('ז', 'zayin', 'z'),
  LetterRow('ח', 'chet', 'ch'),
  LetterRow('ט', 'tet', 't'),
  LetterRow('י', 'yod', 'y'),
  LetterRow('כ', 'kaf', 'k/kh'),
  LetterRow('ל', 'lamed', 'l'),
  LetterRow('מ', 'mem', 'm'),
  LetterRow('נ', 'nun', 'n'),
  LetterRow('ס', 'samekh', 's'),
  LetterRow('ע', 'ayin', "'"),
  LetterRow('פ', 'pe', 'p/f'),
  LetterRow('צ', 'tsadi', 'ts'),
  LetterRow('ק', 'qof', 'q'),
  LetterRow('ר', 'resh', 'r'),
  LetterRow('ש', 'shin', 'sh'),
  LetterRow('ת', 'tav', 't'),
];

/// The 5 final (sofit) forms — the shapes five letters take at the end of a
/// word. Listed separately from the base alef-bet, the way they're taught.
const finalRows = [
  LetterRow('ך', 'final kaf', 'k/kh'),
  LetterRow('ם', 'final mem', 'm'),
  LetterRow('ן', 'final nun', 'n'),
  LetterRow('ף', 'final pe', 'p/f'),
  LetterRow('ץ', 'final tsadi', 'ts'),
];

/// Which script glyphs are shown in — the modern square alef-bet, or its
/// ancient Paleo-Hebrew (Phoenician) forms.
///
/// **cord only ever uses [modern]**: this page is the `heb` app *without*
/// Paleo-Hebrew, so nothing here selects [paleo]. The enum (and [paleoGlyphs] /
/// [glyphIn] below) stay only because `hebrew_scene.dart` is a verbatim copy of
/// the upstream recognizer, which branches on them — the same way the Tifinagh
/// page keeps its unused Neo-Tifinagh classifiers. The paleo-only reference
/// rows (the word separator and the Phoenician numerals) are dropped, since
/// nothing in cord can reach them.
enum HebrewScript { modern, paleo }

/// The Paleo-Hebrew form of each modern glyph, from the Unicode Phoenician
/// block (U+10900–U+10915). Final forms map to their base letter —
/// Paleo-Hebrew has no final forms.
const paleoGlyphs = <String, String>{
  'א': '\u{10900}', // alef
  'ב': '\u{10901}', // bet
  'ג': '\u{10902}', // gimel
  'ד': '\u{10903}', // dalet
  'ה': '\u{10904}', // he
  'ו': '\u{10905}', // vav
  'ז': '\u{10906}', // zayin
  'ח': '\u{10907}', // chet
  'ט': '\u{10908}', // tet
  'י': '\u{10909}', // yod
  'כ': '\u{1090A}', // kaf
  'ל': '\u{1090B}', // lamed
  'מ': '\u{1090C}', // mem
  'נ': '\u{1090D}', // nun
  'ס': '\u{1090E}', // samekh
  'ע': '\u{1090F}', // ayin
  'פ': '\u{10910}', // pe
  'צ': '\u{10911}', // tsadi
  'ק': '\u{10912}', // qof
  'ר': '\u{10913}', // resh
  'ש': '\u{10914}', // shin
  'ת': '\u{10915}', // tav
  'ך': '\u{1090A}', // final kaf → kaf
  'ם': '\u{1090C}', // final mem → mem
  'ן': '\u{1090D}', // final nun → nun
  'ף': '\u{10910}', // final pe → pe
  'ץ': '\u{10911}', // final tsadi → tsadi
};

/// [modernGlyph] shown in [script]: unchanged for [HebrewScript.modern], its
/// Paleo-Hebrew form for [HebrewScript.paleo] (falling back to the modern glyph
/// if somehow unmapped).
String glyphIn(String modernGlyph, HebrewScript script) =>
    script == HebrewScript.paleo
        ? (paleoGlyphs[modernGlyph] ?? modernGlyph)
        : modernGlyph;
