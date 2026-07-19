import 'package:flutter/material.dart';

import '../data/tartessian_scripts.dart';

/// Reference table of the Southwestern ("Tartessian") signary, grouped by
/// category. Shared by the desktop side panel on [TartessianPage] and the
/// full-screen [ReferencePage] on narrow layouts.
///
/// The signs have no Unicode codepoints, so each row shows the epigraphers'
/// transliteration and its sound value rather than a glyph — the letterforms
/// are what you draw on the canvas. A check marks the signs the recognizer
/// can already read.
class SignaryTable extends StatelessWidget {
  const SignaryTable({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final category in tartessianCategories) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              category,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (final sign
              in tartessianSigns.where((s) => s.category == category))
            _SignRow(sign: sign),
          const Divider(height: 1),
        ],
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'A semi-syllabary: the stop signs (b, t, k) carry an inherent '
            'vowel that is also written separately. Decipherment is partial, '
            'so several readings are provisional. A check marks signs the '
            'recognizer can already read freehand.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _SignRow extends StatelessWidget {
  const _SignRow({required this.sign});

  final TartessianSign sign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              sign.transliteration,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          Expanded(child: Text(sign.value)),
          if (sign.recognized)
            Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary)
          else
            Icon(
              Icons.circle_outlined,
              size: 18,
              color: theme.colorScheme.outlineVariant,
            ),
        ],
      ),
    );
  }
}
