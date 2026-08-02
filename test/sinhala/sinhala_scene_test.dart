import 'dart:ui' show Offset, Size;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cord/sinhala/scenes/sinhala_scene.dart';

/// Upstream `sinhala`'s scene test, less the groups for the letters, the vowel
/// modifiers and the dots on them — cord took the numerals only (see
/// `lib/sinhala/pages/sinhala_page.dart`). The letter *rules* are still in the
/// recognizer, so the tests here that reach for them still do: a ර is a Lith
/// ෮ drawn, and switching the canvas from one system to the other is what
/// several of these are about.
///
/// cord's own additions are the last group: the two systems being the only
/// ones a drawing is ever pointed at.
const _size = Size(960, 840);

/// Drags [SinhalaLetterLayer] through [path], interpolating a point every 2
/// logical pixels so the stroke is sampled at least as densely as a real drag.
void drag(SinhalaLetterLayer layer, List<Offset> path) {
  layer.handlePointerEvent(PointerDownEvent(position: path.first), _size);
  for (var i = 1; i < path.length; i++) {
    final from = path[i - 1];
    final to = path[i];
    final steps = ((to - from).distance / 2).ceil();
    for (var step = 1; step <= steps; step++) {
      layer.handlePointerEvent(
        PointerMoveEvent(position: from + (to - from) * (step / steps)),
        _size,
      );
    }
  }
  layer.handlePointerEvent(PointerUpEvent(position: path.last), _size);
}

/// A press and release that goes nowhere — a dot.
void tap(SinhalaLetterLayer layer, Offset at) {
  layer.handlePointerEvent(PointerDownEvent(position: at), _size);
  layer.handlePointerEvent(PointerUpEvent(position: at), _size);
}

/// Draws a glyph body, then any further [marks] strokes, then any [dots].
/// Leaves the canvas on the recognizer's default system, the letters — the
/// numeral groups below set the one they want first.
SinhalaLetterLayer draw(
  List<Offset> path, {
  List<Offset> dots = const [],
  List<List<Offset>> marks = const [],
}) {
  final layer = SinhalaLetterLayer();
  drag(layer, path);
  for (final mark in marks) {
    drag(layer, mark);
  }
  for (final dot in dots) {
    tap(layer, dot);
  }
  return layer;
}

String? recognize(
  List<Offset> path, {
  List<Offset> dots = const [],
  List<List<Offset>> marks = const [],
}) =>
    draw(path, dots: dots, marks: marks).recognizedLetter;

/// A ට as actually drawn on the canvas: one continuous counter-clockwise loop
/// starting at the inner tip, sweeping down and round, and finishing along the
/// top with a leftward run. Traced off a real drawing, so it carries the
/// gentle, large-radius curvature that a hand produces — the case a
/// corner-counting recognizer misses entirely.
const drawnRetroflexTa = [
  Offset(540, 511),
  Offset(490, 508),
  Offset(455, 513),
  Offset(430, 530),
  Offset(417, 555),
  Offset(415, 580),
  Offset(428, 607),
  Offset(452, 628),
  Offset(487, 641),
  Offset(530, 641),
  Offset(570, 628),
  Offset(600, 606),
  Offset(625, 575),
  Offset(641, 540),
  Offset(649, 500),
  Offset(650, 460),
  Offset(645, 437),
  Offset(630, 410),
  Offset(608, 390),
  Offset(585, 376),
  Offset(560, 371),
  Offset(520, 370),
  Offset(480, 370),
];

/// A ර: the pen runs up, sweeps clockwise all the way round, cuts back across
/// the stem it started on, and climbs away to finish.
///
/// Unlike [drawnRetroflexTa] this is *not* traced off a real drawing — it is
/// built to the described geometry (rightward loop, self-crossing, ascending
/// tail), so it pins the rule's logic but not its thresholds against a real
/// hand.
const synthesizedRa = [
  Offset(250, 300),
  Offset(250, 170),
  Offset(262, 140),
  Offset(290, 120),
  Offset(325, 122),
  Offset(352, 145),
  Offset(360, 180),
  Offset(352, 215),
  Offset(330, 243),
  Offset(300, 255),
  Offset(268, 250),
  Offset(240, 232),
  Offset(210, 195),
  Offset(190, 160),
  Offset(178, 130),
];

/// A උ: the pen rises and arches over to the right, comes back down, then
/// hooks left — swinging out right, up, and back across the descent it just
/// drew — before running down and away to finish low on the right.
///
/// Synthesized to the described geometry, like [synthesizedRa]: it pins the
/// rule's logic, not its thresholds against a real hand.
const synthesizedU = [
  Offset(250, 190),
  Offset(250, 155),
  Offset(252, 132),
  Offset(263, 113),
  Offset(285, 104),
  Offset(307, 112),
  Offset(318, 133),
  Offset(322, 168),
  Offset(322, 205),
  Offset(330, 235),
  Offset(352, 255),
  Offset(378, 258),
  Offset(398, 243),
  Offset(405, 218),
  Offset(398, 194),
  Offset(378, 180),
  Offset(354, 180),
  Offset(332, 190),
  Offset(316, 207),
  Offset(308, 228),
  Offset(312, 250),
  Offset(332, 272),
  Offset(354, 275),
];

/// A ං (the vowel modifier): one dot, clear of [synthesizedRa]'s right-hand
/// edge at x=360 — here to be sure no modifier is read on a numeral.
const anusvaraDot = Offset(420, 180);

/// A ෦ (Lith 0): up from the bottom, bending left over the top and back down
/// across the stem it came up on, then bending right away from the crossing.
const synthesizedBinduva = [
  Offset(330, 300),
  Offset(330, 240),
  Offset(328, 200),
  Offset(318, 168),
  Offset(296, 148),
  Offset(270, 152),
  Offset(256, 176),
  Offset(258, 206),
  Offset(276, 228),
  Offset(302, 240),
  Offset(336, 248),
  Offset(356, 262),
  Offset(366, 284),
  Offset(366, 306),
];

