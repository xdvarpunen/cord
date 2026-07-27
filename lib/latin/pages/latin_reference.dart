import 'package:flutter/material.dart';

import '../data/latin_letters.dart';
import '../scenes/latin_scene.dart';

/// The legend for one alphabet — its letters, in its own order, each a
/// capital/lowercase glyph pair with the letter's own name. Letters the
/// recognizer can't identify are muted (see [LatinLayer.recognizedNames]) so
/// they're still listed for reference without implying they can be drawn; as
/// things stand nothing is muted, every letter of every alphabet being
/// drawable.
///
/// Shared by the desktop side panel on [LatinPage] and the full-screen
/// [ReferencePage], the same way the other script features share their table.
class LatinReference extends StatelessWidget {
  const LatinReference({required this.alphabet, super.key});

  final Alphabet alphabet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(alphabet.label, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            legendFor(alphabet),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final row in alphabet.rows)
                _LetterChip(
                  row,
                  disabled: !LatinLayer.recognizedNames.contains(row.name),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// How many letters [alphabet] holds and what makes the set itself, since the
/// letters are the whole of the difference between the alphabets.
String legendFor(Alphabet alphabet) =>
    '${alphabet.rows.length} letters — ${alphabet.note}';

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
