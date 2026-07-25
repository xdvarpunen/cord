/// A ruled grid you write a whole word into, one letter per box.
///
/// Where the single-letter canvas asks *what did you draw*, this one asks
/// *what did you draw, and where* — position is the whole input. A stroke
/// joins whichever box its centre lands in, boxes are read left to right and
/// then down a row, and a box you leave empty between two words is a space.
/// Nothing has to be committed or timed: the word is simply whatever is on
/// the page.
///
/// Each box is recognized by the same classifiers as the single-letter
/// canvas. They are tuned for absolute pixel distances at
/// [kRecognitionBox] size, so a box's strokes are scaled into a box that
/// size before being asked — see [normalizedCells]. That is also why the
/// boxes are kept square: a non-uniform scale would stretch a ㅁ into a ㅂ's
/// proportions and the ratio tests would disagree with what you drew.
library;

import 'package:flutter/material.dart';

import '../engine/scene.dart';
import '../palette.dart';
import 'jamo_scene.dart';

/// What a box currently holds.
enum CellState {
  /// Nothing drawn. Between two written boxes this reads as a space.
  empty,

  /// Strokes that classify as a letter.
  recognized,

  /// Strokes that match nothing. Skipped when reading the word, and marked
  /// so you can see which box to redraw.
  unknown,
}

/// One captured stroke, and the box it landed in.
typedef _GridStroke = ({int cell, List<Offset> points});

/// Draws the ruled boxes and, once the page has recognized them, what each
/// one was read as.
class GridPaperLayer extends Layer {
  GridPaperLayer({required this.columns, required this.rows});

  final int columns;
  final int rows;

  /// Per box, filled in by the page after each change.
  List<CellState> states = const [];
  List<String?> glyphs = const [];

