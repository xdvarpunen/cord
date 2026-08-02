import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// The drawn letterforms under `assets/makasar/glyphs`, decoded once each so a
/// canvas can paint them.
///
/// `GlyphImage` puts the same files on screen as widgets, which is all the
/// listings need; a scene paints into a [ui.Canvas] and so needs the
/// decoded image itself. Decoding is asynchronous and painting isn't, so
/// [of] answers with what it has and starts the work for what it hasn't:
/// the canvas runs a frame loop, and the letterform appears in whichever
/// frame it is ready for.
///
/// cord's addition to upstream's version: each image's [inkOf] box is
/// measured while it is decoded, since every one of them carries a wide
/// margin. A row of characters set from the whole images reads as a line of
/// widely spaced pictures; set from their ink it reads as writing.
class GlyphImages {
  static final Map<String, ui.Image> _decoded = {};
  static final Map<String, ui.Rect> _ink = {};
  static final Set<String> _asked = {};

  /// The decoded image for an `assets/makasar/glyphs` stem, or null while it is
  /// still being read.
  static ui.Image? of(String name) {
    final image = _decoded[name];
    if (image != null) return image;
    if (_asked.add(name)) _decode(name);
    return null;
  }

  /// The part of that image its ink actually occupies, as fractions of the
  /// image — null until it has been decoded ([of]).
  static ui.Rect? inkOf(String name) => _ink[name];

  static Future<void> _decode(String name) async {
    try {
      final data = await rootBundle.load('assets/makasar/glyphs/$name.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      _ink[name] = await _inkBounds(image);
      _decoded[name] = image;
    } catch (_) {
      // A letterform that won't load leaves the reading standing as its
      // own text, which is all there was before there were images to draw
      // beneath it. Nothing here is worth failing a drawing over.
    }
  }

  /// The box the ink sits in, as fractions of [image] — the whole image if
  /// its pixels can't be read, which simply leaves the margins on.
  static Future<ui.Rect> _inkBounds(ui.Image image) async {
    const whole = ui.Rect.fromLTRB(0, 0, 1, 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return whole;
    final pixels = data.buffer.asUint8List();
    final width = image.width, height = image.height;
    var left = width, top = height, right = -1, bottom = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        // The letterforms are black strokes on transparency; anything
        // faint enough to be an edge pixel doesn't move the box.
        if (pixels[(y * width + x) * 4 + 3] < 128) continue;
        if (x < left) left = x;
        if (y < top) top = y;
        if (x > right) right = x;
        if (y > bottom) bottom = y;
      }
    }
    if (right < 0) return whole;
    return ui.Rect.fromLTRB(
      left / width,
      top / height,
      (right + 1) / width,
      (bottom + 1) / height,
    );
  }
}
