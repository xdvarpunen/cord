/// Squares you write whole Han characters into, the way a CJK exercise book
/// rules them — one character per square, sized and centred against a 米 of
/// faint guides.
///
/// Stroke capture is [WordGridLayer]. What differs from square to square is
/// only what happens to those strokes afterwards: here they go to
/// `recognizeCharacter`, which compares the whole square against every glyph
/// in the bundled table with the same number of strokes.
library;

import 'package:flutter/material.dart';

import '../engine/scene.dart';
import '../palette.dart';
import 'grid_scene.dart';

/// What one square was read as: the character, how it is said, what it means,
/// and how sure the reading is.
///
/// The English is the point of the band rather than an extra on it. A row of
/// Han characters read back to you is no help if you cannot read Han yet —
/// which is exactly who is practising writing it.
///
/// [confidence] runs 0..1 and is null when nothing was read. It is on the band
/// because the alternative is a page that states a character flatly and gives
/// you no way to tell a clean match from a lucky one — and the recognizer
/// accepts anything inside its cutoff, which reaches down to about a tenth.
typedef SquareReading = ({
  String? char,
  String? reading,
  String? meaning,
  double? confidence,
});

/// Draws the squares, the 米 guide inside each, and what each was read as.
class HanziPaperLayer extends Layer {
  HanziPaperLayer({
    required this.columns,
    required this.rows,
    this.readHeight = 0,
  });

  final int columns;
  final int rows;

  /// Height of a band under each row for the readings.
  ///
  /// Zero tucks each square's reading into its own bottom-right corner, small
  /// and out of the way. A positive value puts a band of that height under the
  /// row instead and sets the readings out along it, under the square each
  /// came from — larger, and readable as a line of text rather than as eight
  /// separate annotations.
  final double readHeight;

  /// Per square, filled in by the page after each change.
  ///
  /// The reading and the meaning are only drawn in the banded layout — the
  /// corner has no room for them, and they are the whole reason for the band.
  List<CellState> states = const [];
  List<SquareReading> readings = const [];

  int? active;

  /// The 米 guide. Fainter than anything else on the page: it is there to be
  /// written over, and a guide at the square's own weight reads as part of the
  /// character.
  static const _guideColor = Color(0x22000000);