  /// The box the pen is currently in, if any.
  int? active;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kPaper);

    final cell = size.width / columns;
    final rule = Paint()
      ..color = kInk.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < columns * rows; i++) {
      final rect = _cellRect(i, cell);

      if (i == active) {
        canvas.drawRect(
          rect,
          Paint()..color = kPenColor.withValues(alpha: 0.05),
        );
      }
      canvas.drawRect(rect.deflate(0.5), rule);

      final state = i < states.length ? states[i] : CellState.empty;
      if (state == CellState.empty) continue;

      final glyph = i < glyphs.length ? glyphs[i] : null;
      _drawReading(canvas, rect, glyph);
    }
  }

  /// The letter a box was read as, tucked into its bottom-right corner —
  /// small enough not to compete with the writing, close enough to check
  /// without looking away.
  void _drawReading(Canvas canvas, Rect rect, String? glyph) {
    final label = TextPainter(
      text: TextSpan(
        text: glyph ?? '?',
        style: TextStyle(
          fontFamily: glyph == null ? null : kHangulFont,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: glyph == null
              ? kPenColor.withValues(alpha: 0.7)
              : kStartColor.withValues(alpha: 0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(rect.right - label.width - 5, rect.bottom - label.height - 3),
    );
  }

  Rect _cellRect(int index, double cell) => Rect.fromLTWH(
        (index % columns) * cell,
        (index ~/ columns) * cell,
        cell,
        cell,
      );
}

/// Captures strokes and files each one under the box it was drawn in.
class WordGridLayer extends Layer {
  WordGridLayer({
    required this.columns,
    required this.rows,
    this.rowGap = 0,
    this.onChanged,
  });

  final int columns;
  final int rows;

  /// Extra vertical space after each row of boxes.
  ///
  /// Zero means the rows sit directly on each other, which is what both grid
  /// canvases want. A page that puts a band under each row — to show what
  /// the row was read as — passes that band's height, so a stroke drawn in
  /// the band still belongs to the row above it.
  ///
  /// A gap rather than a pitch because the box size is not known until the
  /// canvas is laid out: the pitch is the box plus this.
  final double rowGap;

  /// Called after every change with the boxes' strokes, already scaled into
  /// the recognizer's reference box.
  final void Function(List<List<List<Offset>>> cells)? onChanged;

  /// Called as the pen moves between boxes, so the paper can highlight the
  /// one being written in.
  void Function(int? cell)? onActiveCell;

  final List<_GridStroke> _strokes = [];
  List<Offset>? _active;

  /// The last canvas size seen. Both pointer handling and painting supply
  /// one; recognition needs it after the fact, and the canvas does not
  /// resize between a stroke and its reading.
  Size? _size;

  int get cellCount => columns * rows;

  /// A mark smaller than this fraction of a box is a slip, not a stroke.
  static const _minimumExtentRatio = 0.06;

  /// Points the pen barely moved to add nothing but noise to the shape.
  static const _minPointSpacing = 1.5;

  @override
  void handlePointerEvent(PointerEvent event, Size size) {
    _size = size;
    if (event is PointerDownEvent) {
      _active = [event.localPosition];
      onActiveCell?.call(_cellOf([event.localPosition], size));
    } else if (event is PointerMoveEvent && _active != null) {
      if ((event.localPosition - _active!.last).distance >= _minPointSpacing) {
        _active!.add(event.localPosition);
      }
    } else if (event is PointerUpEvent && _active != null) {
      final points = _active!;
      _active = null;
      onActiveCell?.call(null);
      final cell = size.width / columns;
      if (points.length >= 2 &&
          _extentOf(points) >= cell * _minimumExtentRatio) {
        // The box is decided once, at pen-up, from where the whole mark sits
        // — never split mid-stroke. A letter drawn slightly over a rule
        // still belongs to the box it was aimed at.
        _strokes.add((cell: _cellOf(points, size), points: points));
        _notify();
      }
    }
  }

  /// Strokes grouped by box, in canvas coordinates.
  List<List<List<Offset>>> get cells {
    final out = List.generate(cellCount, (_) => <List<Offset>>[]);
    for (final stroke in _strokes) {
      out[stroke.cell].add(stroke.points);
    }
    return out;
  }

  /// The same, scaled so each box fills a [kRecognitionBox]-sized square.
  ///
  /// This is what makes one set of pixel-tuned classifiers work at any box
  /// size: a letter drawn in a 90px box arrives at the classifiers as the
  /// same shape it would have been in the full-size single-letter canvas.
  List<List<List<Offset>>> get normalizedCells {
    final size = _size;
    if (size == null) return List.generate(cellCount, (_) => <List<Offset>>[]);

    final cell = size.width / columns;
    final scale = kRecognitionBox / cell;
    final out = List.generate(cellCount, (_) => <List<Offset>>[]);
    for (final stroke in _strokes) {
      final origin = _originOf(stroke.cell, cell);
      out[stroke.cell].add([
        for (final p in stroke.points) (p - origin) * scale,
      ]);
    }
    return out;
  }

  /// Strokes grouped by box, in coordinates local to their own box and at
  /// their drawn size.
  ///
  /// This is what a reader that does its own scaling wants — the block
  /// recognizer scales each *piece* of a syllable rather than the box as a
  /// whole, so it needs the strokes as drawn, next to [cellSize].
  List<List<List<Offset>>> get localCells {
    final size = _size;
    if (size == null) return List.generate(cellCount, (_) => <List<Offset>>[]);
    final cell = size.width / columns;
    final out = List.generate(cellCount, (_) => <List<Offset>>[]);
    for (final stroke in _strokes) {
      final origin = _originOf(stroke.cell, cell);
      out[stroke.cell].add([for (final p in stroke.points) p - origin]);
    }
    return out;
  }

  /// The side of one box, or null before the canvas has been laid out.
  double? get cellSize {
    final size = _size;
    return size == null ? null : size.width / columns;
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _strokes.removeLast();
    _notify();
  }

  void clear() {
    if (_strokes.isEmpty && _active == null) return;
    _strokes.clear();
    _active = null;
    _notify();
  }

  void clearCell(int cell) {
    _strokes.removeWhere((s) => s.cell == cell);
    _notify();
  }

  void _notify() => onChanged?.call(normalizedCells);

  int _cellOf(List<Offset> points, Size size) {
    final cell = size.width / columns;
    final bounds = _boundsOf(points);
    final col = (bounds.center.dx / cell).floor().clamp(0, columns - 1);
    final row = (bounds.center.dy / _pitch(cell)).floor().clamp(0, rows - 1);
    return row * columns + col;
  }

  /// The vertical step between rows: the box size plus whatever sits under
  /// it.
  double _pitch(double cell) => cell + rowGap;

  /// The top-left of a box, in canvas coordinates.
  Offset _originOf(int index, double cell) => Offset(
        (index % columns) * cell,
        (index ~/ columns) * _pitch(cell),
      );

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    final paint = Paint()
      ..color = kInk
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in _strokes) {
      _drawPath(canvas, stroke.points, paint);
    }
    if (_active != null) {
      _drawPath(
        canvas,
        _active!,
        Paint()
          ..color = kInk.withValues(alpha: 0.5)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], paint);
    }
  }
}

double _extentOf(List<Offset> points) {
  final b = _boundsOf(points);
  return b.width > b.height ? b.width : b.height;
}

Rect _boundsOf(List<Offset> points) {
  var minX = points.first.dx, maxX = minX;
  var minY = points.first.dy, maxY = minY;
  for (final p in points) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Builds the grid scene plus direct references to both its layers.
(Scene, GridPaperLayer, WordGridLayer) buildWordGridScene({
  required int columns,
  required int rows,
  void Function(List<List<List<Offset>>> cells)? onChanged,
}) {
  final paper = GridPaperLayer(columns: columns, rows: rows);
  final grid = WordGridLayer(
    columns: columns,
    rows: rows,
    onChanged: onChanged,
  )..onActiveCell = (cell) => paper.active = cell;
  return (Scene([paper, grid]), paper, grid);
}
