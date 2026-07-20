/// One Hangul jamo (letter): its glyph, its Korean letter name, and its
/// Revised-Romanization sound value.
///
/// Split into [consonantRows] and [vowelRows] because Hangul's two letter
/// families are drawn — and taught — as separate sets: consonants are
/// shape-derived (ㄱ, ㄴ, ㅁ …), vowels are built from the vertical/
/// horizontal stroke plus short tick marks (ㅣ, ㅡ, ㅏ, ㅗ …).
class JamoRow {
  const JamoRow(this.glyph, this.name, this.sound);

  final String glyph;

  /// The letter's Korean name, romanized (e.g. 'giyeok' for ㄱ). Vowels
  /// are named after their own sound, so for those this matches [sound].
  final String name;

  /// Revised Romanization. Consonants that differ initially vs. finally
  /// list both (e.g. 'g/k' for ㄱ).
  final String sound;
}

/// The 14 basic consonants, in dictionary order.
const consonantRows = [
  JamoRow('ㄱ', 'giyeok', 'g/k'),
  JamoRow('ㄴ', 'nieun', 'n'),
  JamoRow('ㄷ', 'digeut', 'd/t'),
  JamoRow('ㄹ', 'rieul', 'r/l'),
  JamoRow('ㅁ', 'mieum', 'm'),
  JamoRow('ㅂ', 'bieup', 'b/p'),
  JamoRow('ㅅ', 'siot', 's'),
  JamoRow('ㅇ', 'ieung', 'ng'),
  JamoRow('ㅈ', 'jieut', 'j'),
  JamoRow('ㅊ', 'chieut', 'ch'),
  JamoRow('ㅋ', 'kieuk', 'k'),
  JamoRow('ㅌ', 'tieut', 't'),
  JamoRow('ㅍ', 'pieup', 'p'),
  JamoRow('ㅎ', 'hieut', 'h'),
];

/// The 5 tense (doubled) consonants — each a basic consonant written twice.
const tenseConsonantRows = [
  JamoRow('ㄲ', 'ssanggiyeok', 'kk'),
  JamoRow('ㄸ', 'ssangdigeut', 'tt'),
  JamoRow('ㅃ', 'ssangbieup', 'pp'),
  JamoRow('ㅆ', 'ssangsiot', 'ss'),
  JamoRow('ㅉ', 'ssangjieut', 'jj'),
];

/// The 11 complex (compound) vowels, in dictionary order — each built from
/// two basic vowels written together.
const complexVowelRows = [
  JamoRow('ㅐ', 'ae', 'ae'),
  JamoRow('ㅒ', 'yae', 'yae'),
  JamoRow('ㅔ', 'e', 'e'),
  JamoRow('ㅖ', 'ye', 'ye'),
  JamoRow('ㅘ', 'wa', 'wa'),
  JamoRow('ㅙ', 'wae', 'wae'),
  JamoRow('ㅚ', 'oe', 'oe'),
  JamoRow('ㅝ', 'wo', 'wo'),
  JamoRow('ㅞ', 'we', 'we'),
  JamoRow('ㅟ', 'wi', 'wi'),
  JamoRow('ㅢ', 'ui', 'ui'),
];

/// The 10 basic vowels, in dictionary order.
const vowelRows = [
  JamoRow('ㅏ', 'a', 'a'),
  JamoRow('ㅑ', 'ya', 'ya'),
  JamoRow('ㅓ', 'eo', 'eo'),
  JamoRow('ㅕ', 'yeo', 'yeo'),
  JamoRow('ㅗ', 'o', 'o'),
  JamoRow('ㅛ', 'yo', 'yo'),
  JamoRow('ㅜ', 'u', 'u'),
  JamoRow('ㅠ', 'yu', 'yu'),
  JamoRow('ㅡ', 'eu', 'eu'),
  JamoRow('ㅣ', 'i', 'i'),
];
