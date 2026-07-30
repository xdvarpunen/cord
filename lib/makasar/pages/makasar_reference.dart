import 'package:flutter/material.dart';

import '../data/lontara_letters.dart';
import '../data/makasar_letters.dart';
import '../data/script.dart';
import '../scenes/makasar_scene.dart';
import '../widgets/glyph_image.dart';

/// The reference for one of the two South Sulawesi abugidas:
///
/// - **Makasar**, the script the canvas reads: its 18 letters with the sound
///   each carries and how its letterform decomposes into the script's
///   building blocks ([MakasarLetter.shape]), then the four vowel signs that
///   replace a letter's inherent `a`, then the repeater and the two
///   punctuation marks ([makasarOtherSigns]).
/// - **Bugis (Lontara)**, mostly reference: its 23 letters — five of which
///   Makasar has no equivalent for — five vowel signs and two punctuation
///   marks, each row naming the Makasar letter it lines up with. See
///   [LontaraLetter].
///
/// Every row leads with the letterform as drawn ([GlyphImage]), which for the
/// Lontara rows is the only rendering of the character there is. A row the
/// recognizer has no gesture for is muted (see
/// [MakasarLayer.recognizedNamesFor]) — the character is part of the script
/// and still worth listing, but it can't be drawn yet, which is most of
/// Lontara and every vowel sign of neither script.
///
/// Shared by the desktop side panel on [MakasarPage] and the full-screen
/// [ReferencePage], the same way the other script features share their table.
/// This is upstream `makasar`'s own reference table; what it lost in the port
/// is the script dropdown at its head — cord's page carries one already, and
/// the two would only have to be kept agreeing.
class MakasarReference extends StatelessWidget {
  const MakasarReference({required this.script, super.key});

  final WritingScript script;

  /// Below this *panel* width the table's columns tighten up. Measured
  /// against the panel rather than the window: in the 50/50 split the table
  /// gets half the width the window would report, and a table laid out for
  /// the window leaves the description column nothing.
  static const _narrowPanel = 600.0;

  static const _glyphFontSize = 22.0;
  static const _glyphFontSizeMobile = 18.0;

  static const _imageColumnWidth = 76.0;
  static const _imageColumnWidthMobile = 64.0;
  static const _imageHeight = 34.0;
  static const _imageHeightMobile = 28.0;

