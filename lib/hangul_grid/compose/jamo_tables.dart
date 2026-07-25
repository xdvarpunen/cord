/// The Unicode Hangul syllable tables, and the two merge maps that let a
/// stream of single letters reach the clusters you cannot draw in one go.
///
/// Every syllable block is onset + nucleus + optional coda, and the 11,172
/// precomposed syllables sit contiguously at U+AC00–U+D7A3 in exactly that
/// order — so composition is arithmetic, not a lookup table. See [syllable].
///
/// The letters here are *compatibility* jamo (U+3131–U+3163), which is what
/// the recognizer emits and what the on-screen legend shows. They are
/// deliberately not the conjoining jamo (U+1100/U+1161/U+11A8): those need
/// font shaping to render as a block, and web font support for them is
/// unreliable.
library;

/// The 19 onsets, in Unicode order. Index i is conjoining U+1100 + i.
const kChoseong = <String>[
  'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', //
  'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
];

/// The 21 nuclei, in Unicode order. Index i is conjoining U+1161 + i.
const kJungseong = <String>[
  'ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ', 'ㅙ', //
  'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ',
];

/// The 28 codas, in Unicode order.
///
/// Index 0 is "no coda" and is the empty string rather than null, so
/// `kJongseong[i]` is directly renderable at every index.
const kJongseong = <String>[
  '', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ', 'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', //
  'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
];

/// 가, the first precomposed syllable.
const kSyllableBase = 0xAC00;

/// 힣, the last.
const kSyllableLast = 0xD7A3;

/// The word-break token. Not a jamo; carried in the buffer alongside them so
/// spaces survive a backspace like any other keystroke.
const kWordBreak = ' ';

/// The whole of Hangul composition, in one line.
String syllable(int cho, int jung, int jong) =>
    String.fromCharCode(kSyllableBase + (cho * 21 + jung) * 28 + jong);

/// Reverse lookups.
///
/// These three maps are where the script's asymmetries live, and they encode
/// them by *omission* rather than by any flag:
///
/// - ㄱ appears in both [kChoseongIndex] and [kJongseongIndex], because it is
///   genuinely both. Which one applies is decided by position in the fold,
///   not by the character.
/// - ㄸ, ㅃ and ㅉ are missing from [kJongseongIndex] — they are onset-only.
///   That missing entry *is* the rule; the composer needs no special case.
/// - The eleven cluster codas (ㄳ ㄵ ㄶ ㄺ ㄻ ㄼ ㄽ ㄾ ㄿ ㅀ ㅄ) are missing from
///   [kChoseongIndex] — they can never begin a syllable.
final kChoseongIndex = <String, int>{
  for (var i = 0; i < kChoseong.length; i++) kChoseong[i]: i,
};
final kJungseongIndex = <String, int>{
  for (var i = 0; i < kJungseong.length; i++) kJungseong[i]: i,
};

/// Index 0 is skipped: the empty string is "no coda", not a letter.
final kJongseongIndex = <String, int>{
  for (var i = 1; i < kJongseong.length; i++) kJongseong[i]: i,
};

/// Coda clustering: an existing coda, plus one more consonant written after
/// it. 닭 is ㄷ ㅏ ㄹ ㄱ — you write ㄹ and ㄱ, and they merge into ㄺ.
const kJongMerge = <String, String>{
  'ㄱㅅ': 'ㄳ',
  'ㄴㅈ': 'ㄵ',
  'ㄴㅎ': 'ㄶ',
  'ㄹㄱ': 'ㄺ',
  'ㄹㅁ': 'ㄻ',
  'ㄹㅂ': 'ㄼ',
  'ㄹㅅ': 'ㄽ',
  'ㄹㅌ': 'ㄾ',
  'ㄹㅍ': 'ㄿ',
  'ㄹㅎ': 'ㅀ',
  'ㅂㅅ': 'ㅄ',
};

/// The exact inverse of [kJongMerge], used when a following vowel steals the
/// second half of a cluster: 앉 + ㅏ → 안자.
///
/// Every second element here is also a valid onset — that is what makes the
/// steal always representable, and it is asserted in the tests rather than
/// left to trust.
const kJongSplit = <String, (String, String)>{
  'ㄳ': ('ㄱ', 'ㅅ'),
  'ㄵ': ('ㄴ', 'ㅈ'),
  'ㄶ': ('ㄴ', 'ㅎ'),
  'ㄺ': ('ㄹ', 'ㄱ'),
  'ㄻ': ('ㄹ', 'ㅁ'),
  'ㄼ': ('ㄹ', 'ㅂ'),
  'ㄽ': ('ㄹ', 'ㅅ'),
  'ㄾ': ('ㄹ', 'ㅌ'),
  'ㄿ': ('ㄹ', 'ㅍ'),
  'ㅀ': ('ㄹ', 'ㅎ'),
  'ㅄ': ('ㅂ', 'ㅅ'),
};

/// Nucleus merging: two vowels written in a row become one compound vowel.
///
/// Strictly this is optional — the recognizer classifies ㅘ, ㅚ, ㅐ and ㅢ as
/// single shapes already. It is here because those are the hardest shapes to
/// draw: ㅙ is five strokes that must all land as one reading, and since the
/// canvas clears after every letter, nailing it in one go is otherwise the
/// *only* route to it. Writing ㅗ, ㅏ, ㅣ instead is three easy shapes.
///
/// It is safe because a syllable block has exactly one nucleus, so a vowel
/// legitimately following a vowel inside one block never occurs. Where two
/// vowels are adjacent in real text (오아, 좋아) an ㅇ always intervenes and
/// breaks the block first. And merging is gated on the block having no coda,
/// so 앙 + ㅏ steals rather than merging.
///
/// ㅘ+ㅣ and ㅝ+ㅣ are listed so the three-letter route agrees with the
/// two-letter one: ㄱ ㅗ ㅏ ㅣ and ㄱ ㅙ both give 괘.
const kJungMerge = <String, String>{
  'ㅏㅣ': 'ㅐ',
  'ㅑㅣ': 'ㅒ',
  'ㅓㅣ': 'ㅔ',
  'ㅕㅣ': 'ㅖ',
  'ㅗㅏ': 'ㅘ',
  'ㅗㅐ': 'ㅙ',
  'ㅗㅣ': 'ㅚ',
  'ㅘㅣ': 'ㅙ',
  'ㅜㅓ': 'ㅝ',
  'ㅜㅔ': 'ㅞ',
  'ㅜㅣ': 'ㅟ',
  'ㅝㅣ': 'ㅞ',
  'ㅡㅣ': 'ㅢ',
};
