import 'package:flutter/material.dart';

import '../data/tomtom_code.dart';

/// Reusable Tom-Tom reference table (character / stroke pattern), shared by
/// the desktop side panel on the Tom-Tom page and the full-screen
/// [ReferencePage].
class TomtomTable extends StatelessWidget {
  const TomtomTable({super.key});

  static const _mobileBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < _mobileBreakpoint;
    final charWidth = isMobile ? 56.0 : 72.0;
    final patternWidth = isMobile ? 120.0 : 160.0;

    return _ScriptTable(
      contentWidth: charWidth + patternWidth,
      headerCells: [
        _HeaderCell('Char', charWidth),
        _HeaderCell('Strokes', patternWidth),
      ],
      bodyChildren: [
        for (final entry in tomtomAlphabet)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BodyCell(entry.char, charWidth,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              _BodyCell(entry.arrows, patternWidth,
                  style: const TextStyle(fontSize: 18, letterSpacing: 2)),
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
