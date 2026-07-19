import 'package:flutter/material.dart';

import '../data/tomtom_code.dart';
import '../engine/scene.dart';

/// Cream, dot-grid paper background (Moleskine-style notebook page). Copied
/// per-feature — the Tom-Tom feature shares no code with the other scripts.
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

/// Freehand Tom-Tom code, ported from the `shorthand` project's
/// `TomtomCodeLinesInterpreter` (git history) and self-contained under
/// `lib/tomtom/`.
///
/// Every completed mark is classified and appended to a running sequence,
/// which is decoded live:
///
/// - a **vertical** stroke drawn **upward** is an ascending mark (`↑`),
/// - a **vertical** stroke drawn **downward** is a descending mark (`↓`),
/// - a **horizontal** stroke separates letters.
///
/// A run of 1–4 up/down marks between separators spells one letter.
class TomtomLayer extends Layer {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _activePoints;
  List<TomtomStroke> _symbols = [];
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
        .whereType<TomtomStroke>()
        .toList(growable: false);
    _decoded = decodeTomtom(_symbols);
  }

  /// Wider-than-tall → a separator; taller-than-wide → a vertical mark, whose
  /// draw direction (up vs down) picks ascending vs descending. A single
  /// point or a perfect diagonal is ignored.
  TomtomStroke? _classify(List<Offset> stroke) {
    if (stroke.length < 2) return null;
    final dx = (stroke.last.dx - stroke.first.dx).abs();
    final dy = (stroke.last.dy - stroke.first.dy).abs();
    if (dx > dy) return TomtomStroke.space;
    if (dx < dy) {
      return stroke.first.dy > stroke.last.dy
          ? TomtomStroke.ascending
          : TomtomStroke.descending;
    }
    return null;
  }

  void _drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length == 1) {
      canvas.drawCircle(points.first, paint.strokeWidth / 2, paint);
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
              TomtomStroke.ascending => '↑',
              TomtomStroke.descending => '↓',
              TomtomStroke.space => '/',
            })
        .join(' ');

    final label = TextPainter(
      text: _symbols.isEmpty
          ? const TextSpan(
              text: 'Draw vertical strokes up (↑) or down (↓); '
                  'a horizontal stroke separates letters',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            )
          : TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              children: [
                TextSpan(text: '$stream\n'),
                const TextSpan(text: 'Decoded: '),
                TextSpan(
                  text: _decoded.trim().isEmpty ? '—' : _decoded,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);
    label.paint(canvas, Offset(24, size.height - 24 - label.height));
  }
}

/// Builds the scene plus a direct reference to its [TomtomLayer], so the
/// hosting page can call [TomtomLayer.clear] from the Clear button.
(Scene, TomtomLayer) buildTomtomScene() {
  final layer = TomtomLayer();
  return (Scene([PaperLayer(), layer]), layer);
}
