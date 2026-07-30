import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cord/makasar/data/script.dart';
import 'package:cord/makasar/scenes/makasar_scene.dart';

/// Feeds [points] to [layer] as one finished stroke, the same way
/// [GameCanvas] feeds real pointer input.
void _draw(MakasarLayer layer, List<Offset> points) {
  layer.handlePointerEvent(PointerDownEvent(position: points.first), Size.zero);
  for (final point in points.skip(1)) {
    layer.handlePointerEvent(PointerMoveEvent(position: point), Size.zero);
  }
  layer.handlePointerEvent(PointerUpEvent(position: points.last), Size.zero);
}

/// Taps [layer] at [at] — a press and release with no movement.
void _tap(MakasarLayer layer, Offset at) {
  layer.handlePointerEvent(PointerDownEvent(position: at), Size.zero);
  layer.handlePointerEvent(PointerUpEvent(position: at), Size.zero);
}

/// Samples the straight line from [from] to [to], the way a hand-drawn
/// stroke arrives: a run of close-together points rather than two ends.
List<Offset> _line(Offset from, Offset to, {int steps = 8}) => [
      for (var i = 0; i <= steps; i++) Offset.lerp(from, to, i / steps)!,
    ];

/// `Λ` — up from the bottom left to the apex, then down to the bottom
/// right.
List<Offset> _wedge(double left, double top, {double size = 40}) {
  final apex = Offset(left + size / 2, top);
  return [
    ..._line(Offset(left, top + size), apex),
    ..._line(apex, Offset(left + size, top + size)).skip(1),
  ];
}

/// 𑻪's double wedge: up, down, back up across the first arm — which is
/// the one self-crossing — then down again. Also 𑻠's first stroke.
const _jaCorners = [
  Offset(20, 40),
  Offset(30, 0),
  Offset(40, 30),
  Offset(10, 0),
  Offset(18, 35),
];

/// 𑻲's stroke: a tall rise, then a small hook back up off the bottom of
/// it. Also 𑻭's first stroke.
const _angkaCorners = [
  Offset(20, 80),
  Offset(30, 0),
  Offset(40, 25),
  Offset(50, 5),
];

/// 𑻫's triple wedge, crossing itself twice. Also 𑻬's first stroke.
const _nyaCorners = [
  Offset(20, 40),
  Offset(30, 0),
  Offset(40, 30),
  Offset(10, 0),
  Offset(18, 30),
  Offset(5, 0),
  Offset(19, 25),
];

/// 𑻰's stroke: left, right, then a long drop away to the left — that last
/// run taller than it is wide is what makes it 𑻰.
const _saCorners = [
  Offset(60, 10),
  Offset(30, 20),
  Offset(75, 30),
  Offset(55, 90),
];

/// 𑻠's wedges stroke: out to the right over a peak and up again, then back
/// left over one more.
const _kaCorners = [
  Offset(0, 60),
  Offset(20, 10),
  Offset(40, 70),
  Offset(60, 20),
  Offset(45, 5),
  Offset(25, 60),
];

/// A stroke through [corners] in order.
List<Offset> _polyline(List<Offset> corners) => [
      for (var i = 1; i < corners.length; i++)
        ..._line(corners[i - 1], corners[i]).skip(i == 1 ? 0 : 1),
    ];

/// `ΛΛ` — two wedges without lifting the pen.
List<Offset> _doubleWedge(double left, double top, {double size = 40}) => [
      ..._wedge(left, top, size: size),
      ..._wedge(left + size, top, size: size).skip(1),
    ];

/// A closed triangle drawn in one stroke: up, down, then back along the
/// base, closing just above and past where it started so the stroke runs
/// over its own left arm.
List<Offset> _closedWedge(double left, double top, {double size = 30}) {
  final apex = Offset(left + size / 2, top);
  final bottomRight = Offset(left + size, top + size);
  return [
    ..._line(Offset(left, top + size), apex),
    ..._line(apex, bottomRight).skip(1),
    ..._line(bottomRight, Offset(left - 4, top + size - 5)).skip(1),
  ];
}

/// `V` — down to the point and back up, wider than it is tall.
List<Offset> _chevron(double centerX, double top,
    {double width = 40, double height = 20}) {
  final point = Offset(centerX, top + height);
  return [
    ..._line(Offset(centerX - width / 2, top), point),
    ..._line(point, Offset(centerX + width / 2, top)).skip(1),
  ];
}

