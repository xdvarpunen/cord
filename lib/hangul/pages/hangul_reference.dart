import 'package:flutter/material.dart';

import '../data/hangul_jamo.dart';
import '../scenes/hangul_scene.dart';

/// The Hangul jamo legend — the basic consonants and vowels, each shown as a
/// glyph + romanization chip. Letters the recognizer can't identify yet are
/// muted (see [HangulLayer.recognizedSounds]) so they're still listed for
/// reference without implying they can be drawn.
///
/// Shared by the desktop side panel on [HangulPage] and the full-screen
/// [ReferencePage], the same way the other script features share their table.
class HangulReference extends StatelessWidget {
  const HangulReference({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JamoSection('Consonants', consonantRows),
          SizedBox(height: 16),
          _JamoSection('Tense consonants', tenseConsonantRows),
          SizedBox(height: 16),
          _JamoSection('Vowels', vowelRows),
          SizedBox(height: 16),
          _JamoSection('Complex vowels', complexVowelRows),
        ],
      ),
    );
  }
}

/// A titled run of letter chips — one of Hangul's two letter families.
class _JamoSection extends StatelessWidget {
  const _JamoSection(this.title, this.rows);

  final String title;
  final List<JamoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final row in rows)
              _LetterChip(
                row,
                disabled: !HangulLayer.recognizedSounds.contains(row.sound),
              ),
          ],
        ),
      ],
    );
  }
}

/// A bordered glyph + label pair, so letters are visually separated and
/// easier to scan than a plain run-on line of text. [disabled] mutes the
/// whole chip: the letter exists, but the gesture recognizer doesn't
/// support it yet — still listed, for reference.
class _LetterChip extends StatelessWidget {
  const _LetterChip(this.row, {required this.disabled});

  final JamoRow row;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = disabled ? scheme.onSurface.withValues(alpha: 0.38) : null;
    final labelColor = disabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: disabled
              ? scheme.outlineVariant.withValues(alpha: 0.5)
              : scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(row.glyph, style: TextStyle(fontSize: 18, color: fg)),
          const SizedBox(width: 6),
          Text(row.sound, style: TextStyle(fontSize: 13, color: labelColor)),
        ],
      ),
    );
  }
}
