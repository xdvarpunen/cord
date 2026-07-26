import 'package:cord/hanzi/data/hanzi_strokes.dart';
import 'package:cord/hanzi/engine/game_canvas.dart';
import 'package:cord/hanzi/pages/hanzi_grid_page.dart';
import 'package:cord/hanzi/svg/path_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Hanzi Grid page.
///
/// Reading a square is covered against the whole table in
/// `character_recognizer_test.dart`, and which square a stroke lands in by
/// `grid_scene_test.dart`. What matters here is the two of them meeting: that
/// a character traced into a square comes back on the line at the top of the
/// page, from the square it was written in, without the writing surface moving
/// out from under the pen when it does.

const _columns = 4;
const _readHeight = 88.0;

/// Runs an animation out by hand.
///
/// `pumpAndSettle` cannot be used anywhere on this page: [GameCanvas] drives a
/// `Ticker` that never stops, so there is always another frame pending and
/// settling times out rather than finishing. Fixed pumps are the only way past
/// a route or menu transition here.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> pumpApp(WidgetTester tester) =>
    pumpAppWith(tester, const HanziGridPage());

Future<void> pumpAppWith(WidgetTester tester, HanziGridPage page) async {
  tester.view
    ..physicalSize = const Size(1000, 3000)
    ..devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump();
}

/// Traces a stored glyph into one square, centred and at two thirds of the
/// square — roughly where the 米 guide asks for it.
Future<void> traceInto(
  WidgetTester tester,
  String glyphKey,
  int square, {
  List<int>? order,
}) async {
  final canvas = tester.getRect(find.byType(GameCanvas));
  final cell = canvas.width / _columns;
  final box = Rect.fromLTWH(
    canvas.left + (square % _columns) * cell,
    canvas.top + (square ~/ _columns) * (cell + _readHeight),
    cell,
    cell,
  );

  final glyph = strokeGlyphs[glyphKey]!;
  final indices = order ?? [for (var i = 0; i < glyph.medians.length; i++) i];
  final side = box.shortestSide * 0.66;
  final origin = box.center - Offset(side / 2, side / 2);
  Offset place(Offset p) => origin + p / kStrokeViewBox * side;

  for (final i in indices) {
    final median =
        medianToScreen(glyph.source, glyph.medians[i]).map(place).toList();
    // Densified so the capture's minimum point spacing accepts every segment
    // — a median is a handful of corners, not a hand-drawn stroke.
    final dense = <Offset>[median.first];
    for (var k = 0; k + 1 < median.length; k++) {
      final steps =
          ((median[k + 1] - median[k]).distance / 3).ceil().clamp(1, 40);
      for (var s = 1; s <= steps; s++) {
        dense.add(Offset.lerp(median[k], median[k + 1], s / steps)!);
      }
    }
    final gesture = await tester.startGesture(dense.first);
    for (final p in dense.skip(1)) {
      await gesture.moveTo(p);
    }
    await gesture.up();
    await tester.pump();
  }
}

/// The line of characters at the top of the page.
Finder line(String text) => find.byWidgetPredicate(
      (w) => w is Text && w.data == text && w.style?.fontSize == 36,
    );

/// How that line is said — the pinyin under it.
Finder said(String text) => find.byWidgetPredicate(
      (w) => w is Text && w.data == text && w.style?.fontSize == 17,
    );

/// What it means — the English under that.
Finder means(String text) => find.byWidgetPredicate(
      (w) => w is Text && w.data == text && w.style?.fontSize == 13,
    );

const _empty = 'Write a character in each square — the row reads out beneath '
    'it';

