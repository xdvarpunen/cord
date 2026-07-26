// Generates `lib/hanzi/data/hanzi_glosses.dart`: how each character in the
// Hanzi Grid's stroke table is said, and what it means.
//
//   node tool/hanzi_glosses.mjs
//
// Run from the repo root, on the host — this needs the network and Node, and
// the devcontainer has neither. Nothing at runtime depends on it: the output
// is committed Dart, like the stroke table it glosses.
//
// The readings and definitions come from makemeahanzi's `dictionary.txt`, the
// same project the Chinese stroke geometry came from — so the page glosses
// what it draws from one source rather than from something assembled by hand.
// makemeahanzi is CC BY 4.0 and its dictionary derives from CC-CEDICT
// (CC BY-SA 4.0) and Unihan; see `lib/hanzi/data/NOTICE.txt`.
//
// Two things the dictionary cannot answer, handled explicitly below:
//
//   * **Kana.** KanjiVG contributes hiragana and katakana to the stroke table,
//     and they are syllables, not words — there is no pinyin and no meaning to
//     look up. They are glossed with their romaji and named for what they are.
//   * **Japanese and Korean variant forms.** 亀 値 飮 are the shapes those
//     traditions write; the dictionary holds the standard forms. Each is
//     aliased to its counterpart rather than guessed at, and the alias is
//     written out here so the substitution is visible rather than silent.

import { readFileSync, writeFileSync } from 'node:fs';

const DICTIONARY =
  'https://raw.githubusercontent.com/skishore/makemeahanzi/master/dictionary.txt';

const STROKES = 'lib/hanzi/data/hanzi_strokes.dart';
const OUT = 'lib/hanzi/data/hanzi_glosses.dart';

/// Variant shapes the stroke table draws, and the form the dictionary files
/// them under. Same character, different tradition's shape.
const ALIASES = {
  亀: '龜', // Japanese form of 龜/龟 — turtle
  値: '值', // Japanese form of 值 — value, price
  飮: '飲', // Korean form of 飲/饮 — to drink
};

/// Romaji for the kana KanjiVG contributes. A syllable, not a word: the
/// reading is the whole of what there is to say about it.
const KANA = {
  あ: 'a', い: 'i', う: 'u', お: 'o', き: 'ki', く: 'ku', さ: 'sa',
  し: 'shi', た: 'ta', だ: 'da', ち: 'chi', つ: 'tsu', と: 'to', ひ: 'hi',
  ふ: 'fu', ら: 'ra',
  カ: 'ka', ク: 'ku', コ: 'ko', テ: 'te', バ: 'ba', パ: 'pa', ヒ: 'hi',
  ビ: 'bi', ミ: 'mi', ル: 'ru', レ: 're', ン: 'n',
  'ー': 'ā', // chōonpu, the long-vowel mark
};

const HIRAGANA = /^[぀-ゟ]$/;
const KATAKANA = /^[゠-ヿ]$/;

/// The first sense only. A full CC-CEDICT definition runs to several clauses
/// and a dozen words; under a square there is room for one.
function shorten(definition) {
  const first = definition.split(/[;,]/)[0].trim();
  return first.replace(/\s+/g, ' ');
}

function meaningOf(char) {
  if (KANA[char]) {
    if (char === 'ー') return 'long vowel mark';
    return HIRAGANA.test(char) ? 'hiragana' : 'katakana';
  }
  return null;
}

const strokes = readFileSync(STROKES, 'utf8');
const chars = [
  ...new Set(
    [...strokes.matchAll(/'(?:ZH|JA|KO):(.)'/gu)].map((m) => m[1]),
  ),
].sort();
console.log(`${chars.length} characters in the stroke table`);

console.log(`fetching ${DICTIONARY} …`);
const response = await fetch(DICTIONARY);
if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
const dictionary = new Map();
for (const line of (await response.text()).split('\n')) {
  if (!line.trim()) continue;
  const entry = JSON.parse(line);
  dictionary.set(entry.character, entry);
}
console.log(`${dictionary.size} dictionary entries`);

const rows = [];
const missing = [];
for (const char of chars) {
  const kana = KANA[char];
  if (kana) {
    rows.push({ char, reading: kana, meaning: meaningOf(char), from: null });
    continue;
  }
  const alias = ALIASES[char];
  const entry = dictionary.get(char) ?? dictionary.get(alias);
  if (!entry?.definition || !entry.pinyin?.length) {
    missing.push(char);
    continue;
  }
  rows.push({
    char,
    reading: entry.pinyin[0],
    meaning: shorten(entry.definition),
    from: alias ?? null,
  });
}

if (missing.length) {
  console.warn(
    `no gloss for ${missing.length}: ${missing.join('')} — they will simply ` +
      'show no English, which is the honest outcome',
  );
}

const escape = (s) => s.replace(/\\/g, '\\\\').replace(/'/g, "\\'");

const body = rows
  .map(
    ({ char, reading, meaning, from }) =>
      `  '${escape(char)}': Gloss(reading: '${escape(reading)}', ` +
      `meaning: '${escape(meaning)}'),${from ? ` // via ${from}` : ''}`,
  )
  .join('\n');

writeFileSync(
  OUT,
  `// GENERATED FILE -- do not edit by hand.
//
// Regenerate from the repo root: node tool/hanzi_glosses.mjs
//
// Readings and meanings for every character in \`hanzi_strokes.dart\`, so the
// grid can be read by someone who does not read the script yet. From
// makemeahanzi's dictionary.txt (CC BY 4.0; definitions derive from CC-CEDICT,
// CC BY-SA 4.0) -- see NOTICE.txt. Kana are glossed with romaji instead, and
// the Japanese and Korean variant shapes are aliased to the form the
// dictionary files them under; the generator spells out both.
//
// One reading and one sense each. Characters have more of both, but under a
// square there is room for the first, and the first is what a learner wants.

/// How a character is said, and what it means.
class Gloss {
  const Gloss({required this.reading, required this.meaning});

  /// Pinyin, or romaji for a kana. The most common reading, not the only one.
  final String reading;

  /// The first sense only, a word or two.
  final String meaning;
}

/// Keyed by the character itself, since that is what recognition hands back
/// -- the language variant it was matched from does not change what it means.
///
/// A character absent here shows no English rather than a guess.
const Map<String, Gloss> hanziGlosses = <String, Gloss>{
${body}
};
`,
  'utf8',
);

console.log(`wrote ${OUT}: ${rows.length} glossed, ${missing.length} without`);