/// The straight line from [from] to [to], wavering [waver] to either side
/// of it as it goes — a hand drawing a long stroke rather than a ruler.
List<Offset> _wobblyLine(Offset from, Offset to, double waver,
        {int steps = 20}) =>
    [
      for (var i = 0; i <= steps; i++)
        Offset.lerp(from, to, i / steps)!
            .translate(0, i.isEven ? waver : -waver),
    ];

/// ᨀ's element: one line climbing to the right, its x range starting at
/// [left].
List<Offset> _ascendingLine(double left, {double size = 30}) =>
    _line(Offset(left, size), Offset(left + size, 0));

/// `U` — the same down-and-back-up stroke as [_chevron], but taller than
/// it is wide.
List<Offset> _bowl(double centerX, double top,
        {double width = 16, double height = 40}) =>
    _chevron(centerX, top, width: width, height: height);

void main() {
  group('MakasarLayer', () {
    test('a lone wedge is na', () {
      final layer = MakasarLayer();
      _draw(layer, _wedge(0, 0));
      expect(layer.recognizedName, 'na');
    });

    test('a double wedge + a wedge below is ga', () {
      final layer = MakasarLayer();
      _draw(layer, _doubleWedge(0, 0));
      _draw(layer, _wedge(30, 60, size: 30));
      expect(layer.recognizedName, 'ga');
    });

    test('a double wedge + a closed mark below is ma, not ga', () {
      final layer = MakasarLayer();
      _draw(layer, _doubleWedge(0, 0));
      _draw(layer, _closedWedge(30, 60));
      expect(layer.recognizedName, 'ma');
    });

    test('a wedge + a bowl hanging off its arm is nga', () {
      final layer = MakasarLayer();
      _draw(layer, _wedge(0, 0));
      _draw(layer, _bowl(35, 30));
      expect(layer.recognizedName, 'nga');
    });

    test('a wedge whose arm hooks back up across itself is ta', () {
      final layer = MakasarLayer();
      _draw(
        layer,
        _polyline(const [
          Offset(20, 40),
          Offset(30, 0),
          Offset(40, 30),
          Offset(10, 0),
        ]),
      );
      expect(layer.recognizedName, 'ta');
    });

    test('a right-then-left sweep + a line below is ka', () {
      final layer = MakasarLayer();
      _draw(layer, _polyline(_kaCorners));
      _draw(layer, _polyline(const [Offset(10, 110), Offset(50, 85)]));
      expect(layer.recognizedName, 'ka');
    });

    test('ka’s line can be drawn from either end', () {
      final layer = MakasarLayer();
      _draw(layer, _polyline(_kaCorners));
      // The same line as above, drawn the other way round.
      _draw(layer, _polyline(const [Offset(50, 85), Offset(10, 110)]));
      expect(layer.recognizedName, 'ka');
    });

    test('a double wedge whose last descent stays high is pa', () {
      final layer = MakasarLayer();
      _draw(
        layer,
        _polyline(const [
          Offset(0, 80),
          Offset(20, 10),
          Offset(30, 70),
          Offset(40, 5),
          Offset(45, 25),
        ]),
      );
      expect(layer.recognizedName, 'pa');
    });

    test('two left-right pieces standing on a base is da', () {
      final layer = MakasarLayer();
      _draw(
        layer,
        _polyline(const [
          // First piece: back to the left, then out to the right.
          Offset(40, 10),
          Offset(15, 30),
          Offset(45, 55),
          // Down into the bottom third and along the base.
          Offset(50, 80),
          Offset(95, 80),
          // Second piece, doubling back the same way.
          Offset(65, 30),
          Offset(100, 55),
        ]),
      );
      expect(layer.recognizedName, 'da');
    });

    test('pa and da differ by how often the bottom third is entered', () {
      // Both strokes go up-down-up-down; pa dips through the line marking
      // off the bottom third three times, da twice.
      final pa = MakasarLayer();
      _draw(
        pa,
        _polyline(const [
          Offset(0, 80),
          Offset(20, 10),
          Offset(30, 70),
          Offset(40, 5),
          Offset(45, 25),
        ]),
      );
      expect(pa.recognizedName, 'pa');

      final da = MakasarLayer();
      _draw(
        da,
        _polyline(const [
          Offset(40, 10),
          Offset(15, 30),
          Offset(45, 55),
          Offset(50, 80),
          Offset(95, 80),
          Offset(65, 30),
          Offset(100, 55),
        ]),
      );
      expect(da.recognizedName, 'da');
    });

    test('the same shape with both pieces running only rightward is wa', () {
      final layer = MakasarLayer();
      _draw(
        layer,
        _polyline(const [
          Offset(10, 10),
          Offset(30, 55),
          Offset(40, 85),
          Offset(90, 85),
          Offset(120, 25),
        ]),
      );
      expect(layer.recognizedName, 'wa');
    });

    test('a plain double wedge has no base, so it is not da', () {
      final layer = MakasarLayer();
      _draw(layer, _doubleWedge(0, 0));
      expect(layer.recognizedName, isNull);
    });

    test('a double wedge + a chevron below is ba', () {
      final layer = MakasarLayer();
      _draw(layer, _doubleWedge(0, 0));
      _draw(layer, _chevron(40, 60));
      expect(layer.recognizedName, 'ba');
    });

    test('a narrow chevron below a double wedge is still ba', () {
      final layer = MakasarLayer();
      _draw(layer, _doubleWedge(0, 0));
      _draw(layer, _bowl(40, 60));
      expect(layer.recognizedName, 'ba');
    });

    test('a double wedge crossing itself once is ja', () {
      final layer = MakasarLayer();
      _draw(layer, _polyline(_jaCorners));
      expect(layer.recognizedName, 'ja');
    });

    test('a wedge with a loop over each arm is ca', () {
      final layer = MakasarLayer();
      _draw(
        layer,
        _polyline(const [
          // Down into the left bowl, round it, and back up across the
          // arm just drawn — the first crossing.
          Offset(10, 10),
          Offset(25, 55),
          Offset(5, 65),
          Offset(18, 20),
          // The wedge itself.
          Offset(30, 5),
          Offset(45, 55),
          // The right bowl, closing back over the right arm.
          Offset(30, 65),
          Offset(42, 20),
        ]),
      );
      expect(layer.recognizedName, 'ca');
    });

    test('a triple wedge crossing itself twice is nya', () {
      final layer = MakasarLayer();
      _draw(layer, _polyline(_nyaCorners));
      expect(layer.recognizedName, 'nya');
    });

    test('nya’s triple wedge + an ascending line below is ya', () {
      final layer = MakasarLayer();
      _draw(layer, _polyline(_nyaCorners));
      _draw(layer, _polyline(const [Offset(8, 90), Offset(35, 60)]));
      expect(layer.recognizedName, 'ya');
    });

    test('the mark can be drawn before the wedges it belongs under', () {
      final layer = MakasarLayer();
      _draw(layer, _chevron(40, 60));
      _draw(layer, _doubleWedge(0, 0));
      expect(layer.recognizedName, 'ba');
    });

    test('a mark beside the wedges is not read as belonging to them', () {
      final layer = MakasarLayer();
      _draw(layer, _doubleWedge(0, 0));
      // Same chevron, pushed clear of the wedges' x span. It no longer
      // pairs with them, so this isn't ba — the chevron is left to be
      // read on its own terms (a wide one is wa's shape).
      _draw(layer, _chevron(160, 60));
      expect(layer.recognizedName, isNot('ba'));
    });

    test('hand jitter along an arm does not break the wedge', () {
      final layer = MakasarLayer();
      // The upstroke backs off by a few pixels twice on its way to the
      // apex — under _directionNoise, so it stays one arm.
      _draw(layer, [
        const Offset(0, 40),
        const Offset(5, 34),
        const Offset(7, 36),
        const Offset(10, 28),
        const Offset(13, 31),
        const Offset(16, 20),
        const Offset(20, 0),
        const Offset(28, 16),
        const Offset(34, 28),
        const Offset(40, 40),
      ]);
      expect(layer.recognizedName, 'na');
    });

    test('a tap above the letter is -i, and below it -u', () {
      final layer = MakasarLayer();
      _draw(layer, _wedge(0, 20));
      _tap(layer, const Offset(20, 5));
      expect(layer.recognizedName, 'na');
      expect(layer.recognizedVowel, 'i');
      expect(layer.recognizedSyllable, 'ni');

      final other = MakasarLayer();
      _draw(other, _wedge(0, 20));
      _tap(other, const Offset(20, 80));
      expect(other.recognizedVowel, 'u');
      expect(other.recognizedSyllable, 'nu');
    });

    test('a left-then-right stroke in front of the letter is -e', () {
      final layer = MakasarLayer();
      _draw(layer, _wedge(60, 0));
      _draw(
        layer,
        _polyline(const [Offset(40, 10), Offset(10, 25), Offset(35, 40)]),
      );
      expect(layer.recognizedName, 'na');
      expect(layer.recognizedVowel, 'e');
    });

    test('a short-rise-then-long-fall stroke behind the letter is -o', () {
      final layer = MakasarLayer();
      _draw(layer, _wedge(0, 0));
      _draw(
        layer,
        _polyline(const [Offset(60, 25), Offset(70, 10), Offset(80, 70)]),
      );
      expect(layer.recognizedName, 'na');
      expect(layer.recognizedVowel, 'o');
    });

    test('a tap with no letter drawn is not a vowel sign', () {
      final layer = MakasarLayer();
      _tap(layer, const Offset(20, 5));
      expect(layer.recognizedVowel, isNull);
    });

    test('a wedge with a hook, its stem twice the rest, is angka', () {
      final layer = MakasarLayer();
      _draw(layer, _polyline(_angkaCorners));
      expect(layer.recognizedName, 'angka');
    });

    test('angka’s stroke + a chevron below it is ra', () {
      final layer = MakasarLayer();
      _draw(layer, _polyline(_angkaCorners));
      _draw(layer, _chevron(35, 95));
      expect(layer.recognizedName, 'ra');
    });

    test('a right-left-right stroke starting along its base is la', () {
      final layer = MakasarLayer();
      _draw(
        layer,
        _polyline(const [
          Offset(0, 60),
          Offset(40, 55),
          Offset(10, 20),
          Offset(45, 10),
        ]),
      );
      expect(layer.recognizedName, 'la');
    });

    test('the same stroke starting along its top is not la', () {
      final layer = MakasarLayer();
      _draw(
        layer,
        _polyline(const [
          Offset(0, 10),
          Offset(40, 15),
          Offset(10, 50),
          Offset(45, 60),
        ]),
      );
      expect(layer.recognizedName, isNot('la'));
    });

    test('left, right, then a tall run away to the left is sa', () {
      final layer = MakasarLayer();
      _draw(layer, _polyline(_saCorners));
      expect(layer.recognizedName, 'sa');
    });

    test('the same three runs, the last one wide instead of tall, is not sa',
        () {
      final layer = MakasarLayer();
      _draw(
        layer,
        _polyline(const [
          Offset(60, 10),
          Offset(30, 20),
          Offset(75, 30),
          Offset(15, 45),
        ]),
      );
      expect(layer.recognizedName, isNot('sa'));
    });

    test('a stroke sweeping sideways five times, left first, is a', () {
      final layer = MakasarLayer();
      _draw(
        layer,
        _polyline(const [
          Offset(60, 10),
          Offset(30, 15),
          Offset(75, 25),
          Offset(25, 35),
          Offset(80, 45),
          Offset(20, 55),
        ]),
      );
      expect(layer.recognizedName, 'a');
      expect(layer.recognizedSyllable, 'a');
    });

    test('a with a tap above it reads as the syllable i', () {
      final layer = MakasarLayer();
      _draw(
        layer,
        _polyline(const [
          Offset(60, 10),
          Offset(30, 15),
          Offset(75, 25),
          Offset(25, 35),
          Offset(80, 45),
          Offset(20, 55),
        ]),
      );
      _tap(layer, const Offset(50, 0));
      expect(layer.recognizedSyllable, 'i');
    });

    test('three stacked taps are passimbang', () {
      final layer = MakasarLayer();
      _tap(layer, const Offset(40, 20));
      _tap(layer, const Offset(44, 50));
      _tap(layer, const Offset(38, 80));
      expect(layer.recognizedName, 'passimbang');
    });

    test('six stacked taps are end of section', () {
      final layer = MakasarLayer();
      for (var i = 0; i < 6; i++) {
        _tap(layer, Offset(40, 20 + 30.0 * i));
      }
      expect(layer.recognizedName, 'end of section');
    });

    test('a column may drift sideways as long as each tap follows the last',
        () {
      final layer = MakasarLayer();
      // 10px of drift per tap: 50px end to end, well past a single tap's
      // own width, but every tap still lines up with its neighbour.
      for (var i = 0; i < 6; i++) {
        _tap(layer, Offset(40 + 10.0 * i, 20 + 30.0 * i));
      }
      expect(layer.recognizedName, 'end of section');
    });

    test('a tap clear of the one above it breaks the column', () {
      final layer = MakasarLayer();
      _tap(layer, const Offset(40, 20));
      _tap(layer, const Offset(44, 50));
      _tap(layer, const Offset(120, 80));
      expect(layer.recognizedName, isNull);
    });

    test('a second column is read on its own, not against the first', () {
      final layer = MakasarLayer();
      // A finished passimbang, then an end of section beside it.
      for (var i = 0; i < 3; i++) {
        _tap(layer, Offset(40, 20 + 30.0 * i));
      }
      expect(layer.recognizedName, 'passimbang');
      for (var i = 0; i < 6; i++) {
        _tap(layer, Offset(200, 20 + 30.0 * i));
      }
      expect(layer.recognizedName, 'end of section');
    });

    test('taps spread sideways are not punctuation', () {
      final layer = MakasarLayer();
      _tap(layer, const Offset(20, 40));
      _tap(layer, const Offset(80, 44));
      _tap(layer, const Offset(140, 38));
      expect(layer.recognizedName, isNull);
    });

    test('clear() drops what was drawn', () {
      final layer = MakasarLayer();
      _draw(layer, _wedge(0, 0));
      layer.clear();
      expect(layer.recognizedName, isNull);
    });
  });

  group('MakasarLayer set to Lontara', () {
    MakasarLayer lontara() => MakasarLayer()..script = WritingScript.bugis;

    test('a lone wedge is ta — the same element that is na in Makasar', () {
      final layer = lontara();
      _draw(layer, _wedge(0, 0));
      expect(layer.recognizedName, 'ta');
    });

    test('a chevron is ma', () {
      final layer = lontara();
      _draw(layer, _chevron(30, 0));
      expect(layer.recognizedName, 'ma');
    });

    test('a stroke closing on itself is sa, not ta', () {
      final layer = lontara();
      _draw(layer, _closedWedge(0, 0));
      expect(layer.recognizedName, 'sa');
    });

    test('a double wedge is wa', () {
      final layer = lontara();
      _draw(layer, _doubleWedge(0, 0));
      expect(layer.recognizedName, 'wa');
    });

    test('a wedge with a dot inside it is na, not ta', () {
      final layer = lontara();
      _draw(layer, _wedge(0, 0));
      expect(layer.recognizedName, 'ta');
      _tap(layer, const Offset(20, 30));
      expect(layer.recognizedName, 'na');
    });

    test('a chevron with a dot inside it is da, not ma', () {
      final layer = lontara();
      _draw(layer, _chevron(30, 0));
      expect(layer.recognizedName, 'ma');
      _tap(layer, const Offset(30, 8));
      expect(layer.recognizedName, 'da');
    });

    test('a tap clear of the wedge is a vowel sign, not na', () {
      final layer = lontara();
      _draw(layer, _wedge(0, 0));
      _tap(layer, const Offset(20, 70));
      expect(layer.recognizedName, 'ta');
      expect(layer.recognizedSyllable, 'tu');
    });

    test('a stroke out right and back left, each half up-down-up, is ha', () {
      final layer = lontara();
      _draw(
        layer,
        _polyline(const [
          // Out to the right: up, down, up.
          Offset(10, 45),
          Offset(25, 15),
          Offset(40, 45),
          Offset(55, 15),
          // Back to the left, the same profile again, closing two loops.
          // Each run has to clear _minArmExtent to count as its own.
          Offset(46, 0),
          Offset(33, 40),
          Offset(18, 8),
        ]),
      );
      expect(layer.recognizedName, 'ha');
    });

    test('the same turn with a plain wedge on the way out is ja', () {
      final layer = lontara();
      _draw(
        layer,
        _polyline(const [
          // Out to the right: up, then down.
          Offset(10, 45),
          Offset(35, 10),
          Offset(50, 40),
          // Back to the left, low — well below the apex it just made.
          Offset(35, 48),
        ]),
      );
      expect(layer.recognizedName, 'ja');
    });

    test('a return sweeping back over the apex is not ja', () {
      final layer = lontara();
      _draw(
        layer,
        _polyline(const [
          Offset(10, 45),
          Offset(35, 10),
          Offset(50, 40),
          // Back left, but climbing clear of the apex on the way.
          Offset(30, 2),
        ]),
      );
      expect(layer.recognizedName, isNot('ja'));
    });

    /// ᨄ's stroke: the first climb, then a tail out to the right as it
    /// falls and back left as it rises again. Also ᨁ's and ᨋ's.
    const paCorners = [
      Offset(10, 45),
      Offset(35, 12),
      Offset(60, 44),
      Offset(45, 5),
    ];

    test('up, down, up with the tail turning right then left is pa', () {
      final layer = lontara();
      _draw(layer, _polyline(paCorners));
      expect(layer.recognizedName, 'pa');
    });

    test('the same stroke with a dot under its opening wedge is ga', () {
      final layer = lontara();
      _draw(layer, _polyline(paCorners));
      expect(layer.recognizedName, 'pa');
      _tap(layer, const Offset(35, 35));
      expect(layer.recognizedName, 'ga');
    });

    test('with a wedge under that opening instead, it is nra', () {
      final layer = lontara();
      _draw(layer, _polyline(paCorners));
      _draw(layer, _wedge(15, 50, size: 30));
      expect(layer.recognizedName, 'nra');
    });

    test('a left-then-right stroke crossed from its lower left is ba', () {
      final layer = lontara();
      _draw(
          layer,
          _polyline(const [
            Offset(70, 45),
            Offset(40, 20),
            Offset(60, 5),
          ]));
      _draw(layer, _line(const Offset(35, 45), const Offset(65, 25)));
      expect(layer.recognizedName, 'ba');
    });

    test('the same with the turn made right then left is mpa', () {
      final layer = lontara();
      _draw(
          layer,
          _polyline(const [
            Offset(40, 5),
            Offset(70, 30),
            Offset(45, 45),
          ]));
      _draw(layer, _line(const Offset(30, 50), const Offset(58, 15)));
      expect(layer.recognizedName, 'mpa');
    });

    test('a double wedge dotted under both wedges is ya', () {
      final layer = lontara();
      _draw(layer, _doubleWedge(0, 0));
      _tap(layer, const Offset(20, 30));
      _tap(layer, const Offset(60, 30));
      expect(layer.recognizedName, 'ya');
    });

    test('dotted under the second wedge only, it is a', () {
      final layer = lontara();
      _draw(layer, _doubleWedge(0, 0));
      _tap(layer, const Offset(60, 30));
      expect(layer.recognizedName, 'a');
    });

    test('a tap below the whole letter is still -u, not a dot of ya', () {
      final layer = lontara();
      _draw(layer, _doubleWedge(0, 0));
      expect(layer.recognizedName, 'wa');
      // Clear of the wedges rather than tucked under one of them.
      _tap(layer, const Offset(40, 70));
      expect(layer.recognizedName, 'wa');
      expect(layer.recognizedSyllable, 'wu');
    });

    test('two crossings one over the other are the end of section', () {
      final layer = lontara();
      // The upper crossing: the falling stroke below and right of the
      // climbing one.
      _draw(layer, _line(const Offset(50, 30), const Offset(65, 8)));
      _draw(layer, _line(const Offset(56, 18), const Offset(72, 30)));
      // The lower one, made the other way about: above and left.
      _draw(layer, _line(const Offset(56, 55), const Offset(70, 34)));
      _draw(layer, _line(const Offset(50, 33), const Offset(65, 46)));
      expect(layer.recognizedName, 'end of section');
    });

    test('a wavering hand still draws lines, and crosses them once', () {
      // Both halves of what the recognizer asks of ᨟, at the size the
      // canvas is actually written on. A stroke used to stop being a line
      // the moment it doubled back a few pixels, and two wavering strokes
      // crossed and re-crossed where they were meant to meet once — either
      // was enough to lose the mark.
      final lines = lontara();
      _draw(lines, _wobblyLine(const Offset(0, 90), const Offset(60, 20), 5));
      _draw(lines, _wobblyLine(const Offset(30, 90), const Offset(90, 20), 5));
      expect(lines.recognizedName, 'ka');

      final crossing = lontara();
      _draw(crossing,
          _wobblyLine(const Offset(80, 20), const Offset(140, 90), 5));
      _draw(crossing,
          _wobblyLine(const Offset(60, 90), const Offset(120, 40), 5));
      expect(crossing.recognizedName, 'nga');
    });

    test('the end of section survives a wavering hand too', () {
      final layer = lontara();
      _draw(
          layer, _wobblyLine(const Offset(150, 120), const Offset(210, 30), 5));
      _draw(
          layer, _wobblyLine(const Offset(175, 70), const Offset(240, 120), 5));
      _draw(layer,
          _wobblyLine(const Offset(175, 220), const Offset(235, 140), 5));
      _draw(layer,
          _wobblyLine(const Offset(150, 135), const Offset(210, 185), 5));
      expect(layer.recognizedName, 'end of section');
    });

    test('one crossing on its own is not the end of section', () {
      final layer = lontara();
      _draw(layer, _line(const Offset(50, 30), const Offset(65, 8)));
      _draw(layer, _line(const Offset(56, 18), const Offset(72, 30)));
      expect(layer.recognizedName, isNot('end of section'));
    });

    test('three taps stepping down to the right are pallawa', () {
      final layer = lontara();
      _tap(layer, const Offset(20, 20));
      _tap(layer, const Offset(35, 40));
      _tap(layer, const Offset(50, 60));
      expect(layer.recognizedName, 'pallawa');
    });

    test('the same three tapped out from the other end are still pallawa', () {
      final layer = lontara();
      _tap(layer, const Offset(50, 60));
      _tap(layer, const Offset(35, 40));
      _tap(layer, const Offset(20, 20));
      expect(layer.recognizedName, 'pallawa');
    });

    test('three taps stacked in a column are not pallawa', () {
      final layer = lontara();
      for (var i = 0; i < 3; i++) {
        _tap(layer, Offset(40, 20 + 30.0 * i));
      }
      expect(layer.recognizedName, isNull);
    });

    test('three taps stepping up to the right are not pallawa', () {
      final layer = lontara();
      _tap(layer, const Offset(20, 60));
      _tap(layer, const Offset(35, 40));
      _tap(layer, const Offset(50, 20));
      expect(layer.recognizedName, isNull);
    });

    test('two ascending lines whose x ranges overlap are ka', () {
      final layer = lontara();
      _draw(layer, _ascendingLine(0));
      _draw(layer, _ascendingLine(15));
      expect(layer.recognizedName, 'ka');
    });

    test('the same two lines drawn clear of each other are not ka', () {
      final layer = lontara();
      _draw(layer, _ascendingLine(0));
      _draw(layer, _ascendingLine(60));
      expect(layer.recognizedName, isNot('ka'));
    });

    test('two wedges whose x ranges overlap are ra', () {
      final layer = lontara();
      _draw(layer, _wedge(0, 0));
      _draw(layer, _wedge(5, 40));
      expect(layer.recognizedName, 'ra');
    });

    test('a wedge with a right-then-left stroke across it is ca', () {
      final layer = lontara();
      _draw(layer, _wedge(0, 0));
      _draw(
          layer,
          _polyline(const [
            Offset(30, 5),
            Offset(55, 35),
            Offset(35, 45),
          ]));
      expect(layer.recognizedName, 'ca');
    });

    test('the same stroke drawn clear of the wedge is not ca', () {
      final layer = lontara();
      _draw(layer, _wedge(0, 0));
      _draw(
          layer,
          _polyline(const [
            Offset(80, 5),
            Offset(105, 35),
            Offset(85, 45),
          ]));
      expect(layer.recognizedName, isNot('ca'));
    });

    test('two wedges whose arms cross are nca, not ra', () {
      final layer = lontara();
      _draw(layer, _wedge(0, 0));
      // Offset a little, so the arms cross partway along a segment rather
      // than meeting exactly on a shared sample point — which is a touch,
      // not a crossing, and is not what a hand draws anyway.
      _draw(layer, _wedge(18, 3));
      expect(layer.recognizedName, 'nca');
    });

    test('an up-down-up stroke + a wedge over its last climb is la', () {
      final layer = lontara();
      // Up to a peak, down into a valley, then up again to finish around
      // x 60–80.
      _draw(
        layer,
        _polyline(const [
          Offset(20, 80),
          Offset(40, 20),
          Offset(60, 70),
          Offset(80, 25),
        ]),
      );
      _draw(layer, _wedge(55, 0, size: 30));
      expect(layer.recognizedName, 'la');
    });

    test('the wedge has to sit over that last climb, not clear of it', () {
      final layer = lontara();
      _draw(
        layer,
        _polyline(const [
          Offset(20, 80),
          Offset(40, 20),
          Offset(60, 70),
          Offset(80, 25),
        ]),
      );
      _draw(layer, _wedge(200, 0, size: 30));
      expect(layer.recognizedName, isNot('la'));
    });

    test('a descending line crossed from its lower left is nga', () {
      final layer = lontara();
      _draw(layer, _line(const Offset(40, 10), const Offset(70, 45)));
      _draw(layer, _line(const Offset(30, 45), const Offset(60, 20)));
      expect(layer.recognizedName, 'nga');
    });

    test('the same crossing made from the upper right is not nga', () {
      final layer = lontara();
      _draw(layer, _line(const Offset(40, 10), const Offset(70, 45)));
      _draw(layer, _line(const Offset(50, 35), const Offset(80, 10)));
      expect(layer.recognizedName, isNot('nga'));
    });

    test('a wedge cut across its climbing arm by a descending line is ngka',
        () {
      final layer = lontara();
      // Λ with its left arm running (0,40) up to (20,0).
      _draw(layer, _wedge(0, 0));
      // Down across that arm only, well clear of the falling one.
      _draw(layer, _line(const Offset(2, 4), const Offset(22, 34)));
      expect(layer.recognizedName, 'ngka');
    });

    test('a descending line across the falling arm instead is not ngka', () {
      final layer = lontara();
      _draw(layer, _wedge(0, 0));
      // Steeper than that arm, and clear of the climbing one, so it cuts
      // the wedge once — just not where ᨃ wants it.
      _draw(layer, _line(const Offset(22, 0), const Offset(32, 40)));
      expect(layer.recognizedName, isNot('ngka'));
    });

    test('a double wedge + a chevron under it is nya', () {
      final layer = lontara();
      _draw(layer, _doubleWedge(0, 0));
      _draw(layer, _chevron(40, 50));
      expect(layer.recognizedName, 'nya');
    });

    test('two wedges written side by side are not ra', () {
      final layer = lontara();
      _draw(layer, _wedge(0, 0));
      _draw(layer, _wedge(60, 0));
      expect(layer.recognizedName, isNot('ra'));
    });

    test('a tap above a letter is -i, the same mark as in Makasar', () {
      final layer = lontara();
      _draw(layer, _wedge(0, 0));
      _tap(layer, const Offset(20, -20));
      expect(layer.recognizedVowel, 'i');
      expect(layer.recognizedSyllable, 'ti');
    });

    test('a right-then-left stroke above a letter is -ae', () {
      final layer = lontara();
      _draw(layer, _wedge(0, 0));
      _draw(
        layer,
        _polyline(const [
          Offset(10, -30),
          Offset(30, -25),
          Offset(12, -12),
        ]),
      );
      expect(layer.recognizedVowel, 'ae');
      expect(layer.recognizedSyllable, 'tae');
    });

    test('-ae is Lontara’s alone; Makasar never claims it', () {
      final layer = MakasarLayer();
      _draw(layer, _wedge(0, 0));
      expect(layer.recognizedName, 'na');
      _draw(
        layer,
        _polyline(const [
          Offset(10, -30),
          Offset(30, -25),
          Offset(12, -12),
        ]),
      );
      expect(layer.recognizedVowel, isNull);
    });

    test('switching script wipes a reading taken as the other one', () {
      final layer = MakasarLayer();
      _draw(layer, _wedge(0, 0));
      expect(layer.recognizedName, 'na');

      layer.script = WritingScript.bugis;
      expect(layer.recognizedName, isNull);
      expect(layer.recognizer.strokes, isEmpty);
    });

    test('each script has its own recognized names, and shares four vowels',
        () {
      final makasar = MakasarLayer.recognizedNamesFor(WritingScript.makasar);
      final lontara = MakasarLayer.recognizedNamesFor(WritingScript.bugis);

      // Most names appear in both — each script has a ka, a na and so on —
      // so what tells the two sets apart is what only one of them holds:
      // angka and passimbang are Makasar's, ngka and pallawa Lontara's.
      expect(makasar, containsAll(<String>['angka', 'passimbang']));
      expect(lontara, isNot(contains('angka')));
      expect(lontara, containsAll(<String>['ngka', 'pallawa']));
      expect(makasar, isNot(contains('ngka')));

      // -i/-u/-e/-o are the same four marks in both; -ae is Lontara's own.
      expect(MakasarLayer.recognizedVowelsFor(WritingScript.makasar),
          <String>{'i', 'u', 'e', 'o'});
      expect(MakasarLayer.recognizedVowelsFor(WritingScript.bugis),
          <String>{'i', 'u', 'e', 'o', 'ae'});
    });
  });
}
