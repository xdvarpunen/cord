import 'package:cord/hanzi/data/hanzi_glosses.dart';
import 'package:cord/hanzi/data/hanzi_scripts.dart';
import 'package:cord/hanzi/data/hanzi_strokes.dart';
import 'package:cord/hanzi/recognition/character_recognizer.dart';
import 'package:cord/hanzi/svg/path_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// The script selector, as a set of glyphs rather than as a widget.
///
/// The property worth pinning is that narrowing the script narrows what the
/// recognizer can *answer with*, not merely what is displayed afterwards — a
/// filter over the results would report the wrong variant's score and could
/// drop a character outright.

List<List<Offset>> traceGlyph(String glyphKey) {
  final glyph = strokeGlyphs[glyphKey]!;
  return [
    for (final median in glyph.medians) medianToScreen(glyph.source, median),
  ];
}

HanziScript script(String slug) => hanziScriptForSlug(slug);

void main() {
  group('the registry', () {
    test('every script holds something, and Everything holds the lot', () {
      for (final s in hanziScripts) {
        expect(s.count, greaterThan(0), reason: s.name);
      }
      final all = {for (final g in strokeGlyphs.values) g.char};
      expect(script('all').count, all.length);
    });

    test('the parts add up to the whole, without overlapping', () {
      final parts = ['chinese', 'japanese', 'korean', 'hiragana', 'katakana'];
      final union = <String>{};
      for (final slug in parts) {
        for (final entry in glyphsOf(script(slug))) {
          union.add(entry.value.char);
        }
      }
      expect(union.length, script('all').count,
          reason: 'a character in no script could never be selected for');

      // Han characters are shared between traditions, so those overlap by
      // design. The two kana sets must not: a syllable is one or the other.
      final hiragana = {
        for (final e in glyphsOf(script('hiragana'))) e.value.char,
      };
      final katakana = {
        for (final e in glyphsOf(script('katakana'))) e.value.char,
      };
      expect(hiragana.intersection(katakana), isEmpty);
    });

    test('kana are kept out of the three traditions', () {
      // They come from KanjiVG under the same JA: keys as the kanji, so this
      // is the one place the distinction has to be made by hand.
      final kana = {
        for (final e in glyphsOf(script('hiragana'))) e.value.char,
        for (final e in glyphsOf(script('katakana'))) e.value.char,
      };
      for (final slug in ['chinese', 'japanese', 'korean']) {
        for (final entry in glyphsOf(script(slug))) {
          expect(kana.contains(entry.value.char), isFalse,
              reason: '${entry.value.char} in ${script(slug).name}');
        }
      }
    });

    test('an unknown or missing slug falls back to Everything', () {
      expect(hanziScriptForSlug(null).slug, 'all');
      expect(hanziScriptForSlug('klingon').slug, 'all');
      expect(hanziScriptForSlug('korean').slug, 'korean');
    });

    test('every script listed can be glossed', () {
      for (final s in hanziScripts) {
        for (final entry in glyphsOf(s)) {
          expect(hanziGlosses.containsKey(entry.value.char), isTrue,
              reason: '${entry.value.char} in ${s.name}');
        }
      }
    });
  });

  group('what the selector does to recognition', () {
    test('a script the character is not in cannot answer with it', () {
      // 中 is in the table only as a Korean glyph.
      final drawn = traceGlyph('KO:中');
      expect(recognizeCharacter(drawn, where: script('korean').holds).first.char,
          '中');
      expect(
        recognizeCharacter(drawn, where: script('chinese').holds)
            .where((m) => m.char == '中'),
        isEmpty,
        reason: 'Chinese does not carry 中, so it must not be offered',
      );
    });

    test('narrowing removes rivals rather than hiding them', () {
      // 口 exists in all three, so the winner is unchanged — but the field it
      // beat is smaller, which is the whole reason to narrow.
      final drawn = traceGlyph('ZH:口');
      final wide = recognizeCharacter(drawn, where: script('all').holds);
      final narrow = recognizeCharacter(drawn, where: script('chinese').holds);

      expect(wide.first.char, '口');
      expect(narrow.first.char, '口');
      expect(narrow.length, lessThan(wide.length));
      expect(narrow.first.confidence, closeTo(wide.first.confidence, 1e-9),
          reason: 'the winning fit itself must not move');
    });

    test('a kana script answers with kana only', () {
      final kana = {
        for (final e in glyphsOf(script('hiragana'))) e.value.char,
      };
      // Something with a stroke count kana share with kanji, so the filter is
      // doing real work rather than being carried by the stroke-count gate.
      final drawn = traceGlyph('ZH:口');
      for (final m in recognizeCharacter(drawn, where: script('hiragana').holds)) {
        expect(kana.contains(m.char), isTrue, reason: m.char);
      }
    });

    test('omitting the filter is exactly upstream behaviour', () {
      // The parameter is cord's one addition to a verbatim file; with it
      // omitted nothing may change.
      final drawn = traceGlyph('ZH:王');
      final plain = recognizeCharacter(drawn);
      final everything = recognizeCharacter(drawn, where: script('all').holds);
      expect(plain.map((m) => m.char).toList(),
          everything.map((m) => m.char).toList());
    });
  });
}
