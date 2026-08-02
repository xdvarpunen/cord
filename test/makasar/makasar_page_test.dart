import 'package:cord/makasar/data/canvas_mode.dart';
import 'package:cord/makasar/data/glyphs.dart';
import 'package:cord/makasar/data/lontara_letters.dart';
import 'package:cord/makasar/data/makasar_letters.dart';
import 'package:cord/makasar/data/script.dart';
import 'package:cord/makasar/engine/game_canvas.dart';
import 'package:cord/makasar/pages/makasar_page.dart';
import 'package:cord/makasar/pages/makasar_reference.dart';
import 'package:cord/makasar/pages/reference_page.dart';
import 'package:cord/makasar/scenes/makasar_scene.dart';
import 'package:cord/makasar/widgets/glyph_image.dart';
import 'package:cord/makasar/widgets/lontara_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Lontara page — upstream `lontara`'s `test/makasar_page_test.dart`,
/// re-aimed at cord's house layout: the chip listing upstream stacked under
/// the canvas is gone, and the reference table that was a page of its own is
/// a side panel here on wide layouts and behind an app-bar info button on
/// narrow, like Latin, Greek and Cyrillic. The character sets themselves are
/// unchanged, so the assertions about which script lists what carry over as
/// they stood — they just count rows now rather than chips.
///
/// Which marks read as which character is covered exhaustively in
/// `makasar_scene_test.dart`; what matters here are the two dropdowns — that
/// picking a script re-cuts the reference *and* re-points both canvases, that
/// picking a canvas swaps which one is showing without losing what is on the
/// other, and that the page opens on the script it was asked for.

/// `Λ`, the single wedge that is na — enough of a character to tell whether a
/// canvas kept what was on it.
final _wedge = [
  for (var i = 0; i <= 8; i++)
    Offset.lerp(const Offset(0, 40), const Offset(20, 0), i / 8)!,
  for (var i = 1; i <= 8; i++)
    Offset.lerp(const Offset(20, 0), const Offset(40, 40), i / 8)!,
];

/// Pumps the page on a surface wide enough for the 50/50 split and tall
/// enough for the whole table and the two dropdowns to be laid out at once.
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
/// once once the menu is open — on the button, in the menu, and at the head of
/// the table besides — so the menu's copy is taken as the last of them.
Future<void> selectScript(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<WritingScript>));
  await pumpAnimation(tester);
  await tester.tap(find.text(label).last);
  await pumpAnimation(tester);
}

/// The same for the canvas dropdown.
Future<void> selectCanvas(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<CanvasMode>));
  await pumpAnimation(tester);
  await tester.tap(find.text(label).last);
  await pumpAnimation(tester);
}

/// The drawing canvas's layer, reached through the canvas the page built — the
/// page's own state is private. The writing canvas keeps a recognizer per
/// character instead of a [MakasarLayer], so there is only ever one of these.
MakasarLayer drawingLayer(WidgetTester tester) => tester
    .widgetList<GameCanvas>(find.byType(GameCanvas))
    .expand((canvas) => canvas.sceneManager.current.layers)
    .whereType<MakasarLayer>()
    .single;

