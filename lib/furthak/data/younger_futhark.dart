/// One row of the Younger Futhark rune table (per Wikipedia's "Younger
/// Futhark" article): the Latin transliteration, the Old Norse rune name
/// and its meaning, the IPA sound value(s), and the rune's glyph in its
/// long-branch (Danish) form. Wikipedia also lists a short-twig
/// (Swedish/Norwegian) variant column, dropped here — the app sticks to
/// the long-branch forms.
class YoungerFutharkRow {
  const YoungerFutharkRow(
      this.translit, this.name, this.meaning, this.sound, this.glyph);
  final String translit;
  final String name;
  final String meaning;
  final String sound;
  final String glyph;
}

const youngerFutharkRows = [
  YoungerFutharkRow('f', 'fé', 'wealth', 'f', 'ᚠ'),
  YoungerFutharkRow('u', 'úr', 'rain', 'u, y, o, ø, v, w', 'ᚢ'),
  YoungerFutharkRow('þ', 'þurs', 'giant', 'θ, ð', 'ᚦ'),
  YoungerFutharkRow('ą', 'áss', '(a) god', 'ɑ̃, o, æ', 'ᚬ'),
  YoungerFutharkRow('r', 'reið', 'ride', 'r', 'ᚱ'),
  YoungerFutharkRow('k', 'kaun', 'ulcer', 'k, g, ŋ', 'ᚴ'),
  YoungerFutharkRow('h', 'hagall', 'hail', 'h', 'ᚼ'),
  YoungerFutharkRow('n', 'nauðr', 'need', 'n', 'ᚾ'),
  YoungerFutharkRow('i', 'íss', 'ice', 'i, e', 'ᛁ'),
  YoungerFutharkRow('a', 'ár', 'plenty', 'a, æ, e', 'ᛅ'),
  YoungerFutharkRow('s', 'sól', 'sun', 's, z', 'ᛋ'),
  YoungerFutharkRow('t', 'Týr', 'Týr (a deity)', 't, d', 'ᛏ'),
  YoungerFutharkRow('b', 'bjǫrk', 'birch', 'b, p', 'ᛒ'),
  YoungerFutharkRow('m', 'maðr', 'man', 'm', 'ᛘ'),
  YoungerFutharkRow('l', 'lǫgr', 'sea', 'l', 'ᛚ'),
  YoungerFutharkRow('ʀ', 'ýr', 'yew', 'ʀ', 'ᛦ'),
];
