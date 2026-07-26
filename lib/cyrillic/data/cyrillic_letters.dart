/// One letter of the Russian Cyrillic alphabet, as shown in the page's
/// legend: its capital and lowercase forms, the letter's own name, and a
/// rough Latin sound. [name] is the key the recognizer matches on (see
/// `CyrillicLayer.recognizedNames`), since it's the one field that's
/// unambiguous — several letters share a sound spelling, and the glyphs
/// come in pairs.
class LetterRow {
  const LetterRow(this.capital, this.small, this.name, this.sound);

  final String capital;
  final String small;
  final String name;
  final String sound;
}

/// The Russian alphabet in its standard order. The recognizer handles a
/// growing subset of these — see `CyrillicLayer.recognizedNames` — and the
/// rest are listed muted in the legend for reference.
const cyrillicRows = [
  LetterRow('А', 'а', 'a', 'a'),
  LetterRow('Б', 'б', 'be', 'b'),
  LetterRow('В', 'в', 've', 'v'),
  LetterRow('Г', 'г', 'ge', 'g'),
  LetterRow('Д', 'д', 'de', 'd'),
  LetterRow('Е', 'е', 'ye', 'ye'),
  LetterRow('Ё', 'ё', 'yo', 'yo'),
  LetterRow('Ж', 'ж', 'zhe', 'zh'),
  LetterRow('З', 'з', 'ze', 'z'),
  LetterRow('И', 'и', 'i', 'i'),
  LetterRow('Й', 'й', 'short i', 'y'),
  LetterRow('К', 'к', 'ka', 'k'),
  LetterRow('Л', 'л', 'el', 'l'),
  LetterRow('М', 'м', 'em', 'm'),
  LetterRow('Н', 'н', 'en', 'n'),
  LetterRow('О', 'о', 'o', 'o'),
  LetterRow('П', 'п', 'pe', 'p'),
  LetterRow('Р', 'р', 'er', 'r'),
  LetterRow('С', 'с', 'es', 's'),
  LetterRow('Т', 'т', 'te', 't'),
  LetterRow('У', 'у', 'u', 'u'),
  LetterRow('Ф', 'ф', 'ef', 'f'),
  LetterRow('Х', 'х', 'kha', 'kh'),
  LetterRow('Ц', 'ц', 'tse', 'ts'),
  LetterRow('Ч', 'ч', 'che', 'ch'),
  LetterRow('Ш', 'ш', 'sha', 'sh'),
  LetterRow('Щ', 'щ', 'shcha', 'shch'),
  LetterRow('Ъ', 'ъ', 'hard sign', '—'),
  LetterRow('Ы', 'ы', 'yery', 'y'),
  LetterRow('Ь', 'ь', 'soft sign', '—'),
  LetterRow('Э', 'э', 'e', 'e'),
  LetterRow('Ю', 'ю', 'yu', 'yu'),
  LetterRow('Я', 'я', 'ya', 'ya'),
];
