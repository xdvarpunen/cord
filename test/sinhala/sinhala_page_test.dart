import 'package:cord/sinhala/engine/game_canvas.dart';
import 'package:cord/sinhala/pages/reference_page.dart';
import 'package:cord/sinhala/pages/sinhala_page.dart';
import 'package:cord/sinhala/scenes/sinhala_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Sinhala numerals page. Upstream `sinhala` has no page test of its own —
/// this is cord's, aimed at the house layout: the reference beside the canvas
/// on wide, behind an app-bar info button on narrow, and a dropdown where
/// upstream had a row of tabs (and one fewer choice on it, cord having taken
/// the numerals and left the hodiya).
///
/// Which strokes read as which numeral is covered exhaustively in
/// `sinhala_scene_test.dart`; what matters here is the dropdown — that picking
/// a system re-cuts the reference *and* re-points the canvas, that what is
/// already drawn is re-read rather than wiped, and that the page opens on the
/// system it was asked for.

/// Pumps the page on a surface wide enough for the 50/50 split and tall enough
/// for the table and the control bar to be laid out at once.
///
/// The size goes on `tester.view` rather than through `setSurfaceSize`: the
/// page picks its layout off `MediaQuery`, which reads the *view's* physical
/// size, and `setSurfaceSize` moves only the render surface — a page sized
/// that way lays out wide while `MediaQuery` still answers 800×600.
Future<void> pumpPage(
  WidgetTester tester, {
  SinhalaPage page = const SinhalaPage(),
  Size size = const Size(1200, 1600),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump();
}

/// Pumps a frame and then long enough for a dropdown's or a route's own
/// animation to finish. [WidgetTester.pumpAndSettle] can't be used anywhere on
/// this page: `GameCanvas` runs a `Ticker` that schedules a frame every frame,
/// so there is never a moment with nothing pending and settling would simply
/// time out.
Future<void> pumpAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Opens the numerals dropdown and picks [label]. The label appears twice once
/// the menu is open — on the button and in the menu — so the menu's copy is
/// taken as the last of them.
Future<void> selectSystem(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<RecognitionSystem>));
  await pumpAnimation(tester);
  await tester.tap(find.text(label).last);
  await pumpAnimation(tester);
}

/// The recognizer the page built — its own state is private.
SinhalaLetterLayer canvasLayer(WidgetTester tester) => tester
    .widget<GameCanvas>(find.byType(GameCanvas))
    .sceneManager
    .current
    .layers
    .whereType<SinhalaLetterLayer>()
    .single;

/// The ර/෮ loop from `sinhala_scene_test.dart`: a rightward coil, a crossing,
/// and away upward. A Lith 8, and nothing at all under Illakkam — which is why
/// it is the stroke to draw when the question is what switching system does.
const _ata = [
  Offset(250, 300),
  Offset(250, 170),
  Offset(262, 140),
  Offset(290, 120),
  Offset(325, 122),
  Offset(352, 145),
  Offset(360, 180),
  Offset(352, 215),
  Offset(330, 243),
  Offset(300, 255),
  Offset(268, 250),
  Offset(240, 232),
  Offset(210, 195),
  Offset(190, 160),
  Offset(178, 130),
];

/// Drags [layer] through [path], interpolating every 2 logical pixels so the
/// stroke is sampled as densely as a real drag — the scene test's own helper.
void drag(SinhalaLetterLayer layer, List<Offset> path) {
  const size = Size(960, 840);
  layer.handlePointerEvent(PointerDownEvent(position: path.first), size);
  for (var i = 1; i < path.length; i++) {
    final (from, to) = (path[i - 1], path[i]);
    final steps = ((to - from).distance / 2).ceil();
    for (var step = 1; step <= steps; step++) {
      layer.handlePointerEvent(
        PointerMoveEvent(position: from + (to - from) * (step / steps)),
        size,
      );
    }
  }
  layer.handlePointerEvent(PointerUpEvent(position: path.last), size);
}