  /// The guide box, as a fraction of the square. Upstream's proportion — the
  /// margin is what stops a character being written edge to edge, which is the
  /// single most common thing beginners get wrong.
  static const _guideInset = 0.72;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kPaper);

    final cell = size.width / columns;
    final rule = Paint()
      ..color = kInk.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final guide = Paint()
      ..color = _guideColor
      ..style = PaintingStyle.stroke
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
      _guide(canvas, rect, guide);
      canvas.drawRect(rect.deflate(0.5), rule);

      final state = i < states.length ? states[i] : CellState.empty;
      if (state == CellState.empty) continue;
      _drawReading(
        canvas,
        rect,
        i < readings.length
            ? readings[i]
            : (char: null, reading: null, meaning: null, confidence: null),
      );
    }
  }

  /// The 米 inside one square: a box a little in from the edges, halved both
  /// ways and crossed corner to corner. Eight guides in all, which is what the
  /// character 米 is — hence the name of the paper.
  void _guide(Canvas canvas, Rect rect, Paint paint) {
    final side = rect.shortestSide * _guideInset;
    final box = Rect.fromCenter(
      center: rect.center,
      width: side,
      height: side,
    );
    canvas.drawRect(box, paint);
    canvas.drawLine(box.centerLeft, box.centerRight, paint);
    canvas.drawLine(box.topCenter, box.bottomCenter, paint);
    canvas.drawLine(box.topLeft, box.bottomRight, paint);
    canvas.drawLine(box.topRight, box.bottomLeft, paint);
  }

  void _drawReading(Canvas canvas, Rect rect, SquareReading reading) {
    final banded = readHeight > 0;
    final char = reading.char;

    final label = _painter(
      char ?? '?',
      size: banded ? 22 : 15,
      family: char == null ? null : kHanziFont,
      color: char == null
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

    // How it is said, then what it means, each smaller and greyer than the one
    // above it. The order is deliberate: the character is the answer, the
    // reading is how to say the answer, the meaning is how to check it — and
    // Latin script has no business at the same weight as the Han.
    final said = reading.reading == null
        ? null
        : _painter(
            reading.reading!,
            size: 12.5,
            color: kInk.withValues(alpha: 0.62),
            weight: FontWeight.w500,
          );
    final means = reading.meaning == null
        ? null
        : _painter(
            reading.meaning!,
            size: 11,
            color: kInk.withValues(alpha: 0.45),
            weight: FontWeight.w400,
            maxWidth: rect.width - 4,
          );

    final confidence = reading.confidence;
    final percent = confidence == null
        ? null
        : _painter(
            '${(confidence * 100).round()}%',
            size: 9.5,
            color: kInk.withValues(alpha: 0.5),
            weight: FontWeight.w600,
          );

    var stack = label.height;
    if (said != null) stack += said.height + 1;
    if (means != null) stack += means.height + 1;
    if (percent != null) stack += percent.height + 3;
    var top = rect.bottom + (readHeight - stack) / 2;

    // All centred under the square they came from, so the row of readings
    // lines up with the row of writing above it.
    for (final line in [label, said, means]) {
      if (line == null) continue;
      line.paint(canvas, Offset(rect.center.dx - line.width / 2, top));
      top += line.height + 1;
    }
    if (percent != null && confidence != null) {
      _confidence(canvas, rect, top + 2, confidence, percent);
    }
  }

  /// How sure the reading is: a short bar and the number beside it.
  ///
  /// A bar because the number alone is read as a verdict — 41% and 91% look
  /// alike at 9pt, and only one of them means "this is what you wrote". The
  /// bar is the same teal as a settled reading while it is convincing and
  /// turns vermilion once it is not, so a doubtful square is visible from
  /// across the grid without reading anything.
  void _confidence(
    Canvas canvas,
    Rect rect,
    double top,
    double confidence,
    TextPainter percent,
  ) {
    const barWidth = 40.0;
    const gap = 5.0;
    const height = 3.0;

    final total = barWidth + gap + percent.width;
    final left = rect.center.dx - total / 2;
    final middle = top + percent.height / 2;
    final tint = confidence >= _convincing ? kStartColor : kPenColor;

    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, middle - height / 2, barWidth, height),
      const Radius.circular(height / 2),
    );
    canvas.drawRRect(track, Paint()..color = kInk.withValues(alpha: 0.10));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left,
          middle - height / 2,
          // Always a sliver, so a very low score reads as "barely" rather
          // than as an empty track that looks like missing data.
          (barWidth * confidence).clamp(2.0, barWidth),
          height,
        ),
        const Radius.circular(height / 2),
      ),
      Paint()..color = tint.withValues(alpha: 0.75),
    );
    percent.paint(canvas, Offset(left + barWidth + gap, top));
  }

  /// Above this the reading is worth trusting; below it the bar warns.
  ///
  /// Two thirds, chosen against what the numbers actually do: tracing a stored
  /// glyph exactly scores near 100%, a genuine but shaky hand lands in the
  /// seventies and eighties, and the recognizer's own cutoff still admits
  /// matches down near 10%. The line belongs where "recognized" stops meaning
  /// "recognized well".
  static const double _convincing = 0.66;

  TextPainter _painter(
    String text, {
    required double size,
    required Color color,
    String? family,
    FontWeight weight = FontWeight.w600,
    double? maxWidth,
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
        maxLines: 1,
        // A long meaning is clipped rather than wrapped: a second line would
        // push the band out of the height the page laid out for it, and the
        // English in full is on the line at the top of the page anyway.
        ellipsis: '…',
      )..layout(maxWidth: maxWidth ?? double.infinity);
}

/// Builds the grid scene plus direct references to both its layers.
(Scene, HanziPaperLayer, WordGridLayer) buildHanziGridScene({
  required int columns,
  required int rows,
  double readHeight = 0,
  void Function()? onChanged,
}) {
  final paper = HanziPaperLayer(
    columns: columns,
    rows: rows,
    readHeight: readHeight,
  );
  final grid = WordGridLayer(
    columns: columns,
    rows: rows,
    // The rows have to step by the same amount the paper draws them at, or a
    // stroke would land in a different square than the one it looks like.
    rowGap: readHeight,
    onChanged: onChanged,
  )..onActiveCell = (cell) => paper.active = cell;
  return (Scene([paper, grid]), paper, grid);
}
