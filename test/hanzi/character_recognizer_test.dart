import 'package:cord/hanzi/data/hanzi_strokes.dart';
import 'package:cord/hanzi/data/stroke_models.dart';
import 'package:cord/hanzi/recognition/character_recognizer.dart';
import 'package:cord/hanzi/svg/path_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Upstream `hanzi`'s `test/character_recognizer_test.dart`, unchanged but for
/// the import paths — the recognition stack came across verbatim, so its tests
/// should too.

/// Replays a stored glyph as if it had been drawn by hand, in that variant's
/// own stroke order. The best possible input — if recognition cannot manage
/// this, nothing else will work either.
List<List<Offset>> traceGlyph(String glyphKey, {List<int>? order}) {
  final glyph = strokeGlyphs[glyphKey]!;
  final indices = order ?? [for (var i = 0; i < glyph.medians.length; i++) i];
  return [
    for (final i in indices) medianToScreen(glyph.source, glyph.medians[i]),
  ];
}

void main() {
  group('recognition', () {
    test('nothing drawn gives nothing back', () {
      expect(recognizeCharacter(const []), isEmpty);
      expect(recognizeCharacter([const [Offset(1, 1)]]), isEmpty);
    });

    test('tracing a stored glyph identifies that character', () {
      // A handful spanning different stroke counts.
      for (final key in ['ZH:王', 'ZH:田', 'ZH:口', 'ZH:女', 'ZH:心']) {
        final drawn = traceGlyph(key);
        final matches = recognizeCharacter(drawn);
        expect(matches, isNotEmpty, reason: key);
        expect(matches.first.char, strokeGlyphs[key]!.char, reason: key);
      }
    });

    test('only characters with the same stroke count are considered', () {
      final drawn = traceGlyph('ZH:王'); // 4 strokes
      for (final m in recognizeCharacter(drawn)) {
        expect(m.assignment.length, 4, reason: m.char);
      }
    });

    test('each character appears at most once in the results', () {
      final matches = recognizeCharacter(traceGlyph('ZH:田'));
      final chars = matches.map((m) => m.char).toList();
      expect(chars.toSet().length, chars.length);
    });

    test('results are ordered best first', () {
      final matches = recognizeCharacter(traceGlyph('ZH:口'));
      for (var i = 1; i < matches.length; i++) {
        expect(matches[i].score, greaterThanOrEqualTo(matches[i - 1].score));
      }
    });
  });

  group('stroke order', () {
    test('tracing in Chinese order matches the Chinese variant', () {
      final drawn = traceGlyph('ZH:王');
      final variants = variantsFor(drawn, '王');
      final zh = variants.firstWhere((v) => v.lang == Lang.zh);
      expect(zh.orderMatches, isTrue,
          reason: 'the Chinese variant should accept its own order');
    });

    test('tracing in Japanese order does NOT match the Chinese variant', () {
      // 王 is the documented case: Japan writes the vertical second, China
      // third. Trace the Japanese glyph and the Chinese order must object.
      final drawn = traceGlyph('JA:王');
      final variants = variantsFor(drawn, '王');

      final ja = variants.firstWhere((v) => v.lang == Lang.ja);
      expect(ja.orderMatches, isTrue, reason: 'Japanese order should match');

      final zh = variants.firstWhere((v) => v.lang == Lang.zh);
      expect(zh.orderMatches, isFalse,
          reason: 'Chinese order should not accept the Japanese sequence');
      expect(zh.firstOutOfOrder, greaterThanOrEqualTo(0));
    });

    test('shuffling the strokes keeps the character but breaks the order', () {
      final glyph = strokeGlyphs['ZH:田']!;
      final swapped = traceGlyph('ZH:田', order: [0, 1, 3, 2, 4]);

      final matches = recognizeCharacter(swapped);
      expect(matches, isNotEmpty);
      // Shape is unchanged — the same marks are on the page — so 田 must still
      // be found. This is exactly the "right character, wrong order" case.
      expect(matches.first.char, '田');
      expect(matches.first.unorderedDistance,
          lessThan(matches.first.orderedDistance),
          reason: 'ignoring order should fit better than honouring it');

      final zh = variantsFor(swapped, '田').firstWhere((v) => v.lang == Lang.zh);
      expect(zh.orderMatches, isFalse);
      expect(zh.firstOutOfOrder, 2,
          reason: 'strokes 3 and 4 were swapped, so it parts at index 2');
      expect(glyph.medians.length, 5);
    });

    test('a character all three traditions agree on matches every variant', () {
      // 口 is written the same way everywhere.
      final drawn = traceGlyph('ZH:口');
      final variants = variantsFor(drawn, '口');
      expect(variants.length, greaterThan(1),
          reason: '口 should exist in more than one language');
      for (final v in variants) {
        expect(v.orderMatches, isTrue, reason: '${v.lang.name} should agree');
      }
    });

    test('variantsFor returns nothing for an unknown character', () {
      expect(variantsFor(traceGlyph('ZH:王'), '龘'), isEmpty);
    });
  });

  group('normalisation', () {
    test('recognition is independent of where and how big it was drawn', () {
      final original = traceGlyph('ZH:王');
      final moved = [
        for (final s in original)
          [for (final p in s) p * 0.4 + const Offset(300, 120)],
      ];
      expect(recognizeCharacter(moved).first.char,
          recognizeCharacter(original).first.char);
    });
  });

  group('intersections', () {
    // The bug this group exists for: template matching compares where strokes
    // ARE, so it could not tell 人 from 九 — near-identical placement, but 九's
    // strokes cross while 人's only touch at the apex — nor 田 from 由, where
    // the vertical either stops at the box or passes through it.

    void expectDistinct(String a, String b) {
      for (final pair in [(a, b), (b, a)]) {
        final drawn = pair.$1;
        final other = pair.$2;
        final matches = recognizeCharacter(traceGlyph('ZH:$drawn'));
        expect(matches, isNotEmpty, reason: drawn);
        expect(matches.first.char, drawn,
            reason: '$drawn was read as ${matches.first.char}');
        final rival = matches.where((m) => m.char == other);
        if (rival.isNotEmpty) {
          expect(rival.first.score, greaterThan(matches.first.score),
              reason: '$other should not outrank $drawn');
        }
      }
    }

    test('人 and 九 are told apart — touch versus cross', () {
      expectDistinct('人', '九');
    });

    test('田 and 由 are told apart', () => expectDistinct('田', '由'));
    test('王 and 专 are told apart', () => expectDistinct('王', '专'));
    test('生 and 主 are told apart', () => expectDistinct('生', '主'));
    test('姓 and 性 are told apart', () => expectDistinct('姓', '性'));

    test('a character matched against itself has no topology penalty', () {
      for (final key in ['ZH:人', 'ZH:九', 'ZH:田', 'ZH:王']) {
        final match = recognizeCharacter(traceGlyph(key)).first;
        expect(match.topologyPenalty, closeTo(0, 1e-9), reason: key);
      }
    });

    test('the penalty is what separates the confusable pairs', () {
      final rival = recognizeCharacter(traceGlyph('ZH:人'))
          .where((m) => m.char == '九')
          .toList();
      // If 九 no longer even clears the cutoff that is a stronger result still.
      if (rival.isEmpty) return;
      expect(rival.first.topologyPenalty, greaterThan(0),
          reason: 'zero here would mean junctions are not compared at all');
    });
  });

  group('order sensitivity', () {
    // The flag exists because upstream's two drawing tabs want opposite
    // things: free drawing should still recognise a character written oddly,
    // while writing a known target should not let it pass. This page is the
    // free-drawing kind, and asks the order question separately.

    test('order-insensitive still reads 王 written the Japanese way', () {
      final drawn = traceGlyph('JA:王');
      final matches = recognizeCharacter(drawn);
      expect(matches.first.char, '王',
          reason: 'the forgiving default must be unchanged');
    });

    test('order-sensitive prefers the variant whose order was used', () {
      final drawn = traceGlyph('JA:王');
      final strict = recognizeCharacter(drawn, orderSensitive: true);
      expect(strict.first.char, '王');
      expect(strict.first.lang, Lang.ja,
          reason: 'written in the Japanese order, so the Japanese variant '
              'should win when order counts');
    });

    test('the flag actually changes the ranking', () {
      // Shuffling 田's strokes leaves the shape untouched, so the forgiving
      // ranking still finds it easily; the strict one must score it worse.
      final swapped = traceGlyph('ZH:田', order: [0, 1, 3, 2, 4]);
      final loose =
          recognizeCharacter(swapped).firstWhere((m) => m.char == '田');
      final strict = recognizeCharacter(swapped, orderSensitive: true)
          .where((m) => m.char == '田');
      expect(loose.unorderedDistance, lessThan(loose.orderedDistance),
          reason: 'a reordered 田 should fit better when order is ignored');
      if (strict.isNotEmpty) {
        expect(strict.first.orderedDistance,
            greaterThan(loose.unorderedDistance));
      }
    });

    test('writing in the correct order passes strictly', () {
      for (final key in ['ZH:王', 'ZH:口', 'ZH:田']) {
        final matches =
            recognizeCharacter(traceGlyph(key), orderSensitive: true);
        expect(matches, isNotEmpty, reason: key);
        expect(matches.first.char, strokeGlyphs[key]!.char, reason: key);
        expect(matches.first.orderMatches, isTrue, reason: key);
      }
    });
  });
}
