import 'dart:math' as math;

import 'package:cord/cyrillic/scenes/cyrillic_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(400, 400);

/// Feeds [layer] a stroke from [from] to [to] as the pointer events a real
/// drag would produce: a down, a run of moves along the line, and an up.
/// [steps] controls how finely the line is sampled — the recognizer's
/// straightness and touch checks both walk the captured points, so a
/// stroke has to arrive as a path, not just its endpoints.
void drawStroke(CyrillicLayer layer, Offset from, Offset to, {int steps = 20}) {
  layer.handlePointerEvent(PointerDownEvent(position: from), _size);
  for (var i = 1; i <= steps; i++) {
    layer.handlePointerEvent(
        PointerMoveEvent(position: Offset.lerp(from, to, i / steps)!), _size);
  }
  layer.handlePointerEvent(PointerUpEvent(position: to), _size);
}

/// Feeds [layer] one stroke running through [vertices] in order, each leg
/// sampled as a run of moves, so the recognizer sees a genuine path rather
/// than just the corner points.
void drawPath(CyrillicLayer layer, List<Offset> vertices, {int steps = 20}) {
  layer.handlePointerEvent(PointerDownEvent(position: vertices.first), _size);
  for (var v = 1; v < vertices.length; v++) {
    for (var i = 1; i <= steps; i++) {
      layer.handlePointerEvent(
          PointerMoveEvent(
              position: Offset.lerp(vertices[v - 1], vertices[v], i / steps)!),
          _size);
    }
  }
  layer.handlePointerEvent(PointerUpEvent(position: vertices.last), _size);
}

/// Feeds [layer] a single bent stroke: [a] to [corner] to [b] — the
/// two-legged shape Г and Ч's arm are.
void drawCorner(CyrillicLayer layer, Offset a, Offset corner, Offset b,
        {int steps = 20}) =>
    drawPath(layer, [a, corner, b], steps: steps);

/// Feeds [layer] a single stroke tracing a loop: a circle of [radius]
/// around [center] swept a little past a full turn, its center drifting by
/// [drift] as it's drawn so the closing pass comes back off-center and
/// crosses the opening one — the way a hand draws О. A concentric retrace
/// would merely overlap itself; the drift is what turns the overshoot into
/// an actual crossing. Positive [drift] with a modest [overshoot] leaves
/// exactly one crossing.
void drawLoop(CyrillicLayer layer, Offset center, double radius,
    {int steps = 60,
    double overshoot = 0.2,
    Offset drift = const Offset(26, -40)}) {
  final sweep = 2 * math.pi * (1 + overshoot);
  Offset at(double t) {
    final c = center + drift * t;
    return Offset(
      c.dx + radius * math.cos(t * sweep),
      c.dy + radius * math.sin(t * sweep),
    );
  }

  layer.handlePointerEvent(PointerDownEvent(position: at(0)), _size);
  for (var i = 1; i <= steps; i++) {
    layer.handlePointerEvent(PointerMoveEvent(position: at(i / steps)), _size);
  }
  layer.handlePointerEvent(PointerUpEvent(position: at(1)), _size);
}

/// Feeds [layer] a single stroke sweeping the arc of a circle centred on
/// [center] from [fromDegrees] to [toDegrees] — a smooth bend with no
/// elbow, which is what Г has to be told apart from.
void drawArc(CyrillicLayer layer, Offset center, double radius,
    double fromDegrees, double toDegrees,
    {int steps = 40}) {
  Offset at(double t) {
    final angle =
        (fromDegrees + (toDegrees - fromDegrees) * t) * math.pi / 180;
    return center +
        Offset(radius * math.cos(angle), radius * math.sin(angle));
  }

  layer.handlePointerEvent(PointerDownEvent(position: at(0)), _size);
  for (var i = 1; i <= steps; i++) {
    layer.handlePointerEvent(PointerMoveEvent(position: at(i / steps)), _size);
  }
  layer.handlePointerEvent(PointerUpEvent(position: at(1)), _size);
}

/// Feeds [layer] a tap at [at] — a press and release that never travels,
/// which is a dot rather than a stroke. Ё's diaeresis is made of these.
void tap(CyrillicLayer layer, Offset at) {
  layer.handlePointerEvent(PointerDownEvent(position: at), _size);
  layer.handlePointerEvent(PointerUpEvent(position: at), _size);
}

