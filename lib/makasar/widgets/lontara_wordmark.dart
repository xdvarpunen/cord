import 'package:flutter/material.dart';

/// The word *lontara* written in New Lontara: ᨒᨚᨈᨑ — lo, ta, ra, with the
/// nasal left unwritten, as the script leaves it.
///
/// Drawn from the letterform images under `assets/makasar/glyphs`, there being no
/// other way to put the script's own name on the page in its own script:
/// no font in the bundle covers the Buginese block.
///
/// Its own widget rather than a row of `GlyphImage`s, because a word asks
/// two things of the letterforms that a listing doesn't. It inks them in
/// the colour of the text around them, so the wordmark sits in a title
/// rather than beside it. And it crops each image to the band its ink
/// actually occupies ([_inkTop], [_inkBottom] and each glyph's own left
/// and right, all measured off the assets): every one of them carries its
/// own margin, so set side by side untouched they space unevenly and sit
/// at slightly different heights. Cropped to a band they share, they keep
/// a common baseline and a common scale, and the spacing between them
/// becomes this widget's to choose.
///
/// The `-o` is the same crop doing a second job: `sign_o` draws the mark
/// against a dotted circle standing in for whatever letter it attaches to,
/// and the window keeps the hook alone, the letter it belongs to being
/// right there in front of it.
class LontaraWordmark extends StatelessWidget {
  const LontaraWordmark({super.key, this.height = 22, this.color});

  /// How tall the letterforms stand — the ink itself, not the images'
  /// margins.
  final double height;

  /// Defaults to the colour of the surrounding text.
  final Color? color;

  /// The band the ink sits in, as fractions of an image's height. Shared
  /// by all four, so they scale together and line up; the `-o`'s tail is
  /// what reaches lowest.
  static const double _inkTop = 0.27;
  static const double _inkBottom = 0.86;

  static const _la = _Glyph('lon_la', 0.24, 0.78);
  static const _o = _Glyph('sign_o', 0.62, 0.85);
  static const _ta = _Glyph('lon_ta', 0.32, 0.70);
  static const _ra = _Glyph('lon_ra', 0.39, 0.63);

  @override
  Widget build(BuildContext context) {
    final ink =
        color ?? DefaultTextStyle.of(context).style.color ?? Colors.black87;
    // The vowel sign belongs to the letter in front of it, so it is set
    // closer to that letter than the letters are to each other.
    final between = height * 0.22;
    final against = height * 0.06;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cropped(_la),
          SizedBox(width: against),
          _cropped(_o),
          SizedBox(width: between),
          _cropped(_ta),
          SizedBox(width: between),
          _cropped(_ra),
        ],
      ),
    );
  }

  /// One letterform, with everything outside its own window cut away and
  /// the window itself drawn [height] tall.
  Widget _cropped(_Glyph glyph) {
    const heightFactor = _inkBottom - _inkTop;
    return ClipRect(
      child: Align(
        alignment: Alignment(
          _hold(glyph.left, glyph.right),
          _hold(_inkTop, _inkBottom),
        ),
        widthFactor: glyph.right - glyph.left,
        heightFactor: heightFactor,
        child: Image.asset(
          'assets/makasar/glyphs/${glyph.name}.png',
          height: height / heightFactor,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }

  /// Where an [Align] has to hold a child for the window from [from] to
  /// [to] to be the part on show: -1 is flush against the near edge, 1
  /// against the far one.
  static double _hold(double from, double to) =>
      (from + to - 1) / (1 - (to - from));
}

/// One letterform image and the span of it its ink occupies.
class _Glyph {
  const _Glyph(this.name, this.left, this.right);
  final String name;
  final double left;
  final double right;
}