void main() {
  testWidgets('the title says Lontara, and shows it written', (tester) async {
    await pumpPage(tester);
    expect(find.text('Lontara'), findsOneWidget);
    // ᨒᨚᨈᨑ beside it — drawn, the Buginese block having no font here.
    expect(find.byType(LontaraWordmark), findsOneWidget);
  });

  testWidgets('both canvases offer Undo and Clear', (tester) async {
    await pumpPage(tester);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);

    await selectCanvas(tester, 'Write');
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets('the canvas dropdown swaps the drawing canvas for the row',
      (tester) async {
    await pumpPage(tester);
    // The single-character canvas is the one with a MakasarLayer on it; the
    // writing canvas keeps a recognizer per character instead.
    expect(find.byType(GameCanvas), findsOneWidget);
    expect(drawingLayer(tester), isNotNull);

    await selectCanvas(tester, 'Write');

    expect(find.byType(GameCanvas), findsOneWidget);
    expect(
      tester
          .widget<GameCanvas>(find.byType(GameCanvas))
          .sceneManager
          .current
          .layers
          .whereType<MakasarLayer>(),
      isEmpty,
    );
  });

  testWidgets('what was drawn survives a trip to the other canvas',
      (tester) async {
    await pumpPage(tester);
    final layer = drawingLayer(tester);
    layer.recognizer.addMark(_wedge);
    // ta, the page opening on New Lontara — the same wedge is na under Old
    // Lontara, which is the whole point of the script dropdown.
    expect(layer.recognizedName, 'ta');

    await selectCanvas(tester, 'Write');
    await selectCanvas(tester, 'Draw');

    expect(drawingLayer(tester).recognizedName, 'ta');
  });

  testWidgets('the reference shows a letterform for every character',
      (tester) async {
    await pumpPage(tester);

    // One row per character of New Lontara, the script the page opens on, each
    // leading with its drawn letterform. The wordmark's four letterforms are
    // its own widget, not GlyphImages, so they don't count here.
    expect(
      find.byType(GlyphImage),
      findsNWidgets(lontaraLetters.length +
          lontaraVowelSigns.length +
          lontaraOtherSigns.length),
    );
    // ngka is one of the five letters Old Lontara has no equivalent for.
    expect(find.text('ngka'), findsOneWidget);
    // Nothing in the bundle renders the Buginese block, so those rows carry
    // the codepoint where the Old Lontara rows carry the character itself.
    expect(find.text('U+1A00'), findsOneWidget);
  });

  testWidgets('the dropdown swaps the reference for the Old Lontara one',
      (tester) async {
    await pumpPage(tester);
    await selectScript(tester, 'Old Lontara');

    // angka's letterform is the empty placeholder, so every row still has a
    // GlyphImage.
    expect(
      find.byType(GlyphImage),
      findsNWidgets(makasarLetters.length +
          makasarVowelSigns.length +
          makasarOtherSigns.length),
    );
    expect(find.text('nga'), findsOneWidget);
    expect(find.text('ngka'), findsNothing);
    expect(find.text(legendFor(WritingScript.makasar)), findsOneWidget);
  });

  testWidgets('the dropdown points the canvas at the script as well',
      (tester) async {
    await pumpPage(tester);
    expect(drawingLayer(tester).recognizer.script, WritingScript.bugis);

    await selectScript(tester, 'Old Lontara');

    // Otherwise a wedge drawn while the table shows Old Lontara would be read
    // out as New Lontara's ta rather than Old Lontara's na.
    expect(drawingLayer(tester).recognizer.script, WritingScript.makasar);
  });

  testWidgets('the Clear button is there to be pressed', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('every character a canvas can read has a letterform to show', () {
    // What the reading is drawn under, and for New Lontara the only picture of
    // the character there is — so anything recognized has to have one. angka is
    // the exception the source article leaves: there is no image of it to
    // bundle.
    for (final script in WritingScript.values) {
      for (final name in MakasarLayer.recognizedNamesFor(script)) {
        if (name == 'angka') continue;
        expect(glyphImagesFor(script, name: name), isNotEmpty,
            reason: '$script $name');
      }
      for (final vowel in MakasarLayer.recognizedVowelsFor(script)) {
        expect(glyphImagesFor(script, name: 'ka', vowel: vowel), hasLength(2),
            reason: '$script -$vowel');
      }
    }
  });

  test('every vowel sign can be composed onto its letter', () {
    // A syllable is drawn as one picture — the letterform with the mark on
    // it, so ki reads as ki and not as ka followed by a mark on an empty
    // circle. That needs the mark's place in its `sign_*` image, and a sign
    // with none would silently lose its mark.
    for (final script in WritingScript.values) {
      for (final vowel in MakasarLayer.recognizedVowelsFor(script)) {
        final cluster = glyphClusterFor(script, name: 'ka', vowel: vowel);
        expect(MakasarInk.composableSigns, contains(cluster.vowel),
            reason: '$script -$vowel');
      }
    }
  });

  test('every drawable New Lontara letter says how to draw it', () {
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
    // Old Lontara, since New Lontara is what the page opens on unasked.
    await pumpPage(tester, page: const MakasarPage(initialScript: 'makasar'));

    expect(find.text(legendFor(WritingScript.makasar)), findsOneWidget);
    expect(find.text('ngka'), findsNothing);
    expect(drawingLayer(tester).recognizer.script, WritingScript.makasar);
  });

  testWidgets('an unknown script slug falls back to New Lontara',
      (tester) async {
    // The slugs are the enum's own names, so they are still the scripts' older
    // ones — `?script=lontara` names neither.
    await pumpPage(tester, page: const MakasarPage(initialScript: 'lontara'));

    expect(find.text(legendFor(WritingScript.bugis)), findsOneWidget);
    expect(find.text('ngka'), findsOneWidget);
  });

  // ── cord's own: the narrow layout puts the table behind the info button ────

  testWidgets('on narrow the reference moves behind the app bar info button',
      (tester) async {
    await pumpPage(tester, size: const Size(500, 900));

    // Not on the page itself…
    expect(find.byType(GlyphImage), findsNothing);
    expect(find.text(legendFor(WritingScript.bugis)), findsNothing);

    // …but one tap away, on whichever script the page is set to.
    await tester.tap(find.byIcon(Icons.info_outline));
    await pumpAnimation(tester);
    expect(find.byType(ReferencePage), findsOneWidget);
    expect(find.text('New Lontara script reference'), findsOneWidget);
    expect(find.text(legendFor(WritingScript.bugis)), findsOneWidget);
  });
}
