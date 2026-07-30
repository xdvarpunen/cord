import 'package:cord/makasar/data/lontara_letters.dart';
import 'package:cord/makasar/data/makasar_letters.dart';
import 'package:cord/makasar/data/script.dart';
import 'package:cord/makasar/engine/game_canvas.dart';
import 'package:cord/makasar/pages/makasar_page.dart';
import 'package:cord/makasar/pages/makasar_reference.dart';
import 'package:cord/makasar/pages/reference_page.dart';
import 'package:cord/makasar/scenes/makasar_scene.dart';
import 'package:cord/makasar/widgets/glyph_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Makasar page — upstream `makasar`'s `test/makasar_page_test.dart`,
/// re-aimed at cord's house layout: the chip listing upstream stacked under
/// the canvas is gone, and the reference table that was a page of its own is
/// a side panel here on wide layouts and behind an app-bar info button on
/// narrow, like Latin, Greek and Cyrillic. The character sets themselves are
/// unchanged, so the assertions about which script lists what carry over as
/// they stood — they just count rows now rather than chips.
///
/// Which marks read as which character is covered exhaustively in
/// `makasar_scene_test.dart`; what matters here is the script selector — that
/// picking one re-cuts the reference *and* re-points both canvases, and that
/// the page opens on the one it was asked for.

/// Pumps the page on a surface wide enough for the 50/50 split and tall
/// enough for the whole table and the script dropdown to be laid out at once.
///
/// The size goes on `tester.view` rather than through `setSurfaceSize`: the
/// page picks its layout off `MediaQuery`, which reads the *view's* physical
/// size, and `setSurfaceSize` moves only the render surface — a page sized
/// that way lays out wide while `MediaQuery` still answers 800×600.
Future<void> pumpPage(
  WidgetTester tester, {
  MakasarPage page = const MakasarPage(),
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

/// Opens the script dropdown and picks [label]. The label appears more than
/// once once the menu is open — on the button, in the menu, and for 'Makasar'
/// in the app bar and at the head of the table besides — so the menu's copy is
/// taken as the last of them.
Future<void> selectScript(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<WritingScript>));
  await pumpAnimation(tester);
  await tester.tap(find.text(label).last);
  await pumpAnimation(tester);
}

/// The Draw tab's layer, reached through the canvas the page built — the
/// page's own state is private. The Write tab's layer is a [WritingLayer], so
/// there is only ever one of these however many canvases are alive.
MakasarLayer drawingLayer(WidgetTester tester) => tester
    .widgetList<GameCanvas>(find.byType(GameCanvas))
    .expand((canvas) => canvas.sceneManager.current.layers)
    .whereType<MakasarLayer>()
    .single;

void main() {
  testWidgets('only the Write tab offers Undo', (tester) async {
    await pumpPage(tester);
    // The Draw tab holds one character at a time, so Clear is all it needs.
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Clear'), findsOneWidget);

    await tester.tap(find.text('Write'));
    await pumpAnimation(tester);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('the reference shows a letterform for every character',
      (tester) async {
    await pumpPage(tester);

    // One row per character, each leading with its drawn letterform — angka's
    // is the empty placeholder.
    expect(
      find.byType(GlyphImage),
      findsNWidgets(makasarLetters.length +
          makasarVowelSigns.length +
          makasarOtherSigns.length),
    );
    expect(find.text('nga'), findsOneWidget);
    expect(find.text('ngka'), findsNothing);
  });

  testWidgets('the dropdown swaps the reference for the Lontara one',
      (tester) async {
    await pumpPage(tester);
    await selectScript(tester, 'Bugis (Lontara)');

    expect(
      find.byType(GlyphImage),
      findsNWidgets(lontaraLetters.length +
          lontaraVowelSigns.length +
          lontaraOtherSigns.length),
    );
    // ngka is one of the five letters Makasar has no equivalent for, so it
    // only appears once the table has actually switched.
    expect(find.text('ngka'), findsOneWidget);
    expect(find.text(legendFor(WritingScript.bugis)), findsOneWidget);
    // Nothing in the bundle renders the Buginese block, so those rows carry
    // the codepoint where the Makasar rows carry the character itself.
    expect(find.text('U+1A00'), findsOneWidget);
  });

  testWidgets('the dropdown points the canvas at the script as well',
      (tester) async {
    await pumpPage(tester);
    expect(drawingLayer(tester).recognizer.script, WritingScript.makasar);

    await selectScript(tester, 'Bugis (Lontara)');

    // Otherwise a wedge drawn while the table shows Lontara would be read out
    // as the Makasar letter na rather than the Lontara letter ta.
    expect(drawingLayer(tester).recognizer.script, WritingScript.bugis);
  });

  testWidgets('the Clear button is there to be pressed', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('every drawable Lontara letter says how to draw it', () {
    // The invariant upstream's CLAUDE.md asks for: a letter with a classifier
    // carries the description the app shows, and one without carries none.
    final recognized = MakasarLayer.recognizedNamesFor(WritingScript.bugis);
    for (final letter in lontaraLetters) {
      expect(letter.shape != null, recognized.contains(letter.name),
          reason: letter.name);
    }
  });

  // ── cord's own: the search page opens a result on its script ───────────────

  testWidgets('an initialScript opens the page on that script', (tester) async {
    await pumpPage(tester, page: const MakasarPage(initialScript: 'bugis'));

    expect(find.text(legendFor(WritingScript.bugis)), findsOneWidget);
    expect(find.text('ngka'), findsOneWidget);
    expect(drawingLayer(tester).recognizer.script, WritingScript.bugis);
  });

  testWidgets('an unknown script slug falls back to Makasar', (tester) async {
    await pumpPage(tester, page: const MakasarPage(initialScript: 'lontara'));

    expect(find.text(legendFor(WritingScript.makasar)), findsOneWidget);
    expect(find.text('ngka'), findsNothing);
  });

  // ── cord's own: the narrow layout puts the table behind the info button ────

  testWidgets('on narrow the reference moves behind the app bar info button',
      (tester) async {
    await pumpPage(tester, size: const Size(500, 900));

    // Not on the page itself…
    expect(find.byType(GlyphImage), findsNothing);
    expect(find.text(legendFor(WritingScript.makasar)), findsNothing);

    // …but one tap away, on whichever script the page is set to.
    await tester.tap(find.byIcon(Icons.info_outline));
    await pumpAnimation(tester);
    expect(find.byType(ReferencePage), findsOneWidget);
    expect(find.text('Makasar script reference'), findsOneWidget);
    expect(find.text(legendFor(WritingScript.makasar)), findsOneWidget);
  });
}
