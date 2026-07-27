import 'dart:math' as math;

import 'package:cord/greek/data/greek_letters.dart';
import 'package:cord/greek/scenes/greek_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(400, 400);

/// Feeds [layer] a stroke from [from] to [to] as the pointer events a real drag
/// would produce: a down, a run of moves along the line, and an up. [steps]
/// controls how finely the line is sampled — the recognizer's straightness and
/// crossing checks both walk the captured points, so a stroke has to arrive as a
/// path, not just its endpoints.
void drawStroke(GreekLayer layer, Offset from, Offset to, {int steps = 20}) {
  layer.handlePointerEvent(PointerDownEvent(position: from), _size);
  for (var i = 1; i <= steps; i++) {
    layer.handlePointerEvent(
        PointerMoveEvent(position: Offset.lerp(from, to, i / steps)!), _size);
  }
  layer.handlePointerEvent(PointerUpEvent(position: to), _size);
}

/// Feeds [layer] one stroke running through [vertices] in order, each leg
/// sampled as a run of moves, so the recognizer sees a genuine path rather than
/// just the corner points.
void drawPath(GreekLayer layer, List<Offset> vertices, {int steps = 20}) {
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

/// Feeds [layer] a single stroke tracing a loop: a circle of [radius] around
/// [center] swept a little past a full turn, its center drifting by [drift] as
/// it's drawn so the closing pass comes back off-center and crosses the opening
/// one — the way a hand draws Ο. A concentric retrace would merely overlap
/// itself; the drift is what turns the overshoot into an actual crossing.
/// Positive [drift] with a modest [overshoot] leaves exactly one crossing.
void drawLoop(GreekLayer layer, Offset center, double radius,
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

/// Feeds [layer] a circle a hand would actually draw: no drift, sweeping [turn]
/// of a full revolution about [center], so `turn < 1` leaves a real gap and
/// `turn > 1` overlaps. At `turn == 1` it ends exactly where it began.
///
/// Distinct from [drawLoop], which drifts as it sweeps so that its overshoot
/// becomes a genuine self-crossing. This one is the honest shape, and it is what
/// the ring tests are written against: a hand closing a circle comes back round
/// and *stops*, rather than swinging a fifth of the way round again.
void drawCircle(GreekLayer layer, Offset center, double radius, double turn,
    {int steps = 72}) {
  Offset at(double t) => Offset(
        center.dx + radius * math.cos(t * turn * 2 * math.pi),
        center.dy + radius * math.sin(t * turn * 2 * math.pi),
      );

  layer.handlePointerEvent(PointerDownEvent(position: at(0)), _size);
  for (var i = 1; i <= steps; i++) {
    layer.handlePointerEvent(PointerMoveEvent(position: at(i / steps)), _size);
  }
  layer.handlePointerEvent(PointerUpEvent(position: at(1)), _size);
}

/// The ring [drawLoop] leaves for a given centre and radius, sampled the same
/// way — so a test can put a stem or a bar where the ring actually is rather
/// than where its nominal centre suggests. The drift means the two differ by
/// rather more than a pixel.
Rect ringBounds(Offset center, double radius,
    {int steps = 60,
    double overshoot = 0.2,
    Offset drift = const Offset(26, -40)}) {
  final sweep = 2 * math.pi * (1 + overshoot);
  var left = double.infinity, right = double.negativeInfinity;
  var top = double.infinity, bottom = double.negativeInfinity;
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final c = center + drift * t;
    final x = c.dx + radius * math.cos(t * sweep);
    final y = c.dy + radius * math.sin(t * sweep);
    left = math.min(left, x);
    right = math.max(right, x);
    top = math.min(top, y);
    bottom = math.max(bottom, y);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

void main() {
  // ── Α, Δ, Λ: the rise and fall ─────────────────────────────────────────────

  group('Α', () {
    // Λ — up to the apex, back down — with a bar across both legs.
    const apex = [Offset(150, 300), Offset(200, 120), Offset(250, 300)];
    const barLeft = Offset(160, 240);
    const barRight = Offset(240, 240);

    test('a Λ with a bar across both legs is Α', () {
      final layer = GreekLayer();
      drawPath(layer, apex);
      drawStroke(layer, barLeft, barRight);
      expect(layer.recognizedGlyph, 'Α');
    });

    test('the bar drawn before the legs is still Α', () {
      final layer = GreekLayer();
      drawStroke(layer, barLeft, barRight);
      drawPath(layer, apex);
      expect(layer.recognizedGlyph, 'Α');
    });

    test('a bar crossing only one leg is not Α', () {
      final layer = GreekLayer();
      drawPath(layer, apex);
      drawStroke(layer, const Offset(100, 240), const Offset(200, 240));
      expect(layer.recognizedGlyph, isNot('Α'));
    });

    test('a V — down then up — with a bar is not Α', () {
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(150, 120),
        Offset(200, 300),
        Offset(250, 120),
      ]);
      drawStroke(layer, const Offset(160, 180), const Offset(240, 180));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('Δ', () {
    const apex = [Offset(150, 300), Offset(200, 120), Offset(250, 300)];
    const baseLeft = Offset(150, 300);
    const baseRight = Offset(250, 300);

    test('a Λ closed at the feet by a base is Δ', () {
      final layer = GreekLayer();
      drawPath(layer, apex);
      drawStroke(layer, baseLeft, baseRight);
      expect(layer.recognizedGlyph, 'Δ');
    });

    test('the base drawn first is still Δ', () {
      final layer = GreekLayer();
      drawStroke(layer, baseLeft, baseRight);
      drawPath(layer, apex);
      expect(layer.recognizedGlyph, 'Δ');
    });

    test('the base drawn right to left is still Δ', () {
      final layer = GreekLayer();
      drawPath(layer, apex);
      drawStroke(layer, baseRight, baseLeft);
      expect(layer.recognizedGlyph, 'Δ');
    });

    test('a base falling a little short of the feet still closes it', () {
      final layer = GreekLayer();
      drawPath(layer, apex);
      drawStroke(layer, const Offset(162, 295), const Offset(238, 295));
      expect(layer.recognizedGlyph, 'Δ');
    });

    // The four below are how a hand actually draws a Δ, and every one of them
    // used to read as Α or as nothing. The test asked the *base's* ends to land
    // on the Λ's feet, which reads a base drawn exactly to size and nothing
    // else. Asked the other way round — the feet landing on the base — the
    // overshoot costs nothing.
    test('a base running out past both feet is still Δ', () {
      final layer = GreekLayer();
      drawPath(layer, apex);
      drawStroke(layer, const Offset(125, 300), const Offset(275, 300));
      expect(layer.recognizedGlyph, 'Δ');
    });

    test('a base running well past them, and a little low, is still Δ', () {
      final layer = GreekLayer();
      drawPath(layer, apex);
      drawStroke(layer, const Offset(110, 302), const Offset(290, 302));
      expect(layer.recognizedGlyph, 'Δ');
    });

    test('a base slightly sloped, and overshooting, is still Δ', () {
      final layer = GreekLayer();
      drawPath(layer, apex);
      drawStroke(layer, const Offset(128, 296), const Offset(272, 305));
      expect(layer.recognizedGlyph, 'Δ');
    });

    test('an overshooting base drawn before the legs is still Δ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(125, 300), const Offset(275, 300));
      drawPath(layer, apex);
      expect(layer.recognizedGlyph, 'Δ');
    });

    test('the same bar raised to the legs\' middle is Α, not Δ', () {
      final layer = GreekLayer();
      drawPath(layer, apex);
      drawStroke(layer, const Offset(160, 240), const Offset(240, 240));
      expect(layer.recognizedGlyph, 'Α');
    });

    test('a base reaching only one foot is not Δ', () {
      final layer = GreekLayer();
      drawPath(layer, apex);
      drawStroke(layer, const Offset(150, 300), const Offset(205, 300));
      expect(layer.recognizedGlyph, isNot('Δ'));
    });

    // ── Δ drawn without lifting the pen ──────────────────────────────────────
    //
    // Two vertical legs, two horizontal ones, and the horizontal reversal down
    // in the bottom quarter — a corner of the base. That last is what separates
    // a triangle from a circle, which gives the same two-and-two but turns back
    // on itself at its own vertical middle.

    test('a triangle rounded anticlockwise in one stroke is Δ', () {
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(150, 300),
        Offset(200, 120),
        Offset(250, 300),
        Offset(150, 300),
      ]);
      expect(layer.recognizedGlyph, 'Δ');
    });

    test('rounded clockwise instead it is the same triangle', () {
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(250, 300),
        Offset(200, 120),
        Offset(150, 300),
        Offset(250, 300),
      ]);
      expect(layer.recognizedGlyph, 'Δ');
    });

    test('starting along the base it is still Δ', () {
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(150, 300),
        Offset(250, 300),
        Offset(200, 120),
        Offset(150, 300),
      ]);
      expect(layer.recognizedGlyph, 'Δ');
    });

    test('stopping short of the corner it is still Δ', () {
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(150, 300),
        Offset(200, 120),
        Offset(250, 300),
        Offset(163, 299),
      ]);
      expect(layer.recognizedGlyph, 'Δ');
    });

    test('running past the corner along the base it is still Δ', () {
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(150, 300),
        Offset(200, 120),
        Offset(250, 300),
        Offset(132, 301),
      ]);
      expect(layer.recognizedGlyph, 'Δ');
    });

    test('a circle gives the same two-and-two but turns at its own middle', () {
      // The one shape the count of legs can't separate a triangle from, and the
      // reason the horizontal reversal is asked to be down in the bottom
      // quarter. If this ever reports Δ, that measurement has gone wrong.
      final layer = GreekLayer();
      drawCircle(layer, const Offset(200, 200), 70, 1.0);
      expect(layer.recognizedGlyph, 'Ο');
    });

    test('carried back up a leg past the corner, it reads as Ο', () {
      // A known edge. Running well past the closing corner and back up the leg
      // adds a *third* vertical leg, and the triangle test asks for two — so it
      // falls through to the ring it has by then become. Closing along the base,
      // short or long, is what the tests above cover and what a hand does.
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(150, 300),
        Offset(200, 120),
        Offset(250, 300),
        Offset(150, 300),
        Offset(175, 210),
      ]);
      expect(layer.recognizedGlyph, 'Ο');
    });
  });

  group('Λ', () {
    const lambda = [Offset(150, 300), Offset(200, 120), Offset(250, 300)];

    test('a bare Λ — up then down, crossing nothing — is Λ', () {
      final layer = GreekLayer();
      drawPath(layer, lambda);
      expect(layer.recognizedGlyph, 'Λ');
    });

    test('drawn from the other end it is the same Λ', () {
      final layer = GreekLayer();
      drawPath(layer, lambda.reversed.toList());
      expect(layer.recognizedGlyph, 'Λ');
    });

    test('a V — down then up — is no letter of its own', () {
      final layer = GreekLayer();
      drawPath(layer,
          const [Offset(150, 120), Offset(200, 300), Offset(250, 120)]);
      expect(layer.recognizedGlyph, isNull);
    });

    test('a Λ with something crossing it is not Λ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(120, 240), const Offset(280, 240));
      drawPath(layer, lambda);
      expect(layer.recognizedGlyph, isNot('Λ'));
    });
  });

  group('Ω', () {
    // A horseshoe: a flat foot, up the narrowing left side, over the crown,
    // down the right side, and out into the other foot.
    const omega = [
      Offset(135, 300),
      Offset(178, 297),
      Offset(165, 240),
      Offset(168, 190),
      Offset(200, 150),
      Offset(232, 190),
      Offset(235, 240),
      Offset(222, 297),
      Offset(265, 300),
    ];

    test('a bowed rise and fall finished with two flat feet is Ω', () {
      final layer = GreekLayer();
      drawPath(layer, omega);
      expect(layer.recognizedGlyph, 'Ω');
    });

    test('drawn from the other foot it is the same Ω', () {
      final layer = GreekLayer();
      drawPath(layer, omega.reversed.toList());
      expect(layer.recognizedGlyph, 'Ω');
    });

    test('the same shape without its feet is Λ, not Ω', () {
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(178, 297),
        Offset(165, 240),
        Offset(168, 190),
        Offset(200, 150),
        Offset(232, 190),
        Offset(235, 240),
        Offset(222, 297),
      ]);
      expect(layer.recognizedGlyph, 'Λ');
    });

    test('a plain Λ is not Ω — its ends are steep, not flat', () {
      final layer = GreekLayer();
      drawPath(layer,
          const [Offset(150, 300), Offset(200, 120), Offset(250, 300)]);
      expect(layer.recognizedGlyph, 'Λ');
    });

    test('feet turning inward rather than outward are not Ω', () {
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(178, 300),
        Offset(135, 297),
        Offset(165, 240),
        Offset(168, 190),
        Offset(200, 150),
        Offset(232, 190),
        Offset(235, 240),
        Offset(265, 297),
        Offset(222, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('Ω'));
    });
  });

  // ── Γ and Π: the squared corners ───────────────────────────────────────────

  group('Γ', () {
    // Right to left along the top bar, then down the leg — elbow at top left.
    const gamma = [Offset(240, 120), Offset(150, 120), Offset(150, 300)];

    test('a bend with its elbow at the top left is Γ', () {
      final layer = GreekLayer();
      drawPath(layer, gamma);
      expect(layer.recognizedGlyph, 'Γ');
    });

    test('drawn leg-first it is the same bend — still Γ', () {
      final layer = GreekLayer();
      drawPath(layer, gamma.reversed.toList());
      expect(layer.recognizedGlyph, 'Γ');
    });

    test('the elbow at the top right instead is not Γ', () {
      final layer = GreekLayer();
      drawPath(
          layer, const [Offset(150, 120), Offset(250, 120), Offset(250, 300)]);
      expect(layer.recognizedGlyph, isNot('Γ'));
    });

    test('a bar and a leg off its left end is Γ in two strokes', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(155, 120), const Offset(155, 300));
      expect(layer.recognizedGlyph, 'Γ');
    });

    test('the leg drawn first is still Γ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(155, 120), const Offset(155, 300));
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      expect(layer.recognizedGlyph, 'Γ');
    });

    test('the leg at the bar\'s middle is Τ, not Γ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'Τ');
    });
  });

  group('Π', () {
    // Up the left leg, across the top, down the right one.
    const pi = [
      Offset(150, 300),
      Offset(150, 120),
      Offset(250, 120),
      Offset(250, 300),
    ];

    test('two squared corners sharing a top bar is Π', () {
      final layer = GreekLayer();
      drawPath(layer, pi);
      expect(layer.recognizedGlyph, 'Π');
    });

    test('drawn right to left, the arch is unchanged — still Π', () {
      final layer = GreekLayer();
      drawPath(layer, pi.reversed.toList());
      expect(layer.recognizedGlyph, 'Π');
    });

    test('a Λ — the same rise and fall, but pointed — is Λ, not Π', () {
      final layer = GreekLayer();
      drawPath(layer,
          const [Offset(150, 300), Offset(200, 120), Offset(250, 300)]);
      expect(layer.recognizedGlyph, 'Λ');
    });

    test('a bar with a leg hanging from each end is Π in three strokes', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(152, 120), const Offset(152, 300));
      drawStroke(layer, const Offset(248, 120), const Offset(248, 300));
      expect(layer.recognizedGlyph, 'Π');
    });

    test('the bar drawn last is still Π', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(152, 120), const Offset(152, 300));
      drawStroke(layer, const Offset(248, 120), const Offset(248, 300));
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      expect(layer.recognizedGlyph, 'Π');
    });

    test('the same bar dropped to the legs\' middle is Η, not Π', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(152, 120), const Offset(152, 300));
      drawStroke(layer, const Offset(248, 120), const Offset(248, 300));
      drawStroke(layer, const Offset(140, 210), const Offset(260, 210));
      expect(layer.recognizedGlyph, 'Η');
    });
  });

  // ── Ε, Ϝ, Η, Ξ: the stem and its bars ──────────────────────────────────────

  group('Ε', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);

    test('a stem with a bar to each of its thirds is Ε', () {
      final layer = GreekLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      drawStroke(layer, const Offset(150, 300), const Offset(250, 300));
      expect(layer.recognizedGlyph, 'Ε');
    });

    test('the stem drawn last is still Ε', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      drawStroke(layer, const Offset(150, 300), const Offset(250, 300));
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'Ε');
    });

    test('three bars bunched at the top is not Ε', () {
      final layer = GreekLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(150, 130), const Offset(250, 130));
      drawStroke(layer, const Offset(150, 155), const Offset(250, 155));
      drawStroke(layer, const Offset(150, 180), const Offset(250, 180));
      expect(layer.recognizedGlyph, isNot('Ε'));
    });

    test('bars reaching left of the stem are not Ε', () {
      final layer = GreekLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(50, 120), const Offset(150, 120));
      drawStroke(layer, const Offset(50, 210), const Offset(150, 210));
      drawStroke(layer, const Offset(50, 300), const Offset(150, 300));
      expect(layer.recognizedGlyph, isNot('Ε'));
    });

    test('a corner and two bars is Ε in three strokes — one pen lift fewer', () {
      final layer = GreekLayer();
      drawPath(layer,
          const [Offset(150, 120), Offset(150, 300), Offset(250, 300)]);
      drawStroke(layer, const Offset(150, 120), const Offset(240, 120));
      drawStroke(layer, const Offset(150, 210), const Offset(240, 210));
      expect(layer.recognizedGlyph, 'Ε');
    });
  });

  group('Ϝ', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);

    void drawDigamma(GreekLayer layer) {
      drawStroke(layer, stemTop, stemBottom);
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
    }

    test('a stem with a top and a middle bar is Ϝ', () {
      final layer = GreekLayer()..alphabet = Alphabet.archaic;
      drawDigamma(layer);
      expect(layer.recognizedGlyph, 'Ϝ');
    });

    test('the third bar at the foot makes it Ε', () {
      final layer = GreekLayer()..alphabet = Alphabet.archaic;
      drawDigamma(layer);
      drawStroke(layer, const Offset(150, 300), const Offset(250, 300));
      expect(layer.recognizedGlyph, 'Ε');
    });

    test('the archaic letters are archaic — in Greek this reads as nothing', () {
      final layer = GreekLayer();
      drawDigamma(layer);
      expect(layer.recognizedGlyph, isNull);
    });

    // An arm may be a plain bar or a ㄱ — Hangul's own, unturned: out to the
    // right and then down, which is how the archaic letter hooks its arms. Note
    // this ㄱ is *not* mirrored, where Γ's own corner is: Γ's elbow is at the
    // top-left, a digamma arm's at the top-right.
    const hookedArm = [Offset(150, 205), Offset(250, 205), Offset(250, 240)];

    test('a middle arm hooked down as a ㄱ is Ϝ', () {
      final layer = GreekLayer()..alphabet = Alphabet.archaic;
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawPath(layer, hookedArm);
      expect(layer.recognizedGlyph, 'Ϝ');
    });

    test('both arms hooked down is still Ϝ', () {
      final layer = GreekLayer()..alphabet = Alphabet.archaic;
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      drawPath(layer,
          const [Offset(150, 120), Offset(250, 120), Offset(250, 155)]);
      drawPath(layer, hookedArm);
      expect(layer.recognizedGlyph, 'Ϝ');
    });

    test('the hooked arm drawn before the stem is still Ϝ', () {
      final layer = GreekLayer()..alphabet = Alphabet.archaic;
      drawPath(layer, hookedArm);
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      expect(layer.recognizedGlyph, 'Ϝ');
    });

    test('a hooked arm down at the stem\'s foot is not Ϝ', () {
      final layer = GreekLayer()..alphabet = Alphabet.archaic;
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawPath(layer,
          const [Offset(150, 285), Offset(250, 285), Offset(250, 320)]);
      expect(layer.recognizedGlyph, isNot('Ϝ'));
    });

    test('mirrored — the stem on the right, arms reaching left — is not Ϝ', () {
      // The stem has to stand left of the letter's own middle. Every other
      // measurement is taken against the stem, so without that the whole shape
      // could be mirrored and still answer.
      final layer = GreekLayer()..alphabet = Alphabet.archaic;
      drawStroke(layer, const Offset(250, 120), const Offset(250, 300));
      drawStroke(layer, const Offset(250, 120), const Offset(150, 120));
      drawStroke(layer, const Offset(250, 210), const Offset(150, 210));
      expect(layer.recognizedGlyph, isNot('Ϝ'));
    });

    // Bars are asked to *meet* the stem, not to cross it. A hand with an upright
    // already on the page starts each bar beside it rather than back-tracking
    // over it, which leaves a junction and no intersection at all — and used to
    // read as nothing.
    test('bars starting a few pixels clear of the stem are still Ϝ', () {
      final layer = GreekLayer()..alphabet = Alphabet.archaic;
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      drawStroke(layer, const Offset(155, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(155, 210), const Offset(250, 210));
      expect(layer.recognizedGlyph, 'Ϝ');
    });

    test('bars nowhere near the stem are not Ϝ', () {
      final layer = GreekLayer()..alphabet = Alphabet.archaic;
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      drawStroke(layer, const Offset(220, 120), const Offset(300, 120));
      drawStroke(layer, const Offset(220, 210), const Offset(300, 210));
      expect(layer.recognizedGlyph, isNot('Ϝ'));
    });
  });

  group('Η', () {
    const leftStemTop = Offset(150, 120);
    const leftStemBottom = Offset(150, 300);
    const rightStemTop = Offset(250, 120);
    const rightStemBottom = Offset(250, 300);
    const barLeft = Offset(140, 210);
    const barRight = Offset(260, 210);

    test('two stems with a bar across both is Η', () {
      final layer = GreekLayer();
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      drawStroke(layer, barLeft, barRight);
      expect(layer.recognizedGlyph, 'Η');
    });

    test('the bar drawn first is still Η', () {
      final layer = GreekLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      expect(layer.recognizedGlyph, 'Η');
    });

    test('a bar reaching only one stem is not Η', () {
      final layer = GreekLayer();
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      drawStroke(layer, barLeft, const Offset(200, 210));
      expect(layer.recognizedGlyph, isNot('Η'));
    });

    test('two stems with no bar at all is not Η', () {
      final layer = GreekLayer();
      drawStroke(layer, leftStemTop, leftStemBottom);
      drawStroke(layer, rightStemTop, rightStemBottom);
      expect(layer.recognizedGlyph, isNot('Η'));
    });
  });

  group('Ξ', () {
    test('three bars stacked clear of each other is Ξ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(150, 140), const Offset(250, 140));
      drawStroke(layer, const Offset(165, 210), const Offset(235, 210));
      drawStroke(layer, const Offset(150, 280), const Offset(250, 280));
      expect(layer.recognizedGlyph, 'Ξ');
    });

    test('drawn bottom-up it is still Ξ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(150, 280), const Offset(250, 280));
      drawStroke(layer, const Offset(165, 210), const Offset(235, 210));
      drawStroke(layer, const Offset(150, 140), const Offset(250, 140));
      expect(layer.recognizedGlyph, 'Ξ');
    });

    test('two bars is not Ξ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(150, 140), const Offset(250, 140));
      drawStroke(layer, const Offset(150, 280), const Offset(250, 280));
      expect(layer.recognizedGlyph, isNot('Ξ'));
    });

    test('three bars on a stem is Ε, not Ξ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      drawStroke(layer, const Offset(150, 300), const Offset(250, 300));
      expect(layer.recognizedGlyph, 'Ε');
    });

    test('three bars strewn apart across the page are not Ξ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(20, 140), const Offset(90, 140));
      drawStroke(layer, const Offset(160, 210), const Offset(230, 210));
      drawStroke(layer, const Offset(300, 280), const Offset(370, 280));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  // ── Β, Ρ, Κ ────────────────────────────────────────────────────────────────

  group('Β', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    const bowls = [
      Offset(150, 120),
      Offset(240, 150),
      Offset(150, 210),
      Offset(240, 250),
      Offset(150, 300),
    ];

    test('a stem with two bowls laid against it is Β', () {
      final layer = GreekLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowls);
      expect(layer.recognizedGlyph, 'Β');
    });

    test('the bowls drawn before the stem is still Β', () {
      final layer = GreekLayer();
      drawPath(layer, bowls);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'Β');
    });

    test('the bowls on their own are no letter — they are Σ mirrored', () {
      final layer = GreekLayer();
      drawPath(layer, bowls);
      expect(layer.recognizedGlyph, isNull);
    });

    test('bowls that never reach the stem are not Β', () {
      final layer = GreekLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, const [
        Offset(200, 120),
        Offset(280, 150),
        Offset(200, 210),
        Offset(280, 250),
        Offset(200, 300),
      ]);
      expect(layer.recognizedGlyph, isNot('Β'));
    });
  });

  group('Ρ', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    const bowl = [Offset(150, 120), Offset(250, 160), Offset(150, 210)];

    test('a stem with a bowl at its top is Ρ', () {
      final layer = GreekLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, bowl);
      expect(layer.recognizedGlyph, 'Ρ');
    });

    test('the bowl drawn first is still Ρ', () {
      final layer = GreekLayer();
      drawPath(layer, bowl);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'Ρ');
    });

    test('a bowl reaching the stem\'s foot is no Greek letter', () {
      final layer = GreekLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(150, 120), Offset(250, 210), Offset(150, 300)]);
      expect(layer.recognizedGlyph, isNull);
    });

    test('a bowl tight enough to close on itself is still Ρ, not a ring', () {
      // Once a ring is allowed to close by its ends meeting rather than only by
      // crossing itself, a tight bowl answers that description too — so Φ and Ϙ
      // get offered this drawing before Ρ does. What turns them away is that
      // both want their stem *centred* on the ring, and a rho's stands at its
      // edge. This pins that.
      final layer = GreekLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(150, 300));
      drawPath(layer,
          const [Offset(145, 130), Offset(250, 160), Offset(145, 148)]);
      expect(layer.recognizedGlyph, 'Ρ');
    });

    test('a bowl hung on the stem\'s left is not Ρ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(250, 120), const Offset(250, 300));
      drawPath(layer,
          const [Offset(250, 120), Offset(160, 160), Offset(250, 210)]);
      expect(layer.recognizedGlyph, isNot('Ρ'));
    });
  });

  group('Κ', () {
    const stemTop = Offset(150, 120);
    const stemBottom = Offset(150, 300);
    const arm = [Offset(250, 120), Offset(150, 210), Offset(250, 300)];

    test('a stem with an arm running in and away is Κ', () {
      final layer = GreekLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer, arm);
      expect(layer.recognizedGlyph, 'Κ');
    });

    test('the arm drawn first is still Κ', () {
      final layer = GreekLayer();
      drawPath(layer, arm);
      drawStroke(layer, stemTop, stemBottom);
      expect(layer.recognizedGlyph, 'Κ');
    });

    test('an arm that never reaches the stem is not Κ', () {
      final layer = GreekLayer();
      drawStroke(layer, stemTop, stemBottom);
      drawPath(layer,
          const [Offset(300, 120), Offset(220, 210), Offset(300, 300)]);
      expect(layer.recognizedGlyph, isNot('Κ'));
    });
  });

  // ── Θ, Φ, Ϙ, Ο: the ring ───────────────────────────────────────────────────

  group('Ο', () {
    test('a closed loop is Ο', () {
      final layer = GreekLayer();
      drawLoop(layer, const Offset(200, 200), 70);
      expect(layer.recognizedGlyph, 'Ο');
    });

    // A hand closing a circle comes back round and stops. It does not reliably
    // cross its own path, and a stroke that ends exactly where it began crosses
    // it only in the arithmetic sense — which is why the ring test asks whether
    // the two ends *meet* as well as whether the path crosses. Read by
    // self-crossing alone, all three of these were nothing at all.
    test('a circle closed exactly where it began is Ο', () {
      final layer = GreekLayer();
      drawCircle(layer, const Offset(200, 200), 70, 1.0);
      expect(layer.recognizedGlyph, 'Ο');
    });

    test('a circle closed to within a few pixels is Ο', () {
      final layer = GreekLayer();
      drawCircle(layer, const Offset(200, 200), 70, 0.97);
      expect(layer.recognizedGlyph, 'Ο');
    });

    test('a circle carried a little past its start is Ο', () {
      final layer = GreekLayer();
      drawCircle(layer, const Offset(200, 200), 70, 1.03);
      expect(layer.recognizedGlyph, 'Ο');
    });

    test('an arc left with a real gap in it is still not Ο', () {
      // The other half of that bargain: ends *meeting* is forgiving, but an arc
      // that was never closed is not a ring and mustn't become one.
      final layer = GreekLayer();
      drawCircle(layer, const Offset(200, 200), 70, 0.88);
      expect(layer.recognizedGlyph, isNot('Ο'));
    });

    test('a loop that never closes is not Ο', () {
      final layer = GreekLayer();
      drawLoop(layer, const Offset(200, 200), 70, overshoot: -0.08);
      expect(layer.recognizedGlyph, isNot('Ο'));
    });

    test('a loop tangled with another stroke is not Ο', () {
      final layer = GreekLayer();
      drawLoop(layer, const Offset(200, 200), 70);
      drawStroke(layer, const Offset(60, 60), const Offset(340, 340));
      expect(layer.recognizedGlyph, isNot('Ο'));
    });
  });

  group('Θ', () {
    const centre = Offset(200, 200);
    const radius = 70.0;

    test('a circle with a bar across its waist is Θ', () {
      final layer = GreekLayer();
      drawCircle(layer, centre, radius, 1.0);
      drawStroke(layer, const Offset(145, 200), const Offset(255, 200));
      expect(layer.recognizedGlyph, 'Θ');
    });

    test('the bar drawn first is still Θ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(145, 200), const Offset(255, 200));
      drawCircle(layer, centre, radius, 1.0);
      expect(layer.recognizedGlyph, 'Θ');
    });

    // A theta's bar is *contained* by its ring — a hand draws it from inside one
    // side to inside the other, so it very often crosses nothing at all. Counted
    // as crossings, these read as nothing, or (with the ring drawn last) as Ο,
    // the bar having touched nothing and left a plain loop behind.
    test('a bar stopping just inside both sides is Θ', () {
      final layer = GreekLayer();
      final ring = ringBounds(centre, radius);
      drawLoop(layer, centre, radius);
      drawStroke(layer, Offset(ring.left + 12, 160), Offset(ring.right - 12, 160));
      expect(layer.recognizedGlyph, 'Θ');
    });

    test('a bar well inside both sides is Θ', () {
      final layer = GreekLayer();
      final ring = ringBounds(centre, radius);
      drawLoop(layer, centre, radius);
      drawStroke(layer, Offset(ring.left + 25, 160), Offset(ring.right - 25, 160));
      expect(layer.recognizedGlyph, 'Θ');
    });

    test('a contained bar drawn before the ring is Θ, not Ο', () {
      final layer = GreekLayer();
      final ring = ringBounds(centre, radius);
      drawStroke(layer, Offset(ring.left + 12, 160), Offset(ring.right - 12, 160));
      drawLoop(layer, centre, radius);
      expect(layer.recognizedGlyph, 'Θ');
    });

    test('a bar laid across the ring\'s own middle is Θ', () {
      // Where the old reading was at its worst: a ring's leftmost point sits at
      // very nearly its vertical middle, so a bar there is *tangent* to it and
      // the crossing count came down to sampling. Reading where the bar *lies*
      // has no such edge.
      final layer = GreekLayer();
      final ring = ringBounds(centre, radius);
      drawLoop(layer, centre, radius);
      drawStroke(layer, Offset(ring.left - 30, ring.center.dy),
          Offset(ring.right + 30, ring.center.dy));
      expect(layer.recognizedGlyph, 'Θ');
    });

    // Inside the ring is the whole test, so a bar high in it, or short, is a
    // theta too. Both of these used to be refused — by a middle-band check and
    // by a minimum span — and neither check was telling a theta from anything.
    // Nothing else here is a ring with a bar in it.
    test('a bar high in the ring is Θ', () {
      final layer = GreekLayer();
      final ring = ringBounds(centre, radius);
      drawLoop(layer, centre, radius);
      drawStroke(layer, Offset(ring.left - 40, ring.top + 8),
          Offset(ring.right + 40, ring.top + 8));
      expect(layer.recognizedGlyph, 'Θ');
    });

    test('a short bar inside the ring is Θ', () {
      final layer = GreekLayer();
      drawLoop(layer, centre, radius);
      drawStroke(layer, const Offset(200, 175), const Offset(240, 175));
      expect(layer.recognizedGlyph, 'Θ');
    });

    test('a bar hung off the ring\'s side is not Θ', () {
      final layer = GreekLayer();
      final ring = ringBounds(centre, radius);
      drawLoop(layer, centre, radius);
      drawStroke(layer, Offset(ring.center.dx, 175), Offset(ring.right + 110, 175));
      expect(layer.recognizedGlyph, isNot('Θ'));
    });

    test('a ring with nothing on it is Ο', () {
      final layer = GreekLayer();
      drawLoop(layer, centre, radius);
      expect(layer.recognizedGlyph, 'Ο');
    });
  });

  group('Φ', () {
    const centre = Offset(200, 200);
    const radius = 70.0;

    test('a ring run through by a stem is Φ', () {
      final layer = GreekLayer();
      drawLoop(layer, centre, radius);
      drawStroke(layer, const Offset(215, 90), const Offset(215, 300));
      expect(layer.recognizedGlyph, 'Φ');
    });

    test('the stem drawn first is still Φ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(215, 90), const Offset(215, 300));
      drawLoop(layer, centre, radius);
      expect(layer.recognizedGlyph, 'Φ');
    });

    test('a stem through a plainly closed circle is Φ', () {
      final layer = GreekLayer();
      drawCircle(layer, centre, radius, 1.0);
      drawStroke(layer, const Offset(200, 100), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'Φ');
    });

    test('a stem off to one side of the ring is not Φ', () {
      final layer = GreekLayer();
      drawLoop(layer, centre, radius);
      drawStroke(layer, const Offset(285, 90), const Offset(285, 300));
      expect(layer.recognizedGlyph, isNot('Φ'));
    });

    test('a stem stopping at the ring\'s edges is not Φ', () {
      final layer = GreekLayer();
      final ring = ringBounds(centre, radius);
      drawLoop(layer, centre, radius);
      drawStroke(layer, Offset(215, ring.top + 10), Offset(215, ring.bottom - 10));
      expect(layer.recognizedGlyph, isNot('Φ'));
    });
  });

  group('Ϙ', () {
    const centre = Offset(200, 200);
    const radius = 70.0;

    test('a ring with a stem hung under it is Ϙ', () {
      final layer = GreekLayer()..alphabet = Alphabet.archaic;
      drawLoop(layer, centre, radius);
      drawStroke(layer, const Offset(215, 240), const Offset(215, 340));
      expect(layer.recognizedGlyph, 'Ϙ');
    });

    test('the stem drawn first is still Ϙ', () {
      final layer = GreekLayer()..alphabet = Alphabet.archaic;
      drawStroke(layer, const Offset(215, 240), const Offset(215, 340));
      drawLoop(layer, centre, radius);
      expect(layer.recognizedGlyph, 'Ϙ');
    });

    test('the same stem run right through the ring is Φ, not Ϙ', () {
      final layer = GreekLayer()..alphabet = Alphabet.archaic;
      drawLoop(layer, centre, radius);
      drawStroke(layer, const Offset(215, 90), const Offset(215, 300));
      expect(layer.recognizedGlyph, 'Φ');
    });

    test('in Greek, which dropped it, a koppa reads as nothing', () {
      final layer = GreekLayer();
      drawLoop(layer, centre, radius);
      drawStroke(layer, const Offset(215, 240), const Offset(215, 340));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  // ── Υ, Ψ, Τ, Χ ─────────────────────────────────────────────────────────────

  group('Υ', () {
    const vee = [Offset(150, 120), Offset(200, 220), Offset(250, 120)];

    test('a V with a stem below its vertex is Υ', () {
      final layer = GreekLayer();
      drawPath(layer, vee);
      drawStroke(layer, const Offset(200, 220), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'Υ');
    });

    test('the stem drawn first is still Υ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(200, 220), const Offset(200, 300));
      drawPath(layer, vee);
      expect(layer.recognizedGlyph, 'Υ');
    });

    test('a stem hung off one arm rather than the vertex is not Υ', () {
      final layer = GreekLayer();
      drawPath(layer, vee);
      drawStroke(layer, const Offset(160, 140), const Offset(160, 300));
      expect(layer.recognizedGlyph, isNot('Υ'));
    });
  });

  group('Ψ', () {
    const vee = [Offset(150, 120), Offset(200, 220), Offset(250, 120)];

    test('the same V with the stem carried up past the vertex is Ψ', () {
      final layer = GreekLayer();
      drawPath(layer, vee);
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'Ψ');
    });

    test('the stem drawn first is still Ψ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      drawPath(layer, vee);
      expect(layer.recognizedGlyph, 'Ψ');
    });

    test('the stem stopping at the vertex is Υ, not Ψ', () {
      final layer = GreekLayer();
      drawPath(layer, vee);
      drawStroke(layer, const Offset(200, 220), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'Υ');
    });
  });

  group('Τ', () {
    const barLeft = Offset(150, 120);
    const barRight = Offset(250, 120);

    test('a bar with a stem below its middle is Τ', () {
      final layer = GreekLayer();
      drawStroke(layer, barLeft, barRight);
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'Τ');
    });

    test('the stem drawn first is still Τ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      drawStroke(layer, barLeft, barRight);
      expect(layer.recognizedGlyph, 'Τ');
    });

    test('a stem crossing the bar\'s middle is a cross, not Τ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      drawStroke(layer, const Offset(150, 210), const Offset(250, 210));
      expect(layer.recognizedGlyph, isNot('Τ'));
    });
  });

  group('Χ', () {
    const rising = [Offset(150, 300), Offset(250, 120)];
    const falling = [Offset(150, 120), Offset(250, 300)];

    test('a rising and a falling stroke crossing once is Χ', () {
      final layer = GreekLayer();
      drawStroke(layer, rising[0], rising[1]);
      drawStroke(layer, falling[0], falling[1]);
      expect(layer.recognizedGlyph, 'Χ');
    });

    test('either order, either direction, is still Χ', () {
      final layer = GreekLayer();
      drawStroke(layer, falling[1], falling[0]);
      drawStroke(layer, rising[1], rising[0]);
      expect(layer.recognizedGlyph, 'Χ');
    });

    test('two strokes that never cross are not Χ', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(60, 300), const Offset(120, 120));
      drawStroke(layer, const Offset(250, 120), const Offset(340, 300));
      expect(layer.recognizedGlyph, isNot('Χ'));
    });
  });

  // ── Μ, Ν, Σ, Ζ, Ι ──────────────────────────────────────────────────────────

  group('Μ', () {
    const mu = [
      Offset(140, 300),
      Offset(170, 120),
      Offset(200, 240),
      Offset(230, 120),
      Offset(260, 300),
    ];

    test('a stroke rising, falling, rising and falling is Μ', () {
      final layer = GreekLayer();
      drawPath(layer, mu);
      expect(layer.recognizedGlyph, 'Μ');
    });

    test('drawn from the other end it is still Μ', () {
      final layer = GreekLayer();
      drawPath(layer, mu.reversed.toList());
      expect(layer.recognizedGlyph, 'Μ');
    });

    test('one peak short — a Λ — is not Μ', () {
      final layer = GreekLayer();
      drawPath(layer,
          const [Offset(140, 300), Offset(170, 120), Offset(200, 300)]);
      expect(layer.recognizedGlyph, isNot('Μ'));
    });

    test('the same four legs upside down — a W — is no Greek letter', () {
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(140, 120),
        Offset(170, 300),
        Offset(200, 180),
        Offset(230, 300),
        Offset(260, 120),
      ]);
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('Σ', () {
    // In along the top bar, out to the fold, back in, out along the bottom.
    const sigma = [
      Offset(250, 130),
      Offset(150, 130),
      Offset(215, 205),
      Offset(150, 280),
      Offset(250, 280),
    ];

    test('a stroke folding to and fro four times is Σ', () {
      final layer = GreekLayer();
      drawPath(layer, sigma);
      expect(layer.recognizedGlyph, 'Σ');
    });

    test('drawn from the bottom bar it is still Σ', () {
      final layer = GreekLayer();
      drawPath(layer, sigma.reversed.toList());
      expect(layer.recognizedGlyph, 'Σ');
    });

    test('the same four folds mirrored — Β\'s bowls — is not Σ', () {
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(150, 120),
        Offset(240, 150),
        Offset(150, 210),
        Offset(240, 250),
        Offset(150, 300),
      ]);
      expect(layer.recognizedGlyph, isNull);
    });

    test('a fold short — a Ζ — is not Σ', () {
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(150, 140),
        Offset(250, 140),
        Offset(150, 280),
        Offset(250, 280),
      ]);
      expect(layer.recognizedGlyph, isNot('Σ'));
    });
  });

  group('Ν', () {
    // Up the left stem, down the diagonal, up the right stem.
    const nu = [
      Offset(150, 300),
      Offset(150, 120),
      Offset(250, 300),
      Offset(250, 120),
    ];

    test('two stems with a falling diagonal between them is Ν', () {
      final layer = GreekLayer();
      drawPath(layer, nu);
      expect(layer.recognizedGlyph, 'Ν');
    });

    test('drawn from the other end it is still Ν', () {
      final layer = GreekLayer();
      drawPath(layer, nu.reversed.toList());
      expect(layer.recognizedGlyph, 'Ν');
    });

    test('the diagonal rising instead — Cyrillic И — is no Greek letter', () {
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(150, 120),
        Offset(150, 300),
        Offset(250, 120),
        Offset(250, 300),
      ]);
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('Ζ', () {
    // The top bar, the diagonal down-left, then the bottom bar.
    const zeta = [
      Offset(150, 140),
      Offset(250, 140),
      Offset(150, 280),
      Offset(250, 280),
    ];

    test('a stroke running right, back left and right again is Ζ', () {
      final layer = GreekLayer();
      drawPath(layer, zeta);
      expect(layer.recognizedGlyph, 'Ζ');
    });

    test('drawn end for end it is still Ζ', () {
      final layer = GreekLayer();
      drawPath(layer, zeta.reversed.toList());
      expect(layer.recognizedGlyph, 'Ζ');
    });

    test('the diagonal leaning the other way — an S — is no Greek letter', () {
      final layer = GreekLayer();
      drawPath(layer, const [
        Offset(250, 140),
        Offset(150, 140),
        Offset(250, 280),
        Offset(150, 280),
      ]);
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('Ι', () {
    test('a bare upright is Ι', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'Ι');
    });

    test('drawn bottom-up it is still Ι', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(200, 300), const Offset(200, 120));
      expect(layer.recognizedGlyph, 'Ι');
    });

    test('a diagonal is not Ι', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(150, 120), const Offset(250, 300));
      expect(layer.recognizedGlyph, isNull);
    });

    test('an upright already crossed by a bar is Τ, not Ι', () {
      final layer = GreekLayer();
      drawStroke(layer, const Offset(120, 120), const Offset(280, 120));
      drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
      expect(layer.recognizedGlyph, 'Τ');
    });
  });

  // ── The alphabets ──────────────────────────────────────────────────────────

  group('alphabets', () {
    const omega = [
      Offset(135, 300),
      Offset(178, 297),
      Offset(165, 240),
      Offset(168, 190),
      Offset(200, 150),
      Offset(232, 190),
      Offset(235, 240),
      Offset(222, 297),
      Offset(265, 300),
    ];

    test('Greek is what a fresh layer starts on', () {
      final layer = GreekLayer();
      expect(layer.alphabet, Alphabet.greek);
    });

    test('every alphabet\'s letters resolve to rows', () {
      for (final alphabet in Alphabet.values) {
        expect(alphabet.rows.length, alphabet.letters.length,
            reason: alphabet.label);
      }
    });

    test('an alphabet naming a capital with no row throws', () {
      // The guard that makes a typo in one of those strings fail loudly rather
      // than quietly shorten an alphabet. Latin A is not a row here.
      expect(() => _rowsOf('ΑΒA'), throwsStateError);
    });

    test('no alphabet lists a letter twice', () {
      for (final alphabet in Alphabet.values) {
        final capitals = alphabet.letters.split('');
        expect(capitals.toSet().length, capitals.length,
            reason: alphabet.label);
      }
    });

    test('every row is listed by some alphabet', () {
      for (final row in alphabetRows) {
        expect(Alphabet.values.any((a) => a.letters.contains(row.capital)),
            isTrue,
            reason: row.capital);
      }
    });

    /// The letters listed by some alphabet but not yet drawable. Named one by
    /// one on purpose: a letter joining this set is a decision, and should read
    /// as one. Don't loosen the checks below instead.
    const staged = <String>{};

    test('every letter of every alphabet the recognizer knows', () {
      for (final alphabet in Alphabet.values) {
        for (final row in alphabet.rows) {
          if (staged.contains(row.capital)) continue;
          expect(GreekLayer.recognizedNames, contains(row.name),
              reason: '${row.capital} of ${alphabet.label}');
        }
      }
    });

    test('every alphabet is wholly drawable, with nothing staged', () {
      for (final alphabet in Alphabet.values) {
        final undrawable = alphabet.rows
            .where((row) => !GreekLayer.recognizedNames.contains(row.name))
            .map((row) => row.capital);
        expect(undrawable, isEmpty, reason: alphabet.label);
      }
    });

    test('Old Attic has neither Ξ, Ψ nor Ω', () {
      for (final capital in ['Ξ', 'Ψ', 'Ω']) {
        expect(Alphabet.oldAttic.letters.contains(capital), isFalse,
            reason: capital);
        expect(Alphabet.greek.letters.contains(capital), isTrue,
            reason: capital);
      }
    });

    test('an Ω falls through to the Λ it is built on in Old Attic', () {
      final layer = GreekLayer()..alphabet = Alphabet.oldAttic;
      drawPath(layer, omega);
      expect(layer.recognizedGlyph, 'Λ');
    });

    test('a Ξ has nothing to fall through to, so it reads as nothing', () {
      final layer = GreekLayer()..alphabet = Alphabet.oldAttic;
      drawStroke(layer, const Offset(150, 140), const Offset(250, 140));
      drawStroke(layer, const Offset(165, 210), const Offset(235, 210));
      drawStroke(layer, const Offset(150, 280), const Offset(250, 280));
      expect(layer.recognizedGlyph, isNull);
    });

    test('switching alphabets re-reads what is already drawn', () {
      final layer = GreekLayer();
      drawPath(layer, omega);
      expect(layer.recognizedGlyph, 'Ω');
      layer.alphabet = Alphabet.oldAttic;
      expect(layer.recognizedGlyph, 'Λ');
      layer.alphabet = Alphabet.greek;
      expect(layer.recognizedGlyph, 'Ω');
    });

    test('switching alphabets on an empty page reads as nothing', () {
      final layer = GreekLayer()..alphabet = Alphabet.oldAttic;
      expect(layer.recognizedGlyph, isNull);
    });

    test('a letter reads the same in every alphabet that has it', () {
      // Τ all three have; Ω only Greek. Each is reported wherever it belongs
      // and passed over where it doesn't — the shapes are the same either way.
      for (final alphabet in Alphabet.values) {
        final tau = GreekLayer()..alphabet = alphabet;
        drawStroke(tau, const Offset(150, 120), const Offset(250, 120));
        drawStroke(tau, const Offset(200, 120), const Offset(200, 300));
        expect(tau.recognizedGlyph, 'Τ', reason: alphabet.label);

        final oh = GreekLayer()..alphabet = alphabet;
        drawPath(oh, omega);
        expect(oh.recognizedGlyph, alphabet.letters.contains('Ω') ? 'Ω' : 'Λ',
            reason: alphabet.label);
      }
    });
  });

  test('clear() drops the drawing and the reading with it', () {
    final layer = GreekLayer();
    drawStroke(layer, const Offset(150, 120), const Offset(250, 120));
    drawStroke(layer, const Offset(200, 120), const Offset(200, 300));
    expect(layer.recognizedGlyph, 'Τ');
    layer.clear();
    expect(layer.recognizedGlyph, isNull);
  });
}

/// Resolves an arbitrary run of capitals the way [Alphabet.rows] does, so the
/// unknown-capital guard can be tested without adding a bogus alphabet.
List<LetterRow> _rowsOf(String letters) {
  final byCapital = {for (final row in alphabetRows) row.capital: row};
  return letters.split('').map((capital) {
    final row = byCapital[capital];
    if (row == null) throw StateError('no row for "$capital"');
    return row;
  }).toList();
}
