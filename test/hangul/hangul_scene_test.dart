import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cord/hangul/data/hangul_jamo.dart';
import 'package:cord/hangul/scenes/hangul_scene.dart';

/// Feeds [layer] a stroke from [from] to [to] as the pointer events a real
/// drag would produce: a down, a run of moves along the line, and an up.
/// [steps] controls how finely the line is sampled — the recognizer's
/// straightness and touch checks both walk the captured points, so a
/// stroke has to arrive as a path, not just its endpoints.
void drawStroke(HangulLayer layer, Offset from, Offset to, {int steps = 20}) {
  const size = Size(400, 400);
  layer.handlePointerEvent(PointerDownEvent(position: from), size);
  for (var i = 1; i <= steps; i++) {
    final point = Offset.lerp(from, to, i / steps)!;
    layer.handlePointerEvent(PointerMoveEvent(position: point), size);
  }
  layer.handlePointerEvent(PointerUpEvent(position: to), size);
}

/// Feeds [layer] a single stroke tracing a loop: a circle of [radius]
/// around [center] swept a little past a full turn, its center drifting by
/// [drift] as it's drawn so the closing pass comes back off-center and
/// crosses the opening one — the way a hand draws ㅇ. A concentric retrace
/// would merely overlap itself; the drift is what turns the overshoot into
/// an actual crossing. Positive [drift] with a modest [overshoot] leaves
/// exactly one crossing.
void drawLoop(HangulLayer layer, Offset center, double radius,
    {int steps = 60,
    double overshoot = 0.2,
    Offset drift = const Offset(26, -40)}) {
  const size = Size(400, 400);
  final sweep = 2 * math.pi * (1 + overshoot);
  Offset at(double t) {
    final c = center + drift * t;
    return Offset(
      c.dx + radius * math.cos(t * sweep),
      c.dy + radius * math.sin(t * sweep),
    );
  }

  layer.handlePointerEvent(PointerDownEvent(position: at(0)), size);
  for (var i = 1; i <= steps; i++) {
    layer.handlePointerEvent(PointerMoveEvent(position: at(i / steps)), size);
  }
  layer.handlePointerEvent(PointerUpEvent(position: at(1)), size);
}

/// Feeds [layer] a single bent stroke: [a] to [corner] to [b], each leg
/// sampled as a run of moves, so the recognizer sees a genuine two-legged
/// corner (as ㄱ and ㄴ are) rather than just three points.
void drawCorner(HangulLayer layer, Offset a, Offset corner, Offset b,
    {int steps = 20}) {
  const size = Size(400, 400);
  layer.handlePointerEvent(PointerDownEvent(position: a), size);
  for (var i = 1; i <= steps; i++) {
    layer.handlePointerEvent(
        PointerMoveEvent(position: Offset.lerp(a, corner, i / steps)!), size);
  }
  for (var i = 1; i <= steps; i++) {
    layer.handlePointerEvent(
        PointerMoveEvent(position: Offset.lerp(corner, b, i / steps)!), size);
  }
  layer.handlePointerEvent(PointerUpEvent(position: b), size);
}