void main() {
  testWidgets('the title says what the page is', (tester) async {
    await pumpPage(tester);
    expect(find.text('Sinhala numerals'), findsOneWidget);
  });

  testWidgets('it opens on the Lith digits, table and canvas alike',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Lith numerals (ලිත් ඉලක්කම්)'), findsOneWidget);
    // "binduva" is the Lith zero — the digit Illakkam has no symbol for.
    expect(find.text('binduva'), findsOneWidget);
    expect(canvasLayer(tester).system, RecognitionSystem.lithNumerals);
  });

  testWidgets('the dropdown swaps the reference for the Illakkam one',
      (tester) async {
    await pumpPage(tester);
    await selectSystem(tester, 'Illakkam numerals');

    expect(find.text('Illakkam numerals (ඉලක්කම්)'), findsOneWidget);
    expect(find.text('Lith numerals (ලිත් ඉලක්කම්)'), findsNothing);
    // The tens, which are the whole of what having no place value costs.
    expect(find.text('hataliha'), findsOneWidget);
  });

  testWidgets('the dropdown points the canvas at the system as well',
      (tester) async {
    await pumpPage(tester);
    await selectSystem(tester, 'Illakkam numerals');

    // Otherwise a stroke drawn while the table shows Illakkam would still be
    // read out as a Lith digit.
    expect(canvasLayer(tester).system, RecognitionSystem.illakkamNumerals);
  });

  testWidgets('what is drawn is re-read on the switch, not wiped',
      (tester) async {
    await pumpPage(tester);
    final layer = canvasLayer(tester);
    drag(layer, _ata);
    expect(layer.recognizedText, '෮');

    await selectSystem(tester, 'Illakkam numerals');
    expect(canvasLayer(tester).recognizedText, isNull);
    // Still on the canvas, and still a Lith 8 when read as one.
    await selectSystem(tester, 'Lith numerals');
    expect(canvasLayer(tester).recognizedText, '෮');
  });

  testWidgets('the Clear button is there to be pressed', (tester) async {
    await pumpPage(tester);
    final layer = canvasLayer(tester);
    drag(layer, _ata);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(layer.recognizedText, isNull);
  });

  // ── the search page opens a result on its system ──────────────────────────

  testWidgets('an initialSystem opens the page on that system', (tester) async {
    // Illakkam, since Lith is what the page opens on unasked.
    await pumpPage(
      tester,
      page: const SinhalaPage(initialSystem: 'illakkamNumerals'),
    );

    expect(find.text('Illakkam numerals (ඉලක්කම්)'), findsOneWidget);
    expect(canvasLayer(tester).system, RecognitionSystem.illakkamNumerals);
  });

  testWidgets('an unknown system slug falls back to Lith', (tester) async {
    await pumpPage(tester, page: const SinhalaPage(initialSystem: 'lith'));

    expect(find.text('Lith numerals (ලිත් ඉලක්කම්)'), findsOneWidget);
  });

  testWidgets('the letters are not reachable through the slug either',
      (tester) async {
    // The recognizer still has them, but this page is the numerals; a slug
    // naming the letters falls back like any other unknown one.
    await pumpPage(tester, page: const SinhalaPage(initialSystem: 'letters'));

    expect(find.text('Lith numerals (ලිත් ඉලක්කම්)'), findsOneWidget);
    expect(canvasLayer(tester).system, RecognitionSystem.lithNumerals);
  });

  // ── the narrow layout puts the table behind the info button ───────────────

  testWidgets('on narrow the reference moves behind the app bar info button',
      (tester) async {
    await pumpPage(tester, size: const Size(500, 900));

    // Not on the page itself…
    expect(find.text('Lith numerals (ලිත් ඉලක්කම්)'), findsNothing);
    expect(find.text('binduva'), findsNothing);

    // …but one tap away, on whichever system the page is set to.
    await tester.tap(find.byIcon(Icons.info_outline));
    await pumpAnimation(tester);
    expect(find.byType(ReferencePage), findsOneWidget);
    expect(find.text('Lith numerals reference'), findsOneWidget);
    expect(find.text('binduva'), findsOneWidget);
  });
}
