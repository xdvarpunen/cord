import 'package:flutter/material.dart';

import '../data/cyrillic_letters.dart';
import '../scenes/cyrillic_scene.dart';

/// The Cyrillic legend — the 33 letters of the Russian alphabet in their
/// standard order, each a capital/lowercase glyph pair with the letter's own
/// name. Letters the recognizer can't identify are muted (see
/// [CyrillicLayer.recognizedNames]) so they're still listed for reference
/// without implying they can be drawn.
///
/// Shared by the desktop side panel on [CyrillicPage] and the full-screen
/// [ReferencePage], the same way the other script features share their table.
class CyrillicReference extends StatelessWidget {
  const CyrillicReference({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alphabet', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final row in cyrillicRows)
                _LetterChip(
                  row,
                  disabled: !CyrillicLayer.recognizedNames.contains(row.name),
                ),
            ],
          ),
        ],
      ),
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
          Text('${row.capital} ${row.small}',
              style: TextStyle(fontSize: 18, color: fg)),
          const SizedBox(width: 6),
          Text(row.name, style: TextStyle(fontSize: 13, color: labelColor)),
        ],
      ),
    );
  }
}