void main() {
  group('single strokes', () {
    test('a straight vertical line is ㅣ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'ㅣ');
    });

    test('a straight horizontal line is ㅡ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(100, 200), const Offset(300, 200));
      expect(layer.recognizedGlyph, 'ㅡ');
    });

    test('a diagonal is neither ㅣ nor ㅡ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(100, 100), const Offset(300, 300));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a slight slant still reads as ㅣ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(200, 100), const Offset(215, 300));
      expect(layer.recognizedGlyph, 'ㅣ');
    });

    test('a curve is not ㅣ, even end-to-end vertical', () {
      final layer = HangulLayer();
      // A bowed path: same endpoints as a vertical, but bulging right.
      const start = Offset(200, 100);
      const end = Offset(200, 300);
      layer.handlePointerEvent(
          const PointerDownEvent(position: start), const Size(400, 400));
      for (var i = 1; i <= 20; i++) {
        final t = i / 20;
        final point = Offset(200 + 60 * (t * (1 - t) * 4), 100 + 200 * t);
        layer.handlePointerEvent(
            PointerMoveEvent(position: point), const Size(400, 400));
      }
      layer.handlePointerEvent(
          const PointerUpEvent(position: end), const Size(400, 400));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a loop that crosses itself once is ㅇ', () {
      final layer = HangulLayer();
      drawLoop(layer, const Offset(200, 200), 70);
      expect(layer.recognizedGlyph, 'ㅇ');
    });

    test('an open circle that never crosses is not ㅇ', () {
      final layer = HangulLayer();
      // Just shy of a full turn: the ends stop near each other but never
      // cross, so there's no self-intersection to read as a loop.
      drawLoop(layer, const Offset(200, 200), 70, overshoot: -0.08);
      expect(layer.recognizedGlyph, isNull);
    });

    test('a straight line does not read as ㅇ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      expect(layer.recognizedGlyph, isNot('ㅇ'));
    });
  });

  group('corners', () {
    test('a horizontal-then-down corner is ㄱ', () {
      final layer = HangulLayer();
      drawCorner(layer, const Offset(150, 120), const Offset(250, 120),
          const Offset(250, 260));
      expect(layer.recognizedGlyph, 'ㄱ');
    });

    test('a down-then-right corner is ㄴ', () {
      final layer = HangulLayer();
      drawCorner(layer, const Offset(150, 120), const Offset(150, 260),
          const Offset(260, 260));
      expect(layer.recognizedGlyph, 'ㄴ');
    });

    test('ㄱ and ㄴ are told apart by which side of the chord bends', () {
      final giyeok = HangulLayer();
      drawCorner(giyeok, const Offset(150, 120), const Offset(250, 120),
          const Offset(250, 260));
      expect(giyeok.recognizedGlyph, 'ㄱ');

      final nieun = HangulLayer();
      drawCorner(nieun, const Offset(150, 120), const Offset(150, 260),
          const Offset(260, 260));
      expect(nieun.recognizedGlyph, 'ㄴ');
    });

    test('a straight descending diagonal is neither ㄱ nor ㄴ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(120, 120), const Offset(260, 260));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a ㄴ with a bar across its top is ㄷ', () {
      final layer = HangulLayer();
      drawCorner(layer, const Offset(150, 120), const Offset(150, 260),
          const Offset(260, 260));
      drawStroke(layer, const Offset(150, 120), const Offset(260, 120));
      expect(layer.recognizedGlyph, 'ㄷ');
    });

    test('ㄷ drawn top-bar-first still reads as ㄷ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(260, 120));
      drawCorner(layer, const Offset(150, 120), const Offset(150, 260),
          const Offset(260, 260));
      expect(layer.recognizedGlyph, 'ㄷ');
    });

    test('a ㄴ with a bar that misses its top is not ㄷ', () {
      final layer = HangulLayer();
      drawCorner(layer, const Offset(150, 120), const Offset(150, 260),
          const Offset(260, 260));
      // A bar off on its own, nowhere near the corner's top.
      drawStroke(layer, const Offset(50, 60), const Offset(110, 60));
      expect(layer.recognizedGlyph, isNot('ㄷ'));
    });
  });

  group('rieul', () {
    // A ㄷ (ㄴ capped by a middle bar) with a ㄱ on top hooking onto the bar
    // — the ㄹ zigzag: top bar, down right, middle bar, down left, bottom bar.
    void drawRieul(HangulLayer layer) {
      drawCorner(layer, const Offset(150, 120), const Offset(250, 120),
          const Offset(250, 200)); // ㄱ: top bar + right down
      drawStroke(layer, const Offset(150, 200), const Offset(250, 200)); // bar
      drawCorner(layer, const Offset(150, 200), const Offset(150, 280),
          const Offset(250, 280)); // ㄴ: left down + bottom bar
    }

    test('a ㄷ with a ㄱ hooked onto its bar is ㄹ', () {
      final layer = HangulLayer();
      drawRieul(layer);
      expect(layer.recognizedGlyph, 'ㄹ');
    });

    test('a ㄷ with no ㄱ on top is just ㄷ, not ㄹ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(150, 200), const Offset(250, 200)); // bar
      drawCorner(layer, const Offset(150, 200), const Offset(150, 280),
          const Offset(250, 280)); // ㄴ
      expect(layer.recognizedGlyph, 'ㄷ');
    });

    test('a ㄷ with a ㄱ that misses the bar is not ㄹ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(150, 200), const Offset(250, 200)); // bar
      drawCorner(layer, const Offset(150, 200), const Offset(150, 280),
          const Offset(250, 280)); // ㄴ
      // A ㄱ off on its own, nowhere near the bar.
      drawCorner(layer, const Offset(30, 40), const Offset(90, 40),
          const Offset(90, 90));
      expect(layer.recognizedGlyph, isNot('ㄹ'));
    });
  });

  group('siot', () {
    // 人: a descending and an ascending diagonal meeting at the apex.
    void drawSiot(HangulLayer layer) {
      drawStroke(layer, const Offset(200, 120), const Offset(270, 240)); // \
      drawStroke(layer, const Offset(200, 120), const Offset(130, 240)); // /
    }

    test('an ascending and a descending diagonal that meet is ㅅ', () {
      final layer = HangulLayer();
      drawSiot(layer);
      expect(layer.recognizedGlyph, 'ㅅ');
    });

    test('two diagonals sloping the same way are not ㅅ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(270, 240)); // \
      drawStroke(layer, const Offset(130, 120), const Offset(200, 240)); // \
      expect(layer.recognizedGlyph, isNot('ㅅ'));
    });

    test('two crossed diagonals that never meet are not ㅅ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(270, 240)); // \
      // An ascending diagonal off on the far left, nowhere near the first.
      drawStroke(layer, const Offset(40, 240), const Offset(110, 120)); // /
      expect(layer.recognizedGlyph, isNot('ㅅ'));
    });
  });

  group('tieut', () {
    // A ㄴ crossed by a top and a middle bar — ㅌ's three rungs.
    void drawTieut(HangulLayer layer) {
      drawCorner(layer, const Offset(150, 120), const Offset(150, 240),
          const Offset(250, 240)); // ㄴ: left down + bottom bar
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120)); // top
      drawStroke(layer, const Offset(150, 180), const Offset(250, 180)); // middle
    }

    test('a ㄴ crossed by two bars is ㅌ', () {
      final layer = HangulLayer();
      drawTieut(layer);
      expect(layer.recognizedGlyph, 'ㅌ');
    });

    test('a ㄴ with a single bar is ㄷ, not ㅌ', () {
      final layer = HangulLayer();
      drawCorner(layer, const Offset(150, 120), const Offset(150, 240),
          const Offset(250, 240)); // ㄴ
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120)); // top
      expect(layer.recognizedGlyph, 'ㄷ');
    });

    test('a ㄴ with a bar that misses it is not ㅌ', () {
      final layer = HangulLayer();
      drawCorner(layer, const Offset(150, 120), const Offset(150, 240),
          const Offset(250, 240)); // ㄴ
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120)); // top
      // A second bar off on its own, not touching the ㄴ.
      drawStroke(layer, const Offset(40, 60), const Offset(110, 60));
      expect(layer.recognizedGlyph, isNot('ㅌ'));
    });
  });

  group('complex vowels', () {
    test('ㅓ beside a trailing ㅣ is ㅔ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(200, 120), const Offset(200, 240)); // stem
      drawStroke(l, const Offset(140, 180), const Offset(200, 180)); // left tick
      drawStroke(l, const Offset(260, 120), const Offset(260, 240)); // ㅣ
      expect(l.recognizedGlyph, 'ㅔ');
    });

    test('ㅕ beside a trailing ㅣ is ㅖ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(200, 120), const Offset(200, 240)); // stem
      drawStroke(l, const Offset(140, 160), const Offset(200, 160)); // tick 1
      drawStroke(l, const Offset(140, 200), const Offset(200, 200)); // tick 2
      drawStroke(l, const Offset(260, 120), const Offset(260, 240)); // ㅣ
      expect(l.recognizedGlyph, 'ㅖ');
    });

    test('two stems bridged by a tick touching both is ㅐ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(185, 120), const Offset(185, 260)); // ㅏ stem
      drawStroke(l, const Offset(240, 120), const Offset(240, 260)); // ㅣ
      drawStroke(l, const Offset(185, 190), const Offset(240, 190)); // bridging tick
      expect(l.recognizedGlyph, 'ㅐ');
    });

    test('two stems bridged by two short ticks is ㅒ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(180, 120), const Offset(180, 260)); // ㅑ stem
      drawStroke(l, const Offset(230, 120), const Offset(230, 260)); // ㅣ
      drawStroke(l, const Offset(180, 160), const Offset(230, 160)); // tick 1
      drawStroke(l, const Offset(180, 200), const Offset(230, 200)); // tick 2
      expect(l.recognizedGlyph, 'ㅒ');
    });

    test('a plain ㅂ ladder stays ㅂ, not ㅒ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(150, 120), const Offset(150, 240)); // left
      drawStroke(l, const Offset(250, 120), const Offset(250, 240)); // right
      drawStroke(l, const Offset(150, 180), const Offset(250, 180)); // mid
      drawStroke(l, const Offset(150, 240), const Offset(250, 240)); // bottom
      expect(l.recognizedGlyph, 'ㅂ');
    });

    test('a plain ㅓ stays ㅓ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(200, 120), const Offset(200, 240));
      drawStroke(l, const Offset(140, 180), const Offset(200, 180));
      expect(l.recognizedGlyph, 'ㅓ');
    });

    test('a horizontal and vertical of comparable length that meet is ㅢ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(180, 150), const Offset(240, 150)); // ㅡ
      drawStroke(l, const Offset(240, 150), const Offset(240, 210)); // ㅣ
      expect(l.recognizedGlyph, 'ㅢ');
    });

    test('a vertical crossing through a horizontal is ㅢ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(180, 250), const Offset(300, 250)); // ㅡ
      drawStroke(l, const Offset(280, 180), const Offset(280, 300)); // ㅣ through it
      expect(l.recognizedGlyph, 'ㅢ');
    });

    test('a bar twice its vertical is ㅜ, not ㅢ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(100, 200), const Offset(300, 200)); // long bar
      drawStroke(l, const Offset(200, 200), const Offset(200, 260)); // short tick
      expect(l.recognizedGlyph, 'ㅜ');
    });

    test('ㅜ with a ㅣ crossing its bar is ㅟ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(150, 200), const Offset(300, 200)); // ㅜ bar
      drawStroke(l, const Offset(250, 200), const Offset(250, 250)); // ㅜ tick below
      drawStroke(l, const Offset(190, 160), const Offset(190, 260)); // ㅣ crossing
      expect(l.recognizedGlyph, 'ㅟ');
    });

    test('ㅠ (bar with two ticks below) is not ㅟ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(100, 200), const Offset(300, 200)); // bar
      drawStroke(l, const Offset(160, 200), const Offset(160, 260)); // tick
      drawStroke(l, const Offset(240, 200), const Offset(240, 260)); // tick
      expect(l.recognizedGlyph, 'ㅠ');
    });

    test('ㅗ with a ㅣ crossing its bar is ㅚ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(150, 200), const Offset(300, 200)); // ㅗ bar
      drawStroke(l, const Offset(250, 150), const Offset(250, 200)); // ㅗ tick above
      drawStroke(l, const Offset(190, 160), const Offset(190, 260)); // ㅣ crossing
      expect(l.recognizedGlyph, 'ㅚ');
    });

    test('ㅜ crossed by a ㅓ is ㅝ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(150, 200), const Offset(320, 200)); // ㅜ bar
      drawStroke(l, const Offset(200, 200), const Offset(200, 250)); // ㅜ tick below
      drawStroke(l, const Offset(270, 160), const Offset(270, 270)); // ㅓ stem crossing
      drawStroke(l, const Offset(230, 220), const Offset(270, 220)); // ㅓ left tick
      expect(l.recognizedGlyph, 'ㅝ');
    });

    test('ㅝ with a trailing ㅣ is ㅞ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(150, 200), const Offset(320, 200)); // ㅜ bar
      drawStroke(l, const Offset(200, 200), const Offset(200, 250)); // ㅜ tick below
      drawStroke(l, const Offset(270, 160), const Offset(270, 270)); // ㅓ stem crossing
      drawStroke(l, const Offset(230, 220), const Offset(270, 220)); // ㅓ left tick
      drawStroke(l, const Offset(360, 160), const Offset(360, 270)); // trailing ㅣ
      expect(l.recognizedGlyph, 'ㅞ');
    });

    test('ㅗ crossed by a ㅏ is ㅘ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(150, 200), const Offset(320, 200)); // ㅗ bar
      drawStroke(l, const Offset(200, 150), const Offset(200, 200)); // ㅗ tick above
      drawStroke(l, const Offset(270, 160), const Offset(270, 270)); // ㅏ stem crossing
      drawStroke(l, const Offset(270, 180), const Offset(310, 180)); // ㅏ right tick
      expect(l.recognizedGlyph, 'ㅘ');
    });

    test('ㅘ with a trailing ㅣ is ㅙ', () {
      final l = HangulLayer();
      drawStroke(l, const Offset(150, 200), const Offset(320, 200)); // ㅗ bar
      drawStroke(l, const Offset(200, 150), const Offset(200, 200)); // ㅗ tick above
      drawStroke(l, const Offset(270, 160), const Offset(270, 270)); // ㅏ stem crossing
      drawStroke(l, const Offset(270, 180), const Offset(310, 180)); // ㅏ right tick
      drawStroke(l, const Offset(360, 160), const Offset(360, 270)); // trailing ㅣ
      expect(l.recognizedGlyph, 'ㅙ');
    });

    test('every complex vowel is now recognized', () {
      for (final row in complexVowelRows) {
        expect(HangulLayer.recognizedSounds, contains(row.sound),
            reason: '${row.glyph} (${row.sound}) should be recognized');
      }
    });
  });

  group('tense consonants', () {
    // Each base consonant, drawn with its left edge at x, ~70 wide.
    void giyeok(HangulLayer l, double x) =>
        drawCorner(l, Offset(x, 120), Offset(x + 70, 120), Offset(x + 70, 220));
    void nieun(HangulLayer l, double x) =>
        drawCorner(l, Offset(x, 120), Offset(x, 220), Offset(x + 70, 220));
    void digeut(HangulLayer l, double x) {
      nieun(l, x);
      drawStroke(l, Offset(x, 120), Offset(x + 70, 120)); // top bar
    }

    void siot(HangulLayer l, double cx) {
      drawStroke(l, Offset(cx, 130), Offset(cx + 55, 230)); // \
      drawStroke(l, Offset(cx, 130), Offset(cx - 55, 230)); // /
    }

    void jieut(HangulLayer l, double x) {
      giyeok(l, x);
      drawStroke(l, Offset(x + 20, 160), Offset(x + 70, 210)); // \ on stem
    }

    void bieup(HangulLayer l, double x) {
      drawStroke(l, Offset(x, 120), Offset(x, 220)); // left
      drawStroke(l, Offset(x + 70, 120), Offset(x + 70, 220)); // right
      drawStroke(l, Offset(x, 170), Offset(x + 70, 170)); // mid
      drawStroke(l, Offset(x, 220), Offset(x + 70, 220)); // bottom
    }

    test('ㄱ twice, side by side, is ㄲ', () {
      final l = HangulLayer();
      giyeok(l, 120);
      giyeok(l, 240);
      expect(l.recognizedGlyph, 'ㄲ');
    });

    test('ㄷ twice is ㄸ', () {
      final l = HangulLayer();
      digeut(l, 120);
      digeut(l, 240);
      expect(l.recognizedGlyph, 'ㄸ');
    });

    test('ㅂ twice is ㅃ', () {
      final l = HangulLayer();
      bieup(l, 110);
      bieup(l, 240);
      expect(l.recognizedGlyph, 'ㅃ');
    });

    test('ㅅ twice is ㅆ', () {
      final l = HangulLayer();
      siot(l, 90);
      siot(l, 270);
      expect(l.recognizedGlyph, 'ㅆ');
    });

    test('ㅈ twice is ㅉ', () {
      final l = HangulLayer();
      jieut(l, 110);
      jieut(l, 250);
      expect(l.recognizedGlyph, 'ㅉ');
    });

    test('two different letters are not a tense consonant', () {
      final l = HangulLayer();
      giyeok(l, 120);
      nieun(l, 240);
      expect(l.recognizedGlyph, isNot('ㄲ'));
    });

    test('a single ㄱ is ㄱ, not ㄲ', () {
      final l = HangulLayer();
      giyeok(l, 180);
      expect(l.recognizedGlyph, 'ㄱ');
    });

    test('the same letter stacked (not side by side) is not tense', () {
      final l = HangulLayer();
      giyeok(l, 150); // one ㄱ up high
      drawCorner(l, const Offset(150, 260), const Offset(220, 260),
          const Offset(220, 340)); // another ㄱ directly below
      expect(l.recognizedGlyph, isNot('ㄲ'));
    });
  });

  group('kieuk', () {
    test('a ㄱ with a middle horizontal bar is ㅋ', () {
      final layer = HangulLayer();
      drawCorner(layer, const Offset(150, 120), const Offset(250, 120),
          const Offset(250, 240)); // ㄱ
      drawStroke(layer, const Offset(150, 180), const Offset(250, 180)); // rung
      expect(layer.recognizedGlyph, 'ㅋ');
    });

    test('a ㄱ with a bar that misses its stem is not ㅋ', () {
      final layer = HangulLayer();
      drawCorner(layer, const Offset(150, 120), const Offset(250, 120),
          const Offset(250, 240)); // ㄱ
      drawStroke(layer, const Offset(30, 300), const Offset(110, 300)); // off
      expect(layer.recognizedGlyph, isNot('ㅋ'));
    });
  });

  group('jieut', () {
    test('a ㄱ met by a descending diagonal is ㅈ', () {
      final layer = HangulLayer();
      drawCorner(layer, const Offset(150, 120), const Offset(250, 120),
          const Offset(250, 240)); // ㄱ
      drawStroke(layer, const Offset(170, 160), const Offset(250, 220)); // \
      expect(layer.recognizedGlyph, 'ㅈ');
    });

    test('a ㄱ met by an ascending diagonal is not ㅈ', () {
      final layer = HangulLayer();
      drawCorner(layer, const Offset(150, 120), const Offset(250, 120),
          const Offset(250, 240)); // ㄱ
      drawStroke(layer, const Offset(170, 220), const Offset(250, 160)); // /
      expect(layer.recognizedGlyph, isNot('ㅈ'));
    });
  });

  group('chieut', () {
    test('a ㅈ with a bar on top is ㅊ', () {
      final layer = HangulLayer();
      drawCorner(layer, const Offset(150, 150), const Offset(250, 150),
          const Offset(250, 270)); // ㄱ
      drawStroke(layer, const Offset(170, 190), const Offset(250, 250)); // \
      drawStroke(layer, const Offset(150, 110), const Offset(250, 110)); // top
      expect(layer.recognizedGlyph, 'ㅊ');
    });

    test('a ㅈ with no bar on top is just ㅈ', () {
      final layer = HangulLayer();
      drawCorner(layer, const Offset(150, 150), const Offset(250, 150),
          const Offset(250, 270)); // ㄱ
      drawStroke(layer, const Offset(170, 190), const Offset(250, 250)); // \
      expect(layer.recognizedGlyph, 'ㅈ');
    });
  });

  group('pieup', () {
    test('a bar crossed by two verticals under a floating top bar is ㅍ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(150, 200), const Offset(250, 200)); // lower bar
      drawStroke(layer, const Offset(170, 145), const Offset(170, 215)); // vertical
      drawStroke(layer, const Offset(230, 145), const Offset(230, 215)); // vertical
      drawStroke(layer, const Offset(150, 135), const Offset(250, 135)); // top bar
      expect(layer.recognizedGlyph, 'ㅍ');
    });

    test('the ㅂ ladder (both bars crossed) stays ㅂ, not ㅍ', () {
      final layer = HangulLayer();
      // Both verticals run through both bars — four intersections.
      drawStroke(layer, const Offset(170, 120), const Offset(170, 260)); // left
      drawStroke(layer, const Offset(230, 120), const Offset(230, 260)); // right
      drawStroke(layer, const Offset(140, 170), const Offset(260, 170)); // upper
      drawStroke(layer, const Offset(140, 210), const Offset(260, 210)); // lower
      expect(layer.recognizedGlyph, 'ㅂ');
    });
  });

  group('bieup', () {
    // Two verticals rung together by two horizontals — four intersections.
    void drawBieup(HangulLayer layer) {
      drawStroke(layer, const Offset(150, 120), const Offset(150, 240)); // left
      drawStroke(layer, const Offset(250, 120), const Offset(250, 240)); // right
      drawStroke(layer, const Offset(150, 180), const Offset(250, 180)); // mid
      drawStroke(layer, const Offset(150, 240), const Offset(250, 240)); // bottom
    }

    test('two verticals crossed by two horizontals is ㅂ', () {
      final layer = HangulLayer();
      drawBieup(layer);
      expect(layer.recognizedGlyph, 'ㅂ');
    });

    test('two verticals with only one horizontal is not ㅂ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(150, 240));
      drawStroke(layer, const Offset(250, 120), const Offset(250, 240));
      drawStroke(layer, const Offset(150, 180), const Offset(250, 180));
      expect(layer.recognizedGlyph, isNot('ㅂ'));
    });

    test('a horizontal that reaches only one vertical is not ㅂ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(150, 240)); // left
      drawStroke(layer, const Offset(250, 120), const Offset(250, 240)); // right
      drawStroke(layer, const Offset(150, 180), const Offset(250, 180)); // mid
      // A bottom bar that stops well short of the right vertical.
      drawStroke(layer, const Offset(150, 240), const Offset(200, 240));
      expect(layer.recognizedGlyph, isNot('ㅂ'));
    });
  });

  group('mieum', () {
    // A box: left vertical, bottom horizontal, and a ㄱ closing top + right.
    void drawMieum(HangulLayer layer) {
      drawCorner(layer, const Offset(150, 120), const Offset(250, 120),
          const Offset(250, 220)); // ㄱ: top bar + right side down
      drawStroke(layer, const Offset(150, 120), const Offset(150, 220)); // left
      drawStroke(layer, const Offset(150, 220), const Offset(250, 220)); // bottom
    }

    test('a box of vertical, horizontal, and a ㄱ is ㅁ', () {
      final layer = HangulLayer();
      drawMieum(layer);
      expect(layer.recognizedGlyph, 'ㅁ');
    });

    test('a vertical and horizontal with no ㄱ is not ㅁ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(150, 220));
      drawStroke(layer, const Offset(150, 220), const Offset(250, 220));
      expect(layer.recognizedGlyph, isNot('ㅁ'));
    });

    test('a ㄱ that touches neither side does not close the box', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(150, 220)); // left
      drawStroke(layer, const Offset(150, 220), const Offset(250, 220)); // bottom
      // A ㄱ off on its own, not closing anything.
      drawCorner(layer, const Offset(30, 40), const Offset(90, 40),
          const Offset(90, 90));
      expect(layer.recognizedGlyph, isNot('ㅁ'));
    });
  });

  group('hieut', () {
    test('a loop with two bars stacked above it is ㅎ', () {
      final layer = HangulLayer();
      drawLoop(layer, const Offset(200, 270), 70);
      drawStroke(layer, const Offset(150, 155), const Offset(280, 155));
      drawStroke(layer, const Offset(150, 120), const Offset(280, 120));
      expect(layer.recognizedGlyph, 'ㅎ');
    });

    test('ㅎ drawn bars-first still reads as ㅎ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(280, 120));
      drawStroke(layer, const Offset(150, 155), const Offset(280, 155));
      drawLoop(layer, const Offset(200, 270), 70);
      expect(layer.recognizedGlyph, 'ㅎ');
    });

    test('a loop with a single bar above it is not ㅎ', () {
      final layer = HangulLayer();
      drawLoop(layer, const Offset(200, 270), 70);
      drawStroke(layer, const Offset(150, 155), const Offset(280, 155));
      expect(layer.recognizedGlyph, isNot('ㅎ'));
    });
  });

  group('stem and ticks', () {
    test('stem plus one right-side tick is ㅏ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      drawStroke(layer, const Offset(200, 200), const Offset(260, 200));
      expect(layer.recognizedGlyph, 'ㅏ');
    });

    test('a tick that stops short of the stem still reads as ㅏ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      drawStroke(layer, const Offset(215, 200), const Offset(275, 200));
      expect(layer.recognizedGlyph, 'ㅏ');
    });

    test('tick drawn before the stem still reads as ㅏ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(200, 200), const Offset(260, 200));
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'ㅏ');
    });

    test('stem plus two right-side ticks is ㅑ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      drawStroke(layer, const Offset(200, 160), const Offset(260, 160));
      drawStroke(layer, const Offset(200, 240), const Offset(260, 240));
      expect(layer.recognizedGlyph, 'ㅑ');
    });

    test('stem plus one left-side tick is ㅓ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      drawStroke(layer, const Offset(140, 200), const Offset(200, 200));
      expect(layer.recognizedGlyph, 'ㅓ');
    });

    test('stem plus two left-side ticks is ㅕ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      drawStroke(layer, const Offset(140, 160), const Offset(200, 160));
      drawStroke(layer, const Offset(140, 240), const Offset(200, 240));
      expect(layer.recognizedGlyph, 'ㅕ');
    });

    test('ㅏ and ㅓ are told apart by which side the tick is on', () {
      final right = HangulLayer();
      drawStroke(right, const Offset(200, 100), const Offset(200, 300));
      drawStroke(right, const Offset(200, 200), const Offset(260, 200));
      expect(right.recognizedGlyph, 'ㅏ');

      final left = HangulLayer();
      drawStroke(left, const Offset(200, 100), const Offset(200, 300));
      drawStroke(left, const Offset(140, 200), const Offset(200, 200));
      expect(left.recognizedGlyph, 'ㅓ');
    });

    test('a tick crossing the stem dead center is neither side', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      drawStroke(layer, const Offset(160, 200), const Offset(240, 200));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a tick nowhere near the stem is just ㅡ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(60, 100), const Offset(60, 300));
      drawStroke(layer, const Offset(250, 200), const Offset(310, 200));
      expect(layer.recognizedGlyph, 'ㅡ');
    });

    test('bar plus one tick above is ㅗ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(100, 200), const Offset(300, 200));
      drawStroke(layer, const Offset(200, 140), const Offset(200, 200));
      expect(layer.recognizedGlyph, 'ㅗ');
    });

    test('bar plus two ticks above is ㅛ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(100, 200), const Offset(300, 200));
      drawStroke(layer, const Offset(160, 140), const Offset(160, 200));
      drawStroke(layer, const Offset(240, 140), const Offset(240, 200));
      expect(layer.recognizedGlyph, 'ㅛ');
    });

    test('bar plus one tick below is ㅜ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(100, 200), const Offset(300, 200));
      drawStroke(layer, const Offset(200, 200), const Offset(200, 260));
      expect(layer.recognizedGlyph, 'ㅜ');
    });

    test('bar plus two ticks below is ㅠ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(100, 200), const Offset(300, 200));
      drawStroke(layer, const Offset(160, 200), const Offset(160, 260));
      drawStroke(layer, const Offset(240, 200), const Offset(240, 260));
      expect(layer.recognizedGlyph, 'ㅠ');
    });

    test('ㅗ and ㅜ are told apart by which side the tick is on', () {
      final above = HangulLayer();
      drawStroke(above, const Offset(100, 200), const Offset(300, 200));
      drawStroke(above, const Offset(200, 140), const Offset(200, 200));
      expect(above.recognizedGlyph, 'ㅗ');

      final below = HangulLayer();
      drawStroke(below, const Offset(100, 200), const Offset(300, 200));
      drawStroke(below, const Offset(200, 200), const Offset(200, 260));
      expect(below.recognizedGlyph, 'ㅜ');
    });

    test('a centered tick is neither ㅗ nor ㅜ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(100, 200), const Offset(300, 200));
      drawStroke(layer, const Offset(200, 160), const Offset(200, 240));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a tick more than half the stem length is not ㅏ', () {
      final layer = HangulLayer();
      // Stem 200 tall; tick 140 wide — only ~1.4x, under the 2x floor.
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      drawStroke(layer, const Offset(200, 200), const Offset(340, 200));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a bar barely longer than its tick is not ㅗ', () {
      final layer = HangulLayer();
      // Bar 100 wide; tick 60 tall — under 2x.
      drawStroke(layer, const Offset(150, 200), const Offset(250, 200));
      drawStroke(layer, const Offset(200, 140), const Offset(200, 200));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a stem a clear 2x its tick still reads as ㅏ', () {
      final layer = HangulLayer();
      // Stem 200 tall; tick 90 wide — 2.2x, just over the floor.
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      drawStroke(layer, const Offset(200, 200), const Offset(290, 200));
      expect(layer.recognizedGlyph, 'ㅏ');
    });

    test('two ticks at the same height are not ㅑ', () {
      final layer = HangulLayer();
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      drawStroke(layer, const Offset(200, 200), const Offset(260, 200));
      drawStroke(layer, const Offset(200, 205), const Offset(260, 205));
      expect(layer.recognizedGlyph, isNot('ㅑ'));
    });
  });

  test('clear() forgets the drawing', () {
    final layer = HangulLayer();
    drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
    expect(layer.recognizedGlyph, 'ㅣ');
    layer.clear();
    expect(layer.recognizedGlyph, isNull);
  });
}
