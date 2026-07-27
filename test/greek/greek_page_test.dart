import 'package:cord/greek/data/greek_letters.dart';
import 'package:cord/greek/pages/greek_page.dart';
import 'package:cord/greek/pages/reference_page.dart';
import 'package:cord/greek/scenes/greek_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Greek page — upstream `greek`'s `test/greek_page_test.dart`, re-aimed at
/// cord's house layout: the legend that upstream stacked under the canvas is a
/// side panel here on wide layouts and behind an app-bar info button on narrow,
/// like Latin and Cyrillic. The letters themselves are unchanged, so the
/// assertions about which alphabet lists what carry over as they stood.
///
/// Which strokes read as which letter is covered exhaustively in
/// `greek_scene_test.dart`; what matters here is the alphabet selector — that
/// picking one re-cuts the legend, and that the page opens on the one it was
/// asked for.

/// Pumps the page on a surface wide enough for the 50/50 split and tall enough
/// for the whole legend and the alphabet dropdown to be laid out at once.
///
/// The size goes on `tester.view` rather than through `setSurfaceSize`: the
/// page picks its layout off `MediaQuery`, which reads the *view's* physical
/// size, and `setSurfaceSize` moves only the render surface — a page sized that
/// way lays out wide while `MediaQuery` still answers 800×600.
Future<void> pumpPage(
  WidgetTester tester, {
  GreekPage page = const GreekPage(),
  Size size = const Size(1000, 1600),
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

/// Pumps a frame and then long enough for the dropdown's open/close animation
/// to finish. [WidgetTester.pumpAndSettle] can't be used anywhere on this page:
/// `GameCanvas` runs a `Ticker` that schedules a frame every frame, so there is
/// never a moment with nothing pending and settling would simply time out.
Future<void> pumpAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Opens the alphabet dropdown and picks [label]. The label appears more than
/// once once the menu is open — on the button, in the menu, and for 'Greek' in
/// the app bar besides — so the menu's copy is taken as the last of them.
Future<void> selectAlphabet(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<Alphabet>));
  await pumpAnimation(tester);
  await tester.tap(find.text(label).last);
  await pumpAnimation(tester);
}

void main() {
  testWidgets('the page opens on Greek, listing all 24 letters',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('24 letters — the 24 of Α–Ω'), findsOneWidget);
    expect(find.text('Ξ ξ'), findsOneWidget);
    expect(find.text('Ψ ψ'), findsOneWidget);
    expect(find.text('Ω ω'), findsOneWidget);
    // The archaic two belong to the archaic alphabet.
    expect(find.text('Ϝ ϝ'), findsNothing);
    expect(find.text('Ϙ ϙ'), findsNothing);
  });

  testWidgets('choosing Old Attic drops Ξ, Ψ and Ω', (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'Old Attic');

    expect(find.text('21 letters — the 21 before 403 BC — no Ξ, Ψ or Ω'),
        findsOneWidget);
    expect(find.text('Ξ ξ'), findsNothing);
    expect(find.text('Ψ ψ'), findsNothing);
    expect(find.text('Ω ω'), findsNothing);
    // The letters the alphabets share are still there.
    expect(find.text('Η η'), findsOneWidget);
    expect(find.text('Φ φ'), findsOneWidget);
    expect(find.text('Χ χ'), findsOneWidget);
  });

  testWidgets('choosing Archaic adds Ϝ and Ϙ but keeps Ξ, Ψ and Ω out',
      (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'Archaic');

    expect(find.text('23 letters — the 21, with Ϝ and Ϙ besides'),
        findsOneWidget);
    expect(find.text('Ϝ ϝ'), findsOneWidget);
    expect(find.text('Ϙ ϙ'), findsOneWidget);
    expect(find.text('Ξ ξ'), findsNothing);
    expect(find.text('Ω ω'), findsNothing);
  });

  testWidgets('choosing Greek again brings it back to 24', (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'Archaic');
    expect(find.text('Ϝ ϝ'), findsOneWidget);

    await selectAlphabet(tester, 'Greek');
    expect(find.text('24 letters — the 24 of Α–Ω'), findsOneWidget);
    expect(find.text('Ϝ ϝ'), findsNothing);
    expect(find.text('Ω ω'), findsOneWidget);
  });

  testWidgets('the dropdown offers every alphabet', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byType(DropdownButton<Alphabet>));
    await pumpAnimation(tester);

    for (final alphabet in Alphabet.values) {
      expect(find.text(alphabet.label), findsWidgets, reason: alphabet.label);
    }
  });

  testWidgets('every legend chip carries the letter\'s own name',
      (tester) async {
    await pumpPage(tester);

    for (final row in Alphabet.greek.rows) {
      expect(find.text('${row.capital} ${row.small}'), findsOneWidget,
          reason: row.name);
      expect(find.text(row.name), findsOneWidget, reason: row.name);
    }
  });

  testWidgets('nothing in any legend is muted', (tester) async {
    await pumpPage(tester);

    for (final alphabet in Alphabet.values) {
      for (final row in alphabet.rows) {
        expect(GreekLayer.recognizedNames, contains(row.name),
            reason: '${row.capital} of ${alphabet.label}');
      }
    }
  });

  testWidgets('the Clear button is there to be pressed', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  // ── cord's own: the search page opens a result on its alphabet ─────────────

  testWidgets('an initialAlphabet opens the page on that alphabet',
      (tester) async {
    await pumpPage(tester, page: const GreekPage(initialAlphabet: 'archaic'));

    expect(find.text('23 letters — the 21, with Ϝ and Ϙ besides'),
        findsOneWidget);
    expect(find.text('Ϙ ϙ'), findsOneWidget);
    expect(find.text('Ω ω'), findsNothing);
  });

  testWidgets('an unknown alphabet slug falls back to Greek', (tester) async {
    await pumpPage(tester, page: const GreekPage(initialAlphabet: 'linearB'));

    expect(find.text('24 letters — the 24 of Α–Ω'), findsOneWidget);
  });

  // ── cord's own: the narrow layout puts the legend behind the info button ───

  testWidgets('on narrow the legend moves behind the app bar info button',
      (tester) async {
    await pumpPage(tester, size: const Size(500, 900));

    // Not on the page itself…
    expect(find.text('Α α'), findsNothing);
    expect(find.text('24 letters — the 24 of Α–Ω'), findsNothing);

    // …but one tap away.
    await tester.tap(find.byIcon(Icons.info_outline));
    await pumpAnimation(tester);
    expect(find.byType(ReferencePage), findsOneWidget);
    expect(find.text('Greek alphabet reference'), findsOneWidget);
    expect(find.text('24 letters — the 24 of Α–Ω'), findsOneWidget);
    expect(find.text('Α α'), findsOneWidget);
  });
}
