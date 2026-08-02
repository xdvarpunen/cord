import 'package:flutter/material.dart';

import '../data/script.dart';
import '../engine/scene.dart';
import 'makasar_scene.dart';

/// Ruled-paper background for writing along: the same cream as
/// [PaperLayer], with writing lines across it and a margin down the left,
/// so a row of characters has something to sit on.
class RuledPaperLayer extends Layer {
  static const _paperColor = Color(0xFFF3ECDC);
  static const _ruleColor = Color(0x33355070);
  static const _marginColor = Color(0x33A03030);

  /// The gap between writing lines, and how far in the margin sits.
  static const double lineSpacing = 96;
  static const double marginX = 56;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _paperColor);

    final rule = Paint()
      ..color = _ruleColor
      ..strokeWidth = 1;
    for (double y = lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }

    canvas.drawLine(
      const Offset(marginX, 0),
      Offset(marginX, size.height),
      Paint()
        ..color = _marginColor
        ..strokeWidth = 1,
    );
  }
}

/// A row of characters rather than a single one: every mark drawn is kept,
/// the marks are grouped left to right into characters, and each group is
/// read by its own [MakasarRecognizer] — the same recognition as the
/// single-character canvas, run once per character.
///
/// Marks belong to the same character while they keep within
/// [_characterGap] of the ones already in it. That gap is what separates
/// one character from the next, and it has to be generous enough to hold a
/// letter and its vowel sign together (𑻵 is written in front of its letter
/// and 𑻶 behind it) while still breaking between characters — so writing
/// wants a clear space between them, about a character's width.
///
/// Each character's own glyph is drawn under it as it's recognized, and the
/// whole row is read out along the bottom.
class WritingLayer extends Layer {
  static const double _characterGap = 40;

  /// Every finished mark, in the order it was drawn.
  final List<List<Offset>> _marks = [];
  List<Offset>? _activePoints;

  /// One recognizer per character read out of [_marks], left to right.
  List<MakasarRecognizer> _characters = [];

  WritingScript _script = WritingScript.makasar;

  /// Which script the row is read as — wipes it on a change, the same way
  /// [MakasarRecognizer.script] does.
  set script(WritingScript script) {
    if (script == _script) return;
    _script = script;
    clear();
  }

  /// The row as glyphs, e.g. `𑻠𑻳𑻮` — what's been written so far.
  String get glyphs => _characters.map(MakasarInk.glyphsOf).join();

  /// The row as syllables, with `?` standing in for a character that
  /// wasn't recognized.
  String get reading => _characters
      .map((character) => character.recognizedSyllable ?? '?')
      .join();

  /// How many characters the row currently reads as.
  int get characterCount => _characters.length;

  void clear() {
    _marks.clear();
    _characters = [];
    _activePoints = null;
  }

  /// Drops the mark drawn most recently and reads the row again — which
  /// can change more than the character that mark belonged to, since
  /// removing it may leave the rest grouped differently.
  ///
  /// Does nothing on an empty row, so the button offering it needn't know
  /// whether there is anything to undo.
  void undo() {
    if (_marks.isEmpty) return;
    _marks.removeLast();
    _characters = _read();
    _activePoints = null;
  }

  @override
  void handlePointerEvent(PointerEvent event, Size size) {
    if (event is PointerDownEvent) {
      _activePoints = [event.localPosition];
    } else if (event is PointerMoveEvent && _activePoints != null) {
      _activePoints!.add(event.localPosition);
    } else if (event is PointerUpEvent && _activePoints != null) {
      _marks.add(_activePoints!);
      _characters = _read();
      _activePoints = null;
    }
  }

