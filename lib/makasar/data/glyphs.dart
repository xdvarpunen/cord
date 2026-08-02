import 'lontara_letters.dart';
import 'makasar_letters.dart';
import 'script.dart';

/// The `assets/makasar/glyphs` stems for what a canvas has read: the letter as it
/// is drawn, then the vowel sign on it if it carries one.
///
/// This is how a New Lontara reading gets shown at all. No font in the
/// bundle covers the Buginese block, so the drawn letterform is the only
/// picture of the character there is — and Old Lontara is shown the same
/// way for the same reason the listings are: the drawn form is what a
/// hand has to copy, and it reads better than the font at this size.
///
/// Either name may be null (nothing read, or no vowel sign on it), and a
/// character with no image of it — angka — simply contributes none.
List<String> glyphImagesFor(
  WritingScript script, {
  String? name,
  String? vowel,
}) {
  final cluster = glyphClusterFor(script, name: name, vowel: vowel);
  return [
    if (cluster.letter != null) cluster.letter!,
    if (cluster.vowel != null) cluster.vowel!,
  ];
}

/// The same two stems kept apart rather than in a list — which is what a
/// canvas needs, since the sign is written *on* the letter rather than
/// after it: `ka` plus the `-i` mark is the one syllable ki, and it has to
/// be drawn as one (see `MakasarInk.drawGlyphClusters`).
///
/// cord's own; upstream draws the pair as a flat row of images.
({String? letter, String? vowel}) glyphClusterFor(
  WritingScript script, {
  String? name,
  String? vowel,
}) {
  final letters = switch (script) {
    WritingScript.makasar => _makasarLetterImages,
    WritingScript.bugis => _lontaraLetterImages,
  };
  final signs = switch (script) {
    WritingScript.makasar => _makasarSignImages,
    WritingScript.bugis => _lontaraSignImages,
  };
  return (
    letter: name == null ? null : letters[name],
    vowel: vowel == null ? null : signs[vowel],
  );
}

/// Every character of a script by the name recognition gives it —
/// letters and the punctuation and other signs alike, since a canvas
/// reads all of them.
final _makasarLetterImages = <String, String>{
  for (final letter in makasarLetters) letter.name: letter.image,
  for (final sign in makasarOtherSigns)
    if (sign.image != null) sign.name: sign.image!,
};

final _lontaraLetterImages = <String, String>{
  for (final letter in lontaraLetters) letter.name: letter.image,
  for (final sign in lontaraOtherSigns) sign.name: sign.image,
};

/// The vowel signs by the vowel they carry. The `sign_*` images serve both
/// scripts — the four they share are the same marks in the same places —
/// and Lontara's own `-ae` is only in its own map.
final _makasarSignImages = <String, String>{
  for (final sign in makasarVowelSigns) sign.vowel: sign.image,
};

final _lontaraSignImages = <String, String>{
  for (final sign in lontaraVowelSigns) sign.vowel: sign.image,
};