/// A ෧ (Lith 1): the pen sets off rightward, curls all the way round
/// clockwise, cuts back up through the stroke it came in on — closing the
/// circle — and then carries on bending right, away and down to the right of
/// where it crossed.
const synthesizedEka = [
  Offset(250, 190),
  Offset(285, 194),
  Offset(315, 205),
  Offset(338, 226),
  Offset(344, 254),
  Offset(334, 280),
  Offset(310, 294),
  Offset(282, 292),
  Offset(258, 276),
  Offset(250, 252),
  Offset(254, 228),
  Offset(268, 208),
  Offset(295, 192),
  Offset(315, 190),
  Offset(332, 196),
  Offset(346, 212),
  Offset(350, 232),
];

/// A ෨ (Lith 2): [synthesizedEka] up to the point it leaves its first coil,
/// and then a second coil beside it — over the top of the first, round the
/// right, back along the bottom and over its own line again, before dropping
/// away below and right of that second crossing.
///
/// The two coils have to be entered *over the top*: joining two clockwise
/// coils left-to-right the obvious way needs an S-bend between them, and ෨
/// bends right the whole way through.
const synthesizedDeka = [
  // First coil, and out over the top of it.
  Offset(200, 200),
  Offset(228, 196),
  Offset(248, 206),
  Offset(252, 226),
  Offset(238, 240),
  Offset(216, 240),
  Offset(202, 228),
  Offset(202, 210),
  Offset(218, 194),
  Offset(228, 188),
  Offset(252, 184),
  // Second coil, and away below and right of where it closed.
  Offset(276, 190),
  Offset(298, 200),
  Offset(306, 220),
  Offset(296, 238),
  Offset(276, 244),
  Offset(260, 234),
  Offset(256, 214),
  Offset(264, 196),
  Offset(280, 190),
  Offset(296, 186),
  Offset(312, 192),
  Offset(320, 208),
  Offset(318, 226),
];

/// A ෬ (Lith 6): a wide sweep bending right the whole way, passing above the
/// height it set off from and then below it, and finishing with a small curl
/// over on the right that closes on itself once.
const synthesizedHaya = [
  Offset(200, 240),
  Offset(240, 214),
  Offset(290, 204),
  Offset(330, 214),
  Offset(356, 240),
  Offset(364, 272),
  Offset(358, 296),
  Offset(338, 308),
  Offset(318, 300),
  Offset(314, 282),
  Offset(326, 270),
  Offset(368, 276),
];

/// The Illakkam 𑇡: [synthesizedEka], then a bend the other way that comes
/// round through half a turn and draws a line straight up — finishing above
/// where the coil began.
const synthesizedIllakkamEka = [
  ...synthesizedEka,
  Offset(366, 240),
  Offset(378, 232),
  Offset(382, 216),
  Offset(378, 196),
  Offset(378, 170),
  Offset(378, 140),
];

/// The Illakkam 𑇢: the same bend the other way, and no more — it flicks away
/// level rather than climbing.
const synthesizedIllakkamDeka = [
  ...synthesizedEka,
  Offset(362, 244),
  Offset(378, 246),
  Offset(390, 238),
];

/// The Illakkam 𑇣: the coil, then the pen doubling back and away again, its
/// bending changing hand three times over where 𑇡 and 𑇢 change it once.
const synthesizedIllakkamTuna = [
  ...synthesizedEka,
  // Round the other way and up.
  Offset(366, 240),
  Offset(380, 230),
  Offset(384, 208),
  Offset(378, 188),
  // Back again, over and down.
  Offset(384, 172),
  Offset(396, 168),
  Offset(404, 180),
  Offset(406, 198),
  // And away.
  Offset(414, 210),
  Offset(426, 206),
  Offset(432, 192),
];

/// The Illakkam 𑇥: 𑇣 with one more double back, taken right after the coil.
///
/// It turns the same way the coil does, so the two merge into one run and the
/// run count stays at 𑇣's four — what the extra turn leaves behind is another
/// crossing, where it cut over the line it turned on.
const synthesizedIllakkamPaha = [
  ...synthesizedEka,
  // The extra double back, round and over the line it came in on.
  Offset(348, 252),
  Offset(338, 270),
  Offset(320, 278),
  Offset(304, 270),
  Offset(298, 252),
  Offset(306, 236),
  Offset(324, 230),
  Offset(356, 238),
  // And on as 𑇣 does: round the other way and up,
  Offset(386, 232),
  Offset(404, 218),
  Offset(410, 198),
  Offset(404, 180),
  // back again, over and down,
  Offset(410, 164),
  Offset(424, 160),
  Offset(434, 172),
  Offset(436, 190),
  // and away, cutting over that last turn.
  Offset(444, 204),
  Offset(458, 206),
  Offset(468, 196),
  Offset(474, 182),
  Offset(472, 166),
  Offset(458, 160),
  Offset(444, 168),
  Offset(426, 176),
];

/// The Illakkam 𑇤: humps across the top — right, left, right, left — and then
/// a last run that drops away below all of it, closes a small loop at the
/// foot, and leaves off to the right.
const synthesizedIllakkamHathara = [
  // Up, over, down.
  Offset(230, 150),
  Offset(232, 110),
  Offset(244, 72),
  Offset(268, 52),
  Offset(292, 60),
  Offset(302, 84),
  // Trough.
  Offset(306, 108),
  Offset(318, 118),
  Offset(332, 106),
  // Over again.
  Offset(346, 80),
  Offset(360, 70),
  Offset(376, 78),
  Offset(382, 100),
  // And down.
  Offset(386, 120),
  Offset(396, 128),
  Offset(404, 120),
  // The last run: straight down past everything, round a loop, and away.
  Offset(412, 104),
  Offset(414, 124),
  Offset(414, 146),
  Offset(410, 164),
  Offset(392, 170),
  Offset(378, 158),
  Offset(382, 140),
  Offset(400, 136),
  Offset(420, 142),
  Offset(428, 152),
];

