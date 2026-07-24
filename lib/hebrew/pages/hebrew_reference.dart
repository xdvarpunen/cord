import 'package:flutter/material.dart';

import '../data/hebrew_letters.dart';
import '../scenes/hebrew_scene.dart';

/// The Hebrew legend — the 22-letter alef-bet, the 5 final (sofit) forms, and
/// the shapes several letters share. Each letter is a glyph + romanization
/// chip; letters the recognizer can't identify are muted (see
/// [HebrewLayer.recognizedNames]) so they're still listed for reference
/// without implying they can be drawn.
///
/// Shared by the desktop side panel on [HebrewPage] and the full-screen
/// [ReferencePage], the same way the other script features share their table.
class HebrewReference extends StatelessWidget {
  const HebrewReference({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LetterSection('Alphabet', letterRows),
          SizedBox(height: 16),
          _LetterSection('Final forms', finalRows),
          SizedBox(height: 16),
          _SharedShapes(),
        ],
      ),
    );
  }
}

/// A titled run of letter chips — one of the alef-bet's two families.
class _LetterSection extends StatelessWidget {
  const _LetterSection(this.title, this.rows);

  final String title;
  final List<LetterRow> rows;

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
                disabled: !HebrewLayer.recognizedNames.contains(row.name),
              ),
          ],
        ),
      ],
    );
  }
}

/// The letters that share one shape when written alone — a normal Hebrew
/// ambiguity the recognizer doesn't try to resolve (it reports the group's
/// base glyph and names the whole group). Read straight off
/// [HebrewLayer.sharedGroups], so the legend can't drift from the recognizer.
class _SharedShapes extends StatelessWidget {
  const _SharedShapes();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Shared shapes', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          'Drawn alone, these letters are the same shape — the recognizer '
          'reports the group:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final group in HebrewLayer.sharedGroups)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${group.glyphs.join(' ')}  —  ${group.names}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

/// A bordered glyph + label pair, so letters are visually separated and
/// easier to scan than a plain run-on line of text. [disabled] mutes the
/// whole chip: the letter exists, but the gesture recognizer doesn't
/// support it — still listed, for reference.
class _LetterChip extends StatelessWidget {
  const _LetterChip(this.row, {required this.disabled});

  final LetterRow row;
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