  /// Groups every mark into characters by where it sits along the row, then
  /// reads each group.
  ///
  /// Grouping is by position but each group is *fed* in draw order, since
  /// that's what recognition expects — a vowel sign is matched against the
  /// letter already recognized, so the letter has to arrive first.
  List<MakasarRecognizer> _read() {
    final byPosition = [for (var i = 0; i < _marks.length; i++) i]
      ..sort((a, b) => _boundsOf(_marks[a]).left.compareTo(
            _boundsOf(_marks[b]).left,
          ));

    final groups = <List<int>>[];
    var groupRight = 0.0;
    for (final index in byPosition) {
      final bounds = _boundsOf(_marks[index]);
      if (groups.isEmpty || bounds.left > groupRight + _characterGap) {
        groups.add([index]);
        groupRight = bounds.right;
      } else {
        groups.last.add(index);
        if (bounds.right > groupRight) groupRight = bounds.right;
      }
    }

    final characters = <MakasarRecognizer>[];
    for (final group in groups) {
      group.sort();
      final recognizer = MakasarRecognizer(script: _script);
      for (final index in group) {
        recognizer.addMark(_marks[index]);
      }
      characters.add(recognizer);
    }
    return characters;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn from what the recognizers took in rather than from [_marks]
    // directly, since it's the recognizer that decides whether a mark was
    // a stroke or a tap — and so how to draw it. One character at a time,
    // so that whether a tap is drawn small (against a letter) or as a
    // circle (on its own) is decided by its own character's strokes, not
    // by whatever happens to be written further along the row.
    for (final character in _characters) {
      MakasarInk.drawMarks(
        canvas,
        strokes: character.strokes,
        dots: character.dots,
      );
    }
    if (_activePoints != null) {
      MakasarInk.drawMarks(
        canvas,
        strokes: const [],
        dots: const [],
        preview: _activePoints,
      );
    }

    for (final character in _characters) {
      _paintCharacterGlyph(canvas, character);
    }
    _paintReading(canvas, size);
  }

  /// The glyph a character came to, drawn small under the marks it was read
  /// from — so it's clear which part of the row each reading belongs to.
  /// A character that isn't recognized (yet) shows nothing.
  ///
  /// A Lontara character has no glyph to show — nothing in the bundle
  /// renders the Buginese block — so its syllable stands in, in the ordinary
  /// text font.
  void _paintCharacterGlyph(Canvas canvas, MakasarRecognizer character) {
    final glyphs = MakasarInk.glyphsOf(character);
    final syllable = character.recognizedSyllable;
    if (glyphs.isEmpty && syllable == null) return;
    final marks = [
      for (final stroke in character.strokes) ...stroke.points,
      ...character.dots,
    ];
    if (marks.isEmpty) return;
    final bounds = _boundsOf(marks);

    final glyph = TextPainter(
      text: TextSpan(
        text: glyphs.isEmpty ? syllable : glyphs,
        style: TextStyle(
          fontFamily: glyphs.isEmpty ? null : 'NotoSerifMakasar',
          fontSize: glyphs.isEmpty ? 14 : 20,
          color: const Color(0x991B2A4A),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(
      canvas,
      Offset(bounds.center.dx - glyph.width / 2, bounds.bottom + 12),
    );
  }

  /// The row as letterforms, in the order they were written — every
  /// character's own drawn form with its vowel sign written on it, so the
  /// row reads as the word it is rather than as letters and loose marks.
  List<GlyphCluster> get _glyphClusters =>
      [for (final character in _characters) MakasarInk.glyphClusterOf(character)];

  void _paintReading(Canvas canvas, Size size) {
    final label = TextPainter(
      text: _characters.isEmpty
          ? TextSpan(
              text: _script == WritingScript.makasar
                  ? 'Write characters in a row, left to right'
                  : 'Write characters in a row — the characters not greyed '
                      'out underneath are the ones read so far',
              style: const TextStyle(color: Colors.black54, fontSize: 16),
            )
          : TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              children: [
                TextSpan(
                  text: glyphs,
                  style: const TextStyle(
                    fontFamily: 'NotoSerifMakasar',
                    fontSize: 22,
                  ),
                ),
                TextSpan(text: '  ($reading)'),
              ],
            ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);

    // The row drawn out in letterforms under the reading of it — which for
    // New Lontara is the only picture of what was written, there being no
    // font for it.
    final clusters = _glyphClusters;
    final overhang = MakasarInk.glyphClusterOverhang(clusters);
    final glyphTop =
        size.height - 24 - overhang.below - MakasarInk.glyphImageHeight;
    if (clusters.every((cluster) => cluster.letter == null)) {
      label.paint(canvas, Offset(24, size.height - 24 - label.height));
      return;
    }
    label.paint(
      canvas,
      Offset(24, glyphTop - overhang.above - 8 - label.height),
    );
    MakasarInk.drawGlyphClusters(canvas, clusters, Offset(24, glyphTop));
  }

  Rect _boundsOf(List<Offset> points) {
    var minX = points.first.dx, maxX = points.first.dx;
    var minY = points.first.dy, maxY = points.first.dy;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// Builds the writing scene plus a direct reference to its [WritingLayer],
/// so the hosting page can call [WritingLayer.clear] from the Clear button.
(Scene, WritingLayer) buildWritingScene() {
  final layer = WritingLayer();
  return (Scene([RuledPaperLayer(), layer]), layer);
}
