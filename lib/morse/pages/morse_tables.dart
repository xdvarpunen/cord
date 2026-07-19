import 'package:flutter/material.dart';

import '../data/morse_code.dart';

/// Reusable Morse reference table (character / code), shared by the desktop
/// side panel on the Morse page and the full-screen [ReferencePage].
class MorseTable extends StatelessWidget {
  const MorseTable({super.key});

  static const _mobileBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < _mobileBreakpoint;
    final charWidth = isMobile ? 56.0 : 72.0;
    final codeWidth = isMobile ? 140.0 : 180.0;

    final bodyChildren = <Widget>[];
    bool? lastWasDigit;
    for (final entry in morseAlphabet) {
      if (entry.isDigit != lastWasDigit) {
        lastWasDigit = entry.isDigit;
        bodyChildren.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            entry.isDigit ? 'Numbers' : 'Letters',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ));
        bodyChildren.add(const Divider(height: 1));
      }
      final code = entry.code
          .replaceAll('.', '·')
          .replaceAll('-', '—')
          .split('')
          .join(' ');
      bodyChildren.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BodyCell(entry.char, charWidth,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          _BodyCell(code, codeWidth,
              style: const TextStyle(fontSize: 18, letterSpacing: 1)),
        ],
      ));
    }

    return _ScriptTable(
      contentWidth: charWidth + codeWidth,
      headerCells: [
        _HeaderCell('Char', charWidth),
        _HeaderCell('Code', codeWidth),
      ],
      bodyChildren: bodyChildren,
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
