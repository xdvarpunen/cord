import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cord/makasar/scenes/writing_scene.dart';

/// Feeds [points] to [layer] as one finished stroke.
void _draw(WritingLayer layer, List<Offset> points) {
  layer.handlePointerEvent(PointerDownEvent(position: points.first), Size.zero);
  for (final point in points.skip(1)) {
    layer.handlePointerEvent(PointerMoveEvent(position: point), Size.zero);
  }
  layer.handlePointerEvent(PointerUpEvent(position: points.last), Size.zero);
}

/// Taps [layer] at [at].
void _tap(WritingLayer layer, Offset at) {
  layer.handlePointerEvent(PointerDownEvent(position: at), Size.zero);
  layer.handlePointerEvent(PointerUpEvent(position: at), Size.zero);
}

List<Offset> _line(Offset from, Offset to, {int steps = 8}) =>
    [for (var i = 0; i <= steps; i++) Offset.lerp(from, to, i / steps)!];

/// `Λ` — na, the simplest letter there is, at [left].
List<Offset> _wedge(double left, double top, {double size = 40}) {
  final apex = Offset(left + size / 2, top);
  return [
    ..._line(Offset(left, top + size), apex),
    ..._line(apex, Offset(left + size, top + size)).skip(1),
  ];
}

void main() {
  group('WritingLayer', () {
    test('a row of letters is read one character at a time', () {
      final layer = WritingLayer();
      _draw(layer, _wedge(0, 20));
      _draw(layer, _wedge(120, 20));
      _draw(layer, _wedge(240, 20));
      expect(layer.characterCount, 3);
      expect(layer.reading, 'nanana');
    });

    test('a letter and its vowel sign stay one character', () {
      final layer = WritingLayer();
      _draw(layer, _wedge(0, 20));
      _tap(layer, const Offset(20, 5));
      _draw(layer, _wedge(120, 20));
      expect(layer.characterCount, 2);
      expect(layer.reading, 'nina');
    });

    test(
        'characters are read left to right, whatever order they were '
        'written in', () {
      final layer = WritingLayer();
      _draw(layer, _wedge(240, 20));
      _draw(layer, _wedge(0, 20));
      // The middle one, written last, still reads in the middle.
      _draw(layer, _wedge(120, 20));
      expect(layer.reading, 'nanana');
    });

    test('a character nothing matches reads as ?', () {
      final layer = WritingLayer();
      _draw(layer, _wedge(0, 20));
      // A plain line: no letter is a single unbroken stroke like this.
      _draw(layer, _line(const Offset(140, 20), const Offset(180, 60)));
      expect(layer.characterCount, 2);
      expect(layer.reading, 'na?');
    });

    test('the row is glyphs as well as a reading', () {
      final layer = WritingLayer();
      _draw(layer, _wedge(0, 20));
      _tap(layer, const Offset(20, 5));
      // 𑻨 + the -i vowel sign.
      expect(layer.glyphs, '\u{11EE8}\u{11EF3}');
    });

    test('clear() empties the row', () {
      final layer = WritingLayer();
      _draw(layer, _wedge(0, 20));
      _draw(layer, _wedge(120, 20));
      layer.clear();
      expect(layer.characterCount, 0);
      expect(layer.glyphs, isEmpty);
    });

    test('undo() takes back the mark drawn last', () {
      final layer = WritingLayer();
      _draw(layer, _wedge(0, 20));
      _draw(layer, _wedge(120, 20));
      expect(layer.characterCount, 2);

      layer.undo();
      expect(layer.characterCount, 1);
      expect(layer.reading, 'na');
    });

    test('undo() takes back a vowel sign, leaving its letter', () {
      final layer = WritingLayer();
      _draw(layer, _wedge(0, 20));
      _tap(layer, const Offset(20, 5));
      expect(layer.reading, 'ni');

      layer.undo();
      expect(layer.reading, 'na');
    });

    test('undo() on an empty row does nothing', () {
      final layer = WritingLayer();
      layer.undo();
      expect(layer.characterCount, 0);

      _draw(layer, _wedge(0, 20));
      layer.undo();
      layer.undo();
      expect(layer.characterCount, 0);
      expect(layer.glyphs, isEmpty);
    });
  });
}
