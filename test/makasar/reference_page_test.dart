import 'dart:io';

import 'package:cord/makasar/data/lontara_letters.dart';
import 'package:cord/makasar/data/makasar_letters.dart';
import 'package:cord/makasar/data/script.dart';
import 'package:cord/makasar/pages/reference_page.dart';
import 'package:cord/makasar/widgets/glyph_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Upstream `makasar`'s `test/reference_page_test.dart`. The page takes the
/// script it shows as a parameter here rather than carrying a dropdown of its
/// own — cord's page has one already — so what upstream reached by tapping
/// that dropdown is reached by pumping the other script instead.
void main() {
  group('ReferencePage', () {
    Future<void> open(WidgetTester tester, WritingScript script) async {
      await tester.pumpWidget(
        MaterialApp(home: ReferencePage(script: script)),
      );
      await tester.pump();
    }

    testWidgets('the Makasar table gives one drawn letterform per row',
        (tester) async {
      await open(tester, WritingScript.makasar);

      // Every letter, vowel sign and other sign gets a row, so every one gets
      // a GlyphImage — angka's is the empty placeholder.
      expect(
        find.byType(GlyphImage),
        findsNWidgets(makasarLetters.length +
            makasarVowelSigns.length +
            makasarOtherSigns.length),
      );
      expect(find.text('Makasar script reference'), findsOneWidget);
      expect(find.text('Letterform'), findsOneWidget);
      expect(find.text('Notes'), findsNothing);
    });

    testWidgets('the Bugis table names what each letter lines up with',
        (tester) async {
      await open(tester, WritingScript.bugis);

      expect(
        find.byType(GlyphImage),
        findsNWidgets(lontaraLetters.length +
            lontaraVowelSigns.length +
            lontaraOtherSigns.length),
      );
      // Lontara rows show a codepoint rather than the character — nothing in
      // the bundle renders the Buginese block.
      expect(find.text('U+1A00'), findsOneWidget);
      // The Notes column says what to draw once a letter can be drawn…
      for (final letter in lontaraLetters) {
        if (letter.shape != null) {
          expect(find.text(letter.shape!), findsOneWidget, reason: letter.name);
        }
      }
      // …and otherwise names what it lines up with in Makasar, or says it
      // lines up with nothing — the prenasalized series (ngka, mpa, nra, nca)
      // plus ha, less any of them that has a shape by now.
      final unmatched = lontaraLetters.where(
          (letter) => letter.makasarName == null && letter.shape == null);
      expect(find.text('no Makasar letter'), findsNWidgets(unmatched.length));
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Letterform'), findsNothing);
    });
  });

  test('every glyph image names a bundled asset, and none is unused', () {
    final names = <String>{
      for (final letter in makasarLetters) letter.image,
      for (final sign in makasarVowelSigns) sign.image,
      for (final sign in makasarOtherSigns)
        if (sign.image != null) sign.image!,
      for (final letter in lontaraLetters) letter.image,
      for (final sign in lontaraVowelSigns) sign.image,
      for (final sign in lontaraOtherSigns) sign.image,
    };

    // Checked against the directory rather than a hand-kept list, so a renamed
    // or dropped asset surfaces here instead of as a blank row.
    final files = Directory('assets/makasar/glyphs')
        .listSync()
        .map((entry) => entry.uri.pathSegments.last)
        .where((file) => file.endsWith('.png'))
        .map((file) => file.substring(0, file.length - 4))
        .toSet();

    expect(names.difference(files), isEmpty, reason: 'missing asset');
    expect(files.difference(names), isEmpty, reason: 'unused asset');
  });
}
