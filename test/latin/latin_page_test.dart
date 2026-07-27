import 'package:cord/latin/data/latin_letters.dart';
import 'package:cord/latin/pages/latin_page.dart';
import 'package:cord/latin/pages/reference_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Latin page — upstream `latin`'s `test/latin_page_test.dart`, re-aimed at
/// cord's house layout: the legend that upstream stacked under the canvas is a
/// side panel here on wide layouts and behind an app-bar info button on narrow,
/// like Cyrillic and Hebrew. The letters themselves are unchanged, so the
/// assertions about which alphabet lists what carry over as they stood.
///
/// Which strokes read as which letter is covered exhaustively in
/// `latin_scene_test.dart`; what matters here is the alphabet selector — that
/// picking one re-cuts the legend, and that the page opens on the one it was
/// asked for.

/// Pumps the page on a surface wide enough for the 50/50 split and tall enough
/// for the whole alphabet dropdown to open at once.
///
/// The thirty-one entries don't fit the 600px default, and `DropdownButton`'s
/// menu builds only what its viewport shows — so on a short surface an entry
/// near the end isn't merely off-screen, it doesn't exist to be found or
/// tapped.
///
/// The size goes on `tester.view` rather than through `setSurfaceSize`: the
/// page picks its layout off `MediaQuery`, which reads the *view's* physical
/// size, and `setSurfaceSize` moves only the render surface — a page sized that
/// way lays out wide while `MediaQuery` still answers 800×600.
Future<void> pumpPage(
  WidgetTester tester, {
  LatinPage page = const LatinPage(),
  Size size = const Size(1000, 2200),
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
/// once once the menu is open — on the button, in the menu, and for 'Latin' in
/// the app bar besides — so the menu's copy is taken as the last of them.
Future<void> selectAlphabet(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<Alphabet>));
  await pumpAnimation(tester);
  await tester.tap(find.text(label).last);
  await pumpAnimation(tester);
}

