import 'package:flutter/material.dart';

import '../data/illakkam_scripts.dart';
import '../data/lith_scripts.dart';
import '../scenes/sinhala_scene.dart';

/// The reference for whichever numeral system the page's dropdown is on:
///
/// - **Lith** ([RecognitionSystem.lithNumerals], ලිත් ඉලක්කම් — the astrological
///   / almanac digits): ten decimal place-value digits with a zero, each with
///   its value, its Sinhala name and a hint at how it is drawn.
/// - **Illakkam** ([RecognitionSystem.illakkamNumerals], ඉලක්කම් — the older
///   numerals the Lith digits replaced): every unit, every ten, and then a
///   hundred and a thousand, each a symbol of its own, because with no place
///   value there are no columns and so no zero.
///
/// Every row is ticked or not according to whether the recognizer knows the
/// glyph — the table doubles as a map of what can be drawn and what is here to
/// be read. All ten Lith digits are wired up; of the Illakkam symbols the nine
/// units are, and the tens and the hundred and thousand are not. It asks the
/// recognizer rather than holding a list of its own, so it cannot drift as
/// rules are added.
///
/// Shared by the desktop side panel on the Sinhala page and the full-screen
/// [ReferencePage], the same way the other script features share their table.
/// This is upstream `sinhala`'s own reference panel, less its hodiya (vowels
/// and consonants) table — cord took the numerals only.
///
/// All Sinhala glyphs render from the bundled Yaldevi font: Flutter web has no
/// guaranteed system Sinhala font, and Yaldevi also matches the traditional
/// Lith digit forms and carries the Illakkam symbols, which sit outside the
/// Basic Multilingual Plane — see `assets/sinhala/FONT_NOTE.txt`.
class SinhalaReference extends StatelessWidget {
  const SinhalaReference({required this.system, super.key});

  final RecognitionSystem system;

  @override
  Widget build(BuildContext context) {
    final known = system.recognizedGlyphs.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              _Implemented(system.recognizedGlyphs.firstOrNull ?? '෧'),
              Expanded(
                child: Text(
                  known == 0
                      ? 'Nothing here is recognized yet — reference only.'
                      : 'ticks the $known the canvas can recognize in '
                          '${system.label}; the rest are reference only.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (system) {
            RecognitionSystem.lithNumerals => const _LithReferenceTable(),
            RecognitionSystem.illakkamNumerals =>
              const _IllakkamReferenceTable(),
            // The letters are still in the recognizer (see
            // `scenes/sinhala_scene.dart`), but cord took the numerals only and
            // the page's dropdown offers no way to reach this.
            RecognitionSystem.letters => const _NoTable(),
          },
        ),
      ],
    );
  }
}

/// What a numeral system is and how many symbols it holds, for the search
/// page's row — the same job [legendFor] does for Lontara's two scripts.
String legendForSystem(RecognitionSystem system) => switch (system) {
      RecognitionSystem.lithNumerals =>
        '${lithDigits.length} digits, decimal with place value and a zero — '
            'the astrological / almanac digits',
      RecognitionSystem.illakkamNumerals =>
        '${illakkamNumerals.length} symbols, no zero and no place value — the '
            'older numerals the Lith digits replaced',
      // Not reachable from the page; see [SinhalaReference].
      RecognitionSystem.letters => 'the hodiya, which cord did not take',
    };

/// The romanized names of a system's numbers, so searching "dahasa" or
/// "binduva" finds the system that has it. Not shown — the row already says
/// what the system is.
String keywordsForSystem(RecognitionSystem system) => switch (system) {
      RecognitionSystem.lithNumerals =>
        'lith almanac astrological ${lithDigits.map((d) => d.name).join(' ')}',
      RecognitionSystem.illakkamNumerals =>
        'illakkam archaic ${illakkamNumerals.map((n) => n.name).join(' ')}',
      RecognitionSystem.letters => 'hodiya',
    };

/// The ten Lith digits with their value, name, and shape hint.
class _LithReferenceTable extends StatelessWidget {
  const _LithReferenceTable();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text('Lith numerals (ලිත් ඉලක්කම්)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Decimal place-value digits, with a zero placeholder.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final d in lithDigits)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Implemented(d.glyph),
                _Glyph(d.glyph, size: 28, width: 40),
                SizedBox(
                  width: 28,
                  child: Text('${d.value}',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(width: 8),
                _Gloss(d.name, d.shape),
              ],
            ),
          ),
      ],
    );
  }
}

/// The Illakkam numerals (ඉලක්කම්) — every unit, every ten, and then a hundred
/// and a thousand, each with a symbol of its own.
class _IllakkamReferenceTable extends StatelessWidget {
  const _IllakkamReferenceTable();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text('Illakkam numerals (ඉලක්කම්)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'No zero and no place value: a number is written by setting symbols '
          'side by side, so 123 is 100, then 20, then 3. There is no zero '
          'because there are no columns for one to hold.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        _section(context, 'Units', illakkamUnits),
        _section(context, 'Tens', illakkamTens,
            subtitle: 'Each its own symbol, not built from a unit.'),
        _section(context, 'Hundred and thousand', illakkamHundreds,
            subtitle: 'Where the symbols stop; larger numbers combine these.'),
      ],
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    List<IllakkamNumeral> numerals, {
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title, subtitle: subtitle),
        for (final numeral in numerals)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _Implemented(numeral.glyph),
                _Glyph(numeral.glyph, size: 28, width: 44),
                SizedBox(
                  width: 44,
                  child: Text('${numeral.value}',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Expanded(
                  child: Text(numeral.name,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Stands in for the hodiya table upstream shows under
/// [RecognitionSystem.letters], which cord did not take — unreachable from the
/// page, and here so the switch over the systems stays exhaustive rather than
/// being closed with a default that would swallow a system added later.
class _NoTable extends StatelessWidget {
  const _NoTable();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'This page is the Sinhala numerals only.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}

/// Says whether the recognizer can already identify [glyph], so the reference
/// tables double as a map of what is built and what is not.
class _Implemented extends StatelessWidget {
  const _Implemented(this.glyph);

  final String glyph;

  @override
  Widget build(BuildContext context) {
    final known = recognizedGlyphs.contains(glyph);
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 26,
      child: Icon(
        known ? Icons.check_circle : Icons.circle_outlined,
        size: 15,
        color: known ? colors.primary : colors.outlineVariant,
        semanticLabel: known ? 'recognized' : 'not recognized yet',
      ),
    );
  }
}

/// A big Sinhala glyph, sized for a reference row.
class _Glyph extends StatelessWidget {
  const _Glyph(this.text, {this.size = 30, this.width = 44});

  final String text;
  final double size;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(fontFamily: 'Yaldevi', fontSize: size),
      ),
    );
  }
}

/// Section heading inside a reference list.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          if (subtitle != null)
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// The name + shape-hint pair that closes a Lith row.
class _Gloss extends StatelessWidget {
  const _Gloss(this.roman, this.note);

  final String roman;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(roman, style: Theme.of(context).textTheme.bodyMedium),
          Text(note, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
