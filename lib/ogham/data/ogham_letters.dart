/// Ogham reference data (per Wikipedia's "Ogham" article). Self-contained
/// under `lib/ogham/` — shares nothing with the other script features.
///
/// Ogham is written along a central stemline (a *druim*). The twenty
/// primary letters (*feda*) are grouped into four families (*aicmí*) of
/// five, distinguished by where their 1–5 strokes sit relative to the
/// stem:
///
/// - **Aicme Beithe** — 1–5 strokes on one side of the stem (below the
///   horizontal stemline here): B L F S N.
/// - **Aicme hÚatha** — 1–5 strokes on the other side (above): H D T C Q.
/// - **Aicme Muine** — 1–5 strokes crossing the stem (diagonally): M G NG
///   Z R.
/// - **Aicme Ailme** — 1–5 short notches *on* the stem, the vowels:
///   A O U E I.
///
/// A fifth group, the **forfeda** (E A, O I, U I, P/peith, AE), are later
/// additional letters with irregular shapes.
enum OghamAicme {
  beithe('Aicme Beithe', 'strokes below the stem'),
  huatha('Aicme hÚatha', 'strokes above the stem'),
  muine('Aicme Muine', 'strokes across the stem'),
  ailme('Aicme Ailme', 'notches on the stem (vowels)'),
  forfeda('Forfeda', 'extra letters');

  const OghamAicme(this.irishName, this.description);

  final String irishName;
  final String description;
}

/// One letter of the Ogham reference table: the Unicode glyph (kept for
/// documentation — Ogham is drawn as vectors in the app, since Flutter web
/// has no fallback font for the Ogham block U+1680–U+169F), the Latin
/// transliteration, the traditional letter name, its sound value, which
/// *aicme* it belongs to, and how many strokes make it up (1–5 for the
/// primary letters, 0 for the irregular forfeda).
class OghamLetter {
  const OghamLetter({
    required this.char,
    required this.translit,
    required this.name,
    required this.sound,
    required this.aicme,
    required this.strokeCount,
  });

  final String char;
  final String translit;
  final String name;
  final String sound;
  final OghamAicme aicme;
  final int strokeCount;
}

/// The twenty primary letters (four *aicmí* of five) followed by the five
/// *forfeda*. Order within each *aicme* is stroke count 1→5.
const oghamLetters = [
  // Aicme Beithe — strokes below the stem.
  OghamLetter(
      char: 'ᚁ',
      translit: 'b',
      name: 'beith',
      sound: 'b',
      aicme: OghamAicme.beithe,
      strokeCount: 1),
  OghamLetter(
      char: 'ᚂ',
      translit: 'l',
      name: 'luis',
      sound: 'l',
      aicme: OghamAicme.beithe,
      strokeCount: 2),
  OghamLetter(
      char: 'ᚃ',
      translit: 'f',
      name: 'fearn',
      sound: 'w → f',
      aicme: OghamAicme.beithe,
      strokeCount: 3),
  OghamLetter(
      char: 'ᚄ',
      translit: 's',
      name: 'sail',
      sound: 's',
      aicme: OghamAicme.beithe,
      strokeCount: 4),
  OghamLetter(
      char: 'ᚅ',
      translit: 'n',
      name: 'nion',
      sound: 'n',
      aicme: OghamAicme.beithe,
      strokeCount: 5),

  // Aicme hÚatha — strokes above the stem.
  OghamLetter(
      char: 'ᚆ',
      translit: 'h',
      name: 'úath',
      sound: 'j → h',
      aicme: OghamAicme.huatha,
      strokeCount: 1),
  OghamLetter(
      char: 'ᚇ',
      translit: 'd',
      name: 'dair',
      sound: 'd',
      aicme: OghamAicme.huatha,
      strokeCount: 2),
  OghamLetter(
      char: 'ᚈ',
      translit: 't',
      name: 'tinne',
      sound: 't',
      aicme: OghamAicme.huatha,
      strokeCount: 3),
  OghamLetter(
      char: 'ᚉ',
      translit: 'c',
      name: 'coll',
      sound: 'k',
      aicme: OghamAicme.huatha,
      strokeCount: 4),
  OghamLetter(
      char: 'ᚊ',
      translit: 'q',
      name: 'ceirt',
      sound: 'kʷ',
      aicme: OghamAicme.huatha,
      strokeCount: 5),

  // Aicme Muine — strokes across the stem.
  OghamLetter(
      char: 'ᚋ',
      translit: 'm',
      name: 'muin',
      sound: 'm',
      aicme: OghamAicme.muine,
      strokeCount: 1),
  OghamLetter(
      char: 'ᚌ',
      translit: 'g',
      name: 'gort',
      sound: 'ɡ',
      aicme: OghamAicme.muine,
      strokeCount: 2),
  OghamLetter(
      char: 'ᚍ',
      translit: 'ng',
      name: 'nGéadal',
      sound: 'ɡʷ → ŋ',
      aicme: OghamAicme.muine,
      strokeCount: 3),
  OghamLetter(
      char: 'ᚎ',
      translit: 'z',
      name: 'straif',
      sound: 'st → ts',
      aicme: OghamAicme.muine,
      strokeCount: 4),
  OghamLetter(
      char: 'ᚏ',
      translit: 'r',
      name: 'ruis',
      sound: 'r',
      aicme: OghamAicme.muine,
      strokeCount: 5),

  // Aicme Ailme — notches on the stem (the vowels).
  OghamLetter(
      char: 'ᚐ',
      translit: 'a',
      name: 'ailm',
      sound: 'a',
      aicme: OghamAicme.ailme,
      strokeCount: 1),
  OghamLetter(
      char: 'ᚑ',
      translit: 'o',
      name: 'onn',
      sound: 'o',
      aicme: OghamAicme.ailme,
      strokeCount: 2),
  OghamLetter(
      char: 'ᚒ',
      translit: 'u',
      name: 'úr',
      sound: 'u',
      aicme: OghamAicme.ailme,
      strokeCount: 3),
  OghamLetter(
      char: 'ᚓ',
      translit: 'e',
      name: 'eadhadh',
      sound: 'e',
      aicme: OghamAicme.ailme,
      strokeCount: 4),
  OghamLetter(
      char: 'ᚔ',
      translit: 'i',
      name: 'iodhadh',
      sound: 'i',
      aicme: OghamAicme.ailme,
      strokeCount: 5),

  // Forfeda — the later additional letters (irregular shapes).
  OghamLetter(
      char: 'ᚕ',
      translit: 'ea',
      name: 'éabhadh',
      sound: 'k → ea',
      aicme: OghamAicme.forfeda,
      strokeCount: 0),
  OghamLetter(
      char: 'ᚖ',
      translit: 'oi',
      name: 'ór',
      sound: 'oi',
      aicme: OghamAicme.forfeda,
      strokeCount: 0),
  OghamLetter(
      char: 'ᚗ',
      translit: 'ui',
      name: 'uilleann',
      sound: 'ui',
      aicme: OghamAicme.forfeda,
      strokeCount: 0),
  OghamLetter(
      char: 'ᚚ',
      translit: 'p',
      name: 'peith',
      sound: 'p',
      aicme: OghamAicme.forfeda,
      strokeCount: 0),
  OghamLetter(
      char: 'ᚙ',
      translit: 'ae',
      name: 'eamhancholl',
      sound: 'x → ae',
      aicme: OghamAicme.forfeda,
      strokeCount: 0),
];
