import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:cord/hangul_grid/recognition/block_recognizer.dart';

/// Writes whole syllable blocks and checks what they are read as.
///
/// Each letter is defined once, in its own unit square, at the proportions
/// the recognizer's own tests use. [place] drops one into a region of the
/// block, which is what makes a test read like the layout it is testing:
/// 각 is ㄱ top-left, ㅏ top-right, ㄱ along the bottom.

const double _block = 200;

/// A letter, as strokes in a unit square. Curves are already sampled.
typedef Shape = List<List<Offset>>;

List<Offset> _line(Offset a, Offset b, {int steps = 16}) =>
    [for (var i = 0; i <= steps; i++) Offset.lerp(a, b, i / steps)!];

List<Offset> _bend(Offset a, Offset corner, Offset b, {int steps = 12}) => [
      for (var i = 0; i <= steps; i++) Offset.lerp(a, corner, i / steps)!,
      for (var i = 1; i <= steps; i++) Offset.lerp(corner, b, i / steps)!,
    ];

/// A loop that overshoots and drifts, so it crosses itself once — the way a
/// hand draws ㅇ, and what the classifier looks for.
List<Offset> _loop({int steps = 60}) {
  const overshoot = 0.2;
  const drift = Offset(0.13, -0.2);
  const sweep = 2 * math.pi * (1 + overshoot);
  return [
    for (var i = 0; i <= steps; i++)
      () {
        final t = i / steps;
        final c = const Offset(0.5, 0.5) + drift * t;
        return Offset(
          c.dx + 0.35 * math.cos(t * sweep),
          c.dy + 0.35 * math.sin(t * sweep),
        );
      }(),
  ];
}

