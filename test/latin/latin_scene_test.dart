import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cord/latin/data/latin_letters.dart';
import 'package:cord/latin/scenes/latin_scene.dart';

const _size = Size(400, 400);

/// Feeds [layer] a stroke from [from] to [to] as the pointer events a real
/// drag would produce: a down, a run of moves along the line, and an up.
/// [steps] controls how finely the line is sampled — the recognizer's
/// straightness and crossing checks both walk the captured points, so a
/// stroke has to arrive as a path, not just its endpoints.
void drawStroke(LatinLayer layer, Offset from, Offset to, {int steps = 20}) {
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
void drawPath(LatinLayer layer, List<Offset> vertices, {int steps = 20}) {
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

/// Feeds [layer] a single stroke tracing a loop: a circle of [radius]
/// around [center] swept a little past a full turn, its center drifting by
/// [drift] as it's drawn so the closing pass comes back off-center and
/// crosses the opening one — the way a hand draws O. A concentric retrace
/// would merely overlap itself; the drift is what turns the overshoot into
/// an actual crossing. Positive [drift] with a modest [overshoot] leaves
/// exactly one crossing.
void drawLoop(LatinLayer layer, Offset center, double radius,
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
/// [center] from [fromDegrees] to [toDegrees] — a smooth bend, which is
/// what a printed C's curling terminals make of it.
void drawArc(LatinLayer layer, Offset center, double radius, double fromDegrees,
    double toDegrees,
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

/// Feeds [layer] a tap at [at] — a press and release that never travels, which
/// is a dot rather than a stroke. Ä's and Ö's diaereses are made of these.
void tap(LatinLayer layer, Offset at) {
  layer.handlePointerEvent(PointerDownEvent(position: at), _size);
  layer.handlePointerEvent(PointerUpEvent(position: at), _size);
}

void main() {
  group('A', () {
    // Λ — up to the apex, back down — with a bar across both legs.
    const apex = [Offset(150, 300), Offset(200, 120), Offset(250, 300)];
    const barLeft = Offset(160, 240);
    const barRight = Offset(240, 240);

    test('a Λ with a bar across both legs is A', () {
      final layer = LatinLayer();
      drawPath(layer, apex);
      drawStroke(layer, barLeft, barRight);
      expect(layer.recognizedGlyph, 'A');
    });

    test('the bar drawn before the legs is still A', () {
      final layer = LatinLayer();
      drawStroke(layer, barLeft, barRight);
      drawPath(layer, apex);
      expect(layer.recognizedGlyph, 'A');
    });

    test('a Λ on its own is no letter — the bar is what makes it A', () {
      final layer = LatinLayer();
      drawPath(layer, apex);
      expect(layer.recognizedGlyph, isNull);
    });

    test('a bar crossing only one leg is not A', () {
      final layer = LatinLayer();
      drawPath(layer, apex);
      drawStroke(layer, const Offset(100, 240), const Offset(200, 240));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a bar clear of both legs is not A', () {
      final layer = LatinLayer();
      drawPath(layer, apex);
      drawStroke(layer, const Offset(160, 100), const Offset(240, 100));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a V — down then up — with a bar is not A', () {
      final layer = LatinLayer();
      drawPath(layer, const [
        Offset(150, 120),
        Offset(200, 300),
        Offset(250, 120),
      ]);
      drawStroke(layer, const Offset(160, 180), const Offset(240, 180));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('B', () {
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

    test('a stem with two bowls laid against it is B', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowls);
      expect(layer.recognizedGlyph, 'B');
    });

    test('the bowls drawn before the stem is still B', () {
      final layer = LatinLayer();
      drawPath(layer, bowls);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'B');
    });

    test('bowls that never reach the stem are not B', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(200, 120),
        Offset(280, 150),
        Offset(200, 210),
        Offset(280, 250),
        Offset(200, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('B'));
    });

    test('a stem standing right of the bowls is not B', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(250, 120), const Offset(250, 300));
      drawPath(layer, const [
        Offset(250, 120),
        Offset(160, 150),
        Offset(250, 210),
        Offset(160, 250),
        Offset(250, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('B'));
    });

    test('one bowl against a stem is not B', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(150, 150),
        Offset(240, 200),
        Offset(150, 260),
      ]);
      expect(layer.recognizedGlyph, isNot('B'));
    });
  });

  group('P', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    // A bowl riding high on the stem: out right, back left.
    const bowl = [Offset(150, 120), Offset(250, 160), Offset(150, 210)];

    test('a stem with a bowl riding high on it is P', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl);
      expect(layer.recognizedGlyph, 'P');
    });

    test('a bowl starting a little below the stem\'s top is still P', () {
      // No hand starts the bowl exactly level with the stem. Leaving a fifth of
      // stem above it is ordinary, and must not turn a P into a thorn.
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 155), Offset(250, 185), Offset(150, 215)]);
      expect(layer.recognizedGlyph, 'P');
    });

    test('the bowl drawn first is still P', () {
      final layer = LatinLayer();
      drawPath(layer, bowl);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'P');
    });

    test('the same bowl hanging low on the stem is not P', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 210), Offset(250, 250), Offset(150, 300)]);
      // Meeting the stem at its waist and its foot rather than at its top,
      // this is neither P nor D.
      expect(layer.recognizedGlyph, isNull);
    });

    test('the bowl carried down to the stem\'s foot is D, not P', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 120), Offset(250, 210), Offset(150, 300)]);
      expect(layer.recognizedGlyph, 'D');
    });

    test('a bowl meeting the stem only once is not P', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(160, 120), Offset(250, 160), Offset(200, 210)]);
      expect(layer.recognizedGlyph, isNot('P'));
    });

    test('a stem standing right of the bowl is not P', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(250, 120), const Offset(250, 300));
      drawPath(layer,
          const [Offset(250, 120), Offset(160, 160), Offset(250, 210)]);
      expect(layer.recognizedGlyph, isNot('P'));
    });

    test('a second bowl below the first makes it a B, not a P', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(150, 120),
        Offset(240, 150),
        Offset(150, 210),
        Offset(240, 250),
        Offset(150, 300),
      ]);
      expect(layer.recognizedGlyph, 'B');
    });
  });

  group('T', () {
    const barLeft = Offset(150, 120);
    const barRight = Offset(250, 120);

    test('a bar with a stem hanging from its middle is T', () {
      final layer = LatinLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'T');
    });

    test('the stem drawn first is still T', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      drawStroke(layer, barLeft, barRight);
      expect(layer.recognizedGlyph, 'T');
    });

    test('a stem crossing the bar rather than starting on it is still T', () {
      final layer = LatinLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'T');
    });

    test('a stem hanging from the bar\'s left end is no letter here', () {
      final layer = LatinLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a stem standing above the bar — a ⊥ — is not T', () {
      final layer = LatinLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, const Offset(200, 120), const Offset(200, 20));
      expect(layer.recognizedGlyph, isNot('T'));
    });

    test('a bar crossing the stem\'s middle — a cross — is not T', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      expect(layer.recognizedGlyph, isNot('T'));
    });

    test('a stem the bar never reaches is not T', () {
      final layer = LatinLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, const Offset(200, 220), const Offset(200, 380));
      // Touching nothing, the stem is read as the I it is on its own.
      expect(layer.recognizedGlyph, 'I');
    });
  });

  group('X', () {
    const rising = [Offset(150, 300), Offset(250, 120)];
    const falling = [Offset(150, 120), Offset(250, 300)];

    test('a rising and a falling stroke crossing once is X', () {
      final layer = LatinLayer();
      drawStroke(layer, rising[0], rising[1]);
      drawStroke(layer, falling[0], falling[1]);
      expect(layer.recognizedGlyph, 'X');
    });

    test('the falling stroke drawn first is still X', () {
      final layer = LatinLayer();
      drawStroke(layer, falling[0], falling[1]);
      drawStroke(layer, rising[0], rising[1]);
      expect(layer.recognizedGlyph, 'X');
    });

    test('drawn end for end, the slants are unchanged — still X', () {
      final layer = LatinLayer();
      drawStroke(layer, rising[1], rising[0]);
      drawStroke(layer, falling[1], falling[0]);
      expect(layer.recognizedGlyph, 'X');
    });

    test('two strokes at the same slant is not X', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(250, 300));
      drawStroke(layer, const Offset(200, 100), const Offset(300, 280));
      expect(layer.recognizedGlyph, isNot('X'));
    });

    test('opposite slants that never cross is not X', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(60, 300), const Offset(120, 120));
      drawStroke(layer, const Offset(250, 120), const Offset(340, 300));
      expect(layer.recognizedGlyph, isNot('X'));
    });

    test('a stem leaning off plumb, beside its bar, is T and not X', () {
      final layer = LatinLayer();
      // A T whose two strokes each lean by five pixels, which is enough for
      // both to read as slanted — one rising, one falling — and they do
      // cross. Neither reaches across the letter as an X's arms do.
      drawStroke(layer, const Offset(150, 125), const Offset(250, 120));
      drawStroke(layer, const Offset(200, 120), const Offset(205, 300));
      expect(layer.recognizedGlyph, 'T');
    });

    test('a vertical crossed by a horizontal is not X', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      drawStroke(layer, const Offset(120, 210), const Offset(280, 210));
      expect(layer.recognizedGlyph, isNot('X'));
    });
  });

  group('O', () {
    test('a stroke that crosses itself once is O', () {
      final layer = LatinLayer();
      drawLoop(layer, const Offset(200, 200), 70);
      expect(layer.recognizedGlyph, 'O');
    });

    test('an open circle that never closes is not O', () {
      final layer = LatinLayer();
      // Just shy of a full turn: the ends stop near each other but never
      // cross, so there's no self-intersection to read as a loop. An
      // unclosed ring is a wide C, and is read as one — the gap is the
      // whole of what tells the two apart, and this one has a gap.
      drawLoop(layer, const Offset(200, 200), 70, overshoot: -0.08);
      expect(layer.recognizedGlyph, isNot('O'));
    });

    test('a loop with a stem run through it is not O', () {
      final layer = LatinLayer();
      drawLoop(layer, const Offset(200, 200), 70);
      expect(layer.recognizedGlyph, 'O');
      drawStroke(layer, const Offset(200, 80), const Offset(200, 320));
      expect(layer.recognizedGlyph, isNot('O'));
    });

    test('a loop alongside an earlier, untouched stroke is still O', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(60, 80), const Offset(60, 320));
      drawLoop(layer, const Offset(240, 200), 70);
      expect(layer.recognizedGlyph, 'O');
    });

    test('a straight line is an I, not an O', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'I');
    });
  });

  group('D', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    // The bowl meets the stem at its two ends and nowhere between.
    const bowl = [Offset(150, 120), Offset(250, 210), Offset(150, 300)];

    test('a stem with a bowl meeting it top and bottom is D', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl);
      expect(layer.recognizedGlyph, 'D');
    });

    test('the bowl drawn first is still D', () {
      final layer = LatinLayer();
      drawPath(layer, bowl);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'D');
    });

    test('drawn bottom to top, the bowl is unchanged — still D', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl.reversed.toList());
      expect(layer.recognizedGlyph, 'D');
    });

    test('a bowl crossing the stem rather than starting on it is still D', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(130, 130), Offset(250, 210), Offset(130, 290)]);
      expect(layer.recognizedGlyph, 'D');
    });

    test('the bowl stopping at the stem\'s waist is P, not D', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 120), Offset(250, 160), Offset(150, 210)]);
      expect(layer.recognizedGlyph, 'P');
    });

    test('a second bowl inside it — a B — is not D', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(150, 120),
        Offset(240, 150),
        Offset(150, 210),
        Offset(240, 250),
        Offset(150, 300),
      ]);
      expect(layer.recognizedGlyph, 'B');
    });

    test('a bowl meeting the stem only once is not D', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(160, 120), Offset(250, 210), Offset(200, 300)]);
      expect(layer.recognizedGlyph, isNot('D'));
    });

    test('a stem standing right of the bowl is not D', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(250, 120), const Offset(250, 300));
      drawPath(layer,
          const [Offset(250, 120), Offset(160, 210), Offset(250, 300)]);
      expect(layer.recognizedGlyph, isNot('D'));
    });

    test('the bowl turned the other way — C\'s arc — is not D', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(250, 120), const Offset(250, 300));
      drawPath(layer,
          const [Offset(250, 120), Offset(150, 210), Offset(250, 300)]);
      expect(layer.recognizedGlyph, isNot('D'));
    });
  });

  group('C', () {
    // Out to the left across the top, round the back, and away right
    // again — the arc's opening facing right.
    const arc = [Offset(250, 140), Offset(140, 210), Offset(250, 280)];

    test('one stroke out left and back right is C', () {
      final layer = LatinLayer();
      drawPath(layer, arc);
      expect(layer.recognizedGlyph, 'C');
    });

    test('drawn bottom to top, the arc is unchanged — still C', () {
      final layer = LatinLayer();
      drawPath(layer, arc.reversed.toList());
      expect(layer.recognizedGlyph, 'C');
    });

    test('a printed C, its terminals curling back, is C', () {
      final layer = LatinLayer();
      // Three quarters of a circle, from the upper-right terminal up over
      // the top, down the back and round into the lower-right one — so it
      // rises, falls and rises again on the way rather than simply curving
      // the once.
      drawArc(layer, const Offset(200, 200), 70, -45, -315);
      expect(layer.recognizedGlyph, 'C');
    });

    test('a hook whose end stops left of centre is not C', () {
      final layer = LatinLayer();
      drawPath(layer,
          const [Offset(250, 140), Offset(140, 210), Offset(180, 250)]);
      expect(layer.recognizedGlyph, isNot('C'));
    });

    test('the same arc facing left — a D\'s bowl — is not C', () {
      final layer = LatinLayer();
      drawPath(layer,
          const [Offset(140, 140), Offset(250, 210), Offset(140, 280)]);
      expect(layer.recognizedGlyph, isNot('C'));
    });

    test('a stroke that never turns back is not C', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(250, 140), const Offset(140, 280));
      expect(layer.recognizedGlyph, isNot('C'));
    });

    test('the arc with a stem run into it is K, not C', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      drawPath(layer, arc);
      expect(layer.recognizedGlyph, 'K');
    });

    test('an arc crossing another stroke is not C', () {
      final layer = LatinLayer();
      drawPath(layer, arc);
      drawStroke(layer, const Offset(200, 100), const Offset(200, 320));
      expect(layer.recognizedGlyph, isNot('C'));
    });
  });

  group('E', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);

    void drawE(LatinLayer layer,
        {Offset top = const Offset(150, 120),
        Offset middle = const Offset(150, 210),
        Offset bottom = const Offset(150, 300)}) {
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, top, Offset(250, top.dy));
      drawStroke(layer, middle, Offset(250, middle.dy));
      drawStroke(layer, bottom, Offset(250, bottom.dy));
    }

    test('a stem with bars at its top, middle and foot is E', () {
      final layer = LatinLayer();
      drawE(layer);
      expect(layer.recognizedGlyph, 'E');
    });

    test('the stem drawn last is still E', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      drawStroke(layer, const Offset(150, 300), const Offset(250, 300));
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'E');
    });

    test('bars that cross the stem rather than start on it is still E', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(140, 140), const Offset(250, 140));
      drawStroke(layer, const Offset(140, 210), const Offset(250, 210));
      drawStroke(layer, const Offset(140, 285), const Offset(250, 285));
      expect(layer.recognizedGlyph, 'E');
    });

    test('three bars bunched at the top is not E', () {
      final layer = LatinLayer();
      drawE(layer,
          middle: const Offset(150, 150), bottom: const Offset(150, 175));
      expect(layer.recognizedGlyph, isNot('E'));
    });

    test('only two bars is an F, the same letter without its foot', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      expect(layer.recognizedGlyph, 'F');
    });

    test('an E reads as an F on its way — the foot settles it', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      expect(layer.recognizedGlyph, 'F');
      drawStroke(layer, const Offset(150, 300), const Offset(250, 300));
      expect(layer.recognizedGlyph, 'E');
    });

    test('bars reaching left of the stem is not E', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(50, 120), const Offset(150, 120));
      drawStroke(layer, const Offset(50, 210), const Offset(150, 210));
      drawStroke(layer, const Offset(50, 300), const Offset(150, 300));
      expect(layer.recognizedGlyph, isNot('E'));
    });

    test('a bar that never reaches the stem is not E', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(190, 210), const Offset(250, 210));
      drawStroke(layer, const Offset(150, 300), const Offset(250, 300));
      expect(layer.recognizedGlyph, isNot('E'));
    });

    group('written as an L with two bars', () {
      // The stem and the bottom bar in one stroke — the same letter with a pen
      // lift fewer.
      const ell = [Offset(150, 120), Offset(150, 300), Offset(250, 300)];

      void drawCornerE(LatinLayer layer) {
        drawPath(layer, ell);
        drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
        drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      }

      test('an L with a top bar and a middle bar is E', () {
        final layer = LatinLayer();
        drawCornerE(layer);
        expect(layer.recognizedGlyph, 'E');
      });

      test('the bars drawn before the L is still E', () {
        final layer = LatinLayer();
        drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
        drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
        drawPath(layer, ell);
        expect(layer.recognizedGlyph, 'E');
      });

      test('an L with one bar is not E', () {
        final layer = LatinLayer();
        drawPath(layer, ell);
        drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
        expect(layer.recognizedGlyph, isNot('E'));
      });

      test('a third bar down at the L\'s own foot is not E', () {
        // Unlike the four-stroke form, which wants one bar to each third, this
        // one refuses the bottom third outright — the foot is the L's already.
        final layer = LatinLayer();
        drawPath(layer, ell);
        drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
        drawStroke(layer, const Offset(150, 280), const Offset(250, 280));
        expect(layer.recognizedGlyph, isNot('E'));
      });

      test('bars reaching left of the L is not E', () {
        final layer = LatinLayer();
        drawPath(layer, ell);
        drawStroke(layer, const Offset(50, 120), const Offset(150, 120));
        drawStroke(layer, const Offset(50, 210), const Offset(150, 210));
        expect(layer.recognizedGlyph, isNot('E'));
      });

      test('a stem with two bars is still F, not this', () {
        // The two forms can't be confused: F wants a straight stem where this
        // wants a corner.
        final layer = LatinLayer();
        drawStroke(layer, stemTop, stemBottom);
        drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
        drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
        expect(layer.recognizedGlyph, 'F');
      });

      test('a mark over it still finds the letter underneath', () {
        // `_baseOf` had no three-stroke E before this, only H.
        final layer = LatinLayer()..alphabet = Alphabet.czech;
        drawCornerE(layer);
        drawStroke(layer, const Offset(170, 90), const Offset(210, 60));
        expect(layer.recognizedGlyph, 'É');
      });
    });
  });

  group('F', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);

    void drawF(LatinLayer layer,
        {Offset top = const Offset(150, 120),
        Offset middle = const Offset(150, 210)}) {
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, top, Offset(250, top.dy));
      drawStroke(layer, middle, Offset(250, middle.dy));
    }

    test('a stem with bars at its top and middle is F', () {
      final layer = LatinLayer();
      drawF(layer);
      expect(layer.recognizedGlyph, 'F');
    });

    test('the stem drawn last is still F', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'F');
    });

    test('bars that cross the stem rather than start on it is still F', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(140, 140), const Offset(250, 140));
      drawStroke(layer, const Offset(140, 210), const Offset(250, 210));
      expect(layer.recognizedGlyph, 'F');
    });

    test('both bars bunched at the top is not F', () {
      final layer = LatinLayer();
      drawF(layer, middle: const Offset(150, 150));
      expect(layer.recognizedGlyph, isNot('F'));
    });

    test('the second bar down at the stem\'s foot is not F', () {
      final layer = LatinLayer();
      drawF(layer, middle: const Offset(150, 295));
      expect(layer.recognizedGlyph, isNot('F'));
    });

    test('bars reaching left of the stem is not F', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(50, 120), const Offset(150, 120));
      drawStroke(layer, const Offset(50, 210), const Offset(150, 210));
      expect(layer.recognizedGlyph, isNot('F'));
    });

    test('a bar that never reaches the stem is not F', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(190, 210), const Offset(250, 210));
      expect(layer.recognizedGlyph, isNot('F'));
    });
  });

  group('H', () {
    const leftStemTop = Offset(150, 120);
    const leftStemBottom = Offset(150, 300);
    const rightStemTop = Offset(250, 120);
    const rightStemBottom = Offset(250, 300);
    const barLeft = Offset(140, 210);
    const barRight = Offset(260, 210);

    void drawH(LatinLayer layer) {
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      drawStroke(layer, barLeft, barRight);
    }

    test('two stems and a bar crossing both is H', () {
      final layer = LatinLayer();
      drawH(layer);
      expect(layer.recognizedGlyph, 'H');
    });

    test('the bar drawn first is still H', () {
      final layer = LatinLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      expect(layer.recognizedGlyph, 'H');
    });

    test('a bar crossing only one stem is not H', () {
      final layer = LatinLayer();
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      drawStroke(layer, barLeft, const Offset(200, 210));
      expect(layer.recognizedGlyph, isNot('H'));
    });

    test('both stems on the same side of the bar\'s centre is not H', () {
      final layer = LatinLayer();
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      // The bar runs far out to the right, putting its own centre past both
      // stems — a bar with a tail, not an H.
      drawStroke(layer, barLeft, const Offset(500, 210));
      expect(layer.recognizedGlyph, isNot('H'));
    });

    test('three stems and no bar is not H', () {
      final layer = LatinLayer();
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      drawStroke(layer, const Offset(350, 120), const Offset(350, 300));
      // The last stem touches nothing, so it reads as an I on its own.
      expect(layer.recognizedGlyph, 'I');
    });

    test('two stems the bar never reaches is not H', () {
      final layer = LatinLayer();
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      drawStroke(layer, const Offset(140, 340), const Offset(260, 340));
      expect(layer.recognizedGlyph, isNot('H'));
    });
  });

  group('I', () {
    test('a plain upright touching nothing is I', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'I');
    });

    test('drawn bottom to top it is still I', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(200, 300), const Offset(200, 120));
      expect(layer.recognizedGlyph, 'I');
    });

    test('a diagonal is not I', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(250, 300));
      expect(layer.recognizedGlyph, isNot('I'));
    });

    test('a bar is not I', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      expect(layer.recognizedGlyph, isNot('I'));
    });

    test('a stem crossed by an earlier stroke is not I', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(120, 210), const Offset(280, 210));
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      expect(layer.recognizedGlyph, isNot('I'));
    });

    test('a stem beside an untouched earlier stroke is still I', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(60, 120), const Offset(60, 300));
      drawStroke(layer, const Offset(300, 120), const Offset(300, 300));
      expect(layer.recognizedGlyph, 'I');
    });
  });

  group('K', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    // In to the stem, then away again.
    const arm = [Offset(250, 120), Offset(150, 210), Offset(250, 300)];

    test('a stem with an arm turning on it is K', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, arm);
      expect(layer.recognizedGlyph, 'K');
    });

    test('the arm drawn first is still K', () {
      final layer = LatinLayer();
      drawPath(layer, arm);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'K');
    });

    test('an arm carrying past the stem — two crossings — is still K', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(250, 120), Offset(120, 210), Offset(250, 300)]);
      expect(layer.recognizedGlyph, 'K');
    });

    test('an arm that never reaches the stem is not K', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(300, 120), Offset(200, 210), Offset(300, 300)]);
      expect(layer.recognizedGlyph, isNot('K'));
    });

    test('an arm on the stem\'s left is not K', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(140, 120), Offset(50, 210), Offset(140, 300)]);
      expect(layer.recognizedGlyph, isNot('K'));
    });

    test('an arm swinging out and back — P\'s bowl — is not K', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 200), Offset(250, 250), Offset(150, 300)]);
      expect(layer.recognizedGlyph, isNot('K'));
    });
  });

  group('M', () {
    const em = [
      Offset(140, 300),
      Offset(170, 120),
      Offset(200, 240),
      Offset(230, 120),
      Offset(260, 300),
    ];

    test('a stroke rising, falling, rising and falling is M', () {
      final layer = LatinLayer();
      drawPath(layer, em);
      expect(layer.recognizedGlyph, 'M');
    });

    test('one peak short — a Λ — is not M', () {
      final layer = LatinLayer();
      drawPath(layer, const [
        Offset(140, 300),
        Offset(170, 120),
        Offset(200, 240),
      ]);
      expect(layer.recognizedGlyph, isNot('M'));
    });

    test('one peak too many is not M', () {
      final layer = LatinLayer();
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

    test('an M crossed by another stroke is not M', () {
      final layer = LatinLayer();
      drawPath(layer, em);
      expect(layer.recognizedGlyph, 'M');
      drawStroke(layer, const Offset(120, 200), const Offset(280, 200));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a tremor along a leg does not split it into more legs', () {
      final layer = LatinLayer();
      // The same M, but with the hand wobbling a few pixels on the way up
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
      expect(layer.recognizedGlyph, 'M');
    });
  });

  group('W', () {
    // M's own five vertices with their heights swapped: two valleys and a
    // peak between them.
    const w = [
      Offset(140, 120),
      Offset(170, 300),
      Offset(200, 180),
      Offset(230, 300),
      Offset(260, 120),
    ];

    test('a stroke falling, rising, falling and rising is W', () {
      final layer = LatinLayer();
      drawPath(layer, w);
      expect(layer.recognizedGlyph, 'W');
    });

    test('drawn from the other end it is still W', () {
      final layer = LatinLayer();
      drawPath(layer, w.reversed.toList());
      expect(layer.recognizedGlyph, 'W');
    });

    test('the same shape the other way up is M, not W', () {
      final layer = LatinLayer();
      drawPath(layer, const [
        Offset(140, 300),
        Offset(170, 120),
        Offset(200, 240),
        Offset(230, 120),
        Offset(260, 300),
      ]);
      expect(layer.recognizedGlyph, 'M');
    });

    test('one valley short is the V it looks like, not a W', () {
      final layer = LatinLayer();
      drawPath(layer, const [
        Offset(140, 120),
        Offset(170, 300),
        Offset(200, 180),
      ]);
      expect(layer.recognizedGlyph, 'V');
    });

    test('one valley too many is not W', () {
      final layer = LatinLayer();
      drawPath(layer, const [
        Offset(120, 120),
        Offset(150, 300),
        Offset(180, 180),
        Offset(210, 300),
        Offset(240, 180),
        Offset(270, 300),
        Offset(300, 120),
      ]);
      expect(layer.recognizedGlyph, isNull);
    });

    test('a W crossed by another stroke is not W', () {
      final layer = LatinLayer();
      drawPath(layer, w);
      expect(layer.recognizedGlyph, 'W');
      drawStroke(layer, const Offset(120, 220), const Offset(280, 220));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('N', () {
    // Up the left stem, down the diagonal, up the right stem.
    const n = [
      Offset(150, 300),
      Offset(150, 120),
      Offset(250, 300),
      Offset(250, 120),
    ];

    test('a stroke rising, falling and rising is N', () {
      final layer = LatinLayer();
      drawPath(layer, n);
      expect(layer.recognizedGlyph, 'N');
    });

    test('drawn from the other end it is still N', () {
      final layer = LatinLayer();
      // The legs now read down-up-down rather than up-down-up, but the
      // diagonal between them is the same falling line, which is what the
      // test actually asks about.
      drawPath(layer, n.reversed.toList());
      expect(layer.recognizedGlyph, 'N');
    });

    test('the diagonal rising instead — Cyrillic И — is not N', () {
      final layer = LatinLayer();
      drawPath(layer, const [
        Offset(150, 120),
        Offset(150, 300),
        Offset(250, 120),
        Offset(250, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('N'));
    });

    test('an N crossed by another stroke is not N', () {
      final layer = LatinLayer();
      drawPath(layer, n);
      expect(layer.recognizedGlyph, 'N');
      drawStroke(layer, const Offset(120, 160), const Offset(280, 160));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a circle drawn not quite closed is not N', () {
      final layer = LatinLayer();
      // It rises, falls and rises much as N does; only the missing upright
      // stems separate the two.
      drawLoop(layer, const Offset(200, 200), 70, overshoot: -0.08);
      expect(layer.recognizedGlyph, isNot('N'));
    });

    test('outer legs that slant rather than stand plumb is not N', () {
      final layer = LatinLayer();
      // A zigzag with the same three legs and the same falling diagonal
      // between them, but its outer legs splayed past _verticalRatio, so
      // neither reads as the upright stem N needs.
      drawPath(layer, const [
        Offset(100, 300),
        Offset(200, 120),
        Offset(280, 300),
        Offset(380, 120),
      ]);
      expect(layer.recognizedGlyph, isNot('N'));
    });
  });

  group('Q', () {
    // The ring's own box is roughly x[141, 292], y[105, 262], so its centre
    // sits near (216, 183) and the tail has to cross below that.
    const ringCentre = Offset(200, 200);
    const ringRadius = 70.0;

    test('a ring with a descending tail crossing it low down is Q', () {
      final layer = LatinLayer();
      drawLoop(layer, ringCentre, ringRadius);
      drawStroke(layer, const Offset(220, 200), const Offset(330, 300));
      expect(layer.recognizedGlyph, 'Q');
    });

    test('the tail drawn first is still Q', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(220, 200), const Offset(330, 300));
      drawLoop(layer, ringCentre, ringRadius);
      expect(layer.recognizedGlyph, 'Q');
    });

    test('the tail drawn end for end is still Q', () {
      final layer = LatinLayer();
      drawLoop(layer, ringCentre, ringRadius);
      drawStroke(layer, const Offset(330, 300), const Offset(220, 200));
      expect(layer.recognizedGlyph, 'Q');
    });

    test('a ring on its own is O, not Q', () {
      final layer = LatinLayer();
      drawLoop(layer, ringCentre, ringRadius);
      expect(layer.recognizedGlyph, 'O');
    });

    test('a tail that never reaches the ring is not Q', () {
      final layer = LatinLayer();
      drawLoop(layer, ringCentre, ringRadius);
      drawStroke(layer, const Offset(320, 290), const Offset(380, 350));
      expect(layer.recognizedGlyph, isNot('Q'));
    });

    test('a tail slashed through the ring\'s middle is not Q', () {
      final layer = LatinLayer();
      drawLoop(layer, ringCentre, ringRadius);
      // In at the top left and out at the bottom right: one crossing above
      // the ring's centre as well as one below, so it's no Q.
      drawStroke(layer, const Offset(120, 100), const Offset(330, 300));
      expect(layer.recognizedGlyph, isNot('Q'));
    });

    test('an ascending tail is not Q', () {
      final layer = LatinLayer();
      drawLoop(layer, ringCentre, ringRadius);
      drawStroke(layer, const Offset(330, 200), const Offset(220, 300));
      expect(layer.recognizedGlyph, isNot('Q'));
    });

    test('an unclosed ring with a tail is not Q', () {
      final layer = LatinLayer();
      // Never closes, so it's an arc rather than a loop — a C with a slash.
      drawLoop(layer, ringCentre, ringRadius, overshoot: -0.08);
      drawStroke(layer, const Offset(220, 200), const Offset(330, 300));
      expect(layer.recognizedGlyph, isNot('Q'));
    });
  });

  group('R', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    // Across the top of the bowl, home to the stem, then away down the leg.
    const body = [
      Offset(150, 120),
      Offset(230, 140),
      Offset(150, 210),
      Offset(230, 300),
    ];

    test('a stem with a right-left-right body on its right is R', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, body);
      expect(layer.recognizedGlyph, 'R');
    });

    test('the body drawn first is still R', () {
      final layer = LatinLayer();
      drawPath(layer, body);
      // On its own the body is the Z it traces; the stem settles it.
      expect(layer.recognizedGlyph, 'Z');
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'R');
    });

    test('the body drawn from its leg upward is still R', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      // Reversed, the body's run of legs reads left-right-left rather than
      // right-left-right — three legs don't survive reversal — so it's the
      // middle leg's lean that has to carry the shape, and it does.
      drawPath(layer, body.reversed.toList());
      expect(layer.recognizedGlyph, 'R');
    });

    test('a body overshooting the stem each time — 3 meetings — is R', () {
      final layer = LatinLayer();
      // Each leg starts a little left of the stem and crosses it, rather
      // than starting on it: three crossings instead of two.
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(130, 120),
        Offset(230, 140),
        Offset(130, 210),
        Offset(230, 300),
      ]);
      expect(layer.recognizedGlyph, 'R');
    });

    test('a body meeting the stem only once is not R', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(170, 120),
        Offset(230, 140),
        Offset(150, 210),
        Offset(230, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('R'));
    });

    test('a body that never meets the stem is not R', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(200, 120),
        Offset(280, 140),
        Offset(200, 210),
        Offset(280, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('R'));
    });

    test('the body on the stem\'s left is not R', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(250, 120), const Offset(250, 300));
      drawPath(layer, const [
        Offset(250, 120),
        Offset(170, 140),
        Offset(250, 210),
        Offset(170, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('R'));
    });

    test('one leg more — a B — is not R', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(150, 120),
        Offset(230, 140),
        Offset(150, 190),
        Offset(230, 240),
        Offset(150, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('R'));
    });
  });

  group('Y', () {
    // The V, then the stem hanging below its vertex.
    const vee = [Offset(150, 120), Offset(200, 220), Offset(250, 120)];
    const stemTop = Offset(200, 220);
    const stemBottom = Offset(200, 300);

    test('a V with a stem below its vertex is Y', () {
      final layer = LatinLayer();
      drawPath(layer, vee);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'Y');
    });

    test('the stem drawn first is still Y', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, vee);
      expect(layer.recognizedGlyph, 'Y');
    });

    test('a V on its own is V, the same shape without the stem', () {
      final layer = LatinLayer();
      drawPath(layer, vee);
      expect(layer.recognizedGlyph, 'V');
    });

    test('the stem hanging off an arm rather than the vertex is not Y', () {
      final layer = LatinLayer();
      drawPath(layer, vee);
      drawStroke(layer, const Offset(160, 140), const Offset(160, 260));
      expect(layer.recognizedGlyph, isNot('Y'));
    });

    test('the stem standing up inside the V is not Y', () {
      final layer = LatinLayer();
      drawPath(layer, vee);
      drawStroke(layer, const Offset(200, 210), const Offset(200, 130));
      expect(layer.recognizedGlyph, isNot('Y'));
    });

    test('a stem the V never reaches is not Y', () {
      final layer = LatinLayer();
      drawPath(layer, vee);
      drawStroke(layer, const Offset(200, 300), const Offset(200, 380));
      expect(layer.recognizedGlyph, isNot('Y'));
    });

    test('a Λ with a stem below it — not a V — is not Y', () {
      final layer = LatinLayer();
      drawPath(layer,
          const [Offset(150, 220), Offset(200, 120), Offset(250, 220)]);
      drawStroke(layer, const Offset(200, 230), const Offset(200, 310));
      expect(layer.recognizedGlyph, isNot('Y'));
    });
  });

  group('G', () {
    // C's arc: out left across the top, round the back, away right again.
    const arc = [Offset(250, 140), Offset(140, 210), Offset(250, 280)];
    // Up from the arc's lower terminal, then left — the spur and crossbar in
    // one stroke, its elbow at the top right of its own box.
    const spur = [Offset(250, 280), Offset(250, 200), Offset(170, 200)];

    test('an arc finished by a ㄱ-shaped spur at its end is G', () {
      final layer = LatinLayer();
      drawPath(layer, arc);
      drawPath(layer, spur);
      expect(layer.recognizedGlyph, 'G');
    });

    test('the spur drawn first is still G', () {
      final layer = LatinLayer();
      drawPath(layer, spur);
      drawPath(layer, arc);
      expect(layer.recognizedGlyph, 'G');
    });

    test('the spur drawn bar-first is the same corner — still G', () {
      final layer = LatinLayer();
      drawPath(layer, arc);
      drawPath(layer, spur.reversed.toList());
      expect(layer.recognizedGlyph, 'G');
    });

    test('the arc on its own is C, not G', () {
      final layer = LatinLayer();
      drawPath(layer, arc);
      expect(layer.recognizedGlyph, 'C');
    });

    test('a spur meeting the arc partway along rather than at its end '
        'is not G', () {
      final layer = LatinLayer();
      drawPath(layer, arc);
      // The same corner, but run up to and left from the arc's middle.
      drawPath(layer,
          const [Offset(180, 250), Offset(180, 170), Offset(100, 170)]);
      expect(layer.recognizedGlyph, isNot('G'));
    });

    test('a spur that never reaches the arc is not G', () {
      final layer = LatinLayer();
      drawPath(layer, arc);
      drawPath(layer,
          const [Offset(350, 280), Offset(350, 200), Offset(300, 200)]);
      expect(layer.recognizedGlyph, isNot('G'));
    });

    test('a straight bar at the arc\'s end — no elbow — is G as well', () {
      // The second way a hand finishes the letter: no turn down, just a crossbar
      // off the arc's tip.
      final layer = LatinLayer();
      drawPath(layer, arc);
      drawStroke(layer, const Offset(250, 280), const Offset(170, 280));
      expect(layer.recognizedGlyph, 'G');
    });

    test('the bar drawn before the arc is still G', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(250, 280), const Offset(170, 280));
      drawPath(layer, arc);
      expect(layer.recognizedGlyph, 'G');
    });

    test('a bar off the arc\'s upper terminal is G too', () {
      final layer = LatinLayer();
      drawPath(layer, arc);
      drawStroke(layer, const Offset(250, 140), const Offset(170, 140));
      expect(layer.recognizedGlyph, 'G');
    });

    test('a bar reaching out past the bowl is no G', () {
      // A crossbar reaches back *into* the arc. Without that rule the bar form
      // is loose enough to claim an A with an ogonek, the mark reading as a
      // short arc and the A's own bar as the crossbar.
      final layer = LatinLayer();
      drawPath(layer, arc);
      drawStroke(layer, const Offset(250, 280), const Offset(320, 280));
      expect(layer.recognizedGlyph, isNot('G'));
    });

    test('a bar hovering clear of the arc is a macron, not G', () {
      // What keeps the loosened G off the mark that shares its shape: a G's bar
      // meets the arc, a macron must hover. Latvian, which has Ā but no Ḡ, so a
      // hovering bar over an arc reads as the bare C.
      final layer = LatinLayer()..alphabet = Alphabet.latvian;
      drawPath(layer, arc);
      drawStroke(layer, const Offset(230, 90), const Offset(160, 90));
      expect(layer.recognizedGlyph, isNot('G'));
    });

    test('an L-shaped spur — the elbow at the bottom left — is not G', () {
      final layer = LatinLayer();
      drawPath(layer, arc);
      drawPath(layer,
          const [Offset(250, 200), Offset(250, 280), Offset(330, 280)]);
      expect(layer.recognizedGlyph, isNot('G'));
    });
  });

  group('L', () {
    // Down the upright, then right along the foot — Hangul's ㄴ.
    const el = [Offset(150, 120), Offset(150, 300), Offset(250, 300)];

    test('a bend with its elbow at the bottom left is L', () {
      final layer = LatinLayer();
      drawPath(layer, el);
      expect(layer.recognizedGlyph, 'L');
    });

    test('drawn foot-first it is the same bend — still L', () {
      final layer = LatinLayer();
      drawPath(layer, el.reversed.toList());
      expect(layer.recognizedGlyph, 'L');
    });

    test('the elbow at the top left instead is not L', () {
      final layer = LatinLayer();
      drawPath(layer,
          const [Offset(250, 120), Offset(150, 120), Offset(150, 300)]);
      expect(layer.recognizedGlyph, isNot('L'));
    });

    test('the elbow at the bottom right instead is not L', () {
      final layer = LatinLayer();
      drawPath(layer,
          const [Offset(250, 120), Offset(250, 300), Offset(150, 300)]);
      expect(layer.recognizedGlyph, isNot('L'));
    });

    test('a smooth quarter arc bending the same way is not L', () {
      final layer = LatinLayer();
      // Its deepest point sits a quarter of the way along its box rather
      // than in the corner, so it is a curve and not a squared-off bend.
      drawArc(layer, const Offset(250, 200), 100, 180, 90);
      expect(layer.recognizedGlyph, isNot('L'));
    });

    test('a straight line is not L', () {
      final layer = LatinLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      expect(layer.recognizedGlyph, isNot('L'));
    });
  });

  group('J', () {
    // Down the stem on the right, then the hook curling up to the left.
    const jay = [Offset(250, 120), Offset(250, 270), Offset(170, 240)];

    test('a lopsided V — left end low, right end high — is J', () {
      final layer = LatinLayer();
      drawPath(layer, jay);
      expect(layer.recognizedGlyph, 'J');
    });

    test('drawn hook-first it is still J', () {
      final layer = LatinLayer();
      drawPath(layer, jay.reversed.toList());
      expect(layer.recognizedGlyph, 'J');
    });

    test('an even V — both ends high — is V, not J', () {
      final layer = LatinLayer();
      drawPath(layer,
          const [Offset(150, 120), Offset(200, 300), Offset(250, 120)]);
      expect(layer.recognizedGlyph, 'V');
    });

    test('the hook curling the other way is not J', () {
      final layer = LatinLayer();
      // Stem on the left, hook to the right, so the low end is now the right
      // one. That is an upright with a foot running right from it, which is
      // an L — and it's read as one, the foot's slight rise notwithstanding.
      drawPath(layer,
          const [Offset(150, 120), Offset(150, 270), Offset(230, 240)]);
      expect(layer.recognizedGlyph, 'L');
    });

    test('a hook that never rises is not J', () {
      final layer = LatinLayer();
      // The foot runs flat left and never comes back up, so the stroke is
      // never cut in two and there is no falling-then-rising shape at all.
      drawPath(layer,
          const [Offset(250, 120), Offset(250, 270), Offset(170, 270)]);
      expect(layer.recognizedGlyph, isNot('J'));
    });

    test('a J crossed by another stroke is not J', () {
      final layer = LatinLayer();
      drawPath(layer, jay);
      expect(layer.recognizedGlyph, 'J');
      drawStroke(layer, const Offset(140, 200), const Offset(300, 200));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('U', () {
    // Down, flat across the foot, back up — a squared U.
    const squared = [
      Offset(150, 120),
      Offset(150, 260),
      Offset(250, 260),
      Offset(250, 120),
    ];
    // The same letter turned round rather than square.
    const rounded = [
      Offset(150, 120),
      Offset(150, 230),
      Offset(170, 258),
      Offset(200, 262),
      Offset(230, 258),
      Offset(250, 230),
      Offset(250, 120),
    ];

    test('a stroke turning square across its foot is U', () {
      final layer = LatinLayer();
      drawPath(layer, squared);
      expect(layer.recognizedGlyph, 'U');
    });

    test('the same letter turned round is still U', () {
      final layer = LatinLayer();
      drawPath(layer, rounded);
      expect(layer.recognizedGlyph, 'U');
    });

    test('drawn end for end it is still U', () {
      final layer = LatinLayer();
      drawPath(layer, rounded.reversed.toList());
      expect(layer.recognizedGlyph, 'U');
    });

    test('a stroke coming to a point is V, not U', () {
      final layer = LatinLayer();
      drawPath(layer,
          const [Offset(150, 120), Offset(200, 300), Offset(250, 120)]);
      expect(layer.recognizedGlyph, 'V');
    });

    test('a V with its apex off to one side is still V, not U', () {
      final layer = LatinLayer();
      // Level ends, so the two arms span exactly half the width at half the
      // height whatever the apex does — that is the reading a V is meant to
      // give, and the threshold sits above it.
      drawPath(layer,
          const [Offset(150, 120), Offset(160, 300), Offset(250, 120)]);
      expect(layer.recognizedGlyph, 'V');
    });

    test('a V with one arm reaching higher than the other is still V', () {
      final layer = LatinLayer();
      // Uneven ends read wider than a half — the shorter arm is further along
      // by the time the band starts, so it has converged more while the box's
      // width is still set by the two ends. A third of the height between them
      // brings this to about 0.62, which is why the threshold is 0.7 and not
      // something just clear of a half.
      drawPath(layer,
          const [Offset(140, 120), Offset(170, 300), Offset(200, 180)]);
      expect(layer.recognizedGlyph, 'V');
    });

    test('a wide shallow V is not U', () {
      final layer = LatinLayer();
      drawPath(layer,
          const [Offset(100, 160), Offset(200, 260), Offset(300, 160)]);
      expect(layer.recognizedGlyph, isNot('U'));
    });

    test('a U crossed by another stroke is not U', () {
      final layer = LatinLayer();
      drawPath(layer, squared);
      expect(layer.recognizedGlyph, 'U');
      drawStroke(layer, const Offset(120, 200), const Offset(280, 200));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a U with a stem below its foot is Y, not U', () {
      final layer = LatinLayer();
      drawPath(layer, rounded);
      drawStroke(layer, const Offset(200, 262), const Offset(200, 330));
      expect(layer.recognizedGlyph, 'Y');
    });
  });

  group('V', () {
    const vee = [Offset(150, 120), Offset(200, 300), Offset(250, 120)];

    test('a stroke falling then rising is V', () {
      final layer = LatinLayer();
      drawPath(layer, vee);
      expect(layer.recognizedGlyph, 'V');
    });

    test('drawn end for end it is still V', () {
      final layer = LatinLayer();
      drawPath(layer, vee.reversed.toList());
      expect(layer.recognizedGlyph, 'V');
    });

    test('the same shape the other way up — a Λ — is not V', () {
      final layer = LatinLayer();
      drawPath(layer,
          const [Offset(150, 300), Offset(200, 120), Offset(250, 300)]);
      expect(layer.recognizedGlyph, isNot('V'));
    });

    test('a V crossed by another stroke is not V', () {
      final layer = LatinLayer();
      drawPath(layer, vee);
      expect(layer.recognizedGlyph, 'V');
      drawStroke(layer, const Offset(120, 200), const Offset(280, 200));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a V with a stem below its vertex is Y, not V', () {
      final layer = LatinLayer();
      drawPath(layer, vee);
      drawStroke(layer, const Offset(200, 300), const Offset(200, 370));
      expect(layer.recognizedGlyph, 'Y');
    });
  });

  group('Z', () {
    // The top bar, the diagonal down-left, then the bottom bar.
    const zed = [
      Offset(150, 140),
      Offset(250, 140),
      Offset(150, 280),
      Offset(250, 280),
    ];

    test('a stroke running right, back left and right again is Z', () {
      final layer = LatinLayer();
      drawPath(layer, zed);
      expect(layer.recognizedGlyph, 'Z');
    });

    test('drawn end for end it is still Z', () {
      final layer = LatinLayer();
      drawPath(layer, zed.reversed.toList());
      expect(layer.recognizedGlyph, 'Z');
    });

    test('the same run of legs mirrored — an S — is not Z', () {
      final layer = LatinLayer();
      drawPath(layer, const [
        Offset(250, 140),
        Offset(150, 140),
        Offset(250, 280),
        Offset(150, 280),
      ]);
      expect(layer.recognizedGlyph, isNot('Z'));
    });

    test('one leg short is not Z', () {
      final layer = LatinLayer();
      drawPath(layer,
          const [Offset(150, 140), Offset(250, 140), Offset(150, 280)]);
      expect(layer.recognizedGlyph, isNot('Z'));
    });

    test('a Z with a stem laid against it is R, not Z', () {
      final layer = LatinLayer();
      drawPath(layer, zed);
      expect(layer.recognizedGlyph, 'Z');
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      expect(layer.recognizedGlyph, 'R');
    });
  });

  group('S', () {
    // Left across the top, back right through the waist, left again.
    const ess = [
      Offset(250, 140),
      Offset(150, 180),
      Offset(250, 240),
      Offset(150, 280),
    ];

    test('a stroke running left, back right and left again is S', () {
      final layer = LatinLayer();
      drawPath(layer, ess);
      expect(layer.recognizedGlyph, 'S');
    });

    test('drawn end for end it is still S', () {
      final layer = LatinLayer();
      drawPath(layer, ess.reversed.toList());
      expect(layer.recognizedGlyph, 'S');
    });

    test('the same run of legs mirrored — a Z — is not S', () {
      final layer = LatinLayer();
      drawPath(layer, const [
        Offset(150, 140),
        Offset(250, 180),
        Offset(150, 240),
        Offset(250, 280),
      ]);
      expect(layer.recognizedGlyph, isNot('S'));
    });

    test('one leg short — C\'s arc — is not S', () {
      final layer = LatinLayer();
      drawPath(layer,
          const [Offset(250, 140), Offset(150, 210), Offset(250, 280)]);
      expect(layer.recognizedGlyph, isNot('S'));
    });

    test('an S crossed by another stroke is not S', () {
      final layer = LatinLayer();
      drawPath(layer, ess);
      expect(layer.recognizedGlyph, 'S');
      drawStroke(layer, const Offset(200, 100), const Offset(200, 320));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('Å, Ä, Ö and Ü', () {
    // The A the marks go over, low enough on the page to leave room above it.
    const apex = [Offset(150, 300), Offset(200, 180), Offset(250, 300)];
    const barLeft = Offset(160, 260);
    const barRight = Offset(240, 260);

    void drawA(LatinLayer layer) {
      drawPath(layer, apex);
      drawStroke(layer, barLeft, barRight);
    }

    LatinLayer nordic() => LatinLayer()..alphabet = Alphabet.finnish;

    test('an A with two dots above it is Ä', () {
      final layer = nordic();
      drawA(layer);
      expect(layer.recognizedGlyph, 'A');
      tap(layer, const Offset(180, 140));
      tap(layer, const Offset(220, 140));
      expect(layer.recognizedGlyph, 'Ä');
    });

    test('the dots tapped before the A is still Ä', () {
      final layer = nordic();
      tap(layer, const Offset(180, 140));
      tap(layer, const Offset(220, 140));
      expect(layer.recognizedGlyph, isNull);
      drawA(layer);
      expect(layer.recognizedGlyph, 'Ä');
    });

    test('one dot is not enough for Ä', () {
      final layer = nordic();
      drawA(layer);
      tap(layer, const Offset(200, 140));
      expect(layer.recognizedGlyph, 'A');
    });

    test('dots down inside the A are not a diaeresis', () {
      final layer = nordic();
      drawA(layer);
      tap(layer, const Offset(190, 230));
      tap(layer, const Offset(210, 230));
      expect(layer.recognizedGlyph, 'A');
    });

    test('dots off to one side of the A are not a diaeresis', () {
      final layer = nordic();
      drawA(layer);
      tap(layer, const Offset(300, 140));
      tap(layer, const Offset(340, 140));
      expect(layer.recognizedGlyph, 'A');
    });

    test('an O with two dots above it is Ö', () {
      final layer = nordic();
      drawLoop(layer, const Offset(200, 250), 60);
      expect(layer.recognizedGlyph, 'O');
      tap(layer, const Offset(190, 150));
      tap(layer, const Offset(220, 150));
      expect(layer.recognizedGlyph, 'Ö');
    });

    test('an A with a ring above it is Å', () {
      final layer = nordic();
      drawA(layer);
      drawLoop(layer, const Offset(200, 120), 22,
          drift: const Offset(8, -12));
      expect(layer.recognizedGlyph, 'Å');
    });

    test('the ring drawn before the A is still Å', () {
      final layer = nordic();
      drawLoop(layer, const Offset(200, 120), 22,
          drift: const Offset(8, -12));
      expect(layer.recognizedGlyph, 'O');
      drawA(layer);
      expect(layer.recognizedGlyph, 'Å');
    });

    test('a ring down inside the A is not Å', () {
      final layer = nordic();
      drawA(layer);
      drawLoop(layer, const Offset(200, 250), 22,
          drift: const Offset(8, -12));
      expect(layer.recognizedGlyph, isNot('Å'));
    });

    test('a tap on its own is no letter at all', () {
      final layer = nordic();
      tap(layer, const Offset(200, 200));
      expect(layer.recognizedGlyph, isNull);
    });

    test('dots are dropped by clear() along with the strokes', () {
      final layer = nordic();
      drawA(layer);
      tap(layer, const Offset(180, 140));
      tap(layer, const Offset(220, 140));
      expect(layer.recognizedGlyph, 'Ä');
      layer.clear();
      expect(layer.recognizedGlyph, isNull);
      drawA(layer);
      expect(layer.recognizedGlyph, 'A');
    });

    test('English has none of the three, so each falls back to its base', () {
      final diaeresis = LatinLayer();
      drawA(diaeresis);
      tap(diaeresis, const Offset(180, 140));
      tap(diaeresis, const Offset(220, 140));
      expect(diaeresis.recognizedGlyph, 'A');

      final ring = LatinLayer();
      drawA(ring);
      drawLoop(ring, const Offset(200, 120), 22, drift: const Offset(8, -12));
      // The ring is a stroke, so unlike the dots it takes up one of the slots
      // the A is read from — but the mark is set aside and the letter beneath
      // reported all the same.
      expect(ring.recognizedGlyph, 'A');
    });

    test('a U with two dots above it is Ü in German', () {
      final layer = LatinLayer()..alphabet = Alphabet.german;
      drawPath(layer, const [
        Offset(150, 180),
        Offset(150, 300),
        Offset(250, 300),
        Offset(250, 180),
      ]);
      expect(layer.recognizedGlyph, 'U');
      tap(layer, const Offset(180, 140));
      tap(layer, const Offset(220, 140));
      expect(layer.recognizedGlyph, 'Ü');
    });

    test('Finnish has no Ü, so the same drawing reads U', () {
      final layer = LatinLayer()..alphabet = Alphabet.finnish;
      drawPath(layer, const [
        Offset(150, 180),
        Offset(150, 300),
        Offset(250, 300),
        Offset(250, 180),
      ]);
      tap(layer, const Offset(180, 140));
      tap(layer, const Offset(220, 140));
      expect(layer.recognizedGlyph, 'U');
    });

    test('German has no Å, so an A with a ring reads as the plain A', () {
      final layer = LatinLayer()..alphabet = Alphabet.german;
      drawA(layer);
      drawLoop(layer, const Offset(200, 120), 22,
          drift: const Offset(8, -12));
      expect(layer.recognizedGlyph, 'A');
    });

    test('German reads Ä and Ö just as Finnish/Swedish does', () {
      for (final alphabet in [Alphabet.german, Alphabet.finnish]) {
        final umlautA = LatinLayer()..alphabet = alphabet;
        drawA(umlautA);
        tap(umlautA, const Offset(180, 140));
        tap(umlautA, const Offset(220, 140));
        expect(umlautA.recognizedGlyph, 'Ä', reason: alphabet.label);

        final umlautO = LatinLayer()..alphabet = alphabet;
        drawLoop(umlautO, const Offset(200, 250), 60);
        tap(umlautO, const Offset(190, 150));
        tap(umlautO, const Offset(220, 150));
        expect(umlautO.recognizedGlyph, 'Ö', reason: alphabet.label);
      }
    });

    test('switching to Finnish/Swedish re-reads an A as the Ä it is', () {
      final layer = LatinLayer();
      drawA(layer);
      tap(layer, const Offset(180, 140));
      tap(layer, const Offset(220, 140));
      expect(layer.recognizedGlyph, 'A');
      layer.alphabet = Alphabet.finnish;
      expect(layer.recognizedGlyph, 'Ä');
    });
  });

  group('Ø', () {
    const ringCentre = Offset(200, 200);
    const ringRadius = 70.0;
    // Up to the right, clean through the middle.
    const slashFrom = Offset(120, 290);
    const slashTo = Offset(290, 110);

    LatinLayer nordic() => LatinLayer()..alphabet = Alphabet.norwegian;

    test('a ring slashed through the middle is Ø', () {
      final layer = nordic();
      drawLoop(layer, ringCentre, ringRadius);
      drawStroke(layer, slashFrom, slashTo);
      expect(layer.recognizedGlyph, 'Ø');
    });

    test('the slash drawn first is still Ø', () {
      final layer = nordic();
      drawStroke(layer, slashFrom, slashTo);
      drawLoop(layer, ringCentre, ringRadius);
      expect(layer.recognizedGlyph, 'Ø');
    });

    test('the slash drawn end for end is still Ø', () {
      final layer = nordic();
      drawLoop(layer, ringCentre, ringRadius);
      drawStroke(layer, slashTo, slashFrom);
      expect(layer.recognizedGlyph, 'Ø');
    });

    test('a slash falling to the right instead is not Ø', () {
      final layer = nordic();
      drawLoop(layer, ringCentre, ringRadius);
      drawStroke(layer, const Offset(120, 110), const Offset(290, 290));
      expect(layer.recognizedGlyph, isNot('Ø'));
    });

    test('a slash that picks up a third crossing is still Ø', () {
      final layer = nordic();
      // A ring closes by overlapping itself; a slash through where its two ends
      // cross meets it once more than it asked for, and is the same letter.
      drawLoop(layer, ringCentre, ringRadius);
      drawStroke(layer, const Offset(130, 270), const Offset(300, 150));
      expect(layer.recognizedGlyph, 'Ø');
    });

    test('a slash clear of the ring\'s middle is not Ø', () {
      final layer = nordic();
      // Both crossings below the middle: that is Q's arrangement, not Ø's.
      drawLoop(layer, ringCentre, ringRadius);
      drawStroke(layer, const Offset(150, 280), const Offset(280, 240));
      expect(layer.recognizedGlyph, isNot('Ø'));
    });

    test('a ring on its own is O, not Ø', () {
      final layer = nordic();
      drawLoop(layer, ringCentre, ringRadius);
      expect(layer.recognizedGlyph, 'O');
    });

    test('a tail crossing only the lower half is Q, not Ø', () {
      final layer = nordic();
      drawLoop(layer, ringCentre, ringRadius);
      drawStroke(layer, const Offset(220, 200), const Offset(330, 300));
      expect(layer.recognizedGlyph, 'Q');
    });

    test('a slash that never reaches the ring is not Ø', () {
      final layer = nordic();
      drawLoop(layer, ringCentre, ringRadius);
      drawStroke(layer, const Offset(320, 320), const Offset(380, 260));
      expect(layer.recognizedGlyph, isNot('Ø'));
    });

    test('an unclosed ring with a slash is not Ø', () {
      final layer = nordic();
      drawLoop(layer, ringCentre, ringRadius, overshoot: -0.08);
      drawStroke(layer, slashFrom, slashTo);
      expect(layer.recognizedGlyph, isNot('Ø'));
    });

    test('the alphabets without Ø read the same drawing as nothing', () {
      for (final alphabet in [Alphabet.english, Alphabet.german]) {
        final layer = LatinLayer()..alphabet = alphabet;
        drawLoop(layer, ringCentre, ringRadius);
        drawStroke(layer, slashFrom, slashTo);
        expect(layer.recognizedGlyph, isNull, reason: alphabet.label);
      }
    });
  });

  group('Æ', () {
    // The body, in one stroke: up A's left leg to the apex, then down the
    // shared upright and away along the foot — an L.
    const body = [
      Offset(120, 300),
      Offset(200, 140),
      Offset(200, 290),
      Offset(270, 290),
    ];
    // A's crossbar and E's middle bar at once, crossing both uprights.
    const lowerLeft = Offset(140, 220);
    const lowerRight = Offset(270, 220);
    // E's top bar, off the apex and away right.
    const upperLeft = Offset(200, 140);
    const upperRight = Offset(270, 140);

    void drawAe(LatinLayer layer) {
      drawPath(layer, body);
      drawStroke(layer, lowerLeft, lowerRight);
      drawStroke(layer, upperLeft, upperRight);
    }

    LatinLayer nordic() => LatinLayer()..alphabet = Alphabet.norwegian;

    test('a rise-then-L body with a crossbar and a top bar is Æ', () {
      final layer = nordic();
      drawAe(layer);
      expect(layer.recognizedGlyph, 'Æ');
    });

    test('the bars drawn before the body is still Æ', () {
      final layer = nordic();
      drawStroke(layer, upperLeft, upperRight);
      drawStroke(layer, lowerLeft, lowerRight);
      drawPath(layer, body);
      expect(layer.recognizedGlyph, 'Æ');
    });

    test('the top bar drawn before the crossbar is still Æ', () {
      final layer = nordic();
      drawPath(layer, body);
      drawStroke(layer, upperLeft, upperRight);
      drawStroke(layer, lowerLeft, lowerRight);
      expect(layer.recognizedGlyph, 'Æ');
    });

    test('the body drawn from its foot back is still Æ', () {
      final layer = nordic();
      drawPath(layer, body.reversed.toList());
      drawStroke(layer, lowerLeft, lowerRight);
      drawStroke(layer, upperLeft, upperRight);
      expect(layer.recognizedGlyph, 'Æ');
    });

    test('a top bar reaching left across both uprights is still Æ', () {
      final layer = nordic();
      drawPath(layer, body);
      drawStroke(layer, lowerLeft, lowerRight);
      drawStroke(layer, const Offset(160, 150), const Offset(270, 150));
      expect(layer.recognizedGlyph, 'Æ');
    });

    test('a crossbar that misses the rise is not Æ', () {
      final layer = nordic();
      drawPath(layer, body);
      // Starting right of the rise, so it meets the upright alone.
      drawStroke(layer, const Offset(190, 220), lowerRight);
      drawStroke(layer, upperLeft, upperRight);
      expect(layer.recognizedGlyph, isNot('Æ'));
    });

    test('a crossbar that misses the upright is not Æ', () {
      final layer = nordic();
      drawPath(layer, body);
      drawStroke(layer, const Offset(130, 220), const Offset(185, 220));
      drawStroke(layer, upperLeft, upperRight);
      expect(layer.recognizedGlyph, isNot('Æ'));
    });

    test('a top bar that never reaches the body is not Æ', () {
      final layer = nordic();
      drawPath(layer, body);
      drawStroke(layer, lowerLeft, lowerRight);
      drawStroke(layer, const Offset(290, 140), const Offset(370, 140));
      expect(layer.recognizedGlyph, isNot('Æ'));
    });

    test('two bars at the same height is not Æ', () {
      final layer = nordic();
      drawPath(layer, body);
      drawStroke(layer, lowerLeft, lowerRight);
      drawStroke(layer, const Offset(140, 223), const Offset(270, 223));
      expect(layer.recognizedGlyph, isNot('Æ'));
    });

    test('a Λ body — no L in its fall — is not Æ', () {
      final layer = nordic();
      drawPath(layer,
          const [Offset(120, 300), Offset(200, 140), Offset(270, 290)]);
      drawStroke(layer, lowerLeft, lowerRight);
      drawStroke(layer, upperLeft, upperRight);
      expect(layer.recognizedGlyph, isNot('Æ'));
    });

    test('the body with one bar is an A, the up-down being all A asks', () {
      final layer = nordic();
      drawPath(layer, body);
      drawStroke(layer, lowerLeft, lowerRight);
      expect(layer.recognizedGlyph, 'A');
    });

    test('the alphabets without Æ read the same drawing as nothing', () {
      for (final alphabet in [Alphabet.english, Alphabet.german]) {
        final layer = LatinLayer()..alphabet = alphabet;
        drawAe(layer);
        expect(layer.recognizedGlyph, isNull, reason: alphabet.label);
      }
    });

    test('switching to Norwegian re-reads it as the Æ it is', () {
      final layer = LatinLayer();
      drawAe(layer);
      expect(layer.recognizedGlyph, isNull);
      layer.alphabet = Alphabet.norwegian;
      expect(layer.recognizedGlyph, 'Æ');
    });
  });

  group('ß', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    // Off the stem's top, out right and back, out right and away — the lower
    // bowl running out open to the left rather than home to the stem.
    const bowls = [
      Offset(150, 130),
      Offset(230, 160),
      Offset(175, 200),
      Offset(240, 240),
      Offset(170, 290),
    ];

    LatinLayer german() => LatinLayer()..alphabet = Alphabet.german;

    test('a stem with bowls meeting it once at the top is ß', () {
      final layer = german();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowls);
      expect(layer.recognizedGlyph, 'ß');
    });

    test('the bowls drawn before the stem is still ß', () {
      final layer = german();
      drawPath(layer, bowls);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'ß');
    });

    test('bowls that cross their own path are still ß', () {
      final layer = german();
      drawStroke(layer, stemTop, stemBottom);
      // The upper bowl's return overshoots above where it set off, so the
      // stroke genuinely crosses itself — which ß allows and B does too.
      drawPath(layer, const [
        Offset(150, 130),
        Offset(240, 170),
        Offset(155, 120),
        Offset(240, 230),
        Offset(170, 290),
      ]);
      expect(layer.recognizedGlyph, 'ß');
    });

    test('bowls that come home to the stem are a B, not ß', () {
      final layer = german();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(150, 120),
        Offset(240, 150),
        Offset(150, 210),
        Offset(240, 250),
        Offset(150, 300),
      ]);
      expect(layer.recognizedGlyph, 'B');
    });

    test('bowls meeting the stem away down its length is not ß', () {
      final layer = german();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(150, 230),
        Offset(230, 250),
        Offset(175, 270),
        Offset(240, 285),
        Offset(180, 298),
      ]);
      expect(layer.recognizedGlyph, isNot('ß'));
    });

    test('bowls that never reach the stem are not ß', () {
      final layer = german();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(200, 130),
        Offset(280, 160),
        Offset(225, 200),
        Offset(290, 240),
        Offset(220, 290),
      ]);
      expect(layer.recognizedGlyph, isNot('ß'));
    });

    test('a stem standing right of the bowls is not ß', () {
      final layer = german();
      drawStroke(layer, const Offset(250, 120), const Offset(250, 300));
      drawPath(layer, const [
        Offset(250, 130),
        Offset(170, 160),
        Offset(225, 200),
        Offset(160, 240),
        Offset(230, 290),
      ]);
      expect(layer.recognizedGlyph, isNot('ß'));
    });

    test('one bowl short is not ß', () {
      final layer = german();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 130), Offset(230, 170), Offset(175, 220)]);
      expect(layer.recognizedGlyph, isNot('ß'));
    });

    test('the alphabets without ß read the same drawing as nothing', () {
      for (final alphabet in [
        Alphabet.english,
        Alphabet.latin,
        Alphabet.finnish,
      ]) {
        final layer = LatinLayer()..alphabet = alphabet;
        drawStroke(layer, stemTop, stemBottom);
        drawPath(layer, bowls);
        expect(layer.recognizedGlyph, isNull, reason: alphabet.label);
      }
    });

    test('switching to German re-reads it as the ß it is', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowls);
      expect(layer.recognizedGlyph, isNull);
      layer.alphabet = Alphabet.german;
      expect(layer.recognizedGlyph, 'ß');
    });
  });

  group('the marks', () {
    // Every base is drawn low and about 100 wide, so its box tops out at y=185
    // or below and one set of marks — all of them above y=170 — sits over any of
    // them. Nothing here depends on which base a mark is over except the letter
    // it comes out as.
    void drawA(LatinLayer layer) {
      drawPath(layer,
          const [Offset(150, 320), Offset(200, 200), Offset(250, 320)]);
      drawStroke(layer, const Offset(160, 280), const Offset(240, 280));
    }

    void drawE(LatinLayer layer) {
      drawStroke(layer, const Offset(150, 200), const Offset(150, 340));
      drawStroke(layer, const Offset(150, 200), const Offset(250, 200));
      drawStroke(layer, const Offset(150, 270), const Offset(250, 270));
      drawStroke(layer, const Offset(150, 340), const Offset(250, 340));
    }

    void drawI(LatinLayer layer) =>
        drawStroke(layer, const Offset(200, 200), const Offset(200, 340));

    void drawO(LatinLayer layer) => drawLoop(layer, const Offset(200, 270), 60);

    void drawU(LatinLayer layer) => drawPath(layer, const [
          Offset(150, 220),
          Offset(150, 340),
          Offset(250, 340),
          Offset(250, 220),
        ]);

    void drawN(LatinLayer layer) => drawPath(layer, const [
          Offset(150, 340),
          Offset(150, 200),
          Offset(250, 340),
          Offset(250, 200),
        ]);

    void drawY(LatinLayer layer) {
      drawPath(layer,
          const [Offset(150, 200), Offset(200, 300), Offset(250, 200)]);
      drawStroke(layer, const Offset(200, 300), const Offset(200, 360));
    }

    void drawAcute(LatinLayer layer) =>
        drawStroke(layer, const Offset(180, 170), const Offset(220, 140));

    void drawGrave(LatinLayer layer) =>
        drawStroke(layer, const Offset(180, 140), const Offset(220, 170));

    void drawCircumflex(LatinLayer layer) => drawPath(layer,
        const [Offset(175, 170), Offset(200, 140), Offset(225, 170)]);

    void drawTilde(LatinLayer layer) => drawPath(layer, const [
          Offset(170, 165),
          Offset(190, 145),
          Offset(210, 165),
          Offset(230, 145),
        ]);

    void drawDots(LatinLayer layer) {
      tap(layer, const Offset(185, 150));
      tap(layer, const Offset(215, 150));
    }

    LatinLayer on(Alphabet alphabet) => LatinLayer()..alphabet = alphabet;

    group('acute — a line rising to the right', () {
      // Icelandic is the one alphabet with all six.
      final bases = <String, void Function(LatinLayer)>{
        'Á': drawA,
        'É': drawE,
        'Í': drawI,
        'Ó': drawO,
        'Ú': drawU,
        'Ý': drawY,
      };

      bases.forEach((glyph, drawBase) {
        test('over its base it is $glyph', () {
          final layer = on(Alphabet.icelandic);
          drawBase(layer);
          drawAcute(layer);
          expect(layer.recognizedGlyph, glyph);
        });

        test('drawn before its base it is still $glyph', () {
          final layer = on(Alphabet.icelandic);
          drawAcute(layer);
          drawBase(layer);
          expect(layer.recognizedGlyph, glyph);
        });
      });

      test('drawn end for end it is still Á', () {
        final layer = on(Alphabet.icelandic);
        drawA(layer);
        drawStroke(layer, const Offset(220, 140), const Offset(180, 170));
        expect(layer.recognizedGlyph, 'Á');
      });

      test('an acute is the very shape Ø\'s slash is', () {
        // Told apart only by where it sits: above a letter, or across a ring.
        final slash = on(Alphabet.norwegian);
        drawLoop(slash, const Offset(200, 200), 70);
        drawStroke(slash, const Offset(120, 290), const Offset(290, 110));
        expect(slash.recognizedGlyph, 'Ø');
      });
    });

    group('grave — the same line falling', () {
      // Italian is the one alphabet with all five.
      final bases = <String, void Function(LatinLayer)>{
        'À': drawA,
        'È': drawE,
        'Ì': drawI,
        'Ò': drawO,
        'Ù': drawU,
      };

      bases.forEach((glyph, drawBase) {
        test('over its base it is $glyph', () {
          final layer = on(Alphabet.italian);
          drawBase(layer);
          drawGrave(layer);
          expect(layer.recognizedGlyph, glyph);
        });
      });

      test('a grave is not an acute', () {
        final layer = on(Alphabet.italian);
        drawA(layer);
        drawAcute(layer);
        // Italian has no Á, so the acute is passed over and the A read plain.
        expect(layer.recognizedGlyph, 'A');
      });
    });

    group('circumflex — a Λ above', () {
      // French is the one alphabet with all five.
      final bases = <String, void Function(LatinLayer)>{
        'Â': drawA,
        'Ê': drawE,
        'Î': drawI,
        'Ô': drawO,
        'Û': drawU,
      };

      bases.forEach((glyph, drawBase) {
        test('over its base it is $glyph', () {
          final layer = on(Alphabet.french);
          drawBase(layer);
          drawCircumflex(layer);
          expect(layer.recognizedGlyph, glyph);
        });
      });

      test('a circumflex over a bar is no A, its bar crossing neither leg', () {
        // The circumflex answers A's own up-down, so the pair would be an A but
        // for the bar sitting below it rather than across it.
        final layer = on(Alphabet.french);
        drawStroke(layer, const Offset(160, 280), const Offset(240, 280));
        drawCircumflex(layer);
        expect(layer.recognizedGlyph, isNull);
      });
    });

    group('tilde — three legs to and fro above', () {
      test('over an A it is Ã', () {
        final layer = on(Alphabet.portuguese);
        drawA(layer);
        drawTilde(layer);
        expect(layer.recognizedGlyph, 'Ã');
      });

      test('over an O it is Õ', () {
        final layer = on(Alphabet.portuguese);
        drawO(layer);
        drawTilde(layer);
        expect(layer.recognizedGlyph, 'Õ');
      });

      test('over an N it is Ñ', () {
        // Spanish has Ñ; Portuguese, which has Ã and Õ, does not.
        final layer = on(Alphabet.spanish);
        drawN(layer);
        drawTilde(layer);
        expect(layer.recognizedGlyph, 'Ñ');
      });

      test('a tilde on its own is no N, its outer legs being slants', () {
        final layer = on(Alphabet.spanish);
        drawTilde(layer);
        expect(layer.recognizedGlyph, isNull);
      });
    });

    group('diaeresis — a pair of taps above', () {
      test('German reads Ä, Ö and Ü', () {
        for (final (glyph, drawBase) in [
          ('Ä', drawA),
          ('Ö', drawO),
          ('Ü', drawU),
        ]) {
          final layer = on(Alphabet.german);
          drawBase(layer);
          drawDots(layer);
          expect(layer.recognizedGlyph, glyph);
        }
      });

      test('French reads Ë, Ï and Ÿ — the same mark, three more bases', () {
        for (final (glyph, drawBase) in [
          ('Ë', drawE),
          ('Ï', drawI),
          ('Ÿ', drawY),
        ]) {
          final layer = on(Alphabet.french);
          drawBase(layer);
          drawDots(layer);
          expect(layer.recognizedGlyph, glyph);
        }
      });

      test('one tap is not a diaeresis', () {
        final layer = on(Alphabet.german);
        drawA(layer);
        tap(layer, const Offset(200, 150));
        expect(layer.recognizedGlyph, 'A');
      });
    });

    group('ring — a loop above', () {
      test('over an A it is Å', () {
        final layer = on(Alphabet.norwegian);
        drawA(layer);
        drawLoop(layer, const Offset(200, 150), 22,
            drift: const Offset(8, -12));
        expect(layer.recognizedGlyph, 'Å');
      });

      test('the ring is tried before the tilde, both being three legs', () {
        // A ring swept up from its foot leaves the same run of legs a tilde
        // does, so the order in _classify is what settles it.
        final layer = on(Alphabet.swedish);
        drawA(layer);
        drawLoop(layer, const Offset(200, 150), 22,
            drift: const Offset(8, -12));
        expect(layer.recognizedGlyph, 'Å');
      });
    });

    // Bases beyond the seven the marks first sat over. Each is drawn low, about
    // 100 wide, topping out at y=200 or below, so the same marks reach over any of
    // them.
    void drawC(LatinLayer layer) => drawPath(layer,
        const [Offset(250, 220), Offset(140, 280), Offset(250, 340)]);

    void drawD(LatinLayer layer) {
      drawStroke(layer, const Offset(150, 200), const Offset(150, 340));
      drawPath(layer,
          const [Offset(150, 200), Offset(250, 270), Offset(150, 340)]);
    }

    void drawG(LatinLayer layer) {
      drawPath(layer,
          const [Offset(250, 220), Offset(140, 280), Offset(250, 340)]);
      drawPath(layer,
          const [Offset(250, 340), Offset(250, 275), Offset(180, 275)]);
    }

    void drawH(LatinLayer layer) {
      drawStroke(layer, const Offset(150, 200), const Offset(150, 340));
      drawStroke(layer, const Offset(250, 200), const Offset(250, 340));
      drawStroke(layer, const Offset(140, 270), const Offset(260, 270));
    }

    void drawJ(LatinLayer layer) => drawPath(layer,
        const [Offset(250, 200), Offset(250, 330), Offset(170, 305)]);

    void drawL(LatinLayer layer) => drawPath(layer,
        const [Offset(150, 200), Offset(150, 340), Offset(250, 340)]);

    void drawR(LatinLayer layer) {
      drawStroke(layer, const Offset(150, 200), const Offset(150, 340));
      drawPath(layer, const [
        Offset(150, 200),
        Offset(230, 220),
        Offset(150, 270),
        Offset(230, 340),
      ]);
    }

    void drawS(LatinLayer layer) => drawPath(layer, const [
          Offset(250, 210),
          Offset(150, 245),
          Offset(250, 295),
          Offset(150, 335),
        ]);

    void drawT(LatinLayer layer) {
      drawStroke(layer, const Offset(150, 200), const Offset(250, 200));
      drawStroke(layer, const Offset(200, 200), const Offset(200, 340));
    }

    void drawW(LatinLayer layer) => drawPath(layer, const [
          Offset(140, 200),
          Offset(170, 340),
          Offset(200, 250),
          Offset(230, 340),
          Offset(260, 200),
        ]);

    void drawZ(LatinLayer layer) => drawPath(layer, const [
          Offset(150, 215),
          Offset(250, 215),
          Offset(150, 330),
          Offset(250, 330),
        ]);

    void drawCaron(LatinLayer layer) => drawPath(layer,
        const [Offset(175, 140), Offset(200, 170), Offset(225, 140)]);

    void drawOneDot(LatinLayer layer) => tap(layer, const Offset(200, 150));

    group('caron — a V above', () {
      // Czech and Slovak between them want all nine.
      final bases = <String, void Function(LatinLayer)>{
        'Č': drawC,
        'Ď': drawD,
        'Ě': drawE,
        'Ľ': drawL,
        'Ň': drawN,
        'Ř': drawR,
        'Š': drawS,
        'Ť': drawT,
        'Ž': drawZ,
      };

      bases.forEach((glyph, drawBase) {
        test('over its base it is $glyph', () {
          // No one alphabet has all nine: Ě and Ř are Czech's and Ľ is Slovak's,
          // the two languages differing in exactly those.
          final layer =
              on(glyph == 'Ľ' ? Alphabet.slovak : Alphabet.czech);
          drawBase(layer);
          drawCaron(layer);
          expect(layer.recognizedGlyph, glyph);
        });
      });

      test('drawn before its base it is still Š', () {
        final layer = on(Alphabet.czech);
        drawCaron(layer);
        drawS(layer);
        expect(layer.recognizedGlyph, 'Š');
      });

      test('a caron is the circumflex inverted, and never confused with it', () {
        final caron = on(Alphabet.french);
        drawA(caron);
        drawCaron(caron);
        // French has no Ǎ, so the caron is passed over and the A read plain.
        expect(caron.recognizedGlyph, 'A');

        final circumflex = on(Alphabet.french);
        drawA(circumflex);
        drawCircumflex(circumflex);
        expect(circumflex.recognizedGlyph, 'Â');
      });

      test('English has no Š, so the same drawing reads S', () {
        final layer = on(Alphabet.english);
        drawS(layer);
        drawCaron(layer);
        expect(layer.recognizedGlyph, 'S');
      });

      group('tucked inside the letter instead of over it', () {
        // Slovak's Ľ isn't a wedge above the L at all — it's a raised stroke
        // against the upright, inside the letter's own box. Czech writes Ď and Ť
        // the same way. There's room in there: see Ŀ, a dot in the same place.
        void drawInnerCaron(LatinLayer layer) => drawPath(layer, const [
              Offset(185, 215),
              Offset(195, 245),
              Offset(210, 220),
            ]);

        test('a caron inside L\'s box is Ľ', () {
          final layer = on(Alphabet.slovak);
          drawL(layer);
          drawInnerCaron(layer);
          expect(layer.recognizedGlyph, 'Ľ');
        });

        test('drawn before the L it is still Ľ', () {
          final layer = on(Alphabet.slovak);
          drawInnerCaron(layer);
          drawL(layer);
          expect(layer.recognizedGlyph, 'Ľ');
        });

        test('a caron above the L is Ľ as well', () {
          // Both placements, one letter — the mark is found either way.
          final layer = on(Alphabet.slovak);
          drawL(layer);
          drawCaron(layer);
          expect(layer.recognizedGlyph, 'Ľ');
        });

        test('D takes it inside too, as Czech writes Ď', () {
          final layer = on(Alphabet.czech);
          drawD(layer);
          drawInnerCaron(layer);
          expect(layer.recognizedGlyph, 'Ď');
        });

        test('a dot in the same place is Ŀ, not a caron', () {
          // Disjoint by shape: a tap is not a V.
          final layer = on(Alphabet.catalan);
          drawL(layer);
          tap(layer, const Offset(195, 230));
          expect(layer.recognizedGlyph, 'Ŀ');
        });

        test('English has no Ľ, so the same drawing reads L', () {
          final layer = on(Alphabet.english);
          drawL(layer);
          drawInnerCaron(layer);
          expect(layer.recognizedGlyph, 'L');
        });

        test('a V that is part of its letter is not a caron inside it', () {
          // Why letting the caron sit inside costs nothing: within is the strict
          // test, asking every point of the mark to fall in the letter's box, and
          // a V belonging to a letter is as wide as the letter it belongs to.
          final layer = on(Alphabet.english);
          drawY(layer);
          expect(layer.recognizedGlyph, 'Y');
        });
      });
    });

    group('breve — the caron\'s own mark, over bases the caron never takes', () {
      // The two are one gesture told apart by nothing here, on purpose: a breve
      // turns across a span where a caron comes to a point, but no alphabet has
      // both marks and no base takes both, so the alphabet separates them as it
      // does Ð from Đ.
      final bases = <String, void Function(LatinLayer)>{
        'Ă': drawA,
        'Ğ': drawG,
        'Ŭ': drawU,
      };

      bases.forEach((glyph, drawBase) {
        test('over its base it is $glyph', () {
          final alphabet = switch (glyph) {
            'Ă' => Alphabet.romanian,
            'Ğ' => Alphabet.turkish,
            _ => Alphabet.esperanto,
          };
          final layer = on(alphabet);
          drawBase(layer);
          drawCaron(layer);
          expect(layer.recognizedGlyph, glyph);
        });
      });

      test('drawn before its base it is still Ğ', () {
        final layer = on(Alphabet.turkish);
        drawCaron(layer);
        drawG(layer);
        expect(layer.recognizedGlyph, 'Ğ');
      });

      test('no alphabet with a breve has a caron letter', () {
        // What the whole arrangement rests on. If this ever fails, the two marks
        // need telling apart by shape after all — see TODO.md.
        const carons = 'ČĎĚĽŇŘŠŤŽ';
        for (final alphabet in [
          Alphabet.romanian,
          Alphabet.turkish,
          Alphabet.esperanto,
        ]) {
          for (final caron in carons.split('')) {
            expect(alphabet.letters, isNot(contains(caron)),
                reason: '${alphabet.label} has $caron as well as a breve');
          }
        }
      });

      test('no base takes both marks', () {
        // The second half of it, and the reason one table can hold both: A, G
        // and U are in `_caronOver` for the breve, C D E L N R S T Z for the
        // caron, and the two sets don't meet.
        const breveBases = 'AGU';
        const caronBases = 'CDELNRSTZ';
        for (final base in breveBases.split('')) {
          expect(caronBases, isNot(contains(base)));
        }
      });

      test('English has no Ğ, so the same drawing reads G', () {
        final layer = on(Alphabet.english);
        drawG(layer);
        drawCaron(layer);
        expect(layer.recognizedGlyph, 'G');
      });

      test('a caron over a caron\'s own base still reads the caron', () {
        // Adding the breve's three bases to the table doesn't disturb the nine
        // that were there.
        final layer = on(Alphabet.czech);
        drawS(layer);
        drawCaron(layer);
        expect(layer.recognizedGlyph, 'Š');
      });
    });

    group('dot above — a single tap', () {
      final bases = <String, void Function(LatinLayer)>{
        'Ċ': drawC,
        'Ė': drawE,
        'Ġ': drawG,
        'İ': drawI,
        'Ż': drawZ,
      };

      bases.forEach((glyph, drawBase) {
        test('over its base it is $glyph', () {
          // Maltese has Ċ Ġ Ż, Lithuanian Ė, Turkish İ — none has all five, so
          // each is asked of an alphabet that wants it.
          final alphabet = switch (glyph) {
            'Ė' => Alphabet.lithuanian,
            'İ' => Alphabet.turkish,
            _ => Alphabet.maltese,
          };
          final layer = on(alphabet);
          drawBase(layer);
          drawOneDot(layer);
          expect(layer.recognizedGlyph, glyph);
        });
      });

      test('a second dot makes it a diaeresis, not a dot above', () {
        // One dot and two are told apart by order alone: the diaeresis reads the
        // last pair, this reads the last dot.
        final layer = on(Alphabet.german);
        drawO(layer);
        drawOneDot(layer);
        // German has no Ȯ, so a lone dot leaves the plain O.
        expect(layer.recognizedGlyph, 'O');
        tap(layer, const Offset(220, 150));
        expect(layer.recognizedGlyph, 'Ö');
      });

      test('English has no Ż, so the same drawing reads Z', () {
        final layer = on(Alphabet.english);
        drawZ(layer);
        drawOneDot(layer);
        expect(layer.recognizedGlyph, 'Z');
      });
    });

    group('middle dot — a tap inside L\'s box', () {
      test('a dot inside an L is Ŀ', () {
        final layer = on(Alphabet.catalan);
        drawL(layer);
        tap(layer, const Offset(210, 270));
        expect(layer.recognizedGlyph, 'Ŀ');
      });

      test('a dot above the L is not Ŀ', () {
        final layer = on(Alphabet.catalan);
        drawL(layer);
        drawOneDot(layer);
        expect(layer.recognizedGlyph, isNot('Ŀ'));
      });

      test('a dot clear of the box is not Ŀ', () {
        final layer = on(Alphabet.catalan);
        drawL(layer);
        tap(layer, const Offset(330, 270));
        expect(layer.recognizedGlyph, isNot('Ŀ'));
      });

      test('English has no Ŀ, so the same drawing reads L', () {
        final layer = on(Alphabet.english);
        drawL(layer);
        tap(layer, const Offset(210, 270));
        expect(layer.recognizedGlyph, 'L');
      });
    });

    group('double acute — simply two acutes', () {
      void drawDoubleAcute(LatinLayer layer) {
        drawStroke(layer, const Offset(170, 170), const Offset(195, 140));
        drawStroke(layer, const Offset(205, 170), const Offset(230, 140));
      }

      test('over an O it is Ő', () {
        final layer = on(Alphabet.hungarian);
        drawO(layer);
        drawDoubleAcute(layer);
        expect(layer.recognizedGlyph, 'Ő');
      });

      test('over a U it is Ű', () {
        final layer = on(Alphabet.hungarian);
        drawU(layer);
        drawDoubleAcute(layer);
        expect(layer.recognizedGlyph, 'Ű');
      });

      test('drawn before its base it is still Ő', () {
        final layer = on(Alphabet.hungarian);
        drawDoubleAcute(layer);
        drawO(layer);
        expect(layer.recognizedGlyph, 'Ő');
      });

      test('one acute is Ó, two are Ő', () {
        final single = on(Alphabet.hungarian);
        drawO(single);
        drawAcute(single);
        expect(single.recognizedGlyph, 'Ó');

        final double = on(Alphabet.hungarian);
        drawO(double);
        drawDoubleAcute(double);
        expect(double.recognizedGlyph, 'Ő');
      });

      test('two taps are Ö, two acutes are Ő', () {
        // Hungarian has both, and strokes against taps is all that separates them.
        final dots = on(Alphabet.hungarian);
        drawO(dots);
        drawDots(dots);
        expect(dots.recognizedGlyph, 'Ö');

        final acutes = on(Alphabet.hungarian);
        drawO(acutes);
        drawDoubleAcute(acutes);
        expect(acutes.recognizedGlyph, 'Ő');
      });

      test('English has no Ő, so the same drawing reads O', () {
        final layer = on(Alphabet.english);
        drawO(layer);
        drawDoubleAcute(layer);
        expect(layer.recognizedGlyph, 'O');
      });
    });

    group('macron — a flat bar above', () {
      void drawMacron(LatinLayer layer) =>
          drawStroke(layer, const Offset(175, 150), const Offset(225, 150));

      final bases = <String, void Function(LatinLayer)>{
        'Ā': drawA,
        'Ē': drawE,
        'Ī': drawI,
        'Ū': drawU,
      };

      bases.forEach((glyph, drawBase) {
        test('over its base it is $glyph', () {
          final layer = on(Alphabet.latvian);
          drawBase(layer);
          drawMacron(layer);
          expect(layer.recognizedGlyph, glyph);
        });

        test('drawn before its base it is still $glyph', () {
          final layer = on(Alphabet.latvian);
          drawMacron(layer);
          drawBase(layer);
          expect(layer.recognizedGlyph, glyph);
        });
      });

      test('a bar close enough to touch the stem is a T, not Ī', () {
        // A bar over an upright is a T and it is also Ī; nothing in the shapes
        // separates them. The gap does — T takes every bar within _touchTolerance
        // of its stem, and the macron takes the ones that hover clear.
        final layer = on(Alphabet.latvian);
        drawI(layer);
        drawStroke(layer, const Offset(175, 190), const Offset(225, 190));
        expect(layer.recognizedGlyph, 'T');
      });

      test('a bar hovering clear of the stem is Ī, not T', () {
        final layer = on(Alphabet.latvian);
        drawI(layer);
        drawMacron(layer);
        expect(layer.recognizedGlyph, 'Ī');
      });

      test('a plain T is still a T, its bar meeting its stem', () {
        final layer = on(Alphabet.latvian);
        drawT(layer);
        expect(layer.recognizedGlyph, 'T');
      });

      test('a plain E is still an E, no bar of its own taken for a mark', () {
        final layer = on(Alphabet.latvian);
        drawE(layer);
        expect(layer.recognizedGlyph, 'E');
      });

      test('English has no Ā, so the same drawing reads A', () {
        final layer = on(Alphabet.english);
        drawA(layer);
        drawMacron(layer);
        expect(layer.recognizedGlyph, 'A');
      });

      test('switching to Latvian re-reads it as the Ā it is', () {
        final layer = on(Alphabet.english);
        drawA(layer);
        drawMacron(layer);
        expect(layer.recognizedGlyph, 'A');
        layer.alphabet = Alphabet.latvian;
        expect(layer.recognizedGlyph, 'Ā');
      });
    });

    group('comma below — the acute\'s line, hung under the letter', () {
      void drawComma(LatinLayer layer) =>
          drawStroke(layer, const Offset(180, 380), const Offset(215, 352));

      test('under an S it is Ș', () {
        final layer = on(Alphabet.romanian);
        drawS(layer);
        drawComma(layer);
        expect(layer.recognizedGlyph, 'Ș');
      });

      test('under a T it is Ț', () {
        final layer = on(Alphabet.romanian);
        drawT(layer);
        drawComma(layer);
        expect(layer.recognizedGlyph, 'Ț');
      });

      test('drawn before its base it is still Ș', () {
        final layer = on(Alphabet.romanian);
        drawComma(layer);
        drawS(layer);
        expect(layer.recognizedGlyph, 'Ș');
      });

      // Latvian's four are named for the cedilla, after Unicode, but the glyph
      // its standard specifies is this comma — so they come through here rather
      // than through Ç's classifier, which reads the attached cedilla Turkish
      // writes. In lowercase ģ the comma goes above the g instead; capitals
      // only here, so that never arises.
      void drawK(LatinLayer layer) {
        drawStroke(layer, const Offset(150, 200), const Offset(150, 340));
        drawPath(layer, const [
          Offset(230, 200),
          Offset(150, 270),
          Offset(230, 340),
        ]);
      }

      test('under a G it is Ģ', () {
        final layer = on(Alphabet.latvian);
        drawG(layer);
        drawComma(layer);
        expect(layer.recognizedGlyph, 'Ģ');
      });

      test('under a K it is Ķ', () {
        final layer = on(Alphabet.latvian);
        drawK(layer);
        drawComma(layer);
        expect(layer.recognizedGlyph, 'Ķ');
      });

      test('under an L it is Ļ', () {
        final layer = on(Alphabet.latvian);
        drawL(layer);
        drawComma(layer);
        expect(layer.recognizedGlyph, 'Ļ');
      });

      test('under an N it is Ņ', () {
        final layer = on(Alphabet.latvian);
        drawN(layer);
        drawComma(layer);
        expect(layer.recognizedGlyph, 'Ņ');
      });

      test('drawn before its base it is still Ķ', () {
        final layer = on(Alphabet.latvian);
        drawComma(layer);
        drawK(layer);
        expect(layer.recognizedGlyph, 'Ķ');
      });

      test('Romanian and Latvian share one table, their bases being disjoint',
          () {
        // Latvian has S and T but neither Ș nor Ț, so the alphabet turns the
        // pair away and it falls through to the bare S.
        final layer = on(Alphabet.latvian);
        drawS(layer);
        drawComma(layer);
        expect(layer.recognizedGlyph, 'S');
      });

      test('English has no Ķ, so a K with a comma reads as K', () {
        final layer = on(Alphabet.english);
        drawK(layer);
        drawComma(layer);
        expect(layer.recognizedGlyph, 'K');
      });

      test('the same line above the letter is an acute, not a comma', () {
        // One gesture, three placements: above the letter an acute, across a ring
        // Ø's bar, below the letter a comma. Polish for the acute — Slovak's
        // S-with-a-mark is Š, the caron.
        final layer = on(Alphabet.polish);
        drawS(layer);
        drawAcute(layer);
        expect(layer.recognizedGlyph, 'Ś');
      });

      test('a comma dipping into the letter is no comma', () {
        final layer = on(Alphabet.romanian);
        drawS(layer);
        drawStroke(layer, const Offset(180, 340), const Offset(215, 312));
        expect(layer.recognizedGlyph, isNot('Ș'));
      });

      test('a comma off to one side is no comma', () {
        final layer = on(Alphabet.romanian);
        drawS(layer);
        drawStroke(layer, const Offset(340, 380), const Offset(375, 352));
        expect(layer.recognizedGlyph, isNot('Ș'));
      });

      test('a falling line below the letter is no comma', () {
        final layer = on(Alphabet.romanian);
        drawS(layer);
        drawStroke(layer, const Offset(180, 352), const Offset(215, 380));
        expect(layer.recognizedGlyph, isNot('Ș'));
      });

      test('English has no Ș, so the same drawing reads S', () {
        final layer = on(Alphabet.english);
        drawS(layer);
        drawComma(layer);
        expect(layer.recognizedGlyph, 'S');
      });

      test('switching to Romanian re-reads it as the Ș it is', () {
        final layer = on(Alphabet.english);
        drawS(layer);
        drawComma(layer);
        expect(layer.recognizedGlyph, 'S');
        layer.alphabet = Alphabet.romanian;
        expect(layer.recognizedGlyph, 'Ș');
      });
    });

    group('ogonek — two legs, hung across the letter\'s foot', () {
      // Out to the left and back to the right, starting up inside the letter so
      // that it crosses once and ending below it. Placed under each base's own
      // foot, since it is attached rather than hovering.
      // (x, y) is a point just outside the letter's foot: the mark sets off from
      // there, sweeps left across the letter and down past it, then back right.
      void drawOgonek(LatinLayer layer, double x, double y) => drawPath(layer, [
            Offset(x, y),
            Offset(x - 35, y + 40),
            Offset(x + 15, y + 60),
          ]);

      test('across an A\'s foot it is Ą', () {
        final layer = on(Alphabet.polish);
        drawA(layer);
        drawOgonek(layer, 255, 295);
        expect(layer.recognizedGlyph, 'Ą');
      });

      test('across an E\'s foot it is Ę', () {
        final layer = on(Alphabet.polish);
        drawE(layer);
        drawOgonek(layer, 200, 330);
        expect(layer.recognizedGlyph, 'Ę');
      });

      test('across an I\'s foot it is Į', () {
        // I and U ask to cross nothing, where A and E ask no such question — so
        // these two are what `_attached` is for. Without it an Į read as nothing
        // while an Ą was fine, the mark counting against its own letter.
        final layer = on(Alphabet.lithuanian);
        drawI(layer);
        drawOgonek(layer, 215, 300);
        expect(layer.recognizedGlyph, 'Į');
      });

      test('the letter still has to cross nothing else', () {
        // `_attached` excuses the mark and nothing more: a stray stroke through
        // the I is still a stroke through the I, and no Į.
        final layer = on(Alphabet.lithuanian);
        drawI(layer);
        drawStroke(layer, const Offset(160, 240), const Offset(240, 250));
        drawOgonek(layer, 215, 300);
        expect(layer.recognizedGlyph, isNot('Į'));
      });

      test('across a U\'s foot it is Ų', () {
        final layer = on(Alphabet.lithuanian);
        drawU(layer);
        drawOgonek(layer, 215, 330);
        expect(layer.recognizedGlyph, 'Ų');
      });

      test('drawn before its base it is still Ę', () {
        final layer = on(Alphabet.polish);
        drawOgonek(layer, 200, 330);
        drawE(layer);
        expect(layer.recognizedGlyph, 'Ę');
      });

      test('a mark that never reaches the letter is no ogonek', () {
        // Attached is the whole of what it is — this one hangs free underneath,
        // crossing nothing, and no `_markedAcross` finds it.
        final layer = on(Alphabet.polish);
        drawE(layer);
        drawOgonek(layer, 200, 380);
        expect(layer.recognizedGlyph, isNot('Ę'));
      });

      test('a mark that dips back into the letter crosses twice, and is one', () {
        // Out of the letter and back in: the hand that starts inside crosses
        // once, the hand that starts outside and dips back crosses twice, and
        // both have drawn the same mark.
        final layer = on(Alphabet.polish);
        drawE(layer);
        drawPath(layer, const [
          Offset(230, 360),
          Offset(180, 330),
          Offset(215, 390),
        ]);
        expect(layer.recognizedGlyph, 'Ę');
      });

      test('a mark woven through the letter three times is no ogonek', () {
        final layer = on(Alphabet.polish);
        drawE(layer);
        drawPath(layer, const [
          Offset(230, 360),
          Offset(180, 330),
          Offset(230, 335),
          Offset(190, 390),
        ]);
        expect(layer.recognizedGlyph, isNot('Ę'));
      });

      test('one crossing low and one high is no ogonek', () {
        // Every crossing has to be low, not merely one — exactly as Q asks of
        // its tail.
        final layer = on(Alphabet.polish);
        drawE(layer);
        drawPath(layer, const [
          Offset(230, 230),
          Offset(180, 250),
          Offset(215, 390),
        ]);
        expect(layer.recognizedGlyph, isNot('Ę'));
      });

      test('a mark across the letter\'s middle is no ogonek', () {
        // It has to be hung at the foot: the crossing must fall in the letter's
        // bottom third, and this one takes the middle bar of the E.
        final layer = on(Alphabet.polish);
        drawE(layer);
        drawOgonek(layer, 200, 260);
        expect(layer.recognizedGlyph, isNot('Ę'));
      });

      test('a three-legged tail is a cedilla\'s, not an ogonek\'s', () {
        final layer = on(Alphabet.polish);
        drawE(layer);
        drawPath(layer, const [
          Offset(200, 330),
          Offset(165, 360),
          Offset(205, 380),
          Offset(170, 400),
        ]);
        expect(layer.recognizedGlyph, isNot('Ę'));
      });

      test('an ogonek and a comma below are told apart by shape alone', () {
        // Both hang under the letter, so unlike the breve and the caron this
        // pair needs no alphabet argument: two legs against one straight line,
        // and attached against hanging free. Romanian has Ș and no ogonek
        // letter, and reads its own comma correctly with the ogonek in.
        final layer = on(Alphabet.romanian);
        drawS(layer);
        drawStroke(layer, const Offset(180, 380), const Offset(215, 352));
        expect(layer.recognizedGlyph, 'Ș');
      });

      test('English has no Ą, so the same drawing reads A', () {
        final layer = on(Alphabet.english);
        drawA(layer);
        drawOgonek(layer, 255, 295);
        expect(layer.recognizedGlyph, 'A');
      });

      test('switching to Polish re-reads it as the Ą it is', () {
        final layer = on(Alphabet.english);
        drawA(layer);
        drawOgonek(layer, 255, 295);
        expect(layer.recognizedGlyph, 'A');
        layer.alphabet = Alphabet.polish;
        expect(layer.recognizedGlyph, 'Ą');
      });

    });

    group('the marks already read, over their new bases', () {
      test('an acute over C, L, N, R, S and Z', () {
        for (final (glyph, drawBase) in [
          ('Ć', drawC),
          ('Ĺ', drawL),
          ('Ń', drawN),
          ('Ŕ', drawR),
          ('Ś', drawS),
          ('Ź', drawZ),
        ]) {
          final layer = on(Alphabet.slovak.letters.contains(glyph)
              ? Alphabet.slovak
              : Alphabet.polish);
          drawBase(layer);
          drawAcute(layer);
          expect(layer.recognizedGlyph, glyph, reason: glyph);
        }
      });

      test('a circumflex over C, G, H, J, S and W', () {
        for (final (glyph, drawBase) in [
          ('Ĉ', drawC),
          ('Ĝ', drawG),
          ('Ĥ', drawH),
          ('Ĵ', drawJ),
          ('Ŝ', drawS),
        ]) {
          final layer = on(Alphabet.esperanto);
          drawBase(layer);
          drawCircumflex(layer);
          expect(layer.recognizedGlyph, glyph, reason: glyph);
        }
        final welsh = on(Alphabet.welsh);
        drawW(welsh);
        drawCircumflex(welsh);
        expect(welsh.recognizedGlyph, 'Ŵ');
      });

      test('a ring over U is Ů', () {
        final layer = on(Alphabet.czech);
        drawU(layer);
        drawLoop(layer, const Offset(200, 150), 22,
            drift: const Offset(8, -12));
        expect(layer.recognizedGlyph, 'Ů');
      });
    });

    group('where a mark sits', () {
      test('a mark down inside the letter is no mark', () {
        final layer = on(Alphabet.icelandic);
        drawA(layer);
        drawStroke(layer, const Offset(180, 300), const Offset(220, 270));
        expect(layer.recognizedGlyph, isNot('Á'));
      });

      test('a mark off to one side of the letter is no mark', () {
        final layer = on(Alphabet.icelandic);
        drawA(layer);
        drawStroke(layer, const Offset(360, 170), const Offset(400, 140));
        expect(layer.recognizedGlyph, isNot('Á'));
      });

      test('a mark wider than its letter is still a mark', () {
        // A tilde is broader than an I, and an I's box has no width at all, so
        // it's the mark's centre that is asked about rather than its every point.
        final layer = on(Alphabet.spanish);
        drawI(layer);
        drawAcute(layer);
        expect(layer.recognizedGlyph, 'Í');
      });
    });

    group('an alphabet without the marked letter', () {
      test('English reads an acute over an A as the plain A', () {
        final layer = on(Alphabet.english);
        drawA(layer);
        drawAcute(layer);
        expect(layer.recognizedGlyph, 'A');
      });

      test('English reads a tilde over an N as the plain N', () {
        final layer = on(Alphabet.english);
        drawN(layer);
        drawTilde(layer);
        expect(layer.recognizedGlyph, 'N');
      });

      test('switching to Spanish re-reads it as the Ñ it is', () {
        final layer = on(Alphabet.english);
        drawN(layer);
        drawTilde(layer);
        expect(layer.recognizedGlyph, 'N');
        layer.alphabet = Alphabet.spanish;
        expect(layer.recognizedGlyph, 'Ñ');
      });

      test('Spanish has Ñ but no Ã, so a tilde over an A reads A', () {
        final layer = on(Alphabet.spanish);
        drawA(layer);
        drawTilde(layer);
        expect(layer.recognizedGlyph, 'A');
      });
    });
  });

  group('Ç', () {
    // C's arc: out left across the top, round the back, away right again.
    const arc = [Offset(250, 140), Offset(140, 210), Offset(250, 280)];
    // Off the arc's lower arm, down and to and fro three times, ending below it.
    const tail = [
      Offset(230, 255),
      Offset(200, 285),
      Offset(235, 305),
      Offset(205, 325),
    ];

    LatinLayer french() => LatinLayer()..alphabet = Alphabet.french;

    test('an arc with a three-legged tail across its foot is Ç', () {
      final layer = french();
      drawPath(layer, arc);
      drawPath(layer, tail);
      expect(layer.recognizedGlyph, 'Ç');
    });

    test('the tail drawn first is still Ç', () {
      final layer = french();
      drawPath(layer, tail);
      drawPath(layer, arc);
      expect(layer.recognizedGlyph, 'Ç');
    });

    test('the tail drawn end for end is still Ç', () {
      final layer = french();
      drawPath(layer, arc);
      drawPath(layer, tail.reversed.toList());
      expect(layer.recognizedGlyph, 'Ç');
    });

    test('the arc on its own is C, not Ç', () {
      final layer = french();
      drawPath(layer, arc);
      expect(layer.recognizedGlyph, 'C');
    });

    test('a tail across the arc\'s middle is not Ç', () {
      final layer = french();
      drawPath(layer, arc);
      drawPath(layer, const [
        Offset(190, 180),
        Offset(160, 200),
        Offset(195, 215),
        Offset(165, 235),
      ]);
      expect(layer.recognizedGlyph, isNot('Ç'));
    });

    test('a tail that never reaches the arc is not Ç', () {
      final layer = french();
      drawPath(layer, arc);
      drawPath(layer, const [
        Offset(330, 300),
        Offset(300, 320),
        Offset(335, 335),
        Offset(305, 355),
      ]);
      expect(layer.recognizedGlyph, isNot('Ç'));
    });

    test('a straight tail — one leg, not three — is not Ç', () {
      final layer = french();
      drawPath(layer, arc);
      drawStroke(layer, const Offset(230, 255), const Offset(200, 330));
      expect(layer.recognizedGlyph, isNot('Ç'));
    });

    test('English has no Ç, so the same drawing reads as nothing', () {
      final layer = LatinLayer();
      drawPath(layer, arc);
      drawPath(layer, tail);
      expect(layer.recognizedGlyph, isNull);
    });

    test('switching to French re-reads it as the Ç it is', () {
      final layer = LatinLayer();
      drawPath(layer, arc);
      drawPath(layer, tail);
      expect(layer.recognizedGlyph, isNull);
      layer.alphabet = Alphabet.french;
      expect(layer.recognizedGlyph, 'Ç');
    });
  });

  group('Ş — the same cedilla, off an S instead', () {
    // Turkish writes a true attached cedilla on both its Ç and its Ş, where
    // Romanian's Ș carries a comma hanging free. Unicode gave Ș its own code
    // point to say so, which is why these two letters go through two different
    // classifiers here.
    const s = [
      Offset(250, 140),
      Offset(150, 175),
      Offset(250, 225),
      Offset(150, 265),
    ];
    // Off the S's foot, down and to and fro three times, ending below it.
    const tail = [
      Offset(180, 250),
      Offset(150, 280),
      Offset(185, 300),
      Offset(155, 320),
    ];

    LatinLayer turkish() => LatinLayer()..alphabet = Alphabet.turkish;

    test('an S with a three-legged tail across its foot is Ş', () {
      final layer = turkish();
      drawPath(layer, s);
      drawPath(layer, tail);
      expect(layer.recognizedGlyph, 'Ş');
    });

    test('the tail drawn first is still Ş', () {
      // Both strokes are three-legged, so which is the letter can't be read off
      // the pattern. What settles it is that a tail hangs below its letter's
      // foot: read the other way round, the "tail" sits above the "body" and the
      // pair fails.
      final layer = turkish();
      drawPath(layer, tail);
      drawPath(layer, s);
      expect(layer.recognizedGlyph, 'Ş');
    });

    test('a tail that crosses the S high up is not Ş', () {
      final layer = turkish();
      drawPath(layer, s);
      drawPath(layer, const [
        Offset(180, 160),
        Offset(150, 190),
        Offset(185, 210),
        Offset(155, 290),
      ]);
      expect(layer.recognizedGlyph, isNot('Ş'));
    });

    test('a tail that never reaches the S is not Ş', () {
      final layer = turkish();
      drawPath(layer, s);
      drawPath(layer, const [
        Offset(330, 280),
        Offset(300, 300),
        Offset(335, 315),
        Offset(305, 335),
      ]);
      expect(layer.recognizedGlyph, isNot('Ş'));
    });

    test('a straight tail — one leg, not three — is not Ş', () {
      final layer = turkish();
      drawPath(layer, s);
      drawStroke(layer, const Offset(180, 250), const Offset(155, 320));
      expect(layer.recognizedGlyph, isNot('Ş'));
    });

    test('Turkish keeps its Ç too', () {
      final layer = turkish();
      drawPath(layer,
          const [Offset(250, 140), Offset(140, 210), Offset(250, 280)]);
      drawPath(layer, const [
        Offset(230, 255),
        Offset(200, 285),
        Offset(235, 305),
        Offset(205, 325),
      ]);
      expect(layer.recognizedGlyph, 'Ç');
    });

    test('a comma below an S is Romanian\'s Ș, not this', () {
      final layer = LatinLayer()..alphabet = Alphabet.romanian;
      drawPath(layer, s);
      drawStroke(layer, const Offset(190, 310), const Offset(225, 282));
      expect(layer.recognizedGlyph, 'Ș');
    });

    test('English has no Ş, so the same drawing reads as S', () {
      // The cedilla isn't a mark `_classifyMarkedBase` can set aside — it
      // crosses its letter rather than hovering — but the S is the last stroke
      // in neither order, so the fall-through here is `_classifyS`'s own work
      // on a page where nothing else claims the pair.
      final layer = LatinLayer();
      drawPath(layer, s);
      drawPath(layer, tail);
      expect(layer.recognizedGlyph, isNot('Ş'));
    });

    test('switching to Turkish re-reads it as the Ş it is', () {
      final layer = LatinLayer();
      drawPath(layer, s);
      drawPath(layer, tail);
      expect(layer.recognizedGlyph, isNot('Ş'));
      layer.alphabet = Alphabet.turkish;
      expect(layer.recognizedGlyph, 'Ş');
    });
  });

  group('Ł', () {
    // An L: down the upright, then right along the foot.
    const l = [Offset(150, 150), Offset(150, 300), Offset(260, 300)];
    // Through the upright, rising to the right.
    const bar = [Offset(120, 230), Offset(190, 190)];

    LatinLayer polish() => LatinLayer()..alphabet = Alphabet.polish;

    test('an L with a rising line through it is Ł', () {
      final layer = polish();
      drawPath(layer, l);
      drawStroke(layer, bar.first, bar.last);
      expect(layer.recognizedGlyph, 'Ł');
    });

    test('the bar drawn first is still Ł', () {
      final layer = polish();
      drawStroke(layer, bar.first, bar.last);
      drawPath(layer, l);
      expect(layer.recognizedGlyph, 'Ł');
    });

    test('a bar that misses the L is no Ł', () {
      final layer = polish();
      drawPath(layer, l);
      drawStroke(layer, const Offset(200, 230), const Offset(270, 190));
      expect(layer.recognizedGlyph, isNot('Ł'));
    });

    test('a bar laid across the foot alone is no Ł, though it crosses once', () {
      // An L is an upright *and* a foot, so counting the crossing isn't enough
      // — this one takes the foot and misses the upright entirely. Hence the
      // crossing is located as well as counted.
      final layer = polish();
      drawPath(layer, l);
      drawStroke(layer, const Offset(130, 330), const Offset(200, 270));
      expect(layer.recognizedGlyph, isNot('Ł'));
    });

    test('a falling bar is no Ł — the stroke rises, as the acute does', () {
      final layer = polish();
      drawPath(layer, l);
      drawStroke(layer, const Offset(120, 190), const Offset(190, 230));
      expect(layer.recognizedGlyph, isNot('Ł'));
    });

    test('a bare L is still an L in Polish', () {
      final layer = polish();
      drawPath(layer, l);
      expect(layer.recognizedGlyph, 'L');
    });

    test('English has no Ł, so this drawing reads as nothing', () {
      // Not as L, which the alphabet has: the bar takes a stroke slot, and no
      // `_classifyMarkedBase` sets it aside — a stroke laid *through* the letter
      // is no mark that `_sitsAbove` or `_sitsBelow` can find. X is the only
      // other taker for an L and a crossing slant, and it turns this one down
      // because the bar lies wholly left of the pair's middle.
      final layer = LatinLayer();
      drawPath(layer, l);
      drawStroke(layer, bar.first, bar.last);
      expect(layer.recognizedGlyph, isNull);
    });

    test('switching to Polish re-reads it as the Ł it is', () {
      final layer = LatinLayer();
      drawPath(layer, l);
      drawStroke(layer, bar.first, bar.last);
      layer.alphabet = Alphabet.polish;
      expect(layer.recognizedGlyph, 'Ł');
    });
  });

  group('Ħ', () {
    const leftStem = [Offset(150, 120), Offset(150, 300)];
    const rightStem = [Offset(250, 120), Offset(250, 300)];
    const crossbar = [Offset(140, 230), Offset(260, 230)];
    const upperBar = [Offset(140, 175), Offset(260, 175)];

    LatinLayer maltese() => LatinLayer()..alphabet = Alphabet.maltese;

    void drawHStroke(LatinLayer layer) {
      drawStroke(layer, leftStem.first, leftStem.last);
      drawStroke(layer, rightStem.first, rightStem.last);
      drawStroke(layer, crossbar.first, crossbar.last);
      drawStroke(layer, upperBar.first, upperBar.last);
    }

    test('an H with a second bar above its own is Ħ', () {
      final layer = maltese();
      drawHStroke(layer);
      expect(layer.recognizedGlyph, 'Ħ');
    });

    test('the bars drawn before the stems is still Ħ', () {
      final layer = maltese();
      drawStroke(layer, upperBar.first, upperBar.last);
      drawStroke(layer, crossbar.first, crossbar.last);
      drawStroke(layer, leftStem.first, leftStem.last);
      drawStroke(layer, rightStem.first, rightStem.last);
      expect(layer.recognizedGlyph, 'Ħ');
    });

    test('a bar drawn between the stems is still Ħ', () {
      // Which bar is which isn't asked — both cross both uprights.
      final layer = maltese();
      drawStroke(layer, leftStem.first, leftStem.last);
      drawStroke(layer, upperBar.first, upperBar.last);
      drawStroke(layer, rightStem.first, rightStem.last);
      drawStroke(layer, crossbar.first, crossbar.last);
      expect(layer.recognizedGlyph, 'Ħ');
    });

    test('one bar short is an H, not Ħ', () {
      final layer = maltese();
      drawStroke(layer, leftStem.first, leftStem.last);
      drawStroke(layer, rightStem.first, rightStem.last);
      drawStroke(layer, crossbar.first, crossbar.last);
      expect(layer.recognizedGlyph, 'H');
    });

    test('a second bar reaching only one stem is not Ħ', () {
      final layer = maltese();
      drawStroke(layer, leftStem.first, leftStem.last);
      drawStroke(layer, rightStem.first, rightStem.last);
      drawStroke(layer, crossbar.first, crossbar.last);
      drawStroke(layer, const Offset(140, 175), const Offset(200, 175));
      expect(layer.recognizedGlyph, isNot('Ħ'));
    });

    test('two bars at the same height is not Ħ', () {
      final layer = maltese();
      drawStroke(layer, leftStem.first, leftStem.last);
      drawStroke(layer, rightStem.first, rightStem.last);
      drawStroke(layer, crossbar.first, crossbar.last);
      drawStroke(layer, const Offset(140, 233), const Offset(260, 233));
      expect(layer.recognizedGlyph, isNot('Ħ'));
    });

    test('English has no Ħ, so the same drawing reads as nothing', () {
      final layer = LatinLayer();
      drawHStroke(layer);
      expect(layer.recognizedGlyph, isNull);
    });

    test('switching to Maltese re-reads it as the Ħ it is', () {
      final layer = LatinLayer();
      drawHStroke(layer);
      expect(layer.recognizedGlyph, isNull);
      layer.alphabet = Alphabet.maltese;
      expect(layer.recognizedGlyph, 'Ħ');
    });
  });

  group('Þ', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    // The bowl meets the stem twice, both within its middle third (y 180–240).
    const bowl = [Offset(150, 190), Offset(250, 215), Offset(150, 235)];

    LatinLayer icelandic() => LatinLayer()..alphabet = Alphabet.icelandic;

    test('a bowl meeting the stem twice in its middle is Þ', () {
      final layer = icelandic();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl);
      expect(layer.recognizedGlyph, 'Þ');
    });

    test('the bowl drawn first is still Þ', () {
      final layer = icelandic();
      drawPath(layer, bowl);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'Þ');
    });

    test('a bowl sitting in the stem\'s middle half is Þ, as print draws it',
        () {
      // The stem's quarters are 45px on a 180px stem, so a bowl anywhere within
      // y 165–255 leaves a quarter clear at each end.
      final layer = icelandic();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 170), Offset(250, 210), Offset(150, 250)]);
      expect(layer.recognizedGlyph, 'Þ');
    });

    test('D, P and Þ partition the two overhangs between them', () {
      // One stem, one bowl, and the only question is whether the stem stands
      // clear above it and below. All four answers, in order.
      final layer = icelandic();

      // Neither: the bowl reaches both ends.
      final d = icelandic();
      drawStroke(d, stemTop, stemBottom);
      drawPath(d, const [Offset(150, 120), Offset(250, 210), Offset(150, 300)]);
      expect(d.recognizedGlyph, 'D');

      // Below only: the bowl sits at the top.
      final p = icelandic();
      drawStroke(p, stemTop, stemBottom);
      drawPath(p, const [Offset(150, 120), Offset(250, 160), Offset(150, 210)]);
      expect(p.recognizedGlyph, 'P');

      // Both: the bowl sits in the middle.
      final thorn = icelandic();
      drawStroke(thorn, stemTop, stemBottom);
      drawPath(thorn, bowl);
      expect(thorn.recognizedGlyph, 'Þ');

      // Above only — a bowl hung at the stem's foot. No letter here.
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 215), Offset(250, 260), Offset(150, 300)]);
      expect(layer.recognizedGlyph, isNull);
    });

    test('a bowl falling short of the stem\'s top is still D', () {
      // Up to a quarter of slack at each end, which is all a hand needs.
      final layer = icelandic();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 155), Offset(250, 215), Offset(150, 275)]);
      expect(layer.recognizedGlyph, 'D');
    });

    test('a bowl falling short of the stem\'s foot is still D', () {
      final layer = icelandic();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 145), Offset(250, 205), Offset(150, 265)]);
      expect(layer.recognizedGlyph, 'D');
    });

    test('a stem standing right of the bowl is not Þ', () {
      final layer = icelandic();
      drawStroke(layer, const Offset(250, 120), const Offset(250, 300));
      drawPath(layer,
          const [Offset(250, 190), Offset(160, 215), Offset(250, 235)]);
      expect(layer.recognizedGlyph, isNot('Þ'));
    });

    test('English has no Þ, so the same drawing reads as nothing', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl);
      expect(layer.recognizedGlyph, isNull);
    });

    test('switching to Icelandic re-reads it as the Þ it is', () {
      final layer = LatinLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl);
      expect(layer.recognizedGlyph, isNull);
      layer.alphabet = Alphabet.icelandic;
      expect(layer.recognizedGlyph, 'Þ');
    });
  });

  group('Œ', () {
    // The O's bowl, as C's own left-then-right arc.
    const bowl = [Offset(250, 140), Offset(140, 210), Offset(250, 280)];
    // The seam, down through the bowl's middle.
    const seamTop = Offset(200, 120);
    const seamBottom = Offset(200, 300);
    // The E's bar, off the seam's middle and away right, missing the bowl.
    const barLeft = Offset(200, 210);
    const barRight = Offset(300, 210);

    LatinLayer french() => LatinLayer()..alphabet = Alphabet.french;

    void drawEthel(LatinLayer layer) {
      drawPath(layer, bowl);
      drawStroke(layer, seamTop, seamBottom);
      drawStroke(layer, barLeft, barRight);
    }

    test('a bowl, a seam through it and a bar off the seam is Œ', () {
      final layer = french();
      drawEthel(layer);
      expect(layer.recognizedGlyph, 'Œ');
    });

    test('the bowl drawn last is still Œ', () {
      final layer = french();
      drawStroke(layer, seamTop, seamBottom);
      drawStroke(layer, barLeft, barRight);
      drawPath(layer, bowl);
      expect(layer.recognizedGlyph, 'Œ');
    });

    test('the bar drawn first is still Œ', () {
      final layer = french();
      drawStroke(layer, barLeft, barRight);
      drawPath(layer, bowl);
      drawStroke(layer, seamTop, seamBottom);
      expect(layer.recognizedGlyph, 'Œ');
    });

    test('the bowl and seam alone are no letter — the seam is centred', () {
      // Not a K: K wants its arm clear to the stem's right, and a seam running
      // through the bowl's middle is on neither side of it.
      final layer = french();
      drawStroke(layer, seamTop, seamBottom);
      drawPath(layer, bowl);
      expect(layer.recognizedGlyph, isNull);
    });

    test('a seam a little left of centre is still Œ, though K would take it',
        () {
      // Œ allows the seam anywhere within a quarter of the bowl's width of its
      // middle, and a seam at the near edge of that is far enough left for K to
      // claim the pair. Being tried first is what settles it.
      const offCentre = Offset(185, 120);
      const offCentreFoot = Offset(185, 300);

      final pair = french();
      drawStroke(pair, offCentre, offCentreFoot);
      drawPath(pair, bowl);
      expect(pair.recognizedGlyph, 'K');

      final layer = french();
      drawPath(layer, bowl);
      drawStroke(layer, offCentre, offCentreFoot);
      drawStroke(layer, const Offset(185, 210), const Offset(285, 210));
      expect(layer.recognizedGlyph, 'Œ');
    });

    test('a seam clipping one arm of the bowl is not Œ', () {
      final layer = french();
      drawPath(layer, bowl);
      // Off to the right, so it meets the bowl's arms near their tips.
      drawStroke(layer, const Offset(245, 120), const Offset(245, 300));
      drawStroke(layer, const Offset(245, 210), const Offset(330, 210));
      expect(layer.recognizedGlyph, isNot('Œ'));
    });

    test('a bar reaching left across the bowl is not Œ', () {
      final layer = french();
      drawPath(layer, bowl);
      drawStroke(layer, seamTop, seamBottom);
      drawStroke(layer, const Offset(100, 210), const Offset(300, 210));
      expect(layer.recognizedGlyph, isNot('Œ'));
    });

    test('a bar up at the seam\'s top is not Œ', () {
      final layer = french();
      drawPath(layer, bowl);
      drawStroke(layer, seamTop, seamBottom);
      drawStroke(layer, const Offset(200, 130), const Offset(300, 130));
      expect(layer.recognizedGlyph, isNot('Œ'));
    });

    test('English has no Œ, so the same drawing reads as nothing', () {
      final layer = LatinLayer();
      drawEthel(layer);
      expect(layer.recognizedGlyph, isNull);
    });

    test('switching to French re-reads it as the Œ it is', () {
      final layer = LatinLayer();
      drawEthel(layer);
      expect(layer.recognizedGlyph, isNull);
      layer.alphabet = Alphabet.french;
      expect(layer.recognizedGlyph, 'Œ');
    });
  });

  group('Ð', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    // The bowl meets the stem at its two ends — a D.
    const bowl = [Offset(150, 120), Offset(250, 210), Offset(150, 300)];
    // The bar through the stem's middle, jutting out to its left.
    const barLeft = Offset(110, 210);
    const barRight = Offset(180, 210);

    LatinLayer icelandic() => LatinLayer()..alphabet = Alphabet.icelandic;

    void drawEth(LatinLayer layer) {
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl);
      drawStroke(layer, barLeft, barRight);
    }

    test('a D with a bar through its stem is Ð', () {
      final layer = icelandic();
      drawEth(layer);
      expect(layer.recognizedGlyph, 'Ð');
    });

    test('the bar drawn first is still Ð', () {
      final layer = icelandic();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl);
      expect(layer.recognizedGlyph, 'Ð');
    });

    test('the D on its own is D, not Ð', () {
      final layer = icelandic();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl);
      expect(layer.recognizedGlyph, 'D');
    });

    test('a bar carried on across the bowl is still Ð', () {
      final layer = icelandic();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl);
      drawStroke(layer, const Offset(110, 210), const Offset(260, 210));
      expect(layer.recognizedGlyph, 'Ð');
    });

    test('a bar up at the stem\'s top is not Ð', () {
      final layer = icelandic();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl);
      drawStroke(layer, const Offset(110, 140), const Offset(180, 140));
      expect(layer.recognizedGlyph, isNot('Ð'));
    });

    test('a bar that never reaches the stem is not Ð', () {
      final layer = icelandic();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl);
      drawStroke(layer, const Offset(60, 210), const Offset(120, 210));
      expect(layer.recognizedGlyph, isNot('Ð'));
    });

    test('a P with a bar is not Ð, the bowl stopping at the waist', () {
      final layer = icelandic();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 120), Offset(250, 160), Offset(150, 210)]);
      drawStroke(layer, barLeft, barRight);
      expect(layer.recognizedGlyph, isNot('Ð'));
    });

    test('the very same drawing is Đ in Croatian', () {
      // Eth and D-with-stroke are one capital glyph; only the lowercase differs,
      // and this recognizer draws capitals. No alphabet has both, so which letter
      // a drawing is comes down to which alphabet is in play.
      final layer = LatinLayer()..alphabet = Alphabet.croatian;
      drawEth(layer);
      expect(layer.recognizedGlyph, 'Đ');
    });

    test('switching between the two alphabets switches the letter', () {
      final layer = LatinLayer()..alphabet = Alphabet.icelandic;
      drawEth(layer);
      expect(layer.recognizedGlyph, 'Ð');
      layer.alphabet = Alphabet.croatian;
      expect(layer.recognizedGlyph, 'Đ');
      layer.alphabet = Alphabet.faroese;
      expect(layer.recognizedGlyph, 'Ð');
    });

    test('English has neither, so the same drawing reads as nothing', () {
      final layer = LatinLayer();
      drawEth(layer);
      expect(layer.recognizedGlyph, isNull);
    });

    test('switching to Icelandic re-reads it as the Ð it is', () {
      final layer = LatinLayer();
      drawEth(layer);
      expect(layer.recognizedGlyph, isNull);
      layer.alphabet = Alphabet.icelandic;
      expect(layer.recognizedGlyph, 'Ð');
    });
  });

  group('the Latin alphabet', () {
    // The three shapes classical Latin has no letter for.
    const jay = [Offset(250, 120), Offset(250, 270), Offset(170, 240)];
    const you = [
      Offset(150, 120),
      Offset(150, 260),
      Offset(250, 260),
      Offset(250, 120),
    ];
    const doubleU = [
      Offset(140, 120),
      Offset(170, 300),
      Offset(200, 180),
      Offset(230, 300),
      Offset(260, 120),
    ];

    test('the alphabets hold 23, 26, 29, 29 and 30 letters', () {
      expect(Alphabet.latin.rows.length, 23);
      expect(Alphabet.english.rows.length, 26);
      expect(Alphabet.finnish.rows.length, 29);
      expect(Alphabet.norwegian.rows.length, 29);
      expect(Alphabet.german.rows.length, 30);
      expect(
        Alphabet.latin.rows.map((row) => row.capital),
        isNot(anyElement(anyOf('J', 'U', 'W'))),
      );
      expect(
        Alphabet.english.rows.map((row) => row.capital),
        isNot(anyElement(anyOf('Æ', 'Ø', 'Å', 'Ä', 'Ö', 'Ü', 'ß'))),
      );
      expect(
        Alphabet.finnish.rows.map((row) => row.capital),
        containsAll(<String>['J', 'U', 'W', 'Å', 'Ä', 'Ö']),
      );
    });

    test('Norwegian has Æ, Ø and Å, and none of the umlauts', () {
      final capitals = Alphabet.norwegian.rows.map((row) => row.capital);
      expect(capitals, containsAll(<String>['Æ', 'Ø', 'Å']));
      expect(capitals, isNot(anyElement(anyOf('Ä', 'Ö', 'Ü', 'ß'))));
    });

    test('Å sorts last for Norwegian and first of the three for Finnish', () {
      final norwegian =
          Alphabet.norwegian.rows.map((row) => row.capital).toList();
      expect(norwegian.sublist(norwegian.length - 4), ['Z', 'Æ', 'Ø', 'Å']);
      final nordic =
          Alphabet.finnish.rows.map((row) => row.capital).toList();
      expect(nordic.sublist(nordic.length - 4), ['Z', 'Å', 'Ä', 'Ö']);
    });

    test('German has the umlauts and ß, but no Å', () {
      final capitals = Alphabet.german.rows.map((row) => row.capital);
      expect(capitals, containsAll(<String>['Ä', 'Ö', 'Ü', 'ß']));
      expect(capitals, isNot(contains('Å')));
    });

    test('Finnish has Å but neither Ü nor ß', () {
      final capitals = Alphabet.finnish.rows.map((row) => row.capital);
      expect(capitals, contains('Å'));
      expect(capitals, isNot(anyElement(anyOf('Æ', 'Ø', 'Ü', 'ß'))));
    });

    test('each alphabet keeps its own order, not one shared one', () {
      // The whole point of Alphabet spelling its letters out. Å goes last for
      // Norwegian and first of its three for Finnish; German files each umlaut
      // beside its own base where the Nordic pair send them past Z; Spanish
      // gives Ñ a slot of its own between N and O; Icelandic interleaves.
      String order(Alphabet alphabet) =>
          alphabet.rows.map((row) => row.capital).join();

      expect(order(Alphabet.norwegian), endsWith('ZÆØÅ'));
      expect(order(Alphabet.finnish), endsWith('ZÅÄÖ'));
      expect(order(Alphabet.german), startsWith('AÄB'));
      expect(order(Alphabet.german), endsWith('Zß'));
      expect(order(Alphabet.spanish), contains('NÑO'));
      expect(order(Alphabet.icelandic), startsWith('AÁBDÐEÉ'));
    });

    test('every alphabet\'s letters resolve to a row', () {
      // A typo in one of those strings must fail loudly, not quietly shorten an
      // alphabet — Alphabet.rows throws rather than skipping.
      for (final alphabet in Alphabet.values) {
        expect(() => alphabet.rows.toList(), returnsNormally,
            reason: alphabet.label);
        expect(alphabet.rows.length, alphabet.letters.length,
            reason: alphabet.label);
      }
    });

    test('each alphabet holds the letters it should', () {
      const counts = {
        Alphabet.latin: 23,
        Alphabet.english: 26,
        Alphabet.irish: 23,
        Alphabet.albanian: 27,
        Alphabet.danish: 29,
        Alphabet.norwegian: 29,
        Alphabet.swedish: 29,
        Alphabet.finnish: 29,
        Alphabet.faroese: 29,
        Alphabet.dutch: 29,
        Alphabet.german: 30,
        Alphabet.icelandic: 32,
        Alphabet.italian: 32,
        Alphabet.spanish: 33,
        Alphabet.catalan: 37,
        Alphabet.portuguese: 38,
        Alphabet.french: 42,
        // Latin Extended-A's own.
        Alphabet.slovenian: 25,
        Alphabet.croatian: 27,
        Alphabet.maltese: 28,
        Alphabet.esperanto: 28,
        Alphabet.welsh: 28,
        Alphabet.turkish: 29,
        Alphabet.romanian: 31,
        Alphabet.polish: 32,
        Alphabet.lithuanian: 32,
        Alphabet.estonian: 32,
        Alphabet.latvian: 33,
        Alphabet.hungarian: 35,
        Alphabet.czech: 41,
        Alphabet.slovak: 43,
      };
      // Every alphabet is accounted for, so a new one can't be added without a
      // count being stated for it here.
      expect(counts.keys.toSet(), Alphabet.values.toSet());
      counts.forEach((alphabet, count) {
        expect(alphabet.rows.length, count, reason: alphabet.label);
      });
    });

    test('the languages that drop letters of A–Z do so', () {
      String order(Alphabet alphabet) => alphabet.letters;
      expect(order(Alphabet.icelandic), isNot(matches('[CQWZ]')));
      expect(order(Alphabet.faroese), isNot(matches('[CQWXZ]')));
      expect(order(Alphabet.albanian), isNot(contains('W')));
      expect(order(Alphabet.irish), isNot(matches('[JKQVWXYZ]')));
      // Italian keeps all 26 though its textbook alphabet is 21: unlike Latin's
      // missing J, U and W, which genuinely did not exist, Italian writes
      // J K W X Y in loanwords and names.
      for (final letter in ['J', 'K', 'W', 'X', 'Y']) {
        expect(order(Alphabet.italian), contains(letter), reason: letter);
      }
      expect(order(Alphabet.latin), isNot(matches('[JUW]')));
    });

    test('the pairs with identical alphabets really are identical', () {
      expect(Alphabet.danish.letters, Alphabet.norwegian.letters);
      expect(Alphabet.finnish.letters, Alphabet.swedish.letters);
      // And their notes say so, so the duplication reads as deliberate.
      for (final alphabet in [
        Alphabet.danish,
        Alphabet.norwegian,
        Alphabet.finnish,
        Alphabet.swedish,
      ]) {
        expect(alphabet.note, contains('the same 29 as'),
            reason: alphabet.label);
      }
    });

    test('every letter of the catalogue is wanted by some alphabet', () {
      // A row nothing lists would be dead weight.
      for (final row in alphabetRows) {
        expect(Alphabet.values.any((a) => a.letters.contains(row.capital)),
            isTrue, reason: row.capital);
      }
    });

    test('no alphabet lists a letter twice', () {
      for (final alphabet in Alphabet.values) {
        final capitals = alphabet.rows.map((row) => row.capital).toList();
        expect(capitals.toSet().length, capitals.length,
            reason: alphabet.label);
      }
    });

    test('Ä and Ö are the one row each, shared rather than written twice', () {
      LetterRow rowFor(Alphabet alphabet, String capital) =>
          alphabet.rows.firstWhere((row) => row.capital == capital);
      for (final capital in ['Ä', 'Ö']) {
        expect(
          rowFor(Alphabet.german, capital).name,
          rowFor(Alphabet.finnish, capital).name,
        );
      }
    });

    /// The letters listed by some alphabet but not yet drawable — each waiting on
    /// a mark the recognizer doesn't read. Named one by one on purpose: a letter
    /// joining this set is a decision, and should read as one.
    const staged = <String>{};

    test('every letter of every alphabet the recognizer knows, bar the staged',
        () {
      for (final alphabet in Alphabet.values) {
        for (final row in alphabet.rows) {
          if (staged.contains(row.capital)) continue;
          expect(LatinLayer.recognizedNames, contains(row.name),
              reason: '${row.capital} of ${alphabet.label}');
        }
      }
    });

    test('the staged letters are listed but not drawable', () {
      for (final capital in staged) {
        final row = alphabetRows.firstWhere((r) => r.capital == capital,
            orElse: () => throw StateError('no row for $capital'));
        expect(LatinLayer.recognizedNames, isNot(contains(row.name)),
            reason: capital);
        expect(Alphabet.values.any((a) => a.letters.contains(capital)), isTrue,
            reason: '$capital is staged but no alphabet lists it');
      }
    });

    test('every alphabet is wholly drawable, with nothing staged', () {
      // The list this replaced named the alphabets that had got there. With the
      // ogonek in, nothing is left staged and the assertion is simply universal.
      // If a letter is ever added that no classifier reads, name it in `staged`
      // above — the whole point of that set is that muting a letter is a
      // decision, and this test is what forces it to be made.
      for (final alphabet in Alphabet.values) {
        final undrawable = alphabet.rows
            .where((row) => !LatinLayer.recognizedNames.contains(row.name))
            .map((row) => row.capital);
        expect(undrawable, isEmpty, reason: alphabet.label);
      }
    });

    test('a U reads as the V Latin would have written for it', () {
      final layer = LatinLayer()..alphabet = Alphabet.latin;
      drawPath(layer, you);
      expect(layer.recognizedGlyph, 'V');
    });

    test('a J falls through to V as well', () {
      final layer = LatinLayer()..alphabet = Alphabet.latin;
      drawPath(layer, jay);
      expect(layer.recognizedGlyph, 'V');
    });

    test('a W has nothing to fall through to, so it reads as nothing', () {
      final layer = LatinLayer()..alphabet = Alphabet.latin;
      drawPath(layer, doubleU);
      expect(layer.recognizedGlyph, isNull);
    });

    test('a letter reads the same in every alphabet that has it', () {
      // T every alphabet here has; V all but Irish, which wants no V. Each is
      // reported wherever it belongs and passed over where it doesn't — the
      // shapes are the same either way.
      for (final alphabet in Alphabet.values) {
        final vee = LatinLayer()..alphabet = alphabet;
        drawPath(vee,
            const [Offset(150, 120), Offset(200, 300), Offset(250, 120)]);
        expect(vee.recognizedGlyph, alphabet.letters.contains('V') ? 'V' : null,
            reason: alphabet.label);

        final tee = LatinLayer()..alphabet = alphabet;
        drawStroke(tee, const Offset(150, 120), const Offset(250, 120));
        drawStroke(tee, const Offset(200, 120), const Offset(200, 300));
        expect(tee.recognizedGlyph, 'T', reason: alphabet.label);
      }
    });

    test('switching alphabets re-reads what is already drawn', () {
      final layer = LatinLayer();
      drawPath(layer, you);
      expect(layer.recognizedGlyph, 'U');
      layer.alphabet = Alphabet.latin;
      expect(layer.recognizedGlyph, 'V');
      layer.alphabet = Alphabet.english;
      expect(layer.recognizedGlyph, 'U');
    });

    test('switching alphabets on an empty page reads as nothing', () {
      final layer = LatinLayer()..alphabet = Alphabet.latin;
      expect(layer.recognizedGlyph, isNull);
    });

    test('English is what a fresh layer starts on', () {
      final layer = LatinLayer();
      expect(layer.alphabet, Alphabet.english);
      drawPath(layer, you);
      expect(layer.recognizedGlyph, 'U');
    });
  });

  test('clear() drops the drawing and the reading with it', () {
    final layer = LatinLayer();
    drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
    drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
    expect(layer.recognizedGlyph, 'T');
    layer.clear();
    expect(layer.recognizedGlyph, isNull);
  });
}
