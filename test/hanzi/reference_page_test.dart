import 'package:cord/hanzi/data/hanzi_glosses.dart';
import 'package:cord/hanzi/data/hanzi_scripts.dart';
import 'package:cord/hanzi/data/hanzi_strokes.dart';
import 'package:cord/hanzi/pages/character_tables.dart';
import 'package:cord/hanzi/pages/hanzi_grid_page.dart';
import 'package:cord/hanzi/pages/reference_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The character reference: what the grid can actually read.
///
/// It exists because the recognizer is a stroke reference, not a dictionary —
/// a character it does not hold can never be read, and worse, can be read as a
/// different one that it does. Being able to look the set up is the difference
/// between that being a property and being a surprise.

Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}

void main() {
  test('every character the recognizer can return has a gloss', () {
    // The band and the reference both read from `hanziGlosses`; a character in
    // the stroke table with no entry would come back with a blank line under
    // it, and the page would never say why.
    final chars = {for (final g in strokeGlyphs.values) g.char};
    final ungloss = [for (final c in chars) if (!hanziGlosses.containsKey(c)) c];
    expect(ungloss, isEmpty, reason: 'run: node tool/hanzi_glosses.mjs');
    expect(hanziCharacterCount, chars.length);
  });

  test('the glosses are not padded with entries nothing can draw', () {
    final chars = {for (final g in strokeGlyphs.values) g.char};
    expect(hanziGlosses.keys.toSet().difference(chars), isEmpty);
  });

  testWidgets('the reference lists the characters, grouped by stroke count',
      (tester) async {
    await pumpAt(tester, const Size(900, 2400), const HanziReferencePage());

    expect(find.text('Character reference'), findsOneWidget);
    expect(find.text('1 STROKE'), findsOneWidget);
    expect(find.text('2 STROKES'), findsOneWidget);
    // 一 is the one-stroke character, and it has to carry its English.
    expect(find.text('yī'), findsOneWidget);
  });

  testWidgets('there is a tab per script, and it opens on the selected one',
      (tester) async {
    await pumpAt(
      tester,
      const Size(900, 2400),
      HanziReferencePage(initialScript: hanziScriptForSlug('hiragana')),
    );

    for (final script in hanziScripts) {
      expect(find.text(script.name), findsWidgets, reason: script.slug);
    }
    // Opened on Hiragana, so its rows are the ones on screen — romaji, no
    // pinyin, and nothing claiming to be katakana.
    expect(find.text('hiragana'), findsWidgets);
    expect(find.text('yī'), findsNothing);
    expect(find.text('katakana'), findsNothing);
  });

  testWidgets('a script tab says how much of the set it narrows to',
      (tester) async {
    await pumpAt(
      tester,
      const Size(900, 2400),
      HanziReferencePage(initialScript: hanziScriptForSlug('korean')),
    );

    final korean = hanziScriptForSlug('korean');
    expect(
      find.textContaining('${korean.count} of the $hanziCharacterCount'),
      findsOneWidget,
    );
  });

  testWidgets('a narrow grid page reaches the reference by the info button',
      (tester) async {
    await pumpAt(tester, const Size(800, 2400), const HanziGridPage());

    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byType(ReferencePanel), findsNothing,
        reason: 'no room for the side panel this narrow');

    await tester.tap(find.byIcon(Icons.info_outline));
    // Not pumpAndSettle: the grid page behind this route holds a GameCanvas,
    // whose ticker never stops, so nothing on this stack ever settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Character reference'), findsOneWidget);
  });

  testWidgets('a wide grid page shows the reference beside the squares',
      (tester) async {
    await pumpAt(tester, const Size(1400, 2400), const HanziGridPage());

    expect(find.byType(ReferencePanel), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsNothing,
        reason: 'the button would open what is already on screen');
  });
}