Rect _bounds(List<Offset> points) {
  var minX = points.first.dx, maxX = minX;
  var minY = points.first.dy, maxY = minY;
  for (final p in points) {
    minX = math.min(minX, p.dx);
    maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Rescales a stroke so its own bounding box fills [box].
List<Offset> _into(List<Offset> stroke, Rect box) {
  final b = _bounds(stroke);
  return [
    for (final p in stroke)
      Offset(
        box.left + (b.width == 0 ? 0.5 : (p.dx - b.left) / b.width) * box.width,
        box.top +
            (b.height == 0 ? 0.5 : (p.dy - b.top) / b.height) * box.height,
      ),
  ];
}

/// The letters, each drawn to fill its own unit square, at the proportions
/// the recognizer's own tests use.
final shapes = <String, Shape>{
  'ㄱ': [_bend(const Offset(0, 0), const Offset(1, 0), const Offset(1, 1))],
  'ㄴ': [_bend(const Offset(0, 0), const Offset(0, 1), const Offset(1, 1))],
  'ㄷ': [
    _bend(const Offset(0, 0), const Offset(0, 1), const Offset(1, 1)),
    _line(const Offset(0, 0), const Offset(1, 0)),
  ],
  'ㅁ': [
    _bend(const Offset(0, 0), const Offset(1, 0), const Offset(1, 1)),
    _line(const Offset(0, 0), const Offset(0, 1)),
    _line(const Offset(0, 1), const Offset(1, 1)),
  ],
  'ㅂ': [
    _line(const Offset(0, 0), const Offset(0, 1)),
    _line(const Offset(1, 0), const Offset(1, 1)),
    _line(const Offset(0, 0.5), const Offset(1, 0.5)),
    _line(const Offset(0, 1), const Offset(1, 1)),
  ],
  'ㄹ': [
    _bend(const Offset(0, 0), const Offset(1, 0), const Offset(1, 0.5)),
    _line(const Offset(0, 0.5), const Offset(1, 0.5)),
    _bend(const Offset(0, 0.5), const Offset(0, 1), const Offset(1, 1)),
  ],
  'ㅇ': [_into(_loop(), const Rect.fromLTRB(0, 0, 1, 1))],
  'ㅅ': [
    _line(const Offset(0.5, 0), const Offset(1, 1)),
    _line(const Offset(0.5, 0), const Offset(0, 1)),
  ],
  // A loop with two bars stacked over it. The lower bar has to come close
  // enough to rest on the loop — that contact is part of what makes it ㅎ
  // rather than a circle with lines floating above it.
  'ㅎ': [
    _into(_loop(), const Rect.fromLTRB(0, 0.182, 1, 1)),
    _line(const Offset(0.12, 0.159), const Offset(0.90, 0.159)),
    _line(const Offset(0.12, 0), const Offset(0.90, 0)),
  ],
  // Vowels: a stem with a tick, or a bar with a tick.
  'ㅣ': [_line(const Offset(0.5, 0), const Offset(0.5, 1))],
  'ㅡ': [_line(const Offset(0, 0.5), const Offset(1, 0.5))],
  'ㅏ': [
    _line(const Offset(0, 0), const Offset(0, 1)),
    _line(const Offset(0, 0.3), const Offset(1, 0.3)),
  ],
  'ㅓ': [
    _line(const Offset(1, 0), const Offset(1, 1)),
    _line(const Offset(0, 0.3), const Offset(1, 0.3)),
  ],
  'ㅗ': [
    _line(const Offset(0, 1), const Offset(1, 1)),
    _line(const Offset(0.5, 0), const Offset(0.5, 1)),
  ],
  'ㅜ': [
    _line(const Offset(0, 0), const Offset(1, 0)),
    _line(const Offset(0.5, 0), const Offset(0.5, 1)),
  ],
  // ㅘ is ㅗ with a ㅏ crossing its bar — one shape, not two letters.
  'ㅘ': [
    _line(const Offset(0, 0.417), const Offset(1, 0.417)),
    _line(const Offset(0.294, 0), const Offset(0.294, 0.417)),
    _line(const Offset(0.706, 0.083), const Offset(0.706, 1)),
    _line(const Offset(0.706, 0.25), const Offset(0.941, 0.25)),
  ],
};

/// How wide each letter is relative to its height when written normally.
///
/// It matters: several classifiers are proportion tests. A ㅏ whose tick is
/// more than half its stem is not a ㅏ, so a shape stretched into a square
/// stops being the letter it was drawn as.
const aspects = <String, double>{
  'ㄱ': 0.71, 'ㄴ': 0.79, 'ㄷ': 0.79, 'ㅁ': 1.0, 'ㅂ': 0.83, 'ㄹ': 0.63, //
  'ㅇ': 1.0, 'ㅅ': 1.17, 'ㅎ': 0.75, 'ㅣ': 0.22, 'ㅡ': 4.5, 'ㅏ': 0.32, //
  'ㅓ': 0.32, 'ㅗ': 3.0, 'ㅜ': 3.0, 'ㅘ': 1.42,
};

/// A region of the block with [glyph]'s natural proportions, centred.
Rect naturalRegion(String glyph) {
  final aspect = aspects[glyph]!;
  final w = aspect >= 1 ? 0.8 : 0.8 * aspect;
  final h = aspect >= 1 ? 0.8 / aspect : 0.8;
  return Rect.fromLTWH((1 - w) / 2, (1 - h) / 2, w, h);
}

/// Places [glyph] into [region], given in fractions of the block.
Shape place(String glyph, Rect region) {
  final shape = shapes[glyph];
  expect(shape, isNotNull, reason: 'no test shape for $glyph');
  return [
    for (final stroke in shape!)
      [
        for (final p in stroke)
          Offset(
            (region.left + p.dx * region.width) * _block,
            (region.top + p.dy * region.height) * _block,
          ),
      ],
  ];
}

Rect r(double l, double t, double w, double h) => Rect.fromLTWH(l, t, w, h);

BlockReading? read(List<Shape> pieces) => recognizeBlock(
      [for (final piece in pieces) ...piece],
      blockSize: _block,
    );

String? textOf(List<Shape> pieces) => read(pieces)?.text;

void main() {
  group('the test shapes are what they claim to be', () {
    // Guards the rest of the file: a segmentation failure and a badly drawn
    // letter look identical from the outside, and this tells them apart.
    //
    // ㄹ is the one letter that does not read back as itself, and rightly
    // so: alone in a block, ㄱ over a bar over ㄴ *is* the shape of 근. This
    // canvas reads blocks, and nothing in the strokes says otherwise. It is
    // only ambiguous on its own — as a final, under a vowel, ㄹ reads as ㄹ
    // (see 닭).
    const readsAs = {'ㄹ': '근'};

    for (final glyph in shapes.keys) {
      test(glyph, () {
        final reading = read([place(glyph, naturalRegion(glyph))]);
        expect(reading?.text, readsAs[glyph] ?? glyph);
      });
    }
  });

  group('side by side — onset left, vowel right', () {
    test('가', () {
      expect(
        textOf([
          place('ㄱ', r(0.10, 0.18, 0.36, 0.55)),
          place('ㅏ', r(0.58, 0.10, 0.30, 0.80)),
        ]),
        '가',
      );
    });

    test('너', () {
      expect(
        textOf([
          place('ㄴ', r(0.10, 0.20, 0.34, 0.52)),
          place('ㅓ', r(0.56, 0.10, 0.32, 0.80)),
        ]),
        '너',
      );
    });

    test('미', () {
      expect(
        textOf([
          place('ㅁ', r(0.10, 0.25, 0.34, 0.45)),
          place('ㅣ', r(0.60, 0.10, 0.24, 0.80)),
        ]),
        '미',
      );
    });

    test('하', () {
      expect(
        textOf([
          place('ㅎ', r(0.08, 0.15, 0.36, 0.65)),
          place('ㅏ', r(0.62, 0.08, 0.26, 0.84)),
        ]),
        '하',
      );
    });
  });

  group('stacked — onset above, vowel below', () {
    test('고', () {
      expect(
        textOf([
          place('ㄱ', r(0.28, 0.12, 0.44, 0.34)),
          place('ㅗ', r(0.10, 0.55, 0.80, 0.35)),
        ]),
        '고',
      );
    });

    test('누', () {
      expect(
        textOf([
          place('ㄴ', r(0.28, 0.12, 0.42, 0.32)),
          place('ㅜ', r(0.10, 0.55, 0.80, 0.35)),
        ]),
        '누',
      );
    });

    test('스', () {
      expect(
        textOf([
          place('ㅅ', r(0.28, 0.12, 0.44, 0.38)),
          place('ㅡ', r(0.10, 0.62, 0.80, 0.20)),
        ]),
        '스',
      );
    });
  });

  group('with a final underneath', () {
    test('각 — side by side over a final', () {
      expect(
        textOf([
          place('ㄱ', r(0.10, 0.10, 0.34, 0.38)),
          place('ㅏ', r(0.60, 0.06, 0.18, 0.52)),
          place('ㄱ', r(0.26, 0.68, 0.44, 0.26)),
        ]),
        '각',
      );
    });

    test('안', () {
      expect(
        textOf([
          place('ㅇ', r(0.08, 0.08, 0.36, 0.44)),
          place('ㅏ', r(0.60, 0.04, 0.19, 0.54)),
          place('ㄴ', r(0.24, 0.68, 0.46, 0.26)),
        ]),
        '안',
      );
    });

    test('한', () {
      expect(
        textOf([
          place('ㅎ', r(0.08, 0.04, 0.36, 0.52)),
          place('ㅏ', r(0.60, 0.02, 0.19, 0.56)),
          place('ㄴ', r(0.24, 0.70, 0.46, 0.24)),
        ]),
        '한',
      );
    });

    test('곡 — stacked over a final', () {
      expect(
        textOf([
          place('ㄱ', r(0.30, 0.05, 0.40, 0.24)),
          place('ㅗ', r(0.10, 0.36, 0.80, 0.26)),
          place('ㄱ', r(0.28, 0.72, 0.42, 0.22)),
        ]),
        '곡',
      );
    });

    test('공', () {
      expect(
        textOf([
          place('ㄱ', r(0.30, 0.05, 0.40, 0.22)),
          place('ㅗ', r(0.10, 0.34, 0.80, 0.26)),
          place('ㅇ', r(0.30, 0.66, 0.40, 0.28)),
        ]),
        '공',
      );
    });

    // 물 is the most crowded block in the word list: three wide letters
    // stacked in one square, with six near-full-width horizontal strokes
    // between them and almost no room to spare. It is the case most likely
    // to break if the overlap tolerance or the gap scoring is ever loosened.
    //
    // It also pins ㄹ from the other side. Alone in a square ㄹ reads as 근
    // — ㄱ over a bar over ㄴ really is 근's shape — but under a vowel it is
    // unambiguously a final. 닭 shows that for a two-letter final; this
    // shows it for a plain one.
    test('물 — three wide letters stacked, barely any room between them', () {
      expect(
        textOf([
          place('ㅁ', r(0.32, 0.06, 0.36, 0.26)),
          place('ㅜ', r(0.10, 0.36, 0.80, 0.26)),
          place('ㄹ', r(0.32, 0.66, 0.36, 0.28)),
        ]),
        '물',
      );
    });

    test('물 — and again with the tiers set further apart', () {
      expect(
        textOf([
          place('ㅁ', r(0.33, 0.04, 0.34, 0.22)),
          place('ㅜ', r(0.08, 0.34, 0.84, 0.22)),
          place('ㄹ', r(0.30, 0.66, 0.40, 0.30)),
        ]),
        '물',
      );
    });
  });

  group('wrapped — the vowel goes under and around', () {
    test('과', () {
      expect(
        textOf([
          place('ㄱ', r(0.08, 0.08, 0.28, 0.26)),
          // The vowel wraps: its ㅗ half sits under the onset and its ㅏ half
          // runs down the right of the whole block.
          place('ㅘ', r(0.06, 0.40, 0.84, 0.52)),
        ]),
        '과',
      );
    });
  });

  group('two-letter finals', () {
    test('값', () {
      expect(
        textOf([
          place('ㄱ', r(0.08, 0.08, 0.32, 0.36)),
          place('ㅏ', r(0.58, 0.04, 0.18, 0.52)),
          place('ㅂ', r(0.08, 0.66, 0.34, 0.28)),
          place('ㅅ', r(0.54, 0.66, 0.34, 0.28)),
        ]),
        '값',
      );
    });

    test('닭', () {
      expect(
        textOf([
          place('ㄷ', r(0.08, 0.08, 0.32, 0.36)),
          place('ㅏ', r(0.58, 0.04, 0.18, 0.52)),
          place('ㄹ', r(0.08, 0.66, 0.34, 0.28)),
          place('ㄱ', r(0.54, 0.66, 0.34, 0.28)),
        ]),
        '닭',
      );
    });
  });

  group('partial blocks', () {
    test('a lone consonant reads as itself', () {
      final reading = read([place('ㄱ', r(0.2, 0.2, 0.5, 0.5))]);
      expect(reading?.text, 'ㄱ');
      expect(reading?.layout, BlockLayout.partial);
    });

    test('a lone vowel reads as itself', () {
      final reading = read([place('ㅏ', r(0.3, 0.1, 0.4, 0.8))]);
      expect(reading?.text, 'ㅏ');
    });

    test('an empty block reads as nothing', () {
      expect(recognizeBlock(const [], blockSize: _block), isNull);
    });

    test('a scribble reads as nothing', () {
      expect(
        recognizeBlock([
          _line(const Offset(20, 20), const Offset(180, 180)),
        ], blockSize: _block),
        isNull,
      );
    });
  });

  group('the reading feeds the composer', () {
    test('a whole block reports its letters in writing order', () {
      final reading = read([
        place('ㅇ', r(0.08, 0.08, 0.36, 0.44)),
        place('ㅏ', r(0.60, 0.04, 0.19, 0.54)),
        place('ㄴ', r(0.24, 0.68, 0.46, 0.26)),
      ]);
      expect(reading?.jamo, ['ㅇ', 'ㅏ', 'ㄴ']);
    });
  });
}
