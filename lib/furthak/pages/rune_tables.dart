import 'package:flutter/material.dart';

import '../data/elder_futhark.dart';
import '../data/younger_futhark.dart';

/// Reusable Futhark reference tables (rune / Latin / name / sound), shared by
/// the desktop side panel on [FutharkPage] and the full-screen tabbed
/// [ReferencePage]. Ported from the furthak project's reference page.

const _mobileBreakpoint = 600.0;
const _glyphFontSize = 22.0;
const _glyphFontSizeMobile = 18.0;

/// The 16-rune Younger Futhark table (long-branch forms).
class YoungerFutharkTable extends StatelessWidget {
  const YoungerFutharkTable({super.key});

  static const _glyphColumnWidth = 64.0;
  static const _translitColumnWidth = 56.0;
  static const _nameColumnWidth = 150.0;
  static const _soundColumnWidth = 120.0;
  static const _glyphColumnWidthMobile = 52.0;
  static const _translitColumnWidthMobile = 44.0;
  static const _nameColumnWidthMobile = 130.0;
  static const _soundColumnWidthMobile = 100.0;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < _mobileBreakpoint;
    final glyphWidth = isMobile ? _glyphColumnWidthMobile : _glyphColumnWidth;
    final translitWidth =
        isMobile ? _translitColumnWidthMobile : _translitColumnWidth;
    final nameWidth = isMobile ? _nameColumnWidthMobile : _nameColumnWidth;
    final soundWidth = isMobile ? _soundColumnWidthMobile : _soundColumnWidth;
    final glyphFontSize = isMobile ? _glyphFontSizeMobile : _glyphFontSize;
    final glyphStyle =
        TextStyle(fontFamily: 'NotoSansRunic', fontSize: glyphFontSize);

    return _ScriptTable(
      contentWidth: glyphWidth + translitWidth + nameWidth + soundWidth,
      headerCells: [
        _HeaderCell('Rune', glyphWidth),
        _HeaderCell('Latin', translitWidth),
        _HeaderCell('Name', nameWidth),
        _HeaderCell('Sound', soundWidth),
      ],
      bodyChildren: [
        for (final row in youngerFutharkRows)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BodyCell(row.glyph, glyphWidth, style: glyphStyle),
              _BodyCell(row.translit, translitWidth,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              _BodyCell('${row.name} — "${row.meaning}"', nameWidth),
              _BodyCell(row.sound, soundWidth,
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
      ],
    );
  }
}

/// The 24-rune Elder Futhark table, grouped into its three ættir.
class ElderFutharkTable extends StatelessWidget {
  const ElderFutharkTable({super.key});

  static const _glyphColumnWidth = 64.0;
  static const _translitColumnWidth = 56.0;
  static const _nameColumnWidth = 190.0;
  static const _soundColumnWidth = 72.0;
  static const _glyphColumnWidthMobile = 52.0;
  static const _translitColumnWidthMobile = 44.0;
  static const _nameColumnWidthMobile = 160.0;
  static const _soundColumnWidthMobile = 60.0;

  static const _aettNames = {1: 'First ætt', 2: 'Second ætt', 3: 'Third ætt'};

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < _mobileBreakpoint;
    final glyphWidth = isMobile ? _glyphColumnWidthMobile : _glyphColumnWidth;
    final translitWidth =
        isMobile ? _translitColumnWidthMobile : _translitColumnWidth;
    final nameWidth = isMobile ? _nameColumnWidthMobile : _nameColumnWidth;
    final soundWidth = isMobile ? _soundColumnWidthMobile : _soundColumnWidth;
    final glyphFontSize = isMobile ? _glyphFontSizeMobile : _glyphFontSize;
    final glyphStyle =
        TextStyle(fontFamily: 'NotoSansRunic', fontSize: glyphFontSize);

    final bodyChildren = <Widget>[];
    int? currentAett;
    for (final row in elderFutharkRows) {
      if (row.aett != currentAett) {
        currentAett = row.aett;
        bodyChildren.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(_aettNames[row.aett]!,
              style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ));
        bodyChildren.add(const Divider(height: 1));
      }
      bodyChildren.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BodyCell(row.glyph, glyphWidth, style: glyphStyle),
          _BodyCell(row.translit, translitWidth,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          _BodyCell('${row.name} — "${row.meaning}"', nameWidth),
          _BodyCell(row.sound, soundWidth,
              style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ));
    }

    return _ScriptTable(
      contentWidth: glyphWidth + translitWidth + nameWidth + soundWidth,
      headerCells: [
        _HeaderCell('Rune', glyphWidth),
        _HeaderCell('Latin', translitWidth),
        _HeaderCell('Name', nameWidth),
        _HeaderCell('Sound', soundWidth),
      ],
      bodyChildren: bodyChildren,
    );
  }
}

/// Shared table scaffold: a single horizontal scroll wraps both the header
/// and the vertically-scrolling body so they share the same horizontal
/// offset — the header stays pinned while scrolling horizontally in sync with
/// the body, and the body scrolls vertically on its own. The inner column is
/// sized to at least the viewport width (via LayoutBuilder) so the vertical
/// scrollable covers the full width even when the table itself is narrower.
/// (Same pattern as tifi's Tuareg tab.)
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
                  child:
                      Row(mainAxisSize: MainAxisSize.min, children: headerCells),
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
