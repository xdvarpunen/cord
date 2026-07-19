import 'package:flutter/material.dart';

import '../data/etruscan_numerals.dart';

/// Reusable Etruscan numeral reference table (value / figure / how to draw),
/// shared by the desktop side panel on the Etruscan page and the full-screen
/// [ReferencePage]. Figures are drawn as vectors — the classical signs live
/// in the Old Italic Unicode block, which Flutter web has no fallback font
/// for, and the recognizer reads plain strokes anyway.
class EtruscanTable extends StatelessWidget {
  const EtruscanTable({super.key});

  static const _mobileBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < _mobileBreakpoint;
    final valueWidth = isMobile ? 52.0 : 64.0;
    final glyphWidth = isMobile ? 48.0 : 56.0;
    final howToWidth = isMobile ? 220.0 : 300.0;

    return _ScriptTable(
      contentWidth: valueWidth + glyphWidth + howToWidth,
      headerCells: [
        _HeaderCell('Value', valueWidth),
        _HeaderCell('Figure', glyphWidth),
        _HeaderCell('How to draw', howToWidth),
      ],
      bodyChildren: [
        for (final numeral in etruscanNumerals)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BodyCell('${numeral.value}', valueWidth,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(
                width: glyphWidth,
                height: 44,
                child: CustomPaint(
                  painter: EtruscanGlyphPainter(numeral.kind),
                ),
              ),
              _BodyCell(numeral.howTo, howToWidth),
            ],
          ),
      ],
    );
  }
}

/// Shared table scaffold (same pattern as the other features' tables).
class _ScriptTable extends StatelessWidget {
  const _ScriptTable({
    required this.contentWidth,
    required this.headerCells,
    required this.bodyChildren,
  });
  final double contentWidth;
  final List<Widget> headerCells;
  final List<Widget> bodyChildren;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = contentWidth > constraints.maxWidth
            ? contentWidth
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Row(
                      mainAxisSize: MainAxisSize.min, children: headerCells),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: bodyChildren,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      width: width,
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(text, style: style),
      ),
    );
  }
}