void main() {
  testWidgets('the page opens on English, listing all 26 letters',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('26 letters — the 26 of A–Z'), findsOneWidget);
    expect(find.text('U u'), findsOneWidget);
    expect(find.text('J j'), findsOneWidget);
    expect(find.text('W w'), findsOneWidget);
    // English hasn't got the Nordic three.
    expect(find.text('Å å'), findsNothing);
    expect(find.text('Ä ä'), findsNothing);
    expect(find.text('Ö ö'), findsNothing);
  });

  testWidgets('choosing Latin drops J, U and W from the legend',
      (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'Latin');

    expect(find.text('23 letters — no J, U or W'), findsOneWidget);
    expect(find.text('U u'), findsNothing);
    expect(find.text('J j'), findsNothing);
    expect(find.text('W w'), findsNothing);
    // The letters the alphabets share are still there.
    expect(find.text('V v'), findsOneWidget);
    expect(find.text('Y y'), findsOneWidget);
    expect(find.text('Z z'), findsOneWidget);
  });

  testWidgets('choosing Finnish adds Å, Ä and Ö', (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'Finnish');

    expect(find.text('29 letters — A–Z plus Å, Ä and Ö — the same 29 as Swedish'),
        findsOneWidget);
    expect(find.text('Å å'), findsOneWidget);
    expect(find.text('Ä ä'), findsOneWidget);
    expect(find.text('Ö ö'), findsOneWidget);
    // And it keeps the three Latin hasn't got.
    expect(find.text('J j'), findsOneWidget);
    expect(find.text('U u'), findsOneWidget);
    expect(find.text('W w'), findsOneWidget);
  });

  testWidgets('choosing Norwegian adds Æ, Ø and Å', (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'Norwegian');

    expect(find.text('29 letters — A–Z plus Æ, Ø and Å — the same 29 as Danish'),
        findsOneWidget);
    expect(find.text('Æ æ'), findsOneWidget);
    expect(find.text('Ø ø'), findsOneWidget);
    expect(find.text('Å å'), findsOneWidget);
    // The umlauts belong to the other two.
    expect(find.text('Ä ä'), findsNothing);
    expect(find.text('Ü ü'), findsNothing);
    expect(find.text('ß ß'), findsNothing);
  });

  testWidgets('choosing German adds Ä, Ö, Ü and ß but not Å', (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'German');

    expect(find.text('30 letters — A–Z plus Ä, Ö, Ü and ß'), findsOneWidget);
    expect(find.text('Ä ä'), findsOneWidget);
    expect(find.text('Ö ö'), findsOneWidget);
    expect(find.text('Ü ü'), findsOneWidget);
    expect(find.text('ß ß'), findsOneWidget);
    expect(find.text('Å å'), findsNothing);
    expect(find.text('Æ æ'), findsNothing);
    expect(find.text('Ø ø'), findsNothing);
  });

  testWidgets('choosing English again brings it back to 26', (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'Finnish');
    expect(find.text('Ä ä'), findsOneWidget);

    await selectAlphabet(tester, 'English');
    expect(find.text('26 letters — the 26 of A–Z'), findsOneWidget);
    expect(find.text('Ä ä'), findsNothing);
    expect(find.text('U u'), findsOneWidget);
  });

  testWidgets('the dropdown offers every alphabet', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byType(DropdownButton<Alphabet>));
    await pumpAnimation(tester);

    for (final alphabet in Alphabet.values) {
      expect(find.text(alphabet.label), findsWidgets, reason: alphabet.label);
    }
  });

  testWidgets('choosing French lists its accents, and Œ with them',
      (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'French');

    expect(find.text('42 letters — A–Z with sixteen letters beyond it'),
        findsOneWidget);
    for (final chip in ['À à', 'Â â', 'Ç ç', 'Ë ë', 'Ï ï', 'Ô ô', 'Ÿ ÿ']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    expect(find.text('Œ œ'), findsOneWidget);
  });

  testWidgets('choosing Spanish files Ñ between N and O', (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'Spanish');

    expect(find.text('33 letters — A–Z with Ñ, and six accented vowels'),
        findsOneWidget);
    expect(find.text('Ñ ñ'), findsOneWidget);
    expect(find.text('Á á'), findsOneWidget);
    // The tilde over an A belongs to Portuguese, not Spanish.
    expect(find.text('Ã ã'), findsNothing);
  });

  testWidgets('choosing Icelandic drops C, Q, W and Z', (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'Icelandic');

    expect(find.text('Ð ð'), findsOneWidget);
    expect(find.text('Þ þ'), findsOneWidget);
    expect(find.text('Ý ý'), findsOneWidget);
    for (final chip in ['C c', 'Q q', 'W w', 'Z z']) {
      expect(find.text(chip), findsNothing, reason: chip);
    }
  });

  testWidgets('choosing Czech lists its carons', (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'Czech');

    expect(find.text('41 letters — A–Z with Á Č Ď É Ě Í Ň Ó Ř Š Ť Ú Ů Ý Ž'),
        findsOneWidget);
    for (final chip in ['Č č', 'Ď ď', 'Ě ě', 'Ň ň', 'Ř ř', 'Š š', 'Ť ť',
        'Ž ž', 'Ů ů']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    // Slovak's own three belong to Slovak.
    expect(find.text('Ĺ ĺ'), findsNothing);
    expect(find.text('Ľ ľ'), findsNothing);
    expect(find.text('Ô ô'), findsNothing);
  });

  testWidgets('choosing Polish lists Ą, Ę and Ł with the rest', (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'Polish');

    expect(find.text('32 letters — A–Z with Ą Ć Ę Ł Ń Ó Ś Ź Ż'), findsOneWidget);
    for (final chip in ['Ć ć', 'Ń ń', 'Ś ś', 'Ź ź', 'Ż ż']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    for (final chip in ['Ą ą', 'Ę ę', 'Ł ł']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    // Polish has no Q, V or X.
    for (final chip in ['Q q', 'V v', 'X x']) {
      expect(find.text(chip), findsNothing, reason: chip);
    }
  });

  testWidgets('Croatian lists Đ where Icelandic lists Ð', (tester) async {
    await pumpPage(tester);
    await selectAlphabet(tester, 'Croatian');
    expect(find.text('Đ đ'), findsOneWidget);
    expect(find.text('Ð ð'), findsNothing);

    await selectAlphabet(tester, 'Icelandic');
    expect(find.text('Ð ð'), findsOneWidget);
    expect(find.text('Đ đ'), findsNothing);
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
    await pumpPage(tester,
        page: const LatinPage(initialAlphabet: 'icelandic'));

    expect(find.text('Ð ð'), findsOneWidget);
    expect(find.text('Þ þ'), findsOneWidget);
    expect(find.text('C c'), findsNothing);
  });

  testWidgets('an unknown alphabet slug falls back to English', (tester) async {
    await pumpPage(tester, page: const LatinPage(initialAlphabet: 'klingon'));

    expect(find.text('26 letters — the 26 of A–Z'), findsOneWidget);
  });

  // ── cord's own: the narrow layout puts the legend behind the info button ───

  testWidgets('on narrow the legend moves behind the app bar info button',
      (tester) async {
    await pumpPage(tester, size: const Size(500, 900));

    // Not on the page itself…
    expect(find.text('A a'), findsNothing);
    expect(find.text('26 letters — the 26 of A–Z'), findsNothing);

    // …but one tap away.
    await tester.tap(find.byIcon(Icons.info_outline));
    await pumpAnimation(tester);
    expect(find.byType(ReferencePage), findsOneWidget);
    expect(find.text('English alphabet reference'), findsOneWidget);
    expect(find.text('26 letters — the 26 of A–Z'), findsOneWidget);
    expect(find.text('A a'), findsOneWidget);
  });
}