/// The Illakkam 𑇩: 𑇡's two runs, but going the whole way round a loop before
/// the line rather than straight to it — so the same shape, one crossing more.
const synthesizedIllakkamNavaya = [
  ...synthesizedEka,
  // Round a loop, closing on the way in.
  Offset(364, 240),
  Offset(378, 236),
  Offset(384, 222),
  Offset(378, 208),
  Offset(364, 202),
  Offset(350, 208),
  Offset(344, 222),
  Offset(356, 238),
  // And up into the line.
  Offset(370, 240),
  Offset(380, 232),
  Offset(390, 220),
  Offset(392, 200),
  Offset(390, 170),
  Offset(390, 140),
];

/// The Illakkam 𑇦: up and over, back down, down again, and then round and all
/// the way up past everything else to finish at the top.
const synthesizedIllakkamHaya = [
  // Up and over.
  Offset(340, 264),
  Offset(332, 210),
  Offset(340, 164),
  Offset(370, 140),
  Offset(402, 150),
  Offset(414, 186),
  // Double back down.
  Offset(440, 216),
  Offset(460, 214),
  Offset(470, 190),
  Offset(468, 164),
  // And back down again.
  Offset(482, 142),
  Offset(504, 138),
  Offset(518, 158),
  Offset(516, 186),
  // Then round and all the way up, past the lot.
  Offset(526, 212),
  Offset(548, 222),
  Offset(570, 210),
  Offset(580, 180),
  Offset(578, 144),
  Offset(558, 106),
  Offset(524, 78),
  Offset(478, 60),
  Offset(424, 56),
  Offset(374, 68),
  Offset(348, 78),
];

/// The Illakkam 𑇨: 𑇤's humps, but instead of the line it sweeps back left to
/// where the first hump began, turns and comes round right again, cuts over
/// the sweep, and runs downhill from there to the end.
const synthesizedIllakkamAta = [
  // The humps, as 𑇤 has them.
  Offset(230, 150),
  Offset(232, 110),
  Offset(244, 72),
  Offset(268, 52),
  Offset(292, 60),
  Offset(302, 84),
  Offset(306, 108),
  Offset(318, 118),
  Offset(332, 106),
  Offset(346, 80),
  Offset(360, 70),
  Offset(376, 78),
  Offset(382, 100),
  Offset(386, 120),
  Offset(396, 128),
  Offset(404, 120),
  // Round and back leftward, under the lot.
  Offset(416, 116),
  Offset(424, 130),
  Offset(420, 152),
  Offset(402, 166),
  Offset(374, 174),
  Offset(338, 178),
  Offset(300, 174),
  Offset(268, 162),
  Offset(246, 144),
  // Turn and come round to the right again.
  Offset(236, 124),
  Offset(242, 106),
  Offset(260, 98),
  Offset(284, 102),
  // Over the sweep, and downhill to the end.
  Offset(304, 116),
  Offset(318, 140),
  Offset(326, 166),
  Offset(334, 192),
  Offset(338, 214),
];

/// The Illakkam 𑇧: 𑇤 with its two double backs left out — one arch, down to a
/// loop at the foot, and then a tail that drops and comes straight back up.
const synthesizedIllakkamHata = [
  // The arch.
  Offset(230, 200),
  Offset(240, 160),
  Offset(268, 138),
  Offset(300, 146),
  Offset(314, 180),
  // Down, and round a loop over the line it came down on.
  Offset(318, 214),
  Offset(316, 246),
  Offset(306, 266),
  Offset(286, 272),
  Offset(272, 258),
  Offset(278, 238),
  Offset(298, 232),
  Offset(320, 240),
  // The split tail: down, then straight back up.
  Offset(326, 262),
  Offset(328, 286),
  Offset(334, 262),
  Offset(336, 236),
];

/// A ෪ (Lith 4): the ෭ arch, whose leftward hook is carried on up past the top
/// of it without crossing anything, then a turn back the other way that loops
/// round, cuts over its own line, and leaves a tail pointing straight up.
///
/// This is the variant where the last run misses the one before it entirely,
/// so the only crossing is the one it makes with itself.
const synthesizedHathara = [
  // The arch.
  Offset(200, 260),
  Offset(200, 220),
  Offset(210, 190),
  Offset(235, 172),
  Offset(265, 175),
  Offset(282, 200),
  Offset(285, 232),
  // The hook, carried up to the top.
  Offset(300, 252),
  Offset(325, 258),
  Offset(345, 245),
  Offset(352, 220),
  Offset(350, 190),
  Offset(340, 165),
  Offset(322, 150),
  Offset(300, 142),
  // Back the other way, round over its own line, and up.
  Offset(284, 132),
  Offset(278, 114),
  Offset(288, 98),
  Offset(306, 94),
  Offset(320, 104),
  Offset(322, 122),
  Offset(312, 136),
  Offset(296, 140),
  Offset(286, 132),
  Offset(292, 118),
  Offset(296, 104),
];

/// A ෫ (Lith 5): a small hook bending right over the top, then the long
/// leftward sweep of the C, then a short turn back the other way, and a last
/// leftward curl that comes down beneath where it began. Its bending changes
/// hand three times over — R-L-R-L — where ෭ changes once.
const synthesizedPaha = [
  Offset(403, 95),
  Offset(440, 66),
  Offset(482, 68),
  Offset(506, 92),
  Offset(505, 118),
  Offset(480, 130),
  Offset(440, 128),
  Offset(408, 140),
  Offset(378, 168),
  Offset(360, 208),
  Offset(368, 248),
  Offset(400, 276),
  Offset(448, 292),
  Offset(500, 288),
  Offset(534, 270),
  Offset(556, 258),
  Offset(568, 272),
  Offset(566, 296),
  Offset(574, 320),
  Offset(592, 338),
];

