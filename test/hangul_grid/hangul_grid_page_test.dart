import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cord/hangul_grid/engine/game_canvas.dart';
import 'package:cord/hangul_grid/pages/hangul_grid_page.dart';

/// The Hangul Grid page, ported from `hangul-word`'s
/// `test/syllable_rows_page_test.dart` — the same tests, pumping the page
/// itself instead of tab 3 of that project's tab shell (cord has no tabs, no
/// word list and so no target banner).
///
/// Reading a block is covered exhaustively in `block_recognizer_test.dart`
/// and the square-boundary rule in `square_reading_test.dart`. What matters
/// here is the band: that a square's strokes still land in the square they
/// look like they are in, once every row is a box plus a band tall.

const _columns = 4;
const _readHeight = 54.0;

Future<void> pumpApp(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1000, 3000)
    ..devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });
  await tester.pumpWidget(const MaterialApp(home: HangulGridPage()));
  await tester.pump();
}

double cellSize(WidgetTester tester) =>
    tester.getSize(find.byType(GameCanvas)).width / _columns;

/// The top-left of square [index] — a row is a box *plus a band* tall, which
/// is the whole thing this file is checking.
Offset squareOrigin(WidgetTester tester, int index) {
  final cell = cellSize(tester);
  return tester.getTopLeft(find.byType(GameCanvas)) +
      Offset(
        (index % _columns) * cell,
        (index ~/ _columns) * (cell + _readHeight),
      );
}

Future<void> strokeIn(
  WidgetTester tester,
  int square,
  List<Offset> points,
) async {
  final cell = cellSize(tester);
  final base = squareOrigin(tester, square);
  Offset at(Offset p) => base + Offset(p.dx * cell, p.dy * cell);

  final gesture = await tester.startGesture(at(points.first));
  for (var i = 1; i < points.length; i++) {
    for (var s = 1; s <= 10; s++) {
      await gesture.moveTo(at(Offset.lerp(points[i - 1], points[i], s / 10)!));
    }
  }
  await gesture.up();
  await tester.pump();
}

/// Writes 가 into square [n]: ㄱ top-left, then ㅏ down the right.
Future<void> ga(WidgetTester tester, int n) async {
  await strokeIn(tester, n, const [
    Offset(0.12, 0.18),
    Offset(0.44, 0.18),
    Offset(0.44, 0.62),
  ]);
  await strokeIn(tester, n, const [Offset(0.62, 0.10), Offset(0.62, 0.88)]);
  await strokeIn(tester, n, const [Offset(0.62, 0.37), Offset(0.80, 0.37)]);
}

Finder reading(String text) => find.byWidgetPredicate(
      (w) => w is Text && w.data == text && w.style?.fontSize == 36,
    );

void main() {
  testWidgets('starts empty, explaining itself', (tester) async {
    await pumpApp(tester);
    expect(
      find.text('Write a syllable in each square — the row reads out beneath '
          'it'),
      findsOneWidget,
    );
    expect(
        find.textContaining('reads out on the line under it'), findsOneWidget);
  });

  testWidgets('a syllable in the first square is read', (tester) async {
    await pumpApp(tester);
    await ga(tester, 0);

    expect(reading('가'), findsOneWidget);
    expect(find.text('ga'), findsOneWidget);
  });

  testWidgets('a syllable in the second row lands in the second row',
      (tester) async {
    // The band makes each row taller than a box. If the stroke capture
    // stepped by the box alone, this would land in the band under row one
    // and be filed against the wrong square.
    await pumpApp(tester);
    await ga(tester, _columns);

    expect(reading('가'), findsOneWidget);
  });

  testWidgets('neighbouring squares stay separate syllables', (tester) async {
    await pumpApp(tester);
    await ga(tester, 0);
    await ga(tester, 1);

    // Run together these six letters would be 각아. Squares keep them apart.
    expect(reading('가가'), findsOneWidget);
    expect(find.text('gaga'), findsOneWidget);
  });

  testWidgets('the end of a row runs straight into the next', (tester) async {
    // Reading order carries across the wrap; only an empty square is a
    // space, and there is none between the last of one row and the first of
    // the next.
    await pumpApp(tester);
    await ga(tester, _columns - 1);
    await ga(tester, _columns);

    expect(reading('가가'), findsOneWidget);
  });

  testWidgets('an empty square between two is a space', (tester) async {
    await pumpApp(tester);
    await ga(tester, 0);
    await ga(tester, 2);

    expect(reading('가 가'), findsOneWidget);
    expect(find.text('ga ga'), findsOneWidget);
  });

  testWidgets('the squares do not move when the reading appears',
      (tester) async {
    await pumpApp(tester);
    final before = tester.getTopLeft(find.byType(GameCanvas)).dy;

    await ga(tester, 0);
    expect(reading('가'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(GameCanvas)).dy, before);
  });

  testWidgets('clear page empties everything', (tester) async {
    await pumpApp(tester);
    await ga(tester, 0);
    expect(reading('가'), findsOneWidget);

    await tester.tap(find.text('Clear page'));
    await tester.pump();
    expect(
      find.text('Write a syllable in each square — the row reads out beneath '
          'it'),
      findsOneWidget,
    );
  });
}
