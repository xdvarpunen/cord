import 'package:flutter/material.dart';

import '../data/suzhou_numerals.dart';

/// Reference table of the Suzhou numerals, grouped by category. Shared by the
/// desktop side panel on [SuzhouPage] and the full-screen [ReferencePage] on
/// narrow layouts.
///
/// Each row shows the glyph itself, the number it stands for, and its
/// codepoint — the glyphs are encoded, but render only in a CJK-capable font,
/// so the codepoint is there as a fallback identity when a box shows instead.
/// A check marks the digits the recognizer can already read.
class NumeralTable extends StatelessWidget {
  const NumeralTable({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final category in suzhouCategories) ...[
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
          for (final numeral
              in suzhouNumerals.where((n) => n.category == category))
            _NumeralRow(numeral: numeral),
          const Divider(height: 1),
        ],
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Suzhou numerals (蘇州碼子) are the last rod numerals still in '
            'everyday use. 1–3 are simply that many vertical bars; 4–9 are '
            'cursive forms of the ordinary Chinese numerals. This app reads '
            'the numeral forms only — not the ideographs 一二三 that real '
            'Suzhou notation borrows for 1–3 when bars would run together '
            'ambiguously. A check marks digits the recognizer can already '
            'read freehand.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _NumeralRow extends StatelessWidget {
  const _NumeralRow({required this.numeral});

  final SuzhouNumeral numeral;

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
              numeral.glyph,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          SizedBox(width: 40, child: Text('${numeral.value}')),
          Expanded(
            child: Text(
              numeral.codepoint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (numeral.recognized)
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
