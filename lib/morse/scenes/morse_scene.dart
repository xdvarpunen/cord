import 'package:flutter/material.dart';

import '../data/morse_code.dart';
import '../engine/scene.dart';

/// Cream, dot-grid paper background (Moleskine-style notebook page). Copied
/// per-feature — the Morse feature shares no code with the other scripts.
class PaperLayer extends Layer {
  static const _paperColor = Color(0xFFF3ECDC);
  static const _dotColor = Color(0x33000000);
  static const _spacing = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _paperColor);
    final dotPaint = Paint()..color = _dotColor;
    for (double y = _spacing; y < size.height; y += _spacing) {
      for (double x = _spacing; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }
}

/// Freehand Morse code, ported from the `shorthand` project's
/// `MorseLinesInterpreter` (git history) and self-contained under
/// `lib/morse/`.
///
/// Every completed mark is classified and appended to a running sequence,
/// which is decoded live:
///
/// - a **tap** is a dot (`.`),
/// - a **horizontal** stroke is a dash (`-`),
/// - a **vertical** stroke ends the current letter; two in a row make a word
///   space.
class MorseLayer extends Layer {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _activePoints;
  List<MorseSymbol> _symbols = [];
  String _decoded = '';

  /// The decoded text so far — read by tests; the on-canvas readout gets the
  /// same information via [paint].
  String get decoded => _decoded;

  void clear() {
    _strokes.clear();
    _activePoints = null;
    _symbols = [];
    _decoded = '';
  }

  @override
  void handlePointerEvent(PointerEvent event, Size size) {
    if (event is PointerDownEvent) {
      _activePoints = [event.localPosition];
    } else if (event is PointerMoveEvent && _activePoints != null) {
      _activePoints!.add(event.localPosition);
    } else if (event is PointerUpEvent && _activePoints != null) {
      _strokes.add(_activePoints!);
      _activePoints = null;
      _reclassify();
    }
  }

  void _reclassify() {
    _symbols = _strokes
        .map(_classify)
        .whereType<MorseSymbol>()
        .toList(growable: false);
    _decoded = decodeMorse(_symbols);
  }

  /// A single point is a dot; otherwise the wider-than-tall / taller-than-wide
  /// test (first→last) tells a dash from a separator. A perfect diagonal is
  /// ignored.
  MorseSymbol? _classify(List<Offset> stroke) {
    if (stroke.length == 1) return MorseSymbol.dot;
    final dx = (stroke.last.dx - stroke.first.dx).abs();
    final dy = (stroke.last.dy - stroke.first.dy).abs();
    if (dx > dy) return MorseSymbol.dash;
    if (dx < dy) return MorseSymbol.separator;
    return null;
  }

  void _drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length == 1) {
      canvas.drawCircle(points.first, paint.strokeWidth, paint);
      return;
    }
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0xFF1B2A4A)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final stroke in _strokes) {
      _drawPath(canvas, stroke, strokePaint);
    }
    final active = _activePoints;
    if (active != null) {
      _drawPath(
        canvas,
        active,
        Paint()
          ..color = strokePaint.color.withValues(alpha: 0.5)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    // Two-line readout: the raw symbol stream, then the decoded text.
    final stream = _symbols
        .map((s) => switch (s) {
              MorseSymbol.dot => '·',
              MorseSymbol.dash => '—',
              MorseSymbol.separator => '│',
            })
        .join(' ');

    final label = TextPainter(
      text: _symbols.isEmpty
          ? const TextSpan(
              text: 'Tap for a dot, draw a dash, a vertical line ends a letter',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            )
          : TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              children: [
                TextSpan(text: '$stream\n'),
                const TextSpan(text: 'Decoded: '),
                TextSpan(
                  text: _decoded.isEmpty ? '—' : _decoded,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

/// Builds the scene plus a direct reference to its [MorseLayer], so the
/// hosting page can call [MorseLayer.clear] from the Clear button.
(Scene, MorseLayer) buildMorseScene() {
  final layer = MorseLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