/// The stroke ෯ carries above its ෨: bending right the whole way, never
/// dropping below the point it set off from, and finishing at the one place it
/// cuts back over itself, over on the right.
///
/// Not a ෬, though it is close: a ෬ sweeps either side of its start, and this
/// stays above it throughout.
const navayaTop = [
  Offset(200, 260),
  Offset(232, 226),
  Offset(272, 208),
  Offset(312, 216),
  Offset(332, 244),
  Offset(326, 258),
  Offset(306, 250),
  Offset(298, 232),
  Offset(310, 218),
  Offset(330, 222),
];

/// The backwards C that turns [synthesizedDeka] into a ෩: from its top tip,
/// bending right the whole way round to a bottom tip below where it started,
/// leaving both ends in the left half of its own bounding box.
///
/// Placed clear of [synthesizedDeka]'s right-hand edge at x=320, so the sketch
/// sorts it as a mark beside the digit rather than as the digit itself.
const reversedC = [
  Offset(360, 190),
  Offset(382, 194),
  Offset(396, 210),
  Offset(396, 230),
  Offset(382, 246),
  Offset(360, 250),
];

/// A ෭ (Lith 7): the [synthesizedU] arch and hook, stopped before the hook can
/// cut back over the descent — an open hooked curve with no closed loop.
const synthesizedHata = [
  Offset(250, 190),
  Offset(250, 155),
  Offset(252, 132),
  Offset(263, 113),
  Offset(285, 104),
  Offset(307, 112),
  Offset(318, 133),
  Offset(322, 168),
  Offset(322, 205),
  Offset(332, 232),
  Offset(352, 250),
  Offset(374, 258),
];

