// Etruscan numeral reference data, matching the recognizer ported from the
// `shorthand` project's EtruscanNumeralsLinesInterpreter (git history).
// Self-contained under `lib/etruscan/` — shares nothing with the other
// features.

import 'package:flutter/widgets.dart';

/// Which numeral a reference row (and the recognizer) is about — also selects
/// how [EtruscanGlyphPainter] draws its mini figure.
enum EtruscanNumeralKind { one, five, ten, fifty, hundred }

/// One row of the reference table: the value, its classical Etruscan symbol,
/// how to draw it on the canvas, and which figure to render.
class EtruscanNumeral {
  const EtruscanNumeral({
    required this.value,
    required this.symbol,
    required this.howTo,
    required this.kind,
  });

  final int value;

  /// The classical Etruscan numeral sign (Old Italic block — drawn as a
  /// vector in the app; Flutter web has no fallback font for it).
  final String symbol;
  final String howTo;
  final EtruscanNumeralKind kind;
}

const etruscanNumerals = [
  EtruscanNumeral(
    value: 1,
    symbol: '𐌠',
    howTo: 'A single vertical stroke.',
    kind: EtruscanNumeralKind.one,
  ),
  EtruscanNumeral(
    value: 5,
    symbol: '𐌡',
    howTo: 'Two strokes meeting at a peak (∧) — draw up, then down, '
        'without crossing.',
    kind: EtruscanNumeralKind.five,
  ),
  EtruscanNumeral(
    value: 10,
    symbol: '𐌢',
    howTo: 'Two crossing strokes (✕) — one up, one down, that intersect.',
    kind: EtruscanNumeralKind.ten,
  ),
  EtruscanNumeral(
    value: 50,
    symbol: '𐌣',
    howTo: 'A peak (∧) sitting on top of a tall vertical stroke.',
    kind: EtruscanNumeralKind.fifty,
  ),
  EtruscanNumeral(
    value: 100,
    symbol: '𐌟',
    howTo: 'A cross (✕) with a vertical stroke through its centre.',
    kind: EtruscanNumeralKind.hundred,
  ),
];

/// Draws a numeral as the little figure the recognizer reads, on a mini box.
class EtruscanGlyphPainter extends CustomPainter {
  EtruscanGlyphPainter(this.kind);

  final EtruscanNumeralKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1B2A4A)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    const top = 6.0;
    final bottom = size.height - 6;
    final midY = (top + bottom) / 2;
    const w = 9.0; // half-width of the peak / cross

    switch (kind) {
      case EtruscanNumeralKind.one:
        canvas.drawLine(Offset(cx, top), Offset(cx, bottom), paint);
      case EtruscanNumeralKind.five:
        canvas.drawLine(Offset(cx - w, bottom), Offset(cx, top), paint);
        canvas.drawLine(Offset(cx, top), Offset(cx + w, bottom), paint);
      case EtruscanNumeralKind.ten:
        canvas.drawLine(Offset(cx - w, top), Offset(cx + w, bottom), paint);
        canvas.drawLine(Offset(cx + w, top), Offset(cx - w, bottom), paint);
      case EtruscanNumeralKind.fifty:
        canvas.drawLine(Offset(cx, midY), Offset(cx, bottom), paint);
        canvas.drawLine(Offset(cx - w, midY), Offset(cx, top), paint);
        canvas.drawLine(Offset(cx, top), Offset(cx + w, midY), paint);
      case EtruscanNumeralKind.hundred:
        canvas.drawLine(Offset(cx - w, top), Offset(cx + w, bottom), paint);
        canvas.drawLine(Offset(cx + w, top), Offset(cx - w, bottom), paint);
        canvas.drawLine(Offset(cx, top), Offset(cx, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(EtruscanGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
