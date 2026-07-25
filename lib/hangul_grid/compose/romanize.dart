/// Revised Romanization of written Hangul.
///
/// Implements the three rules that carry almost all of the work:
///
/// 1. **Onsets and codas differ.** ㄱ is `g` starting a syllable and `k`
///    ending one, ㄹ is `r` then `l`, and so on. ㅇ is silent as an onset and
///    `ng` as a coda.
/// 2. **Codas neutralize.** Korean only releases seven consonants at the end
///    of a syllable, so ㅅ ㅆ ㅈ ㅊ ㅌ ㅎ all come out as `t` — 꽃 is *kkot*,
///    not *kkoch*. A two-letter final sounds only one of its letters: 값 is
///    *gap*, 닭 is *dak*.
/// 3. **A coda moves when a vowel follows.** Before a syllable that begins
///    with the silent ㅇ, the coda is pronounced as the next syllable's
///    onset: 좋아 is *joa*, 앉아 is *anja*, 없어 is *eopseo*. ㅎ simply drops.
///
/// What it does **not** do is assimilation between neighbouring syllables:
/// 신라 is *Silla* rather than the *sinra* produced here, 국물 is *gungmul*,
/// 같이 is *gachi*. Those need a pronunciation model rather than a letter
/// one. Every word in `word_list.dart` is romanized correctly by these
/// rules, and a test pins that — see `test/romanize_test.dart`.
library;

import 'hangul_composer.dart';
import 'jamo_tables.dart';

/// Onsets, indexed like [kChoseong]. ㅇ is empty: it is a placeholder that
/// lets a syllable start with its vowel, not a sound.
const _onsets = <String>[
  'g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp', 's', //
  'ss', '', 'j', 'jj', 'ch', 'k', 't', 'p', 'h',
];

/// Nuclei, indexed like [kJungseong].
const _nuclei = <String>[
  'a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o', 'wa', 'wae', //
  'oe', 'yo', 'u', 'wo', 'we', 'wi', 'yu', 'eu', 'ui', 'i',
];

/// Codas at the end of a word, or before another consonant — the
/// neutralized set. Indexed like [kJongseong].
const _codasFinal = <String>[
  '', 'k', 'k', 'k', 'n', 'n', 'n', 't', 'l', 'k', 'm', 'l', 'l', 'l', //
  'p', 'l', 'm', 'p', 'p', 't', 't', 'ng', 't', 't', 'k', 't', 'p', 't',
];

/// Codas before a vowel, as (what stays behind, what moves to the next
/// syllable's onset). Indexed like [kJongseong].
///
/// A single consonant moves whole — 물이 is *muri*. A two-letter final keeps
/// its first letter and sends the second — 읽어 is *ilgeo*, 없어 is *eopseo*.
/// ㅎ is the exception that vanishes: 좋아 is *joa*, and in ㄶ and ㅀ its
/// partner moves instead — 많아 is *mana*, 싫어 is *sireo*.
const _codasBeforeVowel = <(String, String)>[
  ('', ''), // (none)
  ('', 'g'), // ㄱ
  ('', 'kk'), // ㄲ
  ('k', 's'), // ㄳ
  ('', 'n'), // ㄴ
  ('n', 'j'), // ㄵ
  ('', 'n'), // ㄶ — ㅎ drops, ㄴ moves
  ('', 'd'), // ㄷ
  ('', 'r'), // ㄹ
  ('l', 'g'), // ㄺ
  ('l', 'm'), // ㄻ
  ('l', 'b'), // ㄼ
  ('l', 's'), // ㄽ
  ('l', 't'), // ㄾ
  ('l', 'p'), // ㄿ
  ('', 'r'), // ㅀ — ㅎ drops, ㄹ moves
  ('', 'm'), // ㅁ
  ('', 'b'), // ㅂ
  ('p', 's'), // ㅄ
  ('', 's'), // ㅅ
  ('', 'ss'), // ㅆ
  ('ng', ''), // ㅇ — stays put; 강아지 is gangaji
  ('', 'j'), // ㅈ
  ('', 'ch'), // ㅊ
  ('', 'k'), // ㅋ
  ('', 't'), // ㅌ
  ('', 'p'), // ㅍ
  ('', ''), // ㅎ — silent before a vowel
];

/// Index of ㅇ in [kChoseong] — the silent onset a coda can move into.
const _silentOnset = 11;

/// Romanizes a composed buffer.
///
/// Unfinished blocks — a consonant with no vowel yet, a stranded vowel — are
/// romanized as the bare letter, so the reading keeps up with what is on
/// screen instead of blanking out mid-word.
String romanizeBlocks(List<ComposedBlock> blocks) =>
    romanizeEachBlock(blocks).join();

/// The same reading, kept in pieces — one per block, in order.
///
/// For printing a syllable's sound under the syllable itself. The pieces
/// join back into exactly what [romanizeBlocks] returns, which is the point:
/// a square's own reading and the reading of the whole word can never
/// disagree.
///
/// A block's piece is what it *contributes*, not what it would say alone.
/// 각 on its own is *gak*, but written before 아 its final moves and the two
/// pieces come out *ga* and *ga* — which is how 각아 is actually pronounced,
/// and worth seeing rather than hiding.
List<String> romanizeEachBlock(List<ComposedBlock> blocks) {
  final out = <String>[];

  /// A sound carried over from the previous syllable's coda, waiting to be
  /// spoken as this syllable's onset.
  var carry = '';

  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    final buf = StringBuffer();

    if (block.isBreak) {
      buf.write(carry);
      carry = '';
      buf.write(' ');
      out.add(buf.toString());
      continue;
    }

    final cho = block.cho;
    final jung = block.jung;

    if (cho != null && jung != null) {
      // A carry is only ever set when the next onset is ㅇ, so writing it
      // instead of the onset never drops a real consonant.
      buf.write(carry.isNotEmpty ? carry : _onsets[cho]);
      carry = '';
      buf.write(_nuclei[jung]);

      final jong = block.jong ?? 0;
      if (jong != 0) {
        final next = i + 1 < blocks.length ? blocks[i + 1] : null;
        final movesOn = next != null &&
            !next.isBreak &&
            next.cho == _silentOnset &&
            next.jung != null;
        if (movesOn) {
          final (stays, moves) = _codasBeforeVowel[jong];
          buf.write(stays);
          carry = moves;
        } else {
          buf.write(_codasFinal[jong]);
        }
      }
      out.add(buf.toString());
      continue;
    }

    // An unfinished block. Flush anything the previous syllable was holding
    // — there is no vowel here for it to attach to.
    buf.write(carry);
    carry = '';
    if (cho != null) {
      buf.write(_onsets[cho].isEmpty ? 'ng' : _onsets[cho]);
    } else if (jung != null) {
      buf.write(_nuclei[jung]);
    }
    out.add(buf.toString());
  }

  // Defensive: a carry is only ever set when a following block exists to
  // take it, so this should already be empty.
  if (carry.isNotEmpty) {
    if (out.isEmpty) {
      out.add(carry);
    } else {
      out[out.length - 1] = out.last + carry;
    }
  }
  return out;
}

/// Romanizes Korean text.
String romanize(String hangul) =>
    romanizeBlocks(compose(decompose(hangul)).blocks);
