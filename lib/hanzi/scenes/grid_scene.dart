/// A ruled grid you write into, one whole character per square.
///
/// Where a single-character canvas asks *what did you draw*, this one asks
/// *what did you draw, and where* — position is half the input. A stroke joins
/// whichever square its centre lands in, squares are read left to right and
/// then down a row, and a square left empty between two written ones is a
/// space. Nothing has to be committed or timed: the line is simply whatever is
/// on the page.
///
/// Stroke capture only. What a square's strokes mean is the page's business,
/// and `recognizeCharacter` normalises them itself — against the bounding box
/// of the whole character, so where the square sits on the canvas and how
/// large it was drawn make no difference. That is why this hands back
/// [localCells] at their drawn size and nothing else: there is no reference
/// box to scale into.
library;

import 'package:flutter/material.dart';

import '../engine/scene.dart';
import '../palette.dart';

/// What a square currently holds.
enum CellState {
  /// Nothing drawn. Between two written squares this reads as a space.
  empty,

  /// Strokes that came out as a character in the table.
  recognized,

  /// Strokes that match nothing. Skipped when reading the line, and marked so
  /// you can see which square to redraw.
  unknown,
}

/// One captured stroke, and the square it landed in.
typedef _GridStroke = ({int cell, List<Offset> points});

/// Captures strokes and files each one under the square it was drawn in.
class WordGridLayer extends Layer {
  WordGridLayer({
    required this.columns,
    required this.rows,
    this.rowGap = 0,
    this.onChanged,
  });

  final int columns;
  final int rows;

  /// Extra vertical space after each row of squares.
  ///
  /// Zero means the rows sit directly on each other. A page that puts a band
  /// under each row — to show what the row was read as — passes that band's
  /// height, so a stroke drawn in the band still belongs to the row above it.
  ///
  /// A gap rather than a pitch because the square size is not known until the
  /// canvas is laid out: the pitch is the square plus this.
  final double rowGap;

  /// Called after every change. The page reads [localCells] itself rather than
  /// being handed them, since it also wants [cellSize].
  final void Function()? onChanged;

  /// Called as the pen moves between squares, so the paper can highlight the
  /// one being written in.
  void Function(int? cell)? onActiveCell;

  final List<_GridStroke> _strokes = [];
  List<Offset>? _active;

  /// The last canvas size seen. Both pointer handling and painting supply
  /// one; recognition needs it after the fact, and the canvas does not resize
  /// between a stroke and its reading.
  Size? _size;

  int get cellCount => columns * rows;

  /// A mark smaller than this fraction of a square is a slip, not a stroke.
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
        // The square is decided once, at pen-up, from where the whole mark
        // sits — never split mid-stroke. A 捺 that runs slightly over a rule
        // still belongs to the square it was aimed at.
        _strokes.add((cell: _cellOf(points, size), points: points));
        _notify();
      }
    }
  }

  /// Strokes grouped by square, in canvas coordinates.
  List<List<List<Offset>>> get cells {
    final out = List.generate(cellCount, (_) => <List<Offset>>[]);
    for (final stroke in _strokes) {
      out[stroke.cell].add(stroke.points);
    }
    return out;
  }

  /// Strokes grouped by square, in coordinates local to their own square and
  /// at their drawn size.
  ///
  /// This is what the recognizer wants: it scales and centres a character
  /// against its own bounding box, so it needs the strokes as drawn and in
  /// one consistent frame — not stretched into a reference box, which would
  /// change the proportions it measures.
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

  /// The side of one square, or null before the canvas has been laid out.
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

  void _notify() => onChanged?.call();

  int _cellOf(List<Offset> points, Size size) {
    final cell = size.width / columns;
    final bounds = _boundsOf(points);
    final col = (bounds.center.dx / cell).floor().clamp(0, columns - 1);
    final row = (bounds.center.dy / _pitch(cell)).floor().clamp(0, rows - 1);
    return row * columns + col;
  }

  /// The vertical step between rows: the square plus whatever sits under it.
  double _pitch(double cell) => cell + rowGap;

  /// The top-left of a square, in canvas coordinates.
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
