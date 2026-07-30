/// The Lontara script (*aksara Lontara*) — the other South Sulawesi
/// abugida, and the reason the `lon_` glyph images exist: Wikipedia's
/// "Makasar script" article sets the two side by side, Makasar above and
/// "Lontara Bugis" below, because they are sibling branches of the same
/// Brahmic family. Lontara is the one that survived; the Makasar script
/// fell out of use in the 19th century.
///
/// It's the Buginese Unicode block (U+1A00–U+1A1F), which the bundled
/// `NotoSerifMakasar` font does not cover, so there is nothing to render
/// these characters with. The `lon_*`/`sign_*` images under
/// `assets/makasar/glyphs` are the letterforms; [LontaraLetter.glyph] is carried
/// anyway so the codepoint can be shown and copied.
///
/// Most of it is reference material: only the letters with a
/// [LontaraLetter.shape] can be drawn, which is what `LontaraCharacter`
/// has a classifier for. The vowel signs are further along — four of the
/// five are the same marks Makasar uses, so they read already.
///
/// Where the two scripts line up, [LontaraLetter.makasarName] names the
/// Makasar letter for the same syllable. Five Lontara letters have no
/// Makasar counterpart at all: the prenasalized series (ngka, mpa, nra,
/// nca) and ha.
class LontaraLetter {
  const LontaraLetter(
      this.glyph, this.name, this.ipa, this.image, this.makasarName,
      {this.shape});

  /// The Unicode codepoint. Very unlikely to render — see the class doc.
  final String glyph;

  /// The letter's name, which is also its transliteration: the consonant
  /// plus its inherent `a`.
  final String name;

  /// The consonant's sound in IPA, without the inherent `a`. The
  /// prenasalized letters are given as the cluster they transliterate.
  final String ipa;

  /// The letterform as drawn, for `GlyphImage`.
  final String image;

  /// The [MakasarLetter] for the same syllable, or null if the Makasar
  /// script has no equivalent letter.
  final String? makasarName;

  /// How the letterform decomposes, for the letters `LontaraCharacter` has
  /// a classifier for — this is what the app tells the user to draw, so it
  /// and the classifier are written to match. Null for the rest, which
  /// can't be drawn yet.
  final String? shape;
}

const lontaraLetters = [
  LontaraLetter('\u{1A00}', 'ka', 'k', 'lon_ka', 'ka',
      shape: '2 ascending lines side by side, their x ranges overlapping'),
  LontaraLetter('\u{1A01}', 'ga', 'ɡ', 'lon_ga', 'ga',
      shape: 'pa’s stroke + a dot under the up-down it opens with'),
  LontaraLetter('\u{1A02}', 'nga', 'ŋ', 'lon_nga', 'nga',
      shape: 'a descending line + an ascending one crossing it from the '
          'bottom left'),
  LontaraLetter('\u{1A03}', 'ngka', 'ŋk', 'lon_ngka', null,
      shape: 'a wedge + a descending line cut once across its climb'),
  LontaraLetter('\u{1A04}', 'pa', 'p', 'lon_pa', 'pa',
      shape: 'one stroke up, down, up, the tail after that first climb '
          'turning right then left'),
  LontaraLetter('\u{1A05}', 'ba', 'b', 'lon_ba', 'ba',
      shape: 'a stroke turning left then right + an ascending one crossing '
          'it once from the bottom left'),
  LontaraLetter('\u{1A06}', 'ma', 'm', 'lon_ma', 'ma',
      shape: 'a chevron — one stroke down, then up'),
  LontaraLetter('\u{1A07}', 'mpa', 'mp', 'lon_mpa', null,
      shape: 'ba’s build with the turn the other way about, right then '
          'left'),
  LontaraLetter('\u{1A08}', 'ta', 't', 'lon_ta', 'ta',
      shape: 'a wedge — one stroke up, then down'),
  LontaraLetter('\u{1A09}', 'da', 'd', 'lon_da', 'da',
      shape: 'a chevron + a dot inside it, over the point'),
  LontaraLetter('\u{1A0A}', 'na', 'n', 'lon_na', 'na',
      shape: 'a wedge + a dot inside it, under the apex'),
  LontaraLetter('\u{1A0B}', 'nra', 'nr', 'lon_nra', null,
      shape: 'pa’s stroke + a wedge under the up-down it opens with'),
  LontaraLetter('\u{1A0C}', 'ca', 'tʃ', 'lon_ca', 'ca',
      shape: 'a wedge + a stroke turning right then left across it'),
  LontaraLetter('\u{1A0D}', 'ja', 'dʒ', 'lon_ja', 'ja',
      shape: 'one stroke out right and back left, the right half up then '
          'down, the return starting below the apex'),
  LontaraLetter('\u{1A0E}', 'nya', 'ɲ', 'lon_nya', 'nya',
      shape: 'a double wedge + a chevron under it'),
  // U+1A0F BUGINESE LETTER NYCA; the article's comparison table
  // transliterates it nca, which is what it's called here.
  LontaraLetter('\u{1A0F}', 'nca', 'ɲtʃ', 'lon_nca', null,
      shape: '2 wedges written across each other, arms crossing'),
  LontaraLetter('\u{1A10}', 'ya', 'j', 'lon_ya', 'ya',
      shape: 'a double wedge + a dot tucked under each wedge'),
  LontaraLetter('\u{1A11}', 'ra', 'r', 'lon_ra', 'ra',
      shape: '2 wedges, one above the other, their x ranges overlapping'),
  LontaraLetter('\u{1A12}', 'la', 'l', 'lon_la', 'la',
      shape: 'one stroke up, down, up + a wedge over that last climb'),
  // U+1A13 BUGINESE LETTER VA, transliterated wa — the same split as
  // Makasar's own wa/VA.
  LontaraLetter('\u{1A13}', 'wa', 'w', 'lon_wa', 'wa',
      shape: 'a double wedge — one stroke up, down, up, down'),
  LontaraLetter('\u{1A14}', 'sa', 's', 'lon_sa', 'sa',
      shape: 'one stroke closing on itself'),
  // The vowel carrier, for a syllable that starts with its vowel.
  LontaraLetter('\u{1A15}', 'a', 'a', 'lon_a', 'a',
      shape: 'a double wedge + a dot tucked under the second wedge only'),
  LontaraLetter('\u{1A16}', 'ha', 'h', 'lon_ha', null,
      shape: 'one stroke out right and back left, each half up, down, up, '
          'crossing itself twice'),
];

