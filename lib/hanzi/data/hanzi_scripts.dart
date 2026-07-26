import 'hanzi_strokes.dart';
import 'stroke_models.dart';

/// Which script the grid is reading — the single source for the page's
/// dropdown, the character reference, and the search index, the same way
/// `lib/tally/data/tally_systems.dart` is for the tally page.
///
/// Narrowing the field is not only a filter over what you are shown. The
/// recognizer scores a square against *every* glyph with the same stroke
/// count, so a hiragana あ competes with three-stroke Han characters and
/// usually loses. Telling it which script you are writing removes the rivals
/// rather than hiding them, and a square that was a coin-toss becomes a
/// reading — which is why this changes the percentage under the square and not
/// just the reference beside it.
class HanziScript {
  const HanziScript({
    required this.slug,
    required this.name,
    required this.label,
    required this.blurb,
    required this.holds,
  });

  /// URL-safe id. Round-trips through `?script=`.
  final String slug;

  /// What the dropdown and the search results call it.
  final String name;

  /// A character of the script itself, for the dropdown's leading glyph.
  final String label;

  /// One line on what the set is, for the reference and search.
  final String blurb;

  /// Whether a glyph belongs to this script. Takes the key rather than the
  /// character because the same character is stored once per tradition, and
  /// which tradition it came from is the whole question here.
  final bool Function(String glyphKey, CharGlyph glyph) holds;

  /// How many distinct characters this script can read.
  int get count => _counts[slug] ?? 0;
}

/// True for the kana blocks — hiragana U+3040–309F, katakana U+30A0–30FF.
///
/// KanjiVG files kana under the same `JA:` keys as kanji, so this is the only
/// thing that tells them apart.
bool _isHiragana(String char) {
  final rune = char.runes.first;
  return rune >= 0x3040 && rune <= 0x309F;
}

bool _isKatakana(String char) {
  final rune = char.runes.first;
  return rune >= 0x30A0 && rune <= 0x30FF;
}

bool _isKana(String char) => _isHiragana(char) || _isKatakana(char);

/// Every script the page offers, in dropdown order.
///
/// "Everything" is first and is the default: it is what the page did before
/// there was a choice, and it is the honest starting point when you have not
/// said what you are practising.
const List<HanziScript> hanziScripts = [
  HanziScript(
    slug: 'all',
    name: 'Everything',
    label: '全',
    blurb: 'Every character bundled, in all three traditions, plus the kana.',
    holds: _holdsAll,
  ),
  HanziScript(
    slug: 'chinese',
    name: 'Chinese',
    label: '中',
    blurb: 'Han characters as China writes them, from makemeahanzi.',
    holds: _holdsChinese,
  ),
  HanziScript(
    slug: 'japanese',
    name: 'Japanese',
    label: '日',
    blurb: 'Kanji as Japan writes them, from KanjiVG. Kana are listed '
        'separately.',
    holds: _holdsJapanese,
  ),
  HanziScript(
    slug: 'korean',
    name: 'Korean',
    label: '한',
    blurb: 'Hanja as Korea writes them, from animCJK. Thinner than the other '
        'two by nature — the source carries far fewer.',
    holds: _holdsKorean,
  ),
  HanziScript(
    slug: 'hiragana',
    name: 'Hiragana',
    label: 'あ',
    blurb: 'The cursive Japanese syllabary. Syllables, not words, so they are '
        'glossed with romaji.',
    holds: _holdsHiragana,
  ),
  HanziScript(
    slug: 'katakana',
    name: 'Katakana',
    label: 'ア',
    blurb: 'The angular Japanese syllabary, used for loanwords and emphasis.',
    holds: _holdsKatakana,
  ),
];

// Top-level functions rather than closures so the list above can stay `const`.
bool _holdsAll(String key, CharGlyph glyph) => true;
bool _holdsChinese(String key, CharGlyph glyph) =>
    key.startsWith('ZH:') && !_isKana(glyph.char);
bool _holdsJapanese(String key, CharGlyph glyph) =>
    key.startsWith('JA:') && !_isKana(glyph.char);
bool _holdsKorean(String key, CharGlyph glyph) =>
    key.startsWith('KO:') && !_isKana(glyph.char);
bool _holdsHiragana(String key, CharGlyph glyph) => _isHiragana(glyph.char);
bool _holdsKatakana(String key, CharGlyph glyph) => _isKatakana(glyph.char);

/// The script for [slug], falling back to the first (Everything) for an
/// unknown or missing one — so a stale link degrades to the widest set rather
/// than to an error.
HanziScript hanziScriptForSlug(String? slug) => hanziScripts.firstWhere(
      (script) => script.slug == slug,
      orElse: () => hanziScripts.first,
    );

/// Distinct characters per script. Computed once: the stroke table is `const`,
/// so this cannot change, and counting it per frame would walk 413 glyphs to
/// label a dropdown.
final Map<String, int> _counts = {
  for (final script in hanziScripts)
    script.slug: {
      for (final entry in strokeGlyphs.entries)
        if (script.holds(entry.key, entry.value)) entry.value.char,
    }.length,
};

/// The characters one script can read, best-known variant first, for the
/// reference tables.
Iterable<MapEntry<String, CharGlyph>> glyphsOf(HanziScript script) =>
    strokeGlyphs.entries.where((e) => script.holds(e.key, e.value));
