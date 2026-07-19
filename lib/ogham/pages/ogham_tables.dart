import 'package:flutter/material.dart';

import '../data/ogham_letters.dart';

/// Reusable Ogham reference table (glyph / Latin / name / sound), shared by
/// the desktop side panel on the Ogham page and the full-screen
/// [ReferencePage]. Letters are drawn as vectors on a mini stemline — Ogham
/// is pure strokes, and Flutter web has no fallback font for the Ogham block,
/// so there is nothing to bundle.
class OghamTable extends StatelessWidget {
  const OghamTable({super.key});

  static const _mobileBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < _mobileBreakpoint;
    final glyphWidth = isMobile ? 52.0 : 64.0;
    final translitWidth = isMobile ? 44.0 : 56.0;
    final nameWidth = isMobile ? 130.0 : 160.0;
    final soundWidth = isMobile ? 80.0 : 96.0;

    final bodyChildren = <Widget>[];
    OghamAicme? currentAicme;
    for (final letter in oghamLetters) {
      if (letter.aicme != currentAicme) {
        currentAicme = letter.aicme;
        bodyChildren.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${letter.aicme.irishName} — ${letter.aicme.description}',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ));
        bodyChildren.add(const Divider(height: 1));
      }
      bodyChildren.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: glyphWidth,
            height: 44,
            child: letter.strokeCount > 0
                ? CustomPaint(
                    painter: _OghamGlyphPainter(
                      aicme: letter.aicme,
                      strokeCount: letter.strokeCount,
                    ),
                  )
                : const Center(
                    child: Text('—', style: TextStyle(color: Colors.black38)),
                  ),
          ),
          _BodyCell(letter.translit, translitWidth,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          _BodyCell(letter.name, nameWidth),
          _BodyCell(letter.sound, soundWidth,
              style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ));
    }

    return _ScriptTable(
      contentWidth: glyphWidth + translitWidth + nameWidth + soundWidth,
      headerCells: [
        _HeaderCell('Ogham', glyphWidth),
        _HeaderCell('Latin', translitWidth),
        _HeaderCell('Name', nameWidth),
        _HeaderCell('Sound', soundWidth),
      ],
      bodyChildren: bodyChildren,
    );
  }
}

/// Draws a single primary letter as strokes on a short stemline, laid out the
/// way the recognizer reads it: [OghamAicme.beithe] below the stem,
/// [OghamAicme.huatha] above, [OghamAicme.muine] diagonally across, and
/// [OghamAicme.ailme] as short notches on the stem.
class _OghamGlyphPainter extends CustomPainter {
  _OghamGlyphPainter({required this.aicme, required this.strokeCount});

  final OghamAicme aicme;
  final int strokeCount;

  @override
  void paint(Canvas canvas, Size size) {
    final stemY = size.height / 2;
    final stemPaint = Paint()
      ..color = const Color(0xFF1B2A4A)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(4, stemY), Offset(size.width - 4, stemY), stemPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFF1B2A4A)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const gap = 8.0;
    const len = 12.0;
    final span = (strokeCount - 1) * gap;
    final startX = size.width / 2 - span / 2;

    for (var i = 0; i < strokeCount; i++) {
      final x = startX + i * gap;
      switch (aicme) {
        case OghamAicme.beithe:
          canvas.drawLine(
              Offset(x, stemY), Offset(x, stemY + len), strokePaint);
        case OghamAicme.huatha:
          canvas.drawLine(
              Offset(x, stemY), Offset(x, stemY - len), strokePaint);
        case OghamAicme.muine:
          canvas.drawLine(Offset(x - 4, stemY + len),
              Offset(x + 4, stemY - len), strokePaint);
        case OghamAicme.ailme:
          canvas.drawLine(
              Offset(x, stemY - 4), Offset(x, stemY + 4), strokePaint);
        case OghamAicme.forfeda:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(_OghamGlyphPainter oldDelegate) =>
      oldDelegate.aicme != aicme || oldDelegate.strokeCount != strokeCount;
}

/// Shared table scaffold: a single horizontal scroll wraps both the header
/// and the vertically-scrolling body so they share the same horizontal
/// offset. (Same pattern as the other features' reference tables.)
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
