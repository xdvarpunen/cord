import 'package:cord/hanzi/scenes/grid_scene.dart';
import 'package:cord/hanzi/scenes/hanzi_grid_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which square a stroke belongs to.
///
/// The grid is one canvas, so this is decided from where a mark landed rather
/// than from which widget received it — upstream `hanzi`'s
/// `test/order_slip_page_test.dart` makes the same point about its one-row
/// slip. What is new here is the second dimension: rows are a square *plus a
/// reading band* apart, and getting that pitch wrong files a stroke against a
/// square other than the one it looks like it is in.

const _columns = 4;
const _rows = 2;
const _rowGap = 54.0;

/// Four 100-wide squares across, two rows 154 apart.
const _size = Size(400, 308);

WordGridLayer layer() =>
    WordGridLayer(columns: _columns, rows: _rows, rowGap: _rowGap);

List<Offset> horizontal(double from, double to, double y) =>
    [for (var x = from; x <= to; x += 5) Offset(x, y)];

void draw(WordGridLayer layer, List<Offset> points) {
  layer.handlePointerEvent(PointerDownEvent(position: points.first), _size);
  for (final p in points.skip(1)) {
    layer.handlePointerEvent(PointerMoveEvent(position: p), _size);
  }
  layer.handlePointerEvent(PointerUpEvent(position: points.last), _size);
}

/// The square one stroke lands in, or -1 if it was discarded.
int squareOf(List<Offset> points) {
  final live = layer();
  draw(live, points);
  return live.cells.indexWhere((c) => c.isNotEmpty);
}

void main() {
  group('stroke-to-square assignment', () {
    test('a stroke sits in the square containing its middle', () {
      expect(squareOf(horizontal(10, 90, 50)), 0);
      expect(squareOf(horizontal(110, 190, 50)), 1);
      expect(squareOf(horizontal(310, 390, 50)), 3);
      expect(squareOf(horizontal(110, 190, 200)), 5);
    });

    test('a stroke that overruns into the next square stays in one square', () {
      // Starts well inside square 1 and spills over the rule at x = 200.
      expect(squareOf(horizontal(120, 230, 50)), 1,
          reason: 'splitting it would hand square 2 a fragment of a character');
    });

    test('a stroke drawn in the reading band belongs to the row above it', () {
      // y = 120 is under the first row's squares but inside its band. Rows
      // step by square + band = 154, so this is still row 0; stepping by the
      // square alone would put it in row 1.
      expect(squareOf(horizontal(10, 90, 120)), 0);
      expect(squareOf(horizontal(210, 290, 120)), 2);
    });

    test('a stroke off the end is clamped rather than thrown away', () {
      expect(squareOf(horizontal(390, 460, 50)), 3);
      expect(squareOf(horizontal(-40, -10, 50)), 0);
      expect(squareOf(horizontal(10, 90, 400)), 4);
    });

    test('a mark too small to be a stroke is ignored', () {
      // Under 6% of a 100-wide square. A tap that slipped, not a 点.
      expect(squareOf(const [Offset(50, 50), Offset(52, 51)]), -1);
    });
  });

  group('what the page reads back', () {
    test('squares keep their strokes in the order they were drawn', () {
      final live = layer();
      // Second square first, then two in the first.
      draw(live, horizontal(220, 380, 30));
      draw(live, horizontal(20, 170, 30));
      draw(live, horizontal(20, 170, 70));

      final cells = live.cells;
      expect(cells.length, _columns * _rows);
      expect(cells[0].length, 2);
      expect(cells[3].length, 1);
      expect(cells[0].first.first.dy, 30, reason: 'drawn order is preserved');
      expect(cells[0].last.first.dy, 70);
    });

    test('undo pops the genuinely last stroke, whichever square it is in', () {
      final live = layer();
      draw(live, horizontal(20, 80, 30));
      draw(live, horizontal(120, 180, 30));

      live.undo();
      expect(live.cells[0].length, 1);
      expect(live.cells[1], isEmpty);
    });

    test('clear empties every square', () {
      final live = layer();
      draw(live, horizontal(20, 80, 30));
      draw(live, horizontal(120, 180, 200));
      live.clear();
      expect(live.cells.every((c) => c.isEmpty), isTrue);
    });

    test('the paper and the capture step their rows by the same amount', () {
      // The one place these two can disagree. The paper draws row *r* at
      // r * (square + band); the capture divides by its own row pitch. Wire
      // one and not the other and every stroke below the first row is filed
      // against a square other than the one it was written in — which is
      // invisible until you write in the second row.
      final built = buildHanziGridScene(
        columns: _columns,
        rows: _rows,
        readHeight: _rowGap,
      );
      expect(built.$2.readHeight, _rowGap);
      expect(built.$3.rowGap, built.$2.readHeight);

      // And the pen tells the paper which square it is in.
      built.$3.handlePointerEvent(
        const PointerDownEvent(position: Offset(150, 200)),
        _size,
      );
      expect(built.$2.active, 5);
    });

    test('a square hands back its strokes in its own coordinates', () {
      // The recognizer scales and centres a character against its own bounding
      // box, so it wants one square's strokes in one frame — not spread across
      // the canvas, where a square's position would leak into the comparison.
      final live = layer();
      draw(live, horizontal(120, 180, 200)); // square 5: row 1, column 1

      final local = live.localCells[5].single;
      expect(local.first, const Offset(20, 46),
          reason: 'square 5 starts at (100, 154)');
      expect(live.cellSize, 100);
    });
  });
}