  static const _glyphColumnWidth = 56.0;
  static const _nameColumnWidth = 84.0;
  static const _soundColumnWidth = 64.0;
  static const _nameColumnWidthMobile = 68.0;
  static const _soundColumnWidthMobile = 48.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _table(context, narrow: constraints.maxWidth < _narrowPanel),
    );
  }

  Widget _table(BuildContext context, {required bool narrow}) {
    final theme = Theme.of(context);
    final glyphFontSize = narrow ? _glyphFontSizeMobile : _glyphFontSize;
    final nameWidth = narrow ? _nameColumnWidthMobile : _nameColumnWidth;
    final soundWidth = narrow ? _soundColumnWidthMobile : _soundColumnWidth;
    final imageWidth = narrow ? _imageColumnWidthMobile : _imageColumnWidth;
    final imageHeight = narrow ? _imageHeightMobile : _imageHeight;

    Widget image(String? name, {required bool muted}) => _Cell(
      imageWidth,
      child: Align(
        alignment: Alignment.centerLeft,
        child: GlyphImage(name, height: imageHeight, muted: muted),
      ),
    );

    final makasarGlyphStyle = TextStyle(
      fontFamily: 'NotoSerifMakasar',
      fontSize: glyphFontSize,
    );
    const nameStyle = TextStyle(fontWeight: FontWeight.bold);
    const soundStyle = TextStyle(fontStyle: FontStyle.italic);

    final recognized = MakasarLayer.recognizedNamesFor(script);
    final vowels = MakasarLayer.recognizedVowelsFor(script);

    return Column(
      children: [
        _head(context),
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: _row([
            _HeaderCell('Drawn', imageWidth),
            _HeaderCell(
              script == WritingScript.makasar ? 'Letter' : 'Code',
              _glyphColumnWidth,
            ),
            _HeaderCell('Name', nameWidth),
            _HeaderCell('IPA', soundWidth),
            _HeaderCell(
              script == WritingScript.makasar ? 'Letterform' : 'Notes',
              0,
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: switch (script) {
                WritingScript.makasar => [
                  for (final letter in makasarLetters)
                    _row([
                      image(
                        letter.image,
                        muted: !recognized.contains(letter.name),
                      ),
                      _BodyCell(
                        letter.glyph,
                        _glyphColumnWidth,
                        style: makasarGlyphStyle,
                      ),
                      _BodyCell(letter.name, nameWidth, style: nameStyle),
                      _BodyCell(
                        '/${letter.ipa}/',
                        soundWidth,
                        style: soundStyle,
                      ),
                      _BodyCell(letter.shape, 0),
                    ], muted: !recognized.contains(letter.name)),
                  const _SectionHeader('Vowel signs'),
                  for (final sign in makasarVowelSigns)
                    _row([
                      image(sign.image, muted: !vowels.contains(sign.vowel)),
                      // On a dotted circle, the convention for a mark
                      // that attaches to a letter rather than standing
                      // alone.
                      _BodyCell(
                        '◌${sign.glyph}',
                        _glyphColumnWidth,
                        style: makasarGlyphStyle,
                      ),
                      _BodyCell(sign.name, nameWidth, style: nameStyle),
                      _BodyCell(
                        '-${sign.vowel}',
                        soundWidth,
                        style: soundStyle,
                      ),
                      _BodyCell(sign.placement, 0),
                    ], muted: !vowels.contains(sign.vowel)),
                  const _SectionHeader('Other signs'),
                  for (final sign in makasarOtherSigns)
                    _row([
                      image(sign.image, muted: !recognized.contains(sign.name)),
                      _BodyCell(
                        sign.glyph,
                        _glyphColumnWidth,
                        style: makasarGlyphStyle,
                      ),
                      _BodyCell(
                        sign.name,
                        nameWidth + soundWidth,
                        style: nameStyle,
                      ),
                      _BodyCell(sign.use, 0),
                    ], muted: !recognized.contains(sign.name)),
                ],
                WritingScript.bugis => [
                  for (final letter in lontaraLetters)
                    _row([
                      image(
                        letter.image,
                        muted: !recognized.contains(letter.name),
                      ),
                      _CodeCell(letter.glyph, _glyphColumnWidth),
                      _BodyCell(letter.name, nameWidth, style: nameStyle),
                      _BodyCell(
                        '/${letter.ipa}/',
                        soundWidth,
                        style: soundStyle,
                      ),
                      // What to draw once a letter can be drawn;
                      // otherwise what it lines up with in Makasar.
                      letter.shape != null
                          ? _BodyCell(letter.shape!, 0)
                          : _Cell(
                              0,
                              child: _counterpart(
                                letter.makasarName,
                                makasarGlyphStyle,
                              ),
                            ),
                    ], muted: !recognized.contains(letter.name)),
                  const _SectionHeader('Vowel signs'),
                  for (final sign in lontaraVowelSigns)
                    _row([
                      image(sign.image, muted: !vowels.contains(sign.vowel)),
                      _CodeCell(sign.glyph, _glyphColumnWidth),
                      _BodyCell('-${sign.vowel}', nameWidth, style: nameStyle),
                      _BodyCell('/${sign.ipa}/', soundWidth, style: soundStyle),
                      _BodyCell(sign.placement, 0),
                    ], muted: !vowels.contains(sign.vowel)),
                  const _SectionHeader('Punctuation'),
                  for (final sign in lontaraOtherSigns)
                    _row([
                      image(sign.image, muted: !recognized.contains(sign.name)),
                      _CodeCell(sign.glyph, _glyphColumnWidth),
                      _BodyCell(
                        sign.name,
                        nameWidth + soundWidth,
                        style: nameStyle,
                      ),
                      _BodyCell(sign.use, 0),
                    ], muted: !recognized.contains(sign.name)),
                ],
              },
            ),
          ),
        ),
      ],
    );
  }

  /// What the script is and how much of it there is, plus — for Lontara —
  /// the reason its rows show a codepoint where the Makasar rows show the
  /// character itself.
  Widget _head(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(script.label, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            legendFor(script),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (script == WritingScript.bugis) ...[
            const SizedBox(height: 4),
            Text(
              'No Buginese font is bundled, so the drawn letterform is the '
              'only rendering here — the Code column is the Unicode '
              'codepoint.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The Makasar letter a Lontara letter lines up with, shown as its glyph
  /// plus name — or a plain note for the five that have no counterpart.
  static Widget _counterpart(String? name, TextStyle glyphStyle) {
    final letter = name == null ? null : makasarLettersByName[name];
    if (letter == null) {
      return const Text(
        'no Makasar letter',
        style: TextStyle(color: Colors.black54),
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Makasar '),
          TextSpan(text: letter.glyph, style: glyphStyle),
          TextSpan(text: ' ${letter.name}'),
        ],
      ),
    );
  }

  /// A table row: fixed-width cells, then one cell that takes whatever width
  /// is left (the description column, which is the only one long enough to
  /// want wrapping). [muted] fades the whole row — see the class doc.
  static Widget _row(List<Widget> cells, {bool muted = false}) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...cells.take(cells.length - 1),
        Expanded(child: cells.last),
      ],
    );
    return muted ? Opacity(opacity: 0.45, child: row) : row;
  }
}

/// How many characters [script] holds, for the head of the reference and the
/// search page's row — the character sets are the whole of the difference
/// between the two scripts.
String legendFor(WritingScript script) => switch (script) {
  WritingScript.makasar =>
    '${makasarLetters.length} letters, '
        '${makasarVowelSigns.length} vowel signs and '
        '${makasarOtherSigns.length} other signs — the script the canvas '
        'reads',
  WritingScript.bugis =>
    '${lontaraLetters.length} letters, '
        '${lontaraVowelSigns.length} vowel signs and '
        '${lontaraOtherSigns.length} punctuation marks — the sibling script, '
        'mostly reference',
};

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// One table cell: a fixed width, or 0 for the trailing cell, which is sized
/// by the [MakasarReference._row]'s own [Expanded] instead.
class _Cell extends StatelessWidget {
  const _Cell(this.width, {required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width == 0 ? null : width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: child,
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, this.width);
  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width == 0 ? null : width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(this.text, this.width, {this.style});
  final String text;
  final double width;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) =>
      _Cell(width, child: Text(text, style: style));
}

/// A character's codepoint, for the Lontara rows — nothing in the bundle
/// renders the Buginese block, so `U+1A00` is shown where the Makasar rows
/// show the character itself.
class _CodeCell extends StatelessWidget {
  const _CodeCell(this.glyph, this.width);
  final String glyph;
  final double width;

  @override
  Widget build(BuildContext context) {
    final code = glyph.runes.first
        .toRadixString(16)
        .toUpperCase()
        .padLeft(4, '0');
    return _Cell(
      width,
      child: Text(
        'U+$code',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.black54,
        ),
      ),
    );
  }
}