void main() {
  group('Б', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    const barLeft = Offset(140, 140);
    const barRight = Offset(250, 140);
    // The belly: out from the stem's middle, round to the right, back to
    // the stem at its foot — so it meets the stem twice.
    const belly = [Offset(140, 200), Offset(250, 240), Offset(140, 300)];

    void drawBe(CyrillicLayer layer) {
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, barLeft, barRight);
      drawPath(layer, belly);
    }

    test('a stem, a top bar and a belly crossing it twice is Б', () {
      final layer = CyrillicLayer();
      drawBe(layer);
      expect(layer.recognizedGlyph, 'Б');
    });

    test('the belly drawn first is still Б', () {
      final layer = CyrillicLayer();
      drawPath(layer, belly);
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, barLeft, barRight);
      expect(layer.recognizedGlyph, 'Б');
    });

    test('a bar that starts on the stem rather than crossing it is Б', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(150, 140), barRight);
      drawPath(layer, belly);
      expect(layer.recognizedGlyph, 'Б');
    });

    test('a bar down in the stem\'s bottom half is not Б', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(140, 280), const Offset(250, 280));
      drawPath(layer, belly);
      expect(layer.recognizedGlyph, isNot('Б'));
    });

    test('a belly meeting the stem only once is not Б', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, barLeft, barRight);
      drawPath(layer, const [
        Offset(160, 200),
        Offset(250, 240),
        Offset(140, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('Б'));
    });

    test('a stem standing right of the bar and belly is not Б', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(250, 120), const Offset(250, 300));
      drawStroke(layer, const Offset(140, 140), const Offset(260, 140));
      drawPath(layer, const [
        Offset(260, 200),
        Offset(150, 240),
        Offset(260, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('Б'));
    });

    test('a belly running left then right is not Б', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, barLeft, barRight);
      drawPath(layer, const [
        Offset(250, 200),
        Offset(140, 240),
        Offset(250, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('Б'));
    });
  });

  group('В', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    // Both bowls in one stroke, each leaving the stem and returning to it.
    const bowls = [
      Offset(150, 120),
      Offset(240, 150),
      Offset(150, 210),
      Offset(240, 250),
      Offset(150, 300),
    ];

    test('a stem with З\'s stroke laid against it is В', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowls);
      expect(layer.recognizedGlyph, 'В');
    });

    test('the bowls drawn before the stem is still В', () {
      final layer = CyrillicLayer();
      drawPath(layer, bowls);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'В');
    });

    test('bowls that never reach the stem are not В', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(200, 120),
        Offset(280, 150),
        Offset(200, 210),
        Offset(280, 250),
        Offset(200, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('В'));
    });

    test('a stem standing right of the bowls is not В', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(250, 120), const Offset(250, 300));
      drawPath(layer, const [
        Offset(250, 120),
        Offset(160, 150),
        Offset(250, 210),
        Offset(160, 250),
        Offset(250, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('В'));
    });

    test('one bowl against a stem is not В', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(150, 150),
        Offset(240, 200),
        Offset(150, 260),
      ]);
      expect(layer.recognizedGlyph, isNot('В'));
    });
  });

  group('Г as one stroke', () {
    test('a bar drawn right-to-left then down its left end is Г', () {
      final layer = CyrillicLayer();
      drawCorner(layer, const Offset(280, 120), const Offset(140, 120),
          const Offset(140, 300));
      expect(layer.recognizedGlyph, 'Г');
    });

    test('the same corner drawn the other way round is still Г', () {
      final layer = CyrillicLayer();
      drawCorner(layer, const Offset(140, 300), const Offset(140, 120),
          const Offset(280, 120));
      expect(layer.recognizedGlyph, 'Г');
    });

    test('a slightly slanted Г still reads as Г', () {
      final layer = CyrillicLayer();
      drawCorner(layer, const Offset(280, 132), const Offset(142, 120),
          const Offset(132, 300));
      expect(layer.recognizedGlyph, 'Г');
    });

    test('the mirrored corner — Hangul ㄱ — is not Г', () {
      final layer = CyrillicLayer();
      drawCorner(layer, const Offset(140, 120), const Offset(280, 120),
          const Offset(280, 300));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a corner with its elbow at the bottom left — an L — is not Г', () {
      final layer = CyrillicLayer();
      drawCorner(layer, const Offset(140, 120), const Offset(140, 300),
          const Offset(280, 300));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a straight line is not Г', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(140, 120), const Offset(280, 120));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a smooth arc bending the same way is not Г', () {
      final layer = CyrillicLayer();
      // A quarter circle from bottom-left round to top-right, bulging
      // toward the top-left the way Г's elbow does — but with no elbow.
      drawArc(layer, const Offset(280, 300), 180, 180, 270);
      expect(layer.recognizedGlyph, isNull);
    });

    test('a corner too small to read is not Г', () {
      final layer = CyrillicLayer();
      drawCorner(layer, const Offset(150, 120), const Offset(140, 120),
          const Offset(140, 300));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('Г as two strokes', () {
    test('a bar plus a leg hanging off its left end is Г', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(140, 120), const Offset(280, 120));
      drawStroke(layer, const Offset(140, 120), const Offset(140, 300));
      expect(layer.recognizedGlyph, 'Г');
    });

    test('the leg drawn before the bar is still Г', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(140, 120), const Offset(140, 300));
      drawStroke(layer, const Offset(140, 120), const Offset(280, 120));
      expect(layer.recognizedGlyph, 'Г');
    });

    test('a leg that stops just short of the bar is still Г', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(140, 120), const Offset(280, 120));
      drawStroke(layer, const Offset(140, 134), const Offset(140, 300));
      expect(layer.recognizedGlyph, 'Г');
    });

    test('a leg hanging from the middle of the bar is Т, not Г', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(140, 120), const Offset(280, 120));
      drawStroke(layer, const Offset(210, 120), const Offset(210, 300));
      expect(layer.recognizedGlyph, 'Т');
    });

    test('a leg hanging from the bar\'s right end is not Г', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(140, 120), const Offset(280, 120));
      drawStroke(layer, const Offset(280, 120), const Offset(280, 300));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a leg nowhere near the bar is not Г', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(140, 120), const Offset(280, 120));
      drawStroke(layer, const Offset(140, 200), const Offset(140, 300));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a leg rising above the bar — an L turned over — is not Г', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(140, 300), const Offset(280, 300));
      drawStroke(layer, const Offset(140, 120), const Offset(140, 300));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('А', () {
    // Λ — up to the apex, back down — with a bar across both legs.
    const apex = [Offset(150, 300), Offset(200, 120), Offset(250, 300)];
    const barLeft = Offset(160, 240);
    const barRight = Offset(240, 240);

    test('a Λ with a bar across both legs is А', () {
      final layer = CyrillicLayer();
      drawPath(layer, apex);
      drawStroke(layer, barLeft, barRight);
      expect(layer.recognizedGlyph, 'А');
    });

    test('the bar drawn before the legs is still А', () {
      final layer = CyrillicLayer();
      drawStroke(layer, barLeft, barRight);
      drawPath(layer, apex);
      expect(layer.recognizedGlyph, 'А');
    });

    test('a Λ on its own is Л, the same shape without the bar', () {
      final layer = CyrillicLayer();
      drawPath(layer, apex);
      expect(layer.recognizedGlyph, 'Л');
    });

    test('a bar crossing only one leg is not А', () {
      final layer = CyrillicLayer();
      drawPath(layer, apex);
      drawStroke(layer, const Offset(100, 240), const Offset(200, 240));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a bar clear of both legs is not А', () {
      final layer = CyrillicLayer();
      drawPath(layer, apex);
      drawStroke(layer, const Offset(160, 100), const Offset(240, 100));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a V — down then up — with a bar is not А', () {
      final layer = CyrillicLayer();
      drawPath(layer, const [
        Offset(150, 120),
        Offset(200, 300),
        Offset(250, 120),
      ]);
      drawStroke(layer, const Offset(160, 180), const Offset(240, 180));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('Л', () {
    const el = [Offset(150, 300), Offset(200, 120), Offset(250, 300)];

    test('a stroke rising then falling is Л', () {
      final layer = CyrillicLayer();
      drawPath(layer, el);
      expect(layer.recognizedGlyph, 'Л');
    });

    test('a Л crossed by another stroke is not Л', () {
      final layer = CyrillicLayer();
      drawPath(layer, el);
      expect(layer.recognizedGlyph, 'Л');
      drawStroke(layer, const Offset(120, 340), const Offset(280, 340));
      expect(layer.recognizedGlyph, isNot('Л'));
    });

    test('a bar laid across it makes it А, not Л', () {
      final layer = CyrillicLayer();
      drawPath(layer, el);
      drawStroke(layer, const Offset(160, 240), const Offset(240, 240));
      expect(layer.recognizedGlyph, 'А');
    });

    test('a V — down then up — is not Л', () {
      final layer = CyrillicLayer();
      drawPath(layer, const [
        Offset(150, 120),
        Offset(200, 300),
        Offset(250, 120),
      ]);
      expect(layer.recognizedGlyph, isNull);
    });

    test('a straight line is not Л', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(150, 300), const Offset(250, 120));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('М', () {
    const em = [
      Offset(140, 300),
      Offset(170, 120),
      Offset(200, 240),
      Offset(230, 120),
      Offset(260, 300),
    ];

    test('a stroke rising, falling, rising and falling is М', () {
      final layer = CyrillicLayer();
      drawPath(layer, em);
      expect(layer.recognizedGlyph, 'М');
    });

    test('one peak short — a Λ — is not М', () {
      final layer = CyrillicLayer();
      drawPath(layer, const [
        Offset(140, 300),
        Offset(170, 120),
        Offset(200, 240),
      ]);
      // It's a Л: one rise and one fall is all that letter asks for.
      expect(layer.recognizedGlyph, isNot('М'));
    });

    test('one peak too many is not М', () {
      final layer = CyrillicLayer();
      drawPath(layer, const [
        Offset(120, 300),
        Offset(150, 120),
        Offset(180, 240),
        Offset(210, 120),
        Offset(240, 240),
        Offset(270, 120),
        Offset(300, 300),
      ]);
      expect(layer.recognizedGlyph, isNull);
    });

    test('an М crossed by another stroke is not М', () {
      final layer = CyrillicLayer();
      drawPath(layer, em);
      expect(layer.recognizedGlyph, 'М');
      drawStroke(layer, const Offset(120, 200), const Offset(280, 200));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a tremor along a leg does not split it into more legs', () {
      final layer = CyrillicLayer();
      // The same М, but with the hand wobbling a few pixels on the way up
      // the first leg — under _directionSlack, so it stays one leg.
      drawPath(layer, const [
        Offset(140, 300),
        Offset(150, 240),
        Offset(152, 243),
        Offset(170, 120),
        Offset(200, 240),
        Offset(230, 120),
        Offset(260, 300),
      ]);
      expect(layer.recognizedGlyph, 'М');
    });
  });

  group('Д', () {
    const apex = [Offset(150, 300), Offset(200, 120), Offset(250, 300)];
    // The base: up from the left foot, along under the legs, down to the
    // right foot.
    const base = [
      Offset(130, 320),
      Offset(130, 275),
      Offset(270, 275),
      Offset(270, 320),
    ];

    test('a Λ on a footed base crossing it low is Д', () {
      final layer = CyrillicLayer();
      drawPath(layer, apex);
      drawPath(layer, base);
      expect(layer.recognizedGlyph, 'Д');
    });

    test('the base drawn before the Λ is still Д', () {
      final layer = CyrillicLayer();
      drawPath(layer, base);
      drawPath(layer, apex);
      expect(layer.recognizedGlyph, 'Д');
    });

    test('a footed base crossing across the middle is not Д', () {
      final layer = CyrillicLayer();
      drawPath(layer, apex);
      drawPath(layer, const [
        Offset(130, 260),
        Offset(130, 210),
        Offset(270, 210),
        Offset(270, 260),
      ]);
      expect(layer.recognizedGlyph, isNot('Д'));
    });

    test('a plain straight bar low down is А, not Д', () {
      final layer = CyrillicLayer();
      drawPath(layer, apex);
      drawStroke(layer, const Offset(130, 275), const Offset(270, 275));
      expect(layer.recognizedGlyph, 'А');
    });

    test('a base whose feet point up is not Д', () {
      final layer = CyrillicLayer();
      drawPath(layer, apex);
      drawPath(layer, const [
        Offset(130, 230),
        Offset(130, 275),
        Offset(270, 275),
        Offset(270, 230),
      ]);
      expect(layer.recognizedGlyph, isNot('Д'));
    });

    test('a base too deep to be feet — a second Λ — is not Д', () {
      final layer = CyrillicLayer();
      drawPath(layer, apex);
      drawPath(layer, const [
        Offset(130, 420),
        Offset(130, 275),
        Offset(270, 275),
        Offset(270, 420),
      ]);
      expect(layer.recognizedGlyph, isNot('Д'));
    });

    test('a base clear of the legs is not Д', () {
      final layer = CyrillicLayer();
      drawPath(layer, apex);
      drawPath(layer, const [
        Offset(130, 360),
        Offset(130, 320),
        Offset(270, 320),
        Offset(270, 360),
      ]);
      expect(layer.recognizedGlyph, isNot('Д'));
    });
  });

  group('Е', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);

    void drawYe(CyrillicLayer layer,
        {Offset top = const Offset(150, 120),
        Offset middle = const Offset(150, 210),
        Offset bottom = const Offset(150, 300)}) {
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, top, Offset(250, top.dy));
      drawStroke(layer, middle, Offset(250, middle.dy));
      drawStroke(layer, bottom, Offset(250, bottom.dy));
    }

    test('a stem with bars at its top, middle and foot is Е', () {
      final layer = CyrillicLayer();
      drawYe(layer);
      expect(layer.recognizedGlyph, 'Е');
    });

    test('the stem drawn last is still Е', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      drawStroke(layer, const Offset(150, 300), const Offset(250, 300));
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'Е');
    });

    test('bars that cross the stem rather than start on it is still Е', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(140, 140), const Offset(250, 140));
      drawStroke(layer, const Offset(140, 210), const Offset(250, 210));
      drawStroke(layer, const Offset(140, 285), const Offset(250, 285));
      expect(layer.recognizedGlyph, 'Е');
    });

    test('three bars bunched at the top is not Е', () {
      final layer = CyrillicLayer();
      drawYe(layer,
          middle: const Offset(150, 150), bottom: const Offset(150, 175));
      expect(layer.recognizedGlyph, isNot('Е'));
    });

    test('only two bars is not Е', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(150, 300), const Offset(250, 300));
      expect(layer.recognizedGlyph, isNot('Е'));
    });

    test('bars reaching left of the stem is not Е', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(50, 120), const Offset(150, 120));
      drawStroke(layer, const Offset(50, 210), const Offset(150, 210));
      drawStroke(layer, const Offset(50, 300), const Offset(150, 300));
      expect(layer.recognizedGlyph, isNot('Е'));
    });

    test('a bar that never reaches the stem is not Е', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(190, 210), const Offset(250, 210));
      drawStroke(layer, const Offset(150, 300), const Offset(250, 300));
      expect(layer.recognizedGlyph, isNot('Е'));
    });
  });

  group('Ё', () {
    // The Е the dots go over: stem on the left, three bars reaching right.
    void drawYe(CyrillicLayer layer) {
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      drawStroke(layer, const Offset(150, 300), const Offset(250, 300));
    }

    test('an Е with two dots above it is Ё', () {
      final layer = CyrillicLayer();
      drawYe(layer);
      expect(layer.recognizedGlyph, 'Е');
      tap(layer, const Offset(180, 90));
      tap(layer, const Offset(220, 90));
      expect(layer.recognizedGlyph, 'Ё');
    });

    test('the dots tapped before the Е is drawn is still Ё', () {
      final layer = CyrillicLayer();
      tap(layer, const Offset(180, 90));
      tap(layer, const Offset(220, 90));
      drawYe(layer);
      expect(layer.recognizedGlyph, 'Ё');
    });

    test('one dot short it is Е, not Ё', () {
      final layer = CyrillicLayer();
      drawYe(layer);
      tap(layer, const Offset(180, 90));
      expect(layer.recognizedGlyph, 'Е');
    });

    test('dots inside the Е rather than above it is not Ё', () {
      final layer = CyrillicLayer();
      drawYe(layer);
      tap(layer, const Offset(180, 160));
      tap(layer, const Offset(220, 160));
      expect(layer.recognizedGlyph, 'Е');
    });

    test('dots clear of the Е\'s own width is not Ё', () {
      final layer = CyrillicLayer();
      drawYe(layer);
      tap(layer, const Offset(320, 90));
      tap(layer, const Offset(360, 90));
      expect(layer.recognizedGlyph, 'Е');
    });

    test('two dots over something that is not an Е is not Ё', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      tap(layer, const Offset(140, 90));
      tap(layer, const Offset(160, 90));
      expect(layer.recognizedGlyph, isNot('Ё'));
    });

    test('clear() drops the dots along with the strokes', () {
      final layer = CyrillicLayer();
      drawYe(layer);
      tap(layer, const Offset(180, 90));
      tap(layer, const Offset(220, 90));
      expect(layer.recognizedGlyph, 'Ё');
      layer.clear();
      drawYe(layer);
      expect(layer.recognizedGlyph, 'Е');
    });
  });

  group('Й', () {
    // Down the left stem, up the diagonal, down the right stem.
    const i = [
      Offset(150, 120),
      Offset(150, 300),
      Offset(250, 120),
      Offset(250, 300),
    ];
    // The breve: falling then rising, Л's Λ upside down.
    const breve = [Offset(160, 80), Offset(200, 100), Offset(240, 80)];

    test('an И with a breve above it is Й', () {
      final layer = CyrillicLayer();
      drawPath(layer, i);
      drawPath(layer, breve);
      expect(layer.recognizedGlyph, 'Й');
    });

    test('the breve drawn first is still Й', () {
      final layer = CyrillicLayer();
      drawPath(layer, breve);
      drawPath(layer, i);
      expect(layer.recognizedGlyph, 'Й');
    });

    test('without the breve it is И, not Й', () {
      final layer = CyrillicLayer();
      drawPath(layer, i);
      expect(layer.recognizedGlyph, 'И');
    });

    test('a breve sitting inside the И is not Й', () {
      final layer = CyrillicLayer();
      drawPath(layer, i);
      drawPath(layer,
          const [Offset(160, 140), Offset(200, 160), Offset(240, 140)]);
      expect(layer.recognizedGlyph, isNot('Й'));
    });

    test('a breve clear of the И\'s own width is not Й', () {
      final layer = CyrillicLayer();
      drawPath(layer, i);
      drawPath(layer,
          const [Offset(300, 80), Offset(340, 100), Offset(380, 80)]);
      expect(layer.recognizedGlyph, isNot('Й'));
    });

    test('a Λ above the И, rather than a breve, is not Й', () {
      final layer = CyrillicLayer();
      drawPath(layer, i);
      drawPath(layer,
          const [Offset(160, 100), Offset(200, 80), Offset(240, 100)]);
      expect(layer.recognizedGlyph, isNot('Й'));
    });
  });

  group('З', () {
    // The 3-shape: out right across the top bowl, back left to the waist,
    // out right again across the bottom bowl, back left to the tail.
    const ze = [
      Offset(150, 130),
      Offset(240, 120),
      Offset(180, 200),
      Offset(250, 250),
      Offset(150, 300),
    ];

    test('a stroke running right, left, right, left is З', () {
      final layer = CyrillicLayer();
      drawPath(layer, ze);
      expect(layer.recognizedGlyph, 'З');
    });

    // Both of these read as Л, which asks only for a rise and a fall and
    // so claims a good many half-drawn shapes. What matters here is that
    // neither is mistaken for the letter under test.
    test('one bowl short is not З', () {
      final layer = CyrillicLayer();
      drawPath(layer, const [
        Offset(150, 130),
        Offset(240, 120),
        Offset(180, 200),
      ]);
      expect(layer.recognizedGlyph, isNot('З'));
    });

    test('the same run of legs mirrored is not З', () {
      final layer = CyrillicLayer();
      drawPath(layer, const [
        Offset(250, 130),
        Offset(160, 120),
        Offset(220, 200),
        Offset(150, 250),
        Offset(250, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('З'));
    });

    test('a З crossed by another stroke is not З', () {
      final layer = CyrillicLayer();
      drawPath(layer, ze);
      expect(layer.recognizedGlyph, 'З');
      drawStroke(layer, const Offset(200, 80), const Offset(200, 340));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a З that crosses its own path is still З', () {
      final layer = CyrillicLayer();
      // The tail curls back up and over the waist, so the stroke crosses
      // itself — which З, unlike М and И, is allowed to do.
      drawPath(layer, const [
        Offset(150, 130),
        Offset(240, 120),
        Offset(170, 200),
        Offset(250, 250),
        Offset(150, 180),
      ]);
      expect(layer.recognizedGlyph, 'З');
    });
  });

  group('Т', () {
    const barLeft = Offset(150, 120);
    const barRight = Offset(250, 120);

    test('a bar with a stem hanging from its middle is Т', () {
      final layer = CyrillicLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'Т');
    });

    test('the stem drawn first is still Т', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      drawStroke(layer, barLeft, barRight);
      expect(layer.recognizedGlyph, 'Т');
    });

    test('a stem crossing the bar rather than starting on it is still Т', () {
      final layer = CyrillicLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'Т');
    });

    test('a stem hanging from the bar\'s left end is Г, not Т', () {
      final layer = CyrillicLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      expect(layer.recognizedGlyph, 'Г');
    });

    test('a stem standing above the bar — a ⊥ — is not Т', () {
      final layer = CyrillicLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, const Offset(200, 120), const Offset(200, 20));
      expect(layer.recognizedGlyph, isNot('Т'));
    });

    test('a bar crossing the stem\'s middle — a cross — is not Т', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      expect(layer.recognizedGlyph, isNot('Т'));
    });

    test('a stem the bar never reaches is not Т', () {
      final layer = CyrillicLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, const Offset(200, 220), const Offset(200, 380));
      expect(layer.recognizedGlyph, isNot('Т'));
    });
  });

  group('У', () {
    // The tail runs from the foot up to the top right; the arm falls from
    // the top left across it at (200, 230), leaving a 12px stub against
    // the 110px the tail still has to drop.
    const tailFoot = Offset(150, 340);
    const tailTop = Offset(250, 120);
    const armTop = Offset(150, 130);
    const armEnd = Offset(206, 242);

    test('an arm falling onto a tail that carries on below it is У', () {
      final layer = CyrillicLayer();
      drawStroke(layer, tailFoot, tailTop);
      drawStroke(layer, armTop, armEnd);
      expect(layer.recognizedGlyph, 'У');
    });

    test('the arm drawn first is still У', () {
      final layer = CyrillicLayer();
      drawStroke(layer, armTop, armEnd);
      drawStroke(layer, tailFoot, tailTop);
      expect(layer.recognizedGlyph, 'У');
    });

    test('drawn end for end, the slants are unchanged — still У', () {
      final layer = CyrillicLayer();
      drawStroke(layer, tailTop, tailFoot);
      drawStroke(layer, armEnd, armTop);
      expect(layer.recognizedGlyph, 'У');
    });

    test('an arm sitting over the tail\'s own box centre is still У', () {
      final layer = CyrillicLayer();
      // A У as actually drawn by hand: the tail runs the whole width of
      // the letter, so its bounding box's centre (x 122) falls to the
      // *left* of the arm's (x 134). Only the arm's middle landing on the
      // tail's upper-left side says this is a У.
      drawStroke(layer, const Offset(55, 292), const Offset(190, 62));
      drawStroke(layer, const Offset(105, 52), const Offset(163, 127));
      expect(layer.recognizedGlyph, 'У');
    });

    test('a longer stub past the crossing is still У', () {
      final layer = CyrillicLayer();
      drawStroke(layer, tailFoot, tailTop);
      drawStroke(layer, armTop, const Offset(210, 250));
      expect(layer.recognizedGlyph, 'У');
    });

    test('an arm falling the whole way is Х, not У', () {
      final layer = CyrillicLayer();
      // Past the crossing it has 134 of its 246 left — more than half —
      // and it drops as far below the crossing as the tail does.
      drawStroke(layer, tailFoot, tailTop);
      drawStroke(layer, armTop, const Offset(260, 350));
      expect(layer.recognizedGlyph, 'Х');
    });

    test('an arm stopping short of the tail is not У', () {
      final layer = CyrillicLayer();
      // Near enough to read as a junction, but it never crosses, and У
      // asks for the crossing Х does.
      drawStroke(layer, tailFoot, tailTop);
      drawStroke(layer, armTop, const Offset(190, 210));
      expect(layer.recognizedGlyph, isNot('У'));
    });

    test('a tick across the top of the tail is not У', () {
      final layer = CyrillicLayer();
      // It leaves as little below the crossing as У's arm does, but sits
      // to the tail's right rather than its left.
      drawStroke(layer, tailFoot, tailTop);
      drawStroke(layer, const Offset(225, 130), const Offset(255, 190));
      expect(layer.recognizedGlyph, isNot('У'));
    });

    test('an arm nowhere near the tail is not У', () {
      final layer = CyrillicLayer();
      drawStroke(layer, tailFoot, tailTop);
      drawStroke(layer, const Offset(60, 120), const Offset(110, 220));
      expect(layer.recognizedGlyph, isNot('У'));
    });

    test('two strokes at the same slant is not У', () {
      final layer = CyrillicLayer();
      drawStroke(layer, tailFoot, tailTop);
      drawStroke(layer, const Offset(120, 300), const Offset(220, 80));
      expect(layer.recognizedGlyph, isNot('У'));
    });
  });

  group('Ф', () {
    const ringCentre = Offset(240, 210);

    test('a ring run through by a stem is Ф', () {
      final layer = CyrillicLayer();
      drawLoop(layer, ringCentre, 70);
      drawStroke(layer, const Offset(250, 90), const Offset(250, 330));
      expect(layer.recognizedGlyph, 'Ф');
    });

    test('the stem drawn first is still Ф', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(250, 90), const Offset(250, 330));
      drawLoop(layer, ringCentre, 70);
      expect(layer.recognizedGlyph, 'Ф');
    });

    test('a stem catching the ring\'s overlap as well — 3 — is still Ф', () {
      final layer = CyrillicLayer();
      // A ring whose closing stroke overshoots up past its own top edge,
      // leaving a tail inside the ring for the stem to catch on the way
      // through: top edge, tail, bottom edge.
      drawPath(layer, const [
        Offset(150, 140),
        Offset(330, 140),
        Offset(330, 280),
        Offset(150, 280),
        Offset(170, 120),
      ]);
      drawStroke(layer, const Offset(165, 100), const Offset(165, 340));
      expect(layer.recognizedGlyph, 'Ф');
    });

    test('a stem clear of the ring is not Ф', () {
      final layer = CyrillicLayer();
      drawLoop(layer, ringCentre, 70);
      drawStroke(layer, const Offset(80, 90), const Offset(80, 330));
      expect(layer.recognizedGlyph, isNot('Ф'));
    });

    test('a stem stopping inside the ring — one crossing — is not Ф', () {
      final layer = CyrillicLayer();
      drawLoop(layer, ringCentre, 70);
      drawStroke(layer, const Offset(250, 90), const Offset(250, 200));
      expect(layer.recognizedGlyph, isNot('Ф'));
    });

    test('an unclosed ring run through by a stem is not Ф', () {
      final layer = CyrillicLayer();
      drawLoop(layer, ringCentre, 70, overshoot: -0.08);
      drawStroke(layer, const Offset(250, 90), const Offset(250, 330));
      expect(layer.recognizedGlyph, isNot('Ф'));
    });
  });

  group('Х', () {
    const rising = [Offset(150, 300), Offset(250, 120)];
    const falling = [Offset(150, 120), Offset(250, 300)];

    test('a rising and a falling stroke crossing once is Х', () {
      final layer = CyrillicLayer();
      drawStroke(layer, rising[0], rising[1]);
      drawStroke(layer, falling[0], falling[1]);
      expect(layer.recognizedGlyph, 'Х');
    });

    test('the falling stroke drawn first is still Х', () {
      final layer = CyrillicLayer();
      drawStroke(layer, falling[0], falling[1]);
      drawStroke(layer, rising[0], rising[1]);
      expect(layer.recognizedGlyph, 'Х');
    });

    test('drawn end for end, the slants are unchanged — still Х', () {
      final layer = CyrillicLayer();
      drawStroke(layer, rising[1], rising[0]);
      drawStroke(layer, falling[1], falling[0]);
      expect(layer.recognizedGlyph, 'Х');
    });

    test('two strokes at the same slant is not Х', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(250, 300));
      drawStroke(layer, const Offset(200, 100), const Offset(300, 280));
      expect(layer.recognizedGlyph, isNot('Х'));
    });

    test('opposite slants that never cross is not Х', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(60, 300), const Offset(120, 120));
      drawStroke(layer, const Offset(250, 120), const Offset(340, 300));
      expect(layer.recognizedGlyph, isNot('Х'));
    });

    test('a leg leaning off plumb, beside a diagonal, is not Х', () {
      final layer = CyrillicLayer();
      // A Ц's own two pieces with the descender left off. The leg leans by
      // five pixels, which is enough to read as rising, and it crosses the
      // foot — but it never reaches across the letter as a Х's arms do.
      drawPath(layer, const [
        Offset(150, 120),
        Offset(150, 300),
        Offset(250, 300),
      ]);
      drawStroke(layer, const Offset(250, 120), const Offset(245, 300));
      expect(layer.recognizedGlyph, isNot('Х'));
    });

    test('a vertical crossed by a horizontal is not Х', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      drawStroke(layer, const Offset(120, 210), const Offset(280, 210));
      expect(layer.recognizedGlyph, isNot('Х'));
    });
  });

  group('Ж', () {
    // Х's own two diagonals, crossing at (200, 210), with the stem run
    // down through that crossing.
    const rising = [Offset(150, 300), Offset(250, 120)];
    const falling = [Offset(150, 120), Offset(250, 300)];
    const stemTop = Offset(200, 100);
    const stemBottom = Offset(200, 320);

    test('a Х with a stem run through it is Ж', () {
      final layer = CyrillicLayer();
      drawStroke(layer, rising[0], rising[1]);
      drawStroke(layer, falling[0], falling[1]);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'Ж');
    });

    test('the stem drawn first is still Ж', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, falling[0], falling[1]);
      drawStroke(layer, rising[0], rising[1]);
      expect(layer.recognizedGlyph, 'Ж');
    });

    test('the diagonals without the stem is Х, not Ж', () {
      final layer = CyrillicLayer();
      drawStroke(layer, rising[0], rising[1]);
      drawStroke(layer, falling[0], falling[1]);
      expect(layer.recognizedGlyph, 'Х');
    });

    test('a stem standing clear of the diagonals is not Ж', () {
      final layer = CyrillicLayer();
      drawStroke(layer, rising[0], rising[1]);
      drawStroke(layer, falling[0], falling[1]);
      drawStroke(layer, const Offset(340, 100), const Offset(340, 320));
      expect(layer.recognizedGlyph, isNot('Ж'));
    });

    test('a stem reaching only one diagonal is not Ж', () {
      final layer = CyrillicLayer();
      drawStroke(layer, rising[0], rising[1]);
      drawStroke(layer, falling[0], falling[1]);
      // Stopping short of the rising diagonal, which it would have met
      // down at y ≈ 282.
      drawStroke(layer, const Offset(160, 100), const Offset(160, 200));
      expect(layer.recognizedGlyph, isNot('Ж'));
    });

    test('two diagonals at the same slant with a stem is not Ж', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(250, 300));
      drawStroke(layer, const Offset(180, 100), const Offset(280, 280));
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, isNot('Ж'));
    });

    test('a stem crossed by a bar and a diagonal is not Ж', () {
      final layer = CyrillicLayer();
      drawStroke(layer, rising[0], rising[1]);
      drawStroke(layer, const Offset(120, 210), const Offset(280, 210));
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, isNot('Ж'));
    });
  });

  group('Ц', () {
    // Down the left leg, right along the foot, then down again into the
    // descender — a 14px tail, deliberately under the 15 the corner check
    // would otherwise demand of it.
    const body = [
      Offset(150, 120),
      Offset(150, 300),
      Offset(250, 300),
      Offset(250, 314),
    ];
    const legTop = Offset(250, 120);
    const legFoot = Offset(250, 300);

    test('a body with a leg standing on its right is Ц', () {
      final layer = CyrillicLayer();
      drawPath(layer, body);
      drawStroke(layer, legTop, legFoot);
      expect(layer.recognizedGlyph, 'Ц');
    });

    test('the leg drawn first is still Ц', () {
      final layer = CyrillicLayer();
      drawStroke(layer, legTop, legFoot);
      drawPath(layer, body);
      expect(layer.recognizedGlyph, 'Ц');
    });

    test('the body drawn in reverse — up, left, up — is still Ц', () {
      final layer = CyrillicLayer();
      drawPath(layer, body.reversed.toList());
      drawStroke(layer, legFoot, legTop);
      expect(layer.recognizedGlyph, 'Ц');
    });

    test('a longer descender is still Ц', () {
      final layer = CyrillicLayer();
      drawPath(layer, const [
        Offset(150, 120),
        Offset(150, 300),
        Offset(250, 300),
        Offset(250, 360),
      ]);
      drawStroke(layer, legTop, legFoot);
      expect(layer.recognizedGlyph, 'Ц');
    });

    test('without the descender it is no letter at all', () {
      final layer = CyrillicLayer();
      // A plain ㄴ: cut at its middle, the right-hand piece is a straight
      // half-foot, and a line has no elbow — so no Ц. Nor a Ч, whose stem
      // has to carry on below where the arm runs into it, where this leg
      // stops dead on the foot. What's left is a ⊔, which is nothing.
      drawCorner(layer, const Offset(150, 120), const Offset(150, 300),
          const Offset(250, 300));
      drawStroke(layer, legTop, legFoot);
      expect(layer.recognizedGlyph, isNull);
    });

    test('a descender short against a long foot is still Ц, not Ч', () {
      final layer = CyrillicLayer();
      // 8px of tail against a 100px foot. Ч reads the body whole, and over
      // that chord the bend falls inside _isStraight's slack, so the body
      // passes for the plain ㄴ Ч wants. Cutting it in half halves the
      // chord and the tail reads as a bend again. Ц going first settles it
      // — the same arrangement Щ has with Ш.
      drawPath(layer, const [
        Offset(150, 120),
        Offset(150, 300),
        Offset(250, 300),
        Offset(250, 308),
      ]);
      drawStroke(layer, legTop, legFoot);
      expect(layer.recognizedGlyph, 'Ц');
    });

    test('a descender of a few pixels is not Ц', () {
      final layer = CyrillicLayer();
      drawPath(layer, const [
        Offset(150, 120),
        Offset(150, 300),
        Offset(250, 300),
        Offset(250, 304),
      ]);
      drawStroke(layer, legTop, legFoot);
      expect(layer.recognizedGlyph, isNot('Ц'));
    });

    test('a leg standing to the body\'s left is not Ц', () {
      final layer = CyrillicLayer();
      drawPath(layer, body);
      drawStroke(layer, const Offset(120, 120), const Offset(120, 300));
      expect(layer.recognizedGlyph, isNot('Ц'));
    });

    test('a leg hanging below the descender is not Ц', () {
      final layer = CyrillicLayer();
      drawPath(layer, body);
      // It meets the body at its top end rather than at its foot.
      drawStroke(layer, const Offset(250, 314), const Offset(250, 480));
      expect(layer.recognizedGlyph, isNot('Ц'));
    });

    test('a П with a leg beside it is not Ц', () {
      final layer = CyrillicLayer();
      // The same two corners, but the left elbow rides at the top.
      drawPath(layer, const [
        Offset(150, 300),
        Offset(150, 120),
        Offset(250, 120),
        Offset(250, 300),
      ]);
      drawStroke(layer, const Offset(300, 120), const Offset(300, 300));
      expect(layer.recognizedGlyph, isNot('Ц'));
    });
  });

  group('Щ', () {
    // Ц's body, drawn wider to leave room for two legs on its foot. The
    // descender is 30px against a 100px half-foot: a shallower bend across
    // that much width reads as a slope rather than a corner.
    const body = [
      Offset(150, 120),
      Offset(150, 300),
      Offset(350, 300),
      Offset(350, 330),
    ];
    const middleLeg = [Offset(250, 120), Offset(250, 300)];
    const rightLeg = [Offset(350, 120), Offset(350, 300)];

    test('a body with two legs standing on its foot is Щ', () {
      final layer = CyrillicLayer();
      drawPath(layer, body);
      drawStroke(layer, middleLeg[0], middleLeg[1]);
      drawStroke(layer, rightLeg[0], rightLeg[1]);
      expect(layer.recognizedGlyph, 'Щ');
    });

    test('the body drawn last is still Щ', () {
      final layer = CyrillicLayer();
      drawStroke(layer, middleLeg[0], middleLeg[1]);
      drawStroke(layer, rightLeg[0], rightLeg[1]);
      drawPath(layer, body);
      expect(layer.recognizedGlyph, 'Щ');
    });

    test('one leg short it is Ц, not Щ', () {
      final layer = CyrillicLayer();
      drawPath(layer, body);
      drawStroke(layer, rightLeg[0], rightLeg[1]);
      expect(layer.recognizedGlyph, 'Ц');
    });

    test('without the descender it is Ш, not Щ', () {
      final layer = CyrillicLayer();
      drawCorner(layer, const Offset(150, 120), const Offset(150, 300),
          const Offset(350, 300));
      drawStroke(layer, middleLeg[0], middleLeg[1]);
      drawStroke(layer, rightLeg[0], rightLeg[1]);
      expect(layer.recognizedGlyph, 'Ш');
    });

    test('a descender short against a long foot is still Щ, not Ш', () {
      final layer = CyrillicLayer();
      // 18px of tail against a 200px foot. Read across the whole body that
      // bend falls inside _isStraight's slack, so the body passes for the
      // plain ㄴ Ш looks for; read across half the body — half the chord,
      // half the slack — it is a bend. Only Щ going first settles it.
      drawPath(layer, const [
        Offset(150, 120),
        Offset(150, 300),
        Offset(350, 300),
        Offset(350, 318),
      ]);
      drawStroke(layer, middleLeg[0], middleLeg[1]);
      drawStroke(layer, rightLeg[0], rightLeg[1]);
      expect(layer.recognizedGlyph, 'Щ');
    });

    test('a descender hooking left is still Щ', () {
      final layer = CyrillicLayer();
      // Written as a hook rather than a stroke, so it leans — here by 27°,
      // which is past what a stem is held to.
      drawPath(layer, const [
        Offset(150, 120),
        Offset(150, 300),
        Offset(350, 300),
        Offset(335, 330),
      ]);
      drawStroke(layer, middleLeg[0], middleLeg[1]);
      drawStroke(layer, rightLeg[0], rightLeg[1]);
      expect(layer.recognizedGlyph, 'Щ');
    });

    test('legs run well past the foot are still Щ', () {
      final layer = CyrillicLayer();
      // A hand stops where it stops. What matters is how little of the leg
      // is left below the foot, not how near its end lands.
      drawPath(layer, body);
      drawStroke(layer, middleLeg[0], const Offset(250, 330));
      drawStroke(layer, rightLeg[0], const Offset(350, 330));
      expect(layer.recognizedGlyph, 'Щ');
    });

    test('legs that stop above the foot is not Щ', () {
      final layer = CyrillicLayer();
      drawPath(layer, body);
      drawStroke(layer, const Offset(250, 100), const Offset(250, 200));
      drawStroke(layer, const Offset(350, 100), const Offset(350, 200));
      expect(layer.recognizedGlyph, isNot('Щ'));
    });

    test('the same leg drawn twice is not Щ', () {
      final layer = CyrillicLayer();
      drawPath(layer, body);
      drawStroke(layer, rightLeg[0], rightLeg[1]);
      drawStroke(layer, rightLeg[0], rightLeg[1]);
      expect(layer.recognizedGlyph, isNot('Щ'));
    });
  });

  group('Ю', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    const barLeft = Offset(150, 210);
    const barRight = Offset(250, 210);
    const ringCentre = Offset(270, 210);

    test('a stem, a bar across its middle and a ring on the end is Ю', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, barLeft, barRight);
      drawLoop(layer, ringCentre, 60);
      expect(layer.recognizedGlyph, 'Ю');
    });

    test('the ring drawn first is still Ю', () {
      final layer = CyrillicLayer();
      drawLoop(layer, ringCentre, 60);
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, barLeft, barRight);
      expect(layer.recognizedGlyph, 'Ю');
    });

    test('a ring the bar never reaches is not Ю', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, barLeft, const Offset(200, 210));
      drawLoop(layer, const Offset(330, 210), 60);
      expect(layer.recognizedGlyph, isNot('Ю'));
    });

    test('a bar meeting the stem at its top is not Ю', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(150, 135), const Offset(250, 135));
      drawLoop(layer, const Offset(270, 135), 60);
      expect(layer.recognizedGlyph, isNot('Ю'));
    });

    test('an unclosed ring is not Ю', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, barLeft, barRight);
      drawLoop(layer, ringCentre, 60, overshoot: -0.08);
      expect(layer.recognizedGlyph, isNot('Ю'));
    });
  });

  group('Я', () {
    const stemTop = Offset(250, 120);
    const stemBottom = Offset(250, 300);
    // Across the top of the bowl, back to the stem, then away down the leg.
    const body = [
      Offset(250, 120),
      Offset(170, 140),
      Offset(250, 210),
      Offset(170, 300),
    ];

    test('a stem with a left-right-left body on its left is Я', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, body);
      expect(layer.recognizedGlyph, 'Я');
    });

    test('the body drawn first is still Я', () {
      final layer = CyrillicLayer();
      drawPath(layer, body);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'Я');
    });

    test('a body overshooting the stem each time — 3 meetings — is Я', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      // Each leg starts a little right of the stem and crosses it, rather
      // than starting on it: three crossings instead of two.
      drawPath(layer, const [
        Offset(270, 120),
        Offset(170, 140),
        Offset(270, 210),
        Offset(170, 300),
      ]);
      expect(layer.recognizedGlyph, 'Я');
    });

    test('a body meeting the stem only once is not Я', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(230, 120),
        Offset(170, 140),
        Offset(250, 210),
        Offset(170, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('Я'));
    });

    test('a body that never meets the stem is not Я', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(200, 120),
        Offset(120, 140),
        Offset(200, 210),
        Offset(120, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('Я'));
    });

    test('the body on the stem\'s right is not Я', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      drawPath(layer, const [
        Offset(150, 120),
        Offset(230, 140),
        Offset(150, 210),
        Offset(230, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('Я'));
    });

    test('one leg more is not Я', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(250, 120),
        Offset(170, 140),
        Offset(250, 190),
        Offset(170, 240),
        Offset(250, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('Я'));
    });
  });

  group('К', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    // In to the stem, then away again.
    const arm = [Offset(250, 120), Offset(150, 210), Offset(250, 300)];

    test('a stem with an arm turning on it is К', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, arm);
      expect(layer.recognizedGlyph, 'К');
    });

    test('the arm drawn first is still К', () {
      final layer = CyrillicLayer();
      drawPath(layer, arm);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'К');
    });

    test('an arm carrying past the stem — two crossings — is still К', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(250, 120), Offset(120, 210), Offset(250, 300)]);
      expect(layer.recognizedGlyph, 'К');
    });

    test('an arm that never reaches the stem is not К', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(300, 120), Offset(200, 210), Offset(300, 300)]);
      expect(layer.recognizedGlyph, isNot('К'));
    });

    test('an arm on the stem\'s left is not К', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(140, 120), Offset(50, 210), Offset(140, 300)]);
      expect(layer.recognizedGlyph, isNot('К'));
    });

    test('an arm swinging out and back — Ь\'s belly — is not К', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 200), Offset(250, 250), Offset(150, 300)]);
      expect(layer.recognizedGlyph, isNot('К'));
    });
  });

  group('Р', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    // A bowl riding high on the stem: out right, back left.
    const bowl = [Offset(150, 120), Offset(250, 160), Offset(150, 210)];

    test('a stem with a bowl riding high on it is Р', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl);
      expect(layer.recognizedGlyph, 'Р');
    });

    test('the bowl drawn first is still Р', () {
      final layer = CyrillicLayer();
      drawPath(layer, bowl);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'Р');
    });

    test('the same bowl hanging low is Ь, not Р', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 210), Offset(250, 250), Offset(150, 300)]);
      expect(layer.recognizedGlyph, 'Ь');
    });

    test('a bowl meeting the stem only once is not Р', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(160, 120), Offset(250, 160), Offset(200, 210)]);
      expect(layer.recognizedGlyph, isNot('Р'));
    });
  });

  group('С', () {
    // Out to the left across the top, round the back, and away right
    // again — the arc's opening facing right.
    const arc = [Offset(250, 140), Offset(140, 210), Offset(250, 280)];

    test('one stroke out left and back right is С', () {
      final layer = CyrillicLayer();
      drawPath(layer, arc);
      expect(layer.recognizedGlyph, 'С');
    });

    test('drawn bottom to top, the arc is unchanged — still С', () {
      final layer = CyrillicLayer();
      drawPath(layer, arc.reversed.toList());
      expect(layer.recognizedGlyph, 'С');
    });

    test('a printed С, its terminals curling back, is С', () {
      final layer = CyrillicLayer();
      // Three quarters of a circle, from the upper-right terminal up over
      // the top, down the back and round into the lower-right one — so it
      // rises, falls and rises again on the way rather than simply curving
      // the once.
      drawArc(layer, const Offset(200, 200), 70, -45, -315);
      expect(layer.recognizedGlyph, 'С');
    });

    test('a hook whose end stops left of centre is not С', () {
      final layer = CyrillicLayer();
      drawPath(layer,
          const [Offset(250, 140), Offset(140, 210), Offset(180, 250)]);
      expect(layer.recognizedGlyph, isNot('С'));
    });

    test('the same arc facing left — Э\'s bowl — is not С', () {
      final layer = CyrillicLayer();
      drawPath(layer,
          const [Offset(140, 140), Offset(250, 210), Offset(140, 280)]);
      expect(layer.recognizedGlyph, isNot('С'));
    });

    test('a stroke that never turns back is not С', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(250, 140), const Offset(140, 280));
      expect(layer.recognizedGlyph, isNot('С'));
    });

    test('the arc with a stem run into it is К, not С', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      drawPath(layer, arc);
      expect(layer.recognizedGlyph, 'К');
    });

    test('an arc crossing another stroke is not С', () {
      final layer = CyrillicLayer();
      drawPath(layer, arc);
      drawStroke(layer, const Offset(200, 100), const Offset(200, 320));
      expect(layer.recognizedGlyph, isNot('С'));
    });
  });

  group('Ь, Ъ and Ы', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    const belly = [Offset(140, 200), Offset(250, 240), Offset(140, 300)];
    // A vav: the bar at the top running right into the stem, then down.
    const vav = [Offset(110, 120), Offset(150, 120), Offset(150, 300)];
    const spareStemTop = Offset(300, 120);
    const spareStemBottom = Offset(300, 300);

    test('a stem with a belly crossing it twice is Ь', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, belly);
      expect(layer.recognizedGlyph, 'Ь');
    });

    test('the belly drawn first is still Ь', () {
      final layer = CyrillicLayer();
      drawPath(layer, belly);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'Ь');
    });

    test('adding a top bar makes it Б, not Ь', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, belly);
      drawStroke(layer, const Offset(140, 140), const Offset(250, 140));
      expect(layer.recognizedGlyph, 'Б');
    });

    test('a belly meeting the stem only once is not Ь', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(160, 200),
        Offset(250, 240),
        Offset(140, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('Ь'));
    });

    test('a vav with a belly crossing it twice is Ъ', () {
      final layer = CyrillicLayer();
      drawPath(layer, vav);
      drawPath(layer, belly);
      expect(layer.recognizedGlyph, 'Ъ');
    });

    test('the belly drawn first is still Ъ', () {
      final layer = CyrillicLayer();
      drawPath(layer, belly);
      drawPath(layer, vav);
      expect(layer.recognizedGlyph, 'Ъ');
    });

    test('a vav\'s head pointing the other way is not Ъ', () {
      final layer = CyrillicLayer();
      // Elbow at the top left — a Г, not a vav.
      drawPath(layer,
          const [Offset(190, 120), Offset(150, 120), Offset(150, 300)]);
      drawPath(layer, belly);
      expect(layer.recognizedGlyph, isNot('Ъ'));
    });

    test('a Ь with a stem standing clear on its right is Ы', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, belly);
      drawStroke(layer, spareStemTop, spareStemBottom);
      expect(layer.recognizedGlyph, 'Ы');
    });

    test('the spare stem drawn first is still Ы', () {
      final layer = CyrillicLayer();
      drawStroke(layer, spareStemTop, spareStemBottom);
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, belly);
      expect(layer.recognizedGlyph, 'Ы');
    });

    test('the spare stem on the left is not Ы', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, belly);
      drawStroke(layer, const Offset(80, 120), const Offset(80, 300));
      expect(layer.recognizedGlyph, isNot('Ы'));
    });

    test('a spare stem well below the soft sign is not Ы', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, belly);
      drawStroke(layer, const Offset(300, 320), const Offset(300, 500));
      expect(layer.recognizedGlyph, isNot('Ы'));
    });

    test('a spare stem run through the belly is not Ы', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, belly);
      drawStroke(layer, const Offset(200, 120), const Offset(200, 320));
      expect(layer.recognizedGlyph, isNot('Ы'));
    });
  });

  group('Э', () {
    // The bowl: out right across the top, down the right side, back left
    // across the bottom. Its opening faces left.
    const bowl = [
      Offset(150, 120),
      Offset(250, 120),
      Offset(250, 300),
      Offset(150, 300),
    ];
    const barLeft = Offset(160, 210);
    const barRight = Offset(270, 210);

    test('a left-opening bowl with a bar reaching left is Э', () {
      final layer = CyrillicLayer();
      drawPath(layer, bowl);
      drawStroke(layer, barLeft, barRight);
      expect(layer.recognizedGlyph, 'Э');
    });

    test('the bar drawn before the bowl is still Э', () {
      final layer = CyrillicLayer();
      drawStroke(layer, barLeft, barRight);
      drawPath(layer, bowl);
      expect(layer.recognizedGlyph, 'Э');
    });

    test('a bowl on its own is not Э', () {
      final layer = CyrillicLayer();
      drawPath(layer, bowl);
      expect(layer.recognizedGlyph, isNull);
    });

    test('the bar reaching right of the crossing is not Э', () {
      final layer = CyrillicLayer();
      drawPath(layer, bowl);
      // Crossing the bowl's left-hand opening instead, so the bar's own
      // centre lands to the crossing's right — the mirrored letter.
      drawStroke(layer, const Offset(130, 210), const Offset(240, 210));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a bar across the bowl\'s arm rather than its middle is not Э', () {
      final layer = CyrillicLayer();
      drawPath(layer, bowl);
      drawStroke(layer, const Offset(160, 132), const Offset(270, 132));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a bar clear of the bowl is not Э', () {
      final layer = CyrillicLayer();
      drawPath(layer, bowl);
      drawStroke(layer, const Offset(300, 210), const Offset(380, 210));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('И', () {
    // Down the left stem, up the diagonal, down the right stem.
    const i = [
      Offset(150, 120),
      Offset(150, 300),
      Offset(250, 120),
      Offset(250, 300),
    ];

    test('a stroke falling, rising and falling is И', () {
      final layer = CyrillicLayer();
      drawPath(layer, i);
      expect(layer.recognizedGlyph, 'И');
    });

    test('an И crossed by another stroke is not И', () {
      final layer = CyrillicLayer();
      drawPath(layer, i);
      expect(layer.recognizedGlyph, 'И');
      drawStroke(layer, const Offset(120, 160), const Offset(280, 160));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a circle drawn not quite closed is not И', () {
      final layer = CyrillicLayer();
      // It falls, rises and falls just as И does — entering and leaving on
      // its right-hand side — so only the missing upright stems separate
      // the two. It reads as С instead: left, back right, uncrossed, and
      // both ends off to the right.
      drawLoop(layer, const Offset(200, 200), 70, overshoot: -0.08);
      expect(layer.recognizedGlyph, isNot('И'));
    });

    test('a Λ — up then down — is Л, not И', () {
      final layer = CyrillicLayer();
      drawPath(layer, const [
        Offset(150, 300),
        Offset(200, 120),
        Offset(250, 300),
      ]);
      expect(layer.recognizedGlyph, 'Л');
    });
  });

  group('Н', () {
    const leftStemTop = Offset(150, 120);
    const leftStemBottom = Offset(150, 300);
    const rightStemTop = Offset(250, 120);
    const rightStemBottom = Offset(250, 300);
    const barLeft = Offset(140, 210);
    const barRight = Offset(260, 210);

    void drawEn(CyrillicLayer layer) {
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      drawStroke(layer, barLeft, barRight);
    }

    test('two stems and a bar crossing both is Н', () {
      final layer = CyrillicLayer();
      drawEn(layer);
      expect(layer.recognizedGlyph, 'Н');
    });

    test('the bar drawn first is still Н', () {
      final layer = CyrillicLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      expect(layer.recognizedGlyph, 'Н');
    });

    test('a bar crossing only one stem is not Н', () {
      final layer = CyrillicLayer();
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      drawStroke(layer, barLeft, const Offset(200, 210));
      expect(layer.recognizedGlyph, isNull);
    });

    test('both stems on the same side of the bar\'s centre is not Н', () {
      final layer = CyrillicLayer();
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      // The bar runs far out to the right, putting its own centre past
      // both stems — a bar with a tail, not an Н.
      drawStroke(layer, barLeft, const Offset(500, 210));
      expect(layer.recognizedGlyph, isNull);
    });

    test('three stems and no bar is not Н', () {
      final layer = CyrillicLayer();
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      drawStroke(layer, const Offset(350, 120), const Offset(350, 300));
      expect(layer.recognizedGlyph, isNull);
    });

    test('two stems the bar never reaches is not Н', () {
      final layer = CyrillicLayer();
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      drawStroke(layer, const Offset(140, 340), const Offset(260, 340));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('Ч', () {
    // A stem down the right, with a ㄴ-shaped arm running into its middle
    // from the left.
    const armTop = Offset(150, 120);
    const armElbow = Offset(150, 240);
    const armEnd = Offset(250, 240);
    const stemTop = Offset(250, 100);
    const stemBottom = Offset(250, 320);

    test('a stem with a ㄴ-shaped arm meeting it from the left is Ч', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawCorner(layer, armTop, armElbow, armEnd);
      expect(layer.recognizedGlyph, 'Ч');
    });

    test('the arm drawn before the stem is still Ч', () {
      final layer = CyrillicLayer();
      drawCorner(layer, armTop, armElbow, armEnd);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'Ч');
    });

    test('an arm that stops just short of the stem is still Ч', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawCorner(layer, armTop, armElbow, const Offset(236, 240));
      expect(layer.recognizedGlyph, 'Ч');
    });

    test('an arm nowhere near the stem is not Ч', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawCorner(layer, const Offset(60, 120), const Offset(60, 240),
          const Offset(140, 240));
      expect(layer.recognizedGlyph, isNull);
    });

    test('an arm running into the stem\'s foot is not Ч', () {
      final layer = CyrillicLayer();
      // Nothing of the stem is left below the junction, so there is no
      // lower half to the letter — the two make a ⊔ instead.
      drawStroke(layer, stemTop, const Offset(250, 240));
      drawCorner(layer, armTop, armElbow, armEnd);
      expect(layer.recognizedGlyph, isNull);
    });

    test('an arm meeting the stem near its foot is not Ч', () {
      final layer = CyrillicLayer();
      // A stub of stem below the junction, but under the quarter of it the
      // letter's lower half wants.
      drawStroke(layer, stemTop, stemBottom);
      drawCorner(layer, const Offset(150, 120), const Offset(150, 290),
          const Offset(250, 290));
      expect(layer.recognizedGlyph, isNull);
    });

    test('the arm mirrored onto the stem\'s right is not Ч', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawCorner(layer, const Offset(350, 120), const Offset(350, 240),
          const Offset(250, 240));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a Г-shaped arm — elbow at the top — is not Ч', () {
      final layer = CyrillicLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawCorner(layer, const Offset(250, 120), const Offset(150, 120),
          const Offset(150, 240));
      // It's a Г next to a stray line, which is exactly how it reads.
      expect(layer.recognizedGlyph, 'Г');
    });

    test('a horizontal stem is not Ч', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(150, 240), const Offset(350, 240));
      drawCorner(layer, armTop, armElbow, armEnd);
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('Ш', () {
    // The ㄴ: down the left stem, along the foot to the right.
    const corner = [Offset(150, 120), Offset(150, 300), Offset(350, 300)];
    const middleStemTop = Offset(220, 120);
    const middleStemBottom = Offset(220, 320);
    const rightStemTop = Offset(290, 120);
    const rightStemBottom = Offset(290, 320);

    test('a ㄴ with two stems standing on its foot is Ш', () {
      final layer = CyrillicLayer();
      drawPath(layer, corner);
      drawStroke(layer, middleStemTop, middleStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      expect(layer.recognizedGlyph, 'Ш');
    });

    test('the corner drawn last is still Ш', () {
      final layer = CyrillicLayer();
      drawStroke(layer, middleStemTop, middleStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      drawPath(layer, corner);
      expect(layer.recognizedGlyph, 'Ш');
    });

    test('one stem short is not Ш', () {
      final layer = CyrillicLayer();
      // Nor is it a Ч, near as the two pieces are to one: a stem standing
      // on the foot has almost nothing of itself left below the junction,
      // where Ч's carries on down for the letter's whole lower half.
      drawPath(layer, corner);
      drawStroke(layer, middleStemTop, middleStemBottom);
      expect(layer.recognizedGlyph, isNull);
    });

    test('stems that stop above the foot is not Ш', () {
      final layer = CyrillicLayer();
      drawPath(layer, corner);
      drawStroke(layer, middleStemTop, const Offset(220, 260));
      drawStroke(layer, rightStemTop, const Offset(290, 260));
      expect(layer.recognizedGlyph, isNot('Ш'));
    });

    test('a Г-shaped corner with two stems is not Ш', () {
      final layer = CyrillicLayer();
      drawPath(layer,
          const [Offset(350, 120), Offset(150, 120), Offset(150, 300)]);
      drawStroke(layer, const Offset(220, 100), middleStemBottom);
      drawStroke(layer, const Offset(290, 100), rightStemBottom);
      expect(layer.recognizedGlyph, isNot('Ш'));
    });
  });

  group('П', () {
    // Up the left leg, across the top, down the right one.
    const pe = [
      Offset(150, 300),
      Offset(150, 120),
      Offset(250, 120),
      Offset(250, 300),
    ];

    test('two squared corners sharing a top bar is П', () {
      final layer = CyrillicLayer();
      drawPath(layer, pe);
      expect(layer.recognizedGlyph, 'П');
    });

    test('drawn right to left, the arch is unchanged — still П', () {
      final layer = CyrillicLayer();
      drawPath(layer, pe.reversed.toList());
      expect(layer.recognizedGlyph, 'П');
    });

    test('a Λ — the same rise and fall, but pointed — is Л, not П', () {
      final layer = CyrillicLayer();
      drawPath(layer,
          const [Offset(150, 300), Offset(200, 120), Offset(250, 300)]);
      expect(layer.recognizedGlyph, 'Л');
    });

    test('a smoothly rounded ∩ is not П', () {
      final layer = CyrillicLayer();
      // The same arch with its corners never squared off: each half bends
      // through its box rather than turning in its corner.
      drawArc(layer, const Offset(200, 220), 90, 180, 360);
      expect(layer.recognizedGlyph, isNot('П'));
    });

    test('a ⊔ — the arch opening upward — is not П', () {
      final layer = CyrillicLayer();
      drawPath(layer, const [
        Offset(150, 120),
        Offset(150, 300),
        Offset(250, 300),
        Offset(250, 120),
      ]);
      expect(layer.recognizedGlyph, isNot('П'));
    });

    test('one corner alone is Г, not П', () {
      final layer = CyrillicLayer();
      drawCorner(layer, const Offset(150, 300), const Offset(150, 120),
          const Offset(250, 120));
      expect(layer.recognizedGlyph, 'Г');
    });

    test('an arch crossed by another stroke is not П', () {
      final layer = CyrillicLayer();
      drawPath(layer, pe);
      expect(layer.recognizedGlyph, 'П');
      drawStroke(layer, const Offset(120, 200), const Offset(280, 200));
      expect(layer.recognizedGlyph, isNot('П'));
    });
  });

  group('О', () {
    test('a stroke that crosses itself once is О', () {
      final layer = CyrillicLayer();
      drawLoop(layer, const Offset(200, 200), 70);
      expect(layer.recognizedGlyph, 'О');
    });

    test('an open circle that never closes is not О', () {
      final layer = CyrillicLayer();
      // Just shy of a full turn: the ends stop near each other but never
      // cross, so there's no self-intersection to read as a loop. An
      // unclosed ring is a wide С, and is read as one — the gap is the
      // whole of what tells the two apart, and this one has a gap.
      drawLoop(layer, const Offset(200, 200), 70, overshoot: -0.08);
      expect(layer.recognizedGlyph, isNot('О'));
    });

    test('a loop crossed by another stroke is not О', () {
      final layer = CyrillicLayer();
      drawLoop(layer, const Offset(200, 200), 70);
      expect(layer.recognizedGlyph, 'О');
      // A ring with a stem run through it is a Ф, which is exactly what
      // the second stroke makes of it.
      drawStroke(layer, const Offset(200, 80), const Offset(200, 320));
      expect(layer.recognizedGlyph, 'Ф');
    });

    test('a loop alongside an earlier, untouched stroke is still О', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(60, 80), const Offset(60, 320));
      drawLoop(layer, const Offset(240, 200), 70);
      expect(layer.recognizedGlyph, 'О');
    });

    test('a straight line does not read as О', () {
      final layer = CyrillicLayer();
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  test('clear() drops the drawing and the reading with it', () {
    final layer = CyrillicLayer();
    drawCorner(layer, const Offset(280, 120), const Offset(140, 120),
        const Offset(140, 300));
    expect(layer.recognizedGlyph, 'Г');
    layer.clear();
    expect(layer.recognizedGlyph, isNull);
  });
}