/// Lontara's five vowel signs, one more than Makasar's four: the extra one
/// is `-ae` for /ə/. The four they share are the same marks in the same
/// places, which is why the `sign_*` images serve both scripts.
class LontaraVowelSign {
  const LontaraVowelSign(
      this.glyph, this.vowel, this.ipa, this.image, this.placement);
  final String glyph;
  final String vowel;
  final String ipa;
  final String image;
  final String placement;
}

const lontaraVowelSigns = [
  LontaraVowelSign('\u{1A17}', 'i', 'i', 'sign_i', 'dot above'),
  LontaraVowelSign('\u{1A18}', 'u', 'u', 'sign_u', 'dot below'),
  // U+1A19 VOWEL SIGN E, which the article writes -é to keep it apart from
  // the -e below.
  LontaraVowelSign('\u{1A19}', 'e', 'e', 'sign_e', 'hook in front (left)'),
  LontaraVowelSign('\u{1A1A}', 'o', 'o', 'sign_o', 'hook behind (right)'),
  // U+1A1B VOWEL SIGN AE, the article's -e. No Makasar equivalent — and
  // the one sign whose gesture is Lontara's own, so its placement doubles
  // as what to draw (see VowelMark.ae).
  LontaraVowelSign(
      '\u{1A1B}', 'ae', 'ə', 'sign_ae', 'a hook above: right, then left'),
];

/// Lontara's two punctuation marks. Like Makasar it is written *scriptio
/// continua*, but pallawa does more work than Makasar's passimbang: it
/// separates words as well as phrases.
class LontaraSign {
  const LontaraSign(this.glyph, this.name, this.image, this.use, {this.shape});
  final String glyph;
  final String name;
  final String image;
  final String use;

  /// How the mark is made, for the ones `LontaraCharacter` has a
  /// classifier for — see [LontaraLetter.shape].
  final String? shape;
}

const lontaraOtherSigns = [
  LontaraSign(
      '\u{1A1E}', 'pallawa', 'lon_pallawa', 'separates words and phrases',
      shape: '3 taps on a line descending to the right'),
  LontaraSign('\u{1A1F}', 'end of section', 'lon_endtext', 'closes a passage',
      shape: '2 crossings one over the other, the falling stroke below '
          'right in one and above left in the other'),
];
