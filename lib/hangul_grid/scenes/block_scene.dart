/// Squares you write whole syllables into, the way Hangul is actually
/// written — the consonant, the vowel beside or beneath it, and any final
/// letter along the bottom, all inside one block.
///
/// Stroke capture is [WordGridLayer], shared with the one-letter-per-box
/// canvas: a stroke joins whichever square its centre lands in, and the
/// squares are read left to right and then down a row. What differs is what
/// happens to a square's strokes afterwards — here they go to
/// `recognizeBlock`, which has to work out where the letters are inside the
/// square before it can say what they are.
library;

import 'package:flutter/material.dart';

import '../engine/scene.dart';
import '../palette.dart';
import 'grid_scene.dart';

/// What one square was read as: the syllable, and how it sounds.
typedef SquareReading = ({String? text, String? roman});

/// Draws the squares, a guide inside each, and the syllable each was read as.
class BlockPaperLayer extends Layer {
  BlockPaperLayer({
    required this.columns,
    required this.rows,
    this.readHeight = 0,
  });

  final int columns;
  final int rows;

  /// Height of a band under each row for the readings.
  ///
  /// Zero tucks each square's reading into its own bottom-right corner,
  /// small and out of the way. A positive value puts a band of that height
  /// under the row instead and sets the readings out along it, under the
  /// square each came from — larger, and readable as a line of text rather
  /// than as eight separate annotations.
  final double readHeight;

  /// Per square, filled in by the page after each change.
  ///
  /// [SquareReading.roman] is only drawn in the banded layout — the corner
  /// has no room for it, and a syllable's sound is the thing a reader who
  /// cannot yet read Hangul actually needs.
  List<CellState> states = const [];
  List<SquareReading> readings = const [];

  int? active;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kPaper);

    final cell = size.width / columns;
    final rule = Paint()
      ..color = kInk.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // A cross through the middle of each square. Hangul sets its parts
    // against these halves — onset left of the vertical, vowel right of it;
    // onset above the horizontal, final below — so the guide is the layout
    // rules drawn out.
    //
    // Dashed, and much fainter than the square's own edge: a solid cross at
    // the same weight reads as four smaller squares, which is the opposite
    // of the point.
    final guide = Paint()
      ..color = kInk.withValues(alpha: 0.16)
      ..strokeWidth = 1;

    final pitch = cell + readHeight;

    for (var i = 0; i < columns * rows; i++) {
      final rect = Rect.fromLTWH(
        (i % columns) * cell,
        (i ~/ columns) * pitch,
        cell,
        cell,
      );

      if (i == active) {
        canvas.drawRect(
          rect,
          Paint()..color = kPenColor.withValues(alpha: 0.05),
        );
      }
      _dashed(canvas, rect.centerLeft, rect.centerRight, guide);
      _dashed(canvas, rect.topCenter, rect.bottomCenter, guide);
      canvas.drawRect(rect.deflate(0.5), rule);

      final state = i < states.length ? states[i] : CellState.empty;
      if (state == CellState.empty) continue;
      _drawReading(
        canvas,
        rect,
        i < readings.length ? readings[i] : (text: null, roman: null),
      );
    }
  }

  /// A dashed line from [a] to [b]. Six on, six off, which at any square
  /// size reads as a guide rather than an edge.
  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 6.0;
    const gap = 6.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final step = (b - a) / total;
    for (var at = 0.0; at < total; at += dash + gap) {
      final end = at + dash < total ? at + dash : total;
      canvas.drawLine(a + step * at, a + step * end, paint);
    }
  }

  void _drawReading(Canvas canvas, Rect rect, SquareReading reading) {
    final banded = readHeight > 0;
    final syllable = reading.text;

    final label = _painter(
      syllable ?? '?',
      size: banded ? 22 : 15,
      family: syllable == null ? null : kHangulFont,
      color: syllable == null
          ? kPenColor.withValues(alpha: 0.7)
          : kStartColor.withValues(alpha: banded ? 0.9 : 0.85),
    );

    if (!banded) {
      label.paint(
        canvas,
        Offset(rect.right - label.width - 6, rect.bottom - label.height - 4),
      );
      return;
    }

    // The sound, under the syllable, for a reader who cannot yet read the
    // syllable. Latin script has no business at the same weight as the
    // Hangul, so it goes smaller and greyer — a gloss, not the answer.
    final roman = reading.roman;
    final gloss = roman == null || roman.trim().isEmpty
        ? null
        : _painter(
            roman.trim(),
            size: 12,
            color: kInk.withValues(alpha: 0.5),
            weight: FontWeight.w400,
          );

    final stack = label.height + (gloss == null ? 0 : gloss.height + 1);
    final top = rect.bottom + (readHeight - stack) / 2;

    // Both centred under the square they came from, so the row of readings
    // lines up with the row of writing above it.
    label.paint(canvas, Offset(rect.center.dx - label.width / 2, top));
    gloss?.paint(
      canvas,
      Offset(rect.center.dx - gloss.width / 2, top + label.height + 1),
    );
  }

  TextPainter _painter(
    String text, {
    required double size,
    required Color color,
    String? family,
    FontWeight weight = FontWeight.w600,
  }) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: family,
            fontSize: size,
            fontWeight: weight,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
}

/// Builds the block scene plus direct references to both its layers.
(Scene, BlockPaperLayer, WordGridLayer) buildBlockScene({
  required int columns,
  required int rows,
  double readHeight = 0,
  void Function()? onChanged,
}) {
  final paper = BlockPaperLayer(
    columns: columns,
    rows: rows,
    readHeight: readHeight,
  );
  final grid = WordGridLayer(
    columns: columns,
    rows: rows,
    // The rows have to step by the same amount the paper draws them at, or
    // a stroke would land in a different square than the one it looks like.
    rowGap: readHeight,
    onChanged: (_) => onChanged?.call(),
  )..onActiveCell = (cell) => paper.active = cell;
  return (Scene([paper, grid]), paper, grid);
}
