import 'package:flutter/material.dart';

/// A small vector drawing of a *completed* cluster for a tally system,
/// identified by its [TallySystem.slug]. Drawn rather than set in a font so
/// it needs no glyph/CJK font bundle and matches the hand-drawn look of the
/// canvas (same navy stroke). Unknown slugs render nothing.
///
/// Geometry is defined in a normalized 0–1 box and scaled to [size], so the
/// same shapes work at any size (table row icon or the big header glyph).
class TallyGlyph extends StatelessWidget {
  const TallyGlyph(this.slug, {this.size = 48, super.key});

  final String slug;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TallyGlyphPainter(slug)),
    );
  }
}

// Corners of the square used by the dot-dash and card systems.
const _tl = Offset(0.2, 0.2);
const _tr = Offset(0.8, 0.2);
const _br = Offset(0.8, 0.8);
const _bl = Offset(0.2, 0.8);

/// Canonical completed-cluster strokes per slug, as line segments in the
/// normalized 0–1 box.
const Map<String, List<List<Offset>>> _strokes = {
  'five-bar-gate': [
    [Offset(0.22, 0.16), Offset(0.22, 0.84)],
    [Offset(0.37, 0.16), Offset(0.37, 0.84)],
    [Offset(0.52, 0.16), Offset(0.52, 0.84)],
    [Offset(0.67, 0.16), Offset(0.67, 0.84)],
    [Offset(0.12, 0.82), Offset(0.78, 0.18)], // the crossing fifth stroke
  ],
  'dot-dash': [
    [_tl, _tr], [_tr, _br], [_br, _bl], [_bl, _tl], // four sides
    [_tl, _br], [_tr, _bl], // two diagonals
  ],
  'zheng': [
    [Offset(0.18, 0.15), Offset(0.82, 0.15)], // top bar
    [Offset(0.5, 0.15), Offset(0.5, 0.85)], //   centre vertical
    [Offset(0.5, 0.5), Offset(0.82, 0.5)], //    mid-right bar
    [Offset(0.22, 0.5), Offset(0.22, 0.85)], //  lower-left vertical
    [Offset(0.18, 0.85), Offset(0.82, 0.85)], // bottom bar
  ],
  'card': [
    [_tl, _tr], [_tr, _br], [_br, _bl], [_bl, _tl], // box
    [_bl, _tr], // closing diagonal slash
  ],
  'five': [
    [Offset(0.28, 0.15), Offset(0.72, 0.15)], // top bar
    [Offset(0.28, 0.15), Offset(0.28, 0.5)], //  upper-left vertical
    [Offset(0.28, 0.5), Offset(0.72, 0.5)], //   middle bar
    [Offset(0.72, 0.5), Offset(0.72, 0.85)], //  lower-right vertical
    [Offset(0.28, 0.85), Offset(0.72, 0.85)], // bottom bar
  ],
};

// Dot-dash also has four corner dots.
const _dots = {'dot-dash': [_tl, _tr, _br, _bl]};

class _TallyGlyphPainter extends CustomPainter {
  _TallyGlyphPainter(this.slug);

  final String slug;

  static const _ink = Color(0xFF1B2A4A);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset scale(Offset o) => Offset(o.dx * size.width, o.dy * size.height);

    final linePaint = Paint()
      ..color = _ink
      ..strokeWidth = s * 0.06
      ..strokeCap = StrokeCap.round;

    for (final seg in _strokes[slug] ?? const []) {
      canvas.drawLine(scale(seg[0]), scale(seg[1]), linePaint);
    }
    final dotPaint = Paint()..color = _ink;
    for (final dot in _dots[slug] ?? const []) {
      canvas.drawCircle(scale(dot), s * 0.055, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_TallyGlyphPainter oldDelegate) => oldDelegate.slug != slug;
}
