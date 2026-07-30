import 'package:flutter/material.dart';

/// One letterform as it is actually drawn, from the images bundled under
/// `assets/makasar/glyphs` — `mak_*` for the Makasar letters, `lon_*` for
/// their Lontara (Bugis) counterparts, `sign_*` for the vowel marks the two
/// scripts share. All of them are black strokes on transparency.
///
/// Worth showing next to the font glyph for two reasons. For Makasar, the
/// drawn form is what a learner has to copy onto the canvas, and it reads
/// far better at a glance than `NotoSerifMakasar` at chip size. For
/// Lontara there is no font here at all — nothing in the bundle covers the
/// Buginese block — so the image *is* the letter.
class GlyphImage extends StatelessWidget {
  const GlyphImage(this.name,
      {super.key, this.height = 30, this.muted = false});

  /// The file stem under `assets/makasar/glyphs`, e.g. `mak_ka`. Null keeps
  /// the space without drawing anything, so a character with no image of it
  /// (angka) still lines up with the rest.
  final String? name;

  final double height;

  /// Fades the strokes to match a muted glyph beside it.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    if (name == null) return SizedBox(height: height);
    return Opacity(
      opacity: muted ? 0.35 : 1,
      child: Image.asset(
        'assets/makasar/glyphs/$name.png',
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