void main() {
  // Screen y points down, and the angle convention is the shorthand project's:
  // left is positive. Going right and then turning up the page is a
  // counter-clockwise — left — turn.
  group('Lith numerals', () {
    /// Draws [path], then any [marks] beside it, with the canvas set to
    /// recognize Lith digits.
    SinhalaLetterLayer drawDigit(
      List<Offset> path, {
      List<List<Offset>> marks = const [],
    }) {
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.lithNumerals;
      drag(layer, path);
      for (final mark in marks) {
        drag(layer, mark);
      }
      return layer;
    }

    test('෦ binduva — bottom up, bending left then right past a crossing', () {
      final layer = drawDigit(synthesizedBinduva);
      // ignore: avoid_print
      print('෦ → ${layer.letterShape}\n   runs ${layer.letterShape!.turnRuns}');
      expect(layer.recognizedText, '෦');
    });

    test('෦ binduva — the same shape carried on to cross a second time', () {
      // The tail is taken further round, back over the stem it came up on. A
      // second crossing is how far the pen was carried, not a different digit.
      final layer = drawDigit(const [
        ...synthesizedBinduva,
        Offset(350, 316),
        Offset(328, 318),
        Offset(306, 310),
        Offset(298, 298),
        Offset(304, 280),
        Offset(322, 272),
        Offset(344, 278),
      ]);
      // ignore: avoid_print
      print('෦ twice → ${layer.letterShape}');
      expect(layer.letterShape!.crossings, hasLength(2));
      expect(layer.recognizedText, '෦');
    });

    /// [navayaTop] lifted clear above [synthesizedDeka], which tops out at 184.
    List<Offset> topAbove() =>
        navayaTop.map((p) => p - const Offset(0, 120)).toList();

    test('෯ navaya — a ෨ with the upper stroke stacked over it', () {
      final layer = drawDigit(synthesizedDeka, marks: [topAbove()]);
      expect(layer.recognizedText, '෯');
    });

    test('෯ does not depend on which half is drawn first', () {
      final layer = drawDigit(topAbove(), marks: const [synthesizedDeka]);
      expect(layer.recognizedText, '෯');
    });

    test('෯ is not read when the two sit side by side', () {
      // Stacking is the whole of what makes it ෯; alongside, it is neither.
      final layer = drawDigit(
        synthesizedDeka,
        marks: [navayaTop.map((p) => p + const Offset(400, 0)).toList()],
      );
      expect(layer.recognizedText, isNot('෯'));
    });

    test('෯ is not read when the halves are the wrong way up', () {
      final layer = drawDigit(
        navayaTop,
        marks: [synthesizedDeka.map((p) => p - const Offset(0, 200)).toList()],
      );
      expect(layer.recognizedText, isNot('෯'));
    });

    test('෯ does not take a ෬ as its upper stroke', () {
      // A ෬ sweeps either side of where it set off; ෯'s upper stroke stays
      // above its start throughout, which is what parts the two shapes.
      final layer = drawDigit(
        synthesizedDeka,
        marks: [synthesizedHaya.map((p) => p - const Offset(0, 200)).toList()],
      );
      expect(layer.recognizedText, isNot('෯'));
    });

    test('෬ haya — a wide sweep with a small curl on the right', () {
      final layer = drawDigit(synthesizedHaya);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('෬ → $shape\n'
          '   whole ${shape.bounds}\n'
          '   closed loop ${shape.closedLoop!.bounds}');
      expect(layer.recognizedText, '෬');
    });

    test('෬ is not read when the loop is the whole shape', () {
      // ෧'s coil is the glyph rather than a curl on the end of one, so it is
      // not tiny next to the stroke — that is what parts them.
      expect(drawDigit(synthesizedEka).recognizedText, '෧');
    });

    test('෬ stays a ෬ when the sweep is wide and shallow', () {
      // The curl then stands taller than half the whole stroke, though it is
      // plainly small against it. Comparing heights axis by axis called that
      // curl large and dropped the digit through to ෧.
      final layer = drawDigit(const [
        Offset(200, 150),
        Offset(250, 124),
        Offset(310, 112),
        Offset(360, 120),
        Offset(392, 136),
        Offset(400, 162),
        Offset(384, 180),
        Offset(360, 176),
        Offset(352, 154),
        Offset(366, 138),
        Offset(400, 142),
      ]);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('wide ෬ → whole ${shape.bounds}\n'
          '   closed loop ${shape.closedLoop!.bounds}\n'
          '   crossing at ${shape.crossingPosition!.toStringAsFixed(2)}');
      expect(shape.closedLoop!.bounds.height,
          greaterThan(shape.bounds.height * 0.5));
      expect(layer.recognizedText, '෬');
    });

    test('෬ is not read when the curl is on the left', () {
      // Mirrored about the vertical, which puts the curl on the left and
      // reverses every bend, so it is no digit at all.
      expect(
        drawDigit(synthesizedHaya
            .map((p) => Offset(568 - p.dx, p.dy))
            .toList()),
        isNot('෬'),
      );
    });

    test('෧ eka — over its own line, then away below and right of it', () {
      final layer = drawDigit(synthesizedEka);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('෧ → $shape\n'
          '   loop ${shape.loopToCrossing}\n'
          '   tail ${shape.tailFromCrossing}');
      expect(layer.recognizedText, '෧');
    });

    test('෧ does not need a full turn before it crosses', () {
      // A long, thin loop: the pen goes back over its own line having turned
      // only about 250°, then drops away below and right of the crossing. How
      // much of a circle it drew getting there is not part of the letter — a
      // rule that asked for a full turn rejected drawings that were good ෧.
      final layer = drawDigit(const [
        Offset(200, 200),
        Offset(300, 230),
        Offset(370, 250),
        Offset(400, 268),
        Offset(404, 292),
        Offset(382, 306),
        Offset(344, 310),
        Offset(296, 300),
        Offset(250, 282),
        Offset(216, 256),
        Offset(200, 226),
        Offset(204, 200),
        Offset(214, 182),
        Offset(240, 174),
        Offset(266, 182),
        Offset(280, 204),
        Offset(280, 216),
      ]);
      final loop = layer.letterShape!.loopToCrossing!;
      // ignore: avoid_print
      print('shallow ෧ → loop $loop');
      expect(layer.recognizedText, '෧');
      expect(loop.totalTurn, lessThan(300), reason: 'not a full turn');
    });

    test('෨ deka — a second coil beside the first', () {
      final layer = drawDigit(synthesizedDeka);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('෨ → $shape\n'
          '   crossings at ${shape.crossings.map((c) => c.point).toList()}');
      expect(shape.crossings, hasLength(2));
      expect(layer.recognizedText, '෨');
    });

    test('෨ allows the second part to bend left as well', () {
      // Carried on into a leftward curl past the second coil. Only the first
      // coil has to bend right throughout; a second hump beside it has a
      // valley between, and a valley is a left turn.
      final layer = drawDigit(const [
        ...synthesizedDeka,
        Offset(334, 232),
        Offset(348, 230),
        Offset(358, 220),
        Offset(362, 206),
      ]);
      // ignore: avoid_print
      print('෨ with a leftward second part → ${layer.letterShape}');
      expect(layer.letterShape!.leftTotal, greaterThan(60));
      expect(layer.recognizedText, '෨');
    });

    test('෩ thuna — ෨ with a backwards C beside it', () {
      final layer = drawDigit(synthesizedDeka, marks: const [reversedC]);
      // ignore: avoid_print
      print('෩ → body ${layer.letterShape}');
      expect(layer.recognizedText, '෩');
    });

    test('෩ is ෨ again once the C is left off', () {
      expect(drawDigit(synthesizedDeka).recognizedText, '෨');
    });

    test('෩ is not read when the C faces the other way', () {
      // A proper C, opening rightward: it bends left, and its ends are in the
      // right half of its own box. Neither is what ෩ asks for.
      expect(
        drawDigit(synthesizedDeka,
            marks: [reversedC.map((p) => Offset(756 - p.dx, p.dy)).toList()]),
        isNot('෩'),
      );
    });

    test('෩ is not read when the mark does not finish below its start', () {
      // The same curve stopped at the far side, before it comes back down.
      expect(
        drawDigit(synthesizedDeka, marks: [reversedC.sublist(0, 3)])
            .recognizedText,
        '෨',
      );
    });

    test('෨ is not read with only the one coil', () {
      // Stopping after the first coil is a ෧, not a half-written ෨.
      expect(drawDigit(synthesizedEka).recognizedText, '෧');
    });

    test('෪ hathara — arch, hook to the top, then back over itself', () {
      final layer = drawDigit(synthesizedHathara);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('෪ → $shape\n'
          '   runs ${shape.turnRuns.length}, '
          'ends heading ${shape.endDirection}');
      expect(layer.recognizedText, '෪');
    });

    test('෪ takes a tail flicked up on the diagonal', () {
      // Up and away at about 45°, which is pointing up by any reading —
      // requiring the rise to beat the sideways run turned these away.
      final layer = drawDigit([
        ...synthesizedHathara.sublist(0, 24),
        const Offset(300, 118),
        const Offset(314, 104),
      ]);
      final direction = layer.letterShape!.endDirection;
      expect(direction.dy.abs(), lessThan(direction.dx.abs() * 1.1),
          reason: 'the tail really is near the diagonal');
      expect(layer.recognizedText, '෪');
    });

    test('෪ takes a tail that clips the loop on its way out', () {
      // A longer flick that cuts across the loop it just closed, making two
      // crossings rather than one. How many the tail catches on the way out is
      // not the letter.
      final layer = drawDigit([
        ...synthesizedHathara.sublist(0, 24),
        const Offset(300, 116),
        const Offset(320, 96),
        const Offset(342, 74),
      ]);
      expect(layer.letterShape!.crossings, hasLength(2));
      expect(layer.recognizedText, '෪');
    });

    test('෪ is not read when the tail does not point up', () {
      // The same stroke, its last stretch running off to the right instead of
      // rising. Everything else about it is unchanged.
      final layer = drawDigit([
        ...synthesizedHathara.sublist(0, 24),
        const Offset(290, 124),
        const Offset(300, 120),
        const Offset(312, 122),
      ]);
      expect(layer.letterShape!.crossings, hasLength(1));
      expect(layer.unmetConditions['෪'], ['ends pointing upwards']);
      expect(layer.recognizedText, isNot('෪'));
    });

    test('෪ is not read when the bending never turns back', () {
      // ෭ is the same opening — an arch and a hook — and stops there.
      final layer = drawDigit(synthesizedHata);
      expect(layer.letterShape!.turnRuns, hasLength(2));
      expect(layer.recognizedText, '෭');
    });

    test('෫ paha — right, left, and round again beneath itself', () {
      final layer = drawDigit(synthesizedPaha);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('෫ → $shape\n'
          '   runs ${shape.turnRuns.length}, '
          'last turn begins at ${shape.turnRuns.last.shape.start}, '
          'ends at ${shape.end}');
      expect(shape.turnRuns, hasLength(greaterThanOrEqualTo(3)));
      expect(layer.recognizedText, '෫');
    });

    test('෭ is not read as ෫, its bending changing hand only once', () {
      final layer = drawDigit(synthesizedHata);
      expect(layer.letterShape!.turnRuns, hasLength(2));
      expect(layer.recognizedText, '෭');
    });

    test('෫ is not read when the last turn never comes back down', () {
      // Stopped partway through that turn, before it drops beneath where it
      // began.
      expect(
        drawDigit(synthesizedPaha.sublist(0, 18)).recognizedText,
        isNot('෫'),
      );
    });

    test('෭ hata — the උ shape left open', () {
      final layer = drawDigit(synthesizedHata);
      // ignore: avoid_print
      print('෭ → ${layer.letterShape}\n   runs ${layer.letterShape!.turnRuns}');
      expect(layer.recognizedText, '෭');
    });

    test('෮ ata — the ර shape exactly', () {
      expect(drawDigit(synthesizedRa).recognizedText, '෮');
    });

    test('෭ is not read when the hook does cut back over the arch', () {
      // The උ shape closed. Its bending changes hand once, where ෫ changes
      // more than once, so as a digit it is nothing.
      expect(drawDigit(synthesizedU).recognizedText, isNull);
    });

    test('a digit is not read while the canvas is set to letters', () {
      expect(recognize(synthesizedBinduva), isNull);
    });

    test('no vowel modifier is read on a numeral', () {
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.lithNumerals;
      drag(layer, synthesizedRa);
      tap(layer, anusvaraDot);
      expect(layer.recognizedText, '෮');
      expect(layer.recognizedModifier, isNull);
    });

    test('switching system re-reads what is already drawn', () {
      final layer = SinhalaLetterLayer();
      drag(layer, synthesizedRa);
      expect(layer.recognizedText, 'ර');

      layer.system = RecognitionSystem.lithNumerals;
      expect(layer.recognizedText, '෮');

      layer.system = RecognitionSystem.letters;
      expect(layer.recognizedText, 'ර');
    });

    test('Illakkam has rules of its own, and ර is none of them', () {
      expect(RecognitionSystem.illakkamNumerals.recognizedGlyphs, isNotEmpty);
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.illakkamNumerals;
      drag(layer, synthesizedRa);
      expect(layer.recognizedText, isNull);
    });
  });

  group('Illakkam numerals', () {
    /// Draws [path], then any [marks] beside it, set to recognize Illakkam.
    SinhalaLetterLayer drawIllakkam(
      List<Offset> path, {
      List<List<Offset>> marks = const [],
    }) {
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.illakkamNumerals;
      drag(layer, path);
      for (final mark in marks) {
        drag(layer, mark);
      }
      return layer;
    }

    test('𑇡 eka — the coil, then a line drawn up above where it began', () {
      final layer = drawIllakkam(synthesizedIllakkamEka);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('𑇡 → $shape\n   runs ${shape.turnRuns}');
      expect(shape.turnRuns, hasLength(2));
      expect(layer.recognizedText, '𑇡');
    });

    test('𑇢 deka — the same bend, without the climb', () {
      final layer = drawIllakkam(synthesizedIllakkamDeka);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('𑇢 → $shape\n   runs ${shape.turnRuns}');
      expect(shape.turnRuns, hasLength(2));
      expect(layer.recognizedText, '𑇢');
    });

    test('𑇣 tuna — the bending changing hand three times over', () {
      final layer = drawIllakkam(synthesizedIllakkamTuna);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('𑇣 → $shape\n   runs ${shape.turnRuns}');
      expect(shape.turnRuns, hasLength(greaterThan(2)));
      expect(layer.recognizedText, '𑇣');
    });

    test('𑇤 hathara — humps, then a last run down to a loop at the foot', () {
      final layer = drawIllakkam(synthesizedIllakkamHathara);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('𑇤 → $shape\n'
          '   runs ${shape.turnRuns}\n'
          '   humps ${shape.verticalRuns.length}');
      expect(shape.turnRuns, hasLength(5));
      expect(layer.recognizedText, '𑇤');
    });

    test('𑇤 is not read when the last run never reaches the foot', () {
      // Stopped before the drop, so the humps are the lowest of it.
      expect(
        drawIllakkam(synthesizedIllakkamHathara.sublist(0, 17)).recognizedText,
        isNot('𑇤'),
      );
    });

    test('𑇩 navaya — 𑇡 by way of a loop, so one crossing more', () {
      final layer = drawIllakkam(synthesizedIllakkamNavaya);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('𑇩 → $shape\n   runs ${shape.turnRuns}');
      expect(layer.recognizedText, '𑇩');
    });


    test('𑇩 and 𑇡 are parted by the loop, not by the line', () {
      final eka = drawIllakkam(synthesizedIllakkamEka).letterShape!;
      final navaya = drawIllakkam(synthesizedIllakkamNavaya).letterShape!;
      // ignore: avoid_print
      print('𑇡 humps ${eka.verticalRuns.length}, '
          'last ${eka.verticalRuns.last}, '
          'clean ${eka.verticalRuns.last.shape.crossings.isEmpty}\n'
          '𑇩 humps ${navaya.verticalRuns.length}, '
          'last ${navaya.verticalRuns.last}, '
          'clean ${navaya.verticalRuns.last.shape.crossings.isEmpty}');

      // Both end in a vertical line and both bend right then left.
      expect(eka.endsVertically, isTrue);
      expect(navaya.endsVertically, isTrue);
      expect(navaya.crossings.length, greaterThan(eka.crossings.length));

      expect(drawIllakkam(synthesizedIllakkamEka).recognizedText, '𑇡');
      expect(drawIllakkam(synthesizedIllakkamNavaya).recognizedText, '𑇩');
    });

    test('𑇦 haya — up, back down twice, then round and up past the lot', () {
      final layer = drawIllakkam(synthesizedIllakkamHaya);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('𑇦 → $shape\n'
          '   runs ${shape.turnRuns}\n'
          '   humps ${shape.verticalRuns.length}');
      expect(layer.recognizedText, '𑇦');
    });

    test('𑇨 ata — round back left, over the sweep, then downhill', () {
      final layer = drawIllakkam(synthesizedIllakkamAta);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('𑇨 → $shape\n'
          '   runs ${shape.turnRuns}\n'
          '   humps ${shape.verticalRuns.length}');
      expect(layer.recognizedText, '𑇨');
    });

    test('𑇨 is not read when the tail climbs away instead', () {
      // The same stroke, its tail turned uphill past the crossing.
      expect(
        drawIllakkam([
          ...synthesizedIllakkamAta.sublist(0, 31),
          const Offset(326, 120),
          const Offset(334, 96),
        ]).recognizedText,
        isNot('𑇨'),
      );
    });

    test('𑇧 hata — 𑇤 without the double backs, tail dropping and rising', () {
      final layer = drawIllakkam(synthesizedIllakkamHata);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('𑇧 → $shape\n'
          '   runs ${shape.turnRuns}\n'
          '   tail past the crossing ${shape.tailFromCrossing?.verticalRuns}');
      expect(layer.recognizedText, '𑇧');
    });

    test('𑇧 is not read when the tail only drops', () {
      // Cut before it comes back up, so the tail is one stretch, not two.
      expect(
        drawIllakkam(synthesizedIllakkamHata.sublist(0, 15)).recognizedText,
        isNot('𑇧'),
      );
    });

    test('𑇥 paha — 𑇣 with one more double back', () {
      final layer = drawIllakkam(synthesizedIllakkamPaha);
      final shape = layer.letterShape!;
      // ignore: avoid_print
      print('𑇥 → $shape\n   runs ${shape.turnRuns}');
      expect(layer.recognizedText, '𑇥');
    });

    test('the extra double back tells in the humps', () {
      final tuna = drawIllakkam(synthesizedIllakkamTuna).letterShape!;
      final paha = drawIllakkam(synthesizedIllakkamPaha).letterShape!;
      // ignore: avoid_print
      print('𑇣 humps ${tuna.verticalRuns}\n'
          '𑇥 humps ${paha.verticalRuns}');

      expect(paha.verticalRuns.length, greaterThan(tuna.verticalRuns.length));
    });

    test('𑇥 and 𑇣 are parted by the one extra double back', () {
      expect(drawIllakkam(synthesizedIllakkamTuna).recognizedText, '𑇣');
      expect(drawIllakkam(synthesizedIllakkamPaha).recognizedText, '𑇥');
    });

    test('𑇡 and 𑇢 are parted only by whether the end climbs', () {
      expect(drawIllakkam(synthesizedIllakkamEka).recognizedText, '𑇡');
      expect(drawIllakkam(synthesizedIllakkamDeka).recognizedText, '𑇢');
    });

    test('the bare ෧ coil is none of them, having no bend the other way', () {
      expect(drawIllakkam(synthesizedEka).recognizedText, isNull);
    });
  });

  group('why a drawing was not recognized', () {
    test('names the condition the drawing fell down on', () {
      // ෧'s circle with its tail cut short: it gets to the right of the
      // crossing but stops level with it instead of dropping below. Stopping
      // any earlier would be a perfectly good ෮, the tail still climbing.
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.lithNumerals;
      drag(layer, synthesizedEka.sublist(0, 15));

      expect(layer.recognizedText, isNull);
      expect(layer.unmetConditions['෧'],
          ['ends below and right of the crossing']);
      // ෬ is tied with it on the share of conditions met, but has two of them
      // outstanding rather than one, so ෧ is the more useful thing to name.
      expect(layer.nearestMiss?.$1, '෧');
      expect(layer.nearestMiss?.$2, ['ends below and right of the crossing']);
    });

    test('the same circle stopped while still climbing is a ෮', () {
      // ෧ and ෮ are one shape parted only by which way the tail leaves the
      // crossing, so where the pen stops decides which digit it is.
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.lithNumerals;
      drag(layer, synthesizedEka.sublist(0, 13));
      expect(layer.recognizedText, '෮');
    });

    test('a digit drawn while set to letters says where it does match', () {
      // The picker being on the wrong system fails a drawing for a reason that
      // has nothing to do with how it was drawn, so the canvas says so rather
      // than listing conditions that were never the problem.
      final layer = SinhalaLetterLayer();
      drag(layer, synthesizedEka);

      expect(layer.recognizedText, isNull);
      expect(layer.matchInAnotherSystem?.$1, '෧');
      expect(layer.matchInAnotherSystem?.$2, RecognitionSystem.lithNumerals);
    });

    test('there is nowhere else to point once something matches', () {
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.lithNumerals;
      drag(layer, synthesizedEka);
      expect(layer.matchInAnotherSystem, isNull);
    });

    test('a drawing that is no glyph anywhere points nowhere', () {
      final layer = SinhalaLetterLayer();
      drag(layer, const [Offset(200, 200), Offset(320, 200)]);
      expect(layer.matchInAnotherSystem, isNull);
    });

    test('a more specific glyph that all but matched is still reported', () {
      // ෯'s upper stroke dips below the point it set off from. Everything else
      // about the drawing is right, and it reads as some other digit — but ෯
      // is what was being drawn, and saying nothing leaves no way to see which
      // condition to look at.
      final dipping = [
        for (final p in navayaTop)
          (p == const Offset(326, 258) ? const Offset(326, 272) : p) -
              const Offset(0, 120),
      ];

      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.lithNumerals;
      drag(layer, synthesizedDeka);
      drag(layer, dipping);

      expect(layer.recognizedText, isNot('෯'));
      expect(layer.narrowlyMissed?.$1, '෯');
      expect(layer.narrowlyMissed?.$2,
          ['the upper one never drops below its start']);
    });

    test('nothing is reported when the match was outright', () {
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.lithNumerals;
      drag(layer, synthesizedDeka);
      drag(layer, navayaTop.map((p) => p - const Offset(0, 120)).toList());

      expect(layer.recognizedText, '෯');
      expect(layer.narrowlyMissed, isNull);
    });

    test('a glyph nowhere near the one that matched is not reported', () {
      // ෮ matches outright; no other digit is within two conditions of it.
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.lithNumerals;
      drag(layer, synthesizedRa);

      expect(layer.recognizedText, '෮');
      expect(layer.narrowlyMissed, isNull);
    });

    test('there is no near miss once something matches', () {
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.lithNumerals;
      drag(layer, synthesizedEka);
      expect(layer.recognizedText, '෧');
      expect(layer.nearestMiss, isNull);
    });

    test('every rule reports what it wanted, not just the closest', () {
      // A short straight line, which is no digit at all.
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.lithNumerals;
      drag(layer, const [Offset(200, 200), Offset(320, 200)]);

      expect(
        layer.unmetConditions['෧'],
        containsAll(<String>[
          'bends only right',
          'crosses itself once',
          'ends below and right of the crossing',
        ]),
      );
      expect(layer.unmetConditions['෮'], ['loops right then climbs']);
    });

    test('closest goes by proportion met, not by count', () {
      // A straight line meets 1 of ෭'s 2 conditions and none of ෧'s 3.
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.lithNumerals;
      drag(layer, const [Offset(200, 200), Offset(320, 200)]);
      expect(layer.nearestMiss?.$1, '෭');
    });
  });

  group('what is implemented', () {
    test('every rule contributes its glyph to the reference tables', () {
      expect(recognizedGlyphs, containsAll(<String>['ට', 'ර', 'ඊ', 'උ', 'ං']));
      expect(recognizedGlyphs, containsAll(<String>['෦', '෧', '෭', '෮']));
    });

    test('modifiers are counted under letters, not numerals', () {
      expect(RecognitionSystem.letters.recognizedGlyphs, contains('ං'));
      expect(RecognitionSystem.lithNumerals.recognizedGlyphs, isNot(contains('ං')));
    });
  });

  group('turn runs', () {
    test('an arch then a hook is cut into two pieces', () {
      final runs = draw(synthesizedU).letterShape!.turnRuns;
      expect(runs, hasLength(2));
      expect(runs.first.isRight, isTrue);
      expect(runs.last.isLeft, isTrue);
    });

    test('a stroke that only bends one way is a single run', () {
      expect(draw(drawnRetroflexTa).letterShape!.turnRuns, hasLength(1));
    });

    test('the pieces together cover the whole stroke', () {
      final shape = draw(synthesizedU).letterShape!;
      final runs = shape.turnRuns;
      expect(runs.first.shape.start, shape.start);
      expect(runs.last.shape.end, shape.end);
      for (var i = 1; i < runs.length; i++) {
        expect(runs[i].shape.start, runs[i - 1].shape.end);
      }
    });
  });

  group('dots', () {
    test('a tap is kept as a dot, not discarded', () {
      final layer = SinhalaLetterLayer();
      tap(layer, const Offset(120, 120));
      expect(layer.dots, const [Offset(120, 120)]);
    });

    test('a drag is a path, not a dot', () {
      expect(draw(synthesizedRa).dots, isEmpty);
    });

    test('a closed loop is a path even though it ends where it began', () {
      // Judged by path length, not start-to-end distance — measuring end to
      // end would file this whole circle away as a stray tap.
      final layer = SinhalaLetterLayer();
      drag(layer, const [
        Offset(300, 200),
        Offset(360, 260),
        Offset(300, 320),
        Offset(240, 260),
        Offset(300, 200),
      ]);
      expect(layer.dots, isEmpty);
      expect(layer.letterShape, isNotNull);
    });

    test('clearing removes dots as well as strokes', () {
      final layer = draw(synthesizedRa, dots: const [Offset(193, 198)]);
      layer.clear();
      expect(layer.dots, isEmpty);
      expect(layer.recognizedLetter, isNull);
    });
  });

  // cord's own: the page offers the two numeral systems and no letters, so a
  // drawing that matches nothing is only ever pointed at a numeral system.
  group('only the numerals are pointed at', () {
    test('the two systems are what the page and the search index list', () {
      expect(numeralSystems, [
        RecognitionSystem.lithNumerals,
        RecognitionSystem.illakkamNumerals,
      ]);
    });

    test('a shape shared with a letter names the digit, not the letter', () {
      // ෮ is drawn exactly as ර is. Upstream looks through every system in
      // turn and would answer "ර, under Letters" here — a letter, under a
      // system this page cannot be put on.
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.illakkamNumerals;
      drag(layer, synthesizedRa);

      expect(layer.recognizedText, isNull);
      expect(layer.matchInAnotherSystem?.$1, '෮');
      expect(layer.matchInAnotherSystem?.$2, RecognitionSystem.lithNumerals);
    });

    test('a letter that is no numeral at all points nowhere', () {
      // ට has a rule, but only among the letters, so there is nothing here to
      // send anyone to.
      final layer = SinhalaLetterLayer()
        ..system = RecognitionSystem.lithNumerals;
      drag(layer, drawnRetroflexTa);

      expect(layer.recognizedText, isNull);
      expect(layer.matchInAnotherSystem, isNull);
    });
  });
}