void main() {
  testWidgets('starts empty, explaining itself', (tester) async {
    await pumpApp(tester);
    expect(find.text(_empty), findsOneWidget);
    expect(
      find.textContaining('reads out on the line under it'),
      findsOneWidget,
    );
  });

  testWidgets('a character in the first square is read', (tester) async {
    await pumpApp(tester);
    await traceInto(tester, 'ZH:口', 0);

    expect(line('口'), findsOneWidget);
    // The whole reason the English is here: 口 on its own is not a reading
    // for someone who cannot read Han yet.
    expect(said('kǒu'), findsOneWidget);
    expect(means('mouth'), findsOneWidget);
  });

  testWidgets('the gloss comes from the table, not from the language it '
      'matched', (tester) async {
    // 中 exists only as a Korean glyph, and still has to read out in English.
    await pumpApp(tester);
    await traceInto(tester, 'KO:中', 0);

    expect(line('中'), findsOneWidget);
    expect(said('zhōng'), findsOneWidget);
    expect(means('central'), findsOneWidget);
  });

  testWidgets('a character in the second row is read', (tester) async {
    await pumpApp(tester);
    await traceInto(tester, 'ZH:口', _columns);

    expect(line('口'), findsOneWidget,
        reason: 'every row is a square plus a band tall, and the second row '
            'has to be reachable through that');
  });

  testWidgets('neighbouring squares stay separate characters', (tester) async {
    await pumpApp(tester);
    await traceInto(tester, 'ZH:口', 0);
    await traceInto(tester, 'ZH:王', 1);

    // Seven strokes on one canvas. The squares are what keep them two
    // characters rather than one unreadable pile.
    expect(line('口王'), findsOneWidget);
    expect(said('kǒu  wáng'), findsOneWidget);
    expect(means('mouth · king'), findsOneWidget);
  });

  testWidgets('the grid says whose stroke order you used, in English',
      (tester) async {
    await pumpApp(tester);
    // 王 is the documented disagreement: Japan writes the vertical second,
    // China third. Trace the Japanese glyph and only Japanese should own it.
    await traceInto(tester, 'JA:王', 0);

    expect(line('王'), findsOneWidget);
    expect(find.text('WHAT EACH SQUARE SAYS'), findsOneWidget);
    expect(find.text('Japanese'), findsOneWidget);
    expect(find.text('Chinese'), findsNothing);
  });

  testWidgets('a square says how sure it is, and what it beat', (tester) async {
    await pumpApp(tester);
    await traceInto(tester, 'ZH:口', 0);

    expect(find.text('WHAT EACH SQUARE SAYS'), findsOneWidget);
    // A stored glyph traced exactly is as good as input gets, so the reading
    // has to come back convincing — anything less would mean the percentage
    // is not measuring what it claims to.
    final percent = tester.widgetList<Text>(find.byType(Text)).firstWhere(
          (t) => t.data != null && RegExp(r'^\d+%$').hasMatch(t.data!),
        );
    final value = int.parse(percent.data!.replaceAll('%', ''));
    expect(value, greaterThan(66), reason: 'a traced glyph should be certain');
    expect(find.text('shape match'), findsOneWidget);
    expect(find.text('3 strokes drawn'), findsOneWidget);
  });

  testWidgets('a square reports every tradition that writes it that way',
      (tester) async {
    // 田's third and fourth strokes are the Chinese/Japanese disagreement:
    // writing the Chinese glyph with those two swapped *is* the Japanese
    // order, so the page has to credit Japan rather than call it wrong.
    await pumpApp(tester);
    await traceInto(tester, 'ZH:田', 0, order: [0, 1, 3, 2, 4]);

    expect(line('田'), findsOneWidget);
    expect(find.text('Japanese'), findsOneWidget);
    expect(find.text('Chinese'), findsNothing);
  });

  testWidgets('an order no tradition uses is said so in words', (tester) async {
    await pumpApp(tester);
    // The same marks as 田, opened with the second stroke. No source writes
    // it that way round — unlike the swap above, which is simply Japanese.
    await traceInto(tester, 'ZH:田', 0, order: [1, 0, 2, 3, 4]);

    expect(line('田'), findsOneWidget);
    expect(
      find.text('written in an order no tradition uses'),
      findsOneWidget,
    );
  });

  testWidgets('the end of a row runs straight into the next', (tester) async {
    // Reading order carries across the wrap; only an empty square is a space,
    // and there is none between the last of one row and the first of the next.
    await pumpApp(tester);
    await traceInto(tester, 'ZH:口', _columns - 1);
    await traceInto(tester, 'ZH:王', _columns);

    expect(line('口王'), findsOneWidget);
  });

  testWidgets('an empty square between two is a space', (tester) async {
    await pumpApp(tester);
    await traceInto(tester, 'ZH:口', 0);
    await traceInto(tester, 'ZH:口', 2);

    expect(line('口 口'), findsOneWidget);
  });

  testWidgets('a square that reads as nothing shows as ?', (tester) async {
    await pumpApp(tester);
    // The same diagonal three times over. No character is three strokes on
    // top of each other, so nothing clears the cutoff — which is the point:
    // an unrecognized square says so rather than guessing.
    final canvas = tester.getRect(find.byType(GameCanvas));
    final cell = canvas.width / _columns;
    Offset at(double t) =>
        canvas.topLeft + Offset(cell * (0.2 + 0.6 * t), cell * (0.2 + 0.6 * t));
    for (var stroke = 0; stroke < 3; stroke++) {
      final gesture = await tester.startGesture(at(0));
      for (var s = 1; s <= 10; s++) {
        await gesture.moveTo(at(s / 10));
      }
      await gesture.up();
      await tester.pump();
    }

    expect(line('?'), findsOneWidget);
    expect(find.textContaining('One square reads as ?'), findsOneWidget);
  });

  testWidgets('the squares do not move when the reading appears',
      (tester) async {
    await pumpApp(tester);
    final before = tester.getTopLeft(find.byType(GameCanvas)).dy;

    await traceInto(tester, 'ZH:口', 0);
    expect(line('口'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(GameCanvas)).dy, before);
  });

  testWidgets('the script selector narrows what a square can be read as',
      (tester) async {
    await pumpApp(tester);
    // 中 is in the table only as a Korean glyph, so it reads back under
    // Everything and must stop reading back under Chinese — with the same
    // strokes still on the page.
    await traceInto(tester, 'KO:中', 0);
    expect(line('中'), findsOneWidget);

    await tester.tap(find.text('Everything'));
    await settle(tester);
    await tester.tap(find.text('Chinese').last);
    await settle(tester);

    expect(line('中'), findsNothing,
        reason: 'Chinese does not carry 中, so it cannot be the answer');
    expect(find.text(_empty), findsNothing,
        reason: 'the strokes are still there — only the field moved');
  });

  testWidgets('opening on a script starts there', (tester) async {
    await pumpAppWith(tester, const HanziGridPage(initialScript: 'katakana'));

    expect(find.text('Katakana'), findsOneWidget);
    expect(find.text('Everything'), findsNothing);
  });

  testWidgets('an unknown script falls back rather than failing',
      (tester) async {
    await pumpAppWith(tester, const HanziGridPage(initialScript: 'klingon'));

    expect(find.text('Everything'), findsOneWidget);
  });

  testWidgets('clear page empties everything', (tester) async {
    await pumpApp(tester);
    await traceInto(tester, 'ZH:口', 0);
    expect(line('口'), findsOneWidget);

    await tester.tap(find.text('Clear page'));
    await tester.pump();
    expect(find.text(_empty), findsOneWidget);
  });

  testWidgets('undo removes the last stroke only', (tester) async {
    await pumpApp(tester);
    await traceInto(tester, 'ZH:口', 0);
    expect(line('口'), findsOneWidget);

    await tester.tap(find.text('Undo stroke'));
    await tester.pump();
    expect(line('口'), findsNothing, reason: 'two thirds of a 口 is not a 口');
    expect(find.text(_empty), findsNothing,
        reason: 'the square still holds the strokes that are left');
  });
}
