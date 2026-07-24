import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cord/hebrew/scenes/hebrew_scene.dart';

// Ported from the standalone `heb` project's `test/hebrew_scene_test.dart`,
// minus its Paleo-Hebrew group: cord's Hebrew page is the modern square script
// only, so paleo mode is never selected here (see `hebrew_letters.dart`).

/// Feeds [layer] a straight stroke from [from] to [to] as the pointer events a
/// real drag would produce: a down, a run of moves along the line, and an up.
void drawStroke(HebrewLayer layer, Offset from, Offset to, {int steps = 20}) {
  const size = Size(400, 400);
  layer.handlePointerEvent(PointerDownEvent(position: from), size);
  for (var i = 1; i <= steps; i++) {
    final point = Offset.lerp(from, to, i / steps)!;
    layer.handlePointerEvent(PointerMoveEvent(position: point), size);
  }
  layer.handlePointerEvent(PointerUpEvent(position: to), size);
}

/// Feeds [layer] a single bent stroke: [a] to [corner] to [b], each leg
/// sampled as a run of moves, so the recognizer sees a genuine two-legged
/// corner (as the giyeok-style base is) rather than just three points.
void drawCorner(HebrewLayer layer, Offset a, Offset corner, Offset b,
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

/// The giyeok-style base corner both letters build on: a top bar running
/// right, then the right leg dropping down.
void drawBaseCorner(HebrewLayer layer) {
  drawCorner(layer, const Offset(150, 120), const Offset(250, 120),
      const Offset(250, 260));
}

void main() {
  group('bet', () {
    test('a base corner crossed by a horizontal line is ב', () {
      final layer = HebrewLayer();
      drawBaseCorner(layer);
      drawStroke(layer, const Offset(200, 200), const Offset(300, 200));
      expect(layer.recognizedGlyph, 'ב');
    });

    test('ב drawn line-first still reads as ב', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(200, 200), const Offset(300, 200));
      drawBaseCorner(layer);
      expect(layer.recognizedGlyph, 'ב');
    });

    test('a corner whose horizontal misses it entirely is not ב', () {
      final layer = HebrewLayer();
      drawBaseCorner(layer);
      // A horizontal off on its own, nowhere near the corner.
      drawStroke(layer, const Offset(30, 320), const Offset(110, 320));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a corner whose horizontal stops short of the leg is not ב', () {
      final layer = HebrewLayer();
      drawBaseCorner(layer);
      // Reaches toward the right leg (x=250) but stops before crossing it.
      drawStroke(layer, const Offset(150, 200), const Offset(235, 200));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('chet', () {
    test('a base corner crossed by a vertical line is ח', () {
      final layer = HebrewLayer();
      drawBaseCorner(layer);
      drawStroke(layer, const Offset(200, 90), const Offset(200, 180));
      expect(layer.recognizedGlyph, 'ח');
    });

    test('ח drawn line-first still reads as ח', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(200, 90), const Offset(200, 180));
      drawBaseCorner(layer);
      expect(layer.recognizedGlyph, 'ח');
    });

    test('a vertical off to the side of the corner is not ח', () {
      final layer = HebrewLayer();
      drawBaseCorner(layer);
      // A vertical well clear of the corner's box — neither crossing it (ח)
      // nor sitting inside its frame (ה).
      drawStroke(layer, const Offset(330, 150), const Offset(330, 240));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('he', () {
    // A giyeok-style corner with a detached vertical left leg hanging inside
    // its frame — inside the bounding box, but not crossing the ㄱ.
    void drawHey(HebrewLayer layer) {
      drawBaseCorner(layer); // ㄱ, bbox x[150,250] y[120,260]
      drawStroke(layer, const Offset(170, 155), const Offset(170, 250)); // leg
    }

    test('a corner with a detached vertical leg inside its box is ה', () {
      final layer = HebrewLayer();
      drawHey(layer);
      expect(layer.recognizedGlyph, 'ה');
    });

    test('ה drawn leg-first still reads as ה', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(170, 155), const Offset(170, 250)); // leg
      drawBaseCorner(layer);
      expect(layer.recognizedGlyph, 'ה');
    });

    test('a vertical that crosses the top bar is ח, not ה', () {
      final layer = HebrewLayer();
      drawBaseCorner(layer);
      drawStroke(layer, const Offset(200, 90), const Offset(200, 180)); // crosses
      expect(layer.recognizedGlyph, 'ח');
    });

    test('a vertical leg clear of the corner box is not ה', () {
      final layer = HebrewLayer();
      drawBaseCorner(layer);
      // Off to the left of the box entirely.
      drawStroke(layer, const Offset(80, 150), const Offset(80, 250));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('final mem', () {
    // A giyeok corner (ㄱ) and a nieun corner (ㄴ) overshooting so their ends
    // cross at top-left and bottom-right — a closed box.
    void drawFinalMem(HebrewLayer layer) {
      drawCorner(layer, const Offset(140, 120), const Offset(250, 120),
          const Offset(250, 270)); // ㄱ: top bar + right side down
      drawCorner(layer, const Offset(150, 110), const Offset(150, 260),
          const Offset(260, 260)); // ㄴ: left side down + bottom bar
    }

    test('a ㄱ and ㄴ corner crossing twice (a closed box) is ם', () {
      final layer = HebrewLayer();
      drawFinalMem(layer);
      expect(layer.recognizedGlyph, 'ם');
    });

    test('ם drawn nieun-first still reads as ם', () {
      final layer = HebrewLayer();
      drawCorner(layer, const Offset(150, 110), const Offset(150, 260),
          const Offset(260, 260)); // ㄴ
      drawCorner(layer, const Offset(140, 120), const Offset(250, 120),
          const Offset(250, 270)); // ㄱ
      expect(layer.recognizedGlyph, 'ם');
    });

    test('two ㄱ corners (no nieun) are not ם', () {
      final layer = HebrewLayer();
      drawCorner(layer, const Offset(140, 120), const Offset(250, 120),
          const Offset(250, 270)); // ㄱ
      drawCorner(layer, const Offset(150, 120), const Offset(260, 120),
          const Offset(260, 270)); // ㄱ
      expect(layer.recognizedGlyph, isNull);
    });

    test('a ㄱ and ㄴ drawn apart (no crossings) are not ם', () {
      final layer = HebrewLayer();
      drawCorner(layer, const Offset(140, 120), const Offset(250, 120),
          const Offset(250, 270)); // ㄱ
      // A ㄴ off to the right, nowhere near the ㄱ.
      drawCorner(layer, const Offset(350, 110), const Offset(350, 260),
          const Offset(460, 260)); // ㄴ
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('final pe', () {
    // A tall, narrow giyeok (ㄱ, long descender) and a nieun (ㄴ) inner tongue
    // whose left leg crosses the giyeok's top bar once, high on the nieun.
    void drawTallGiyeok(HebrewLayer layer) {
      drawCorner(layer, const Offset(180, 120), const Offset(260, 120),
          const Offset(260, 380)); // ㄱ, bbox x[180,260] y[120,380] (h≫2w)
    }

    void drawTongue(HebrewLayer layer) {
      // ㄴ: left leg dropping through the top bar, bottom bar stopping before
      // the descender. Its left leg crosses the top bar at (210,120) — the
      // nieun's top half — and nowhere else.
      drawCorner(layer, const Offset(210, 105), const Offset(210, 155),
          const Offset(252, 155));
    }

    test('a nieun crossing a tall giyeok once, high on it, is ף', () {
      final layer = HebrewLayer();
      drawTallGiyeok(layer);
      drawTongue(layer);
      expect(layer.recognizedGlyph, 'ף');
    });

    test('ף drawn tongue-first still reads as ף', () {
      final layer = HebrewLayer();
      drawTongue(layer);
      drawTallGiyeok(layer);
      expect(layer.recognizedGlyph, 'ף');
    });

    test('a wide giyeok (not a tall descender) is not ף', () {
      final layer = HebrewLayer();
      // Short, wide ㄱ — height not over twice its width.
      drawCorner(layer, const Offset(180, 120), const Offset(300, 120),
          const Offset(300, 200));
      drawTongue(layer);
      expect(layer.recognizedGlyph, isNull);
    });

    test('a nieun crossing low on itself (bottom half) is not ף', () {
      final layer = HebrewLayer();
      drawTallGiyeok(layer);
      // ㄴ sitting below the top bar, its bottom bar crossing the descender low
      // — in the nieun's bottom half, not high.
      drawCorner(layer, const Offset(220, 150), const Offset(220, 240),
          const Offset(290, 240));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('final tsadi', () {
    // A descending line (\) crossed once by an ascending diagonal (/) whose
    // body sits up and to the right of it.
    void drawFinalTsadi(HebrewLayer layer) {
      drawStroke(layer, const Offset(160, 150), const Offset(260, 290)); // \
      drawStroke(layer, const Offset(190, 230), const Offset(280, 150)); // /
    }

    test('a descending line crossed by an up-right ascending diagonal is ץ',
        () {
      final layer = HebrewLayer();
      drawFinalTsadi(layer);
      expect(layer.recognizedGlyph, 'ץ');
    });

    test('ץ drawn arm-first still reads as ץ', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(190, 230), const Offset(280, 150)); // /
      drawStroke(layer, const Offset(160, 150), const Offset(260, 290)); // \
      expect(layer.recognizedGlyph, 'ץ');
    });

    test('two descending diagonals (no ascending arm) are not ץ', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(160, 150), const Offset(260, 290)); // \
      drawStroke(layer, const Offset(190, 150), const Offset(290, 290)); // \
      expect(layer.recognizedGlyph, isNull);
    });

    test('an arm centered left of the descending line is not ץ', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(220, 150), const Offset(320, 290)); // \
      drawStroke(layer, const Offset(170, 230), const Offset(260, 150)); // / left
      expect(layer.recognizedGlyph, isNull);
    });

    test('an arm centered below the descending line center is ג, not ץ', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(160, 150), const Offset(260, 290)); // \
      drawStroke(layer, const Offset(190, 320), const Offset(280, 240)); // / low
      expect(layer.recognizedGlyph, 'ג');
    });

    test('an arm that never crosses the descending line is not ץ', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(160, 150), const Offset(230, 290)); // \
      // An ascending diagonal off to the upper right, never meeting the \.
      drawStroke(layer, const Offset(260, 200), const Offset(340, 130)); // /
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('zayin', () {
    test('a vertical crossed near its top by a descending diagonal is ז', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 320)); // |
      drawStroke(layer, const Offset(170, 135), const Offset(250, 185)); // \ top
      expect(layer.recognizedGlyph, 'ז');
    });

    test('ז drawn arm-first still reads as ז', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(170, 135), const Offset(250, 185)); // \
      drawStroke(layer, const Offset(200, 120), const Offset(200, 320)); // |
      expect(layer.recognizedGlyph, 'ז');
    });

    test('a descending diagonal crossing lower down the stem is not ז', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 320)); // |
      // Crosses around mid-stem, well below the top quarter.
      drawStroke(layer, const Offset(170, 220), const Offset(250, 270)); // \ low
      expect(layer.recognizedGlyph, isNull);
    });

    test('a vertical crossed by an ascending diagonal is not ז', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(200, 120), const Offset(200, 320)); // |
      drawStroke(layer, const Offset(170, 185), const Offset(250, 135)); // /
      expect(layer.recognizedGlyph, isNull);
    });
  });

  test('bet and chet are told apart by the crossing line orientation', () {
    final bet = HebrewLayer();
    drawBaseCorner(bet);
    drawStroke(bet, const Offset(200, 200), const Offset(300, 200)); // horizontal
    expect(bet.recognizedGlyph, 'ב');

    final chet = HebrewLayer();
    drawBaseCorner(chet);
    drawStroke(chet, const Offset(200, 90), const Offset(200, 180)); // vertical
    expect(chet.recognizedGlyph, 'ח');
  });

  group('lone corner (resh/yod, vav/final nun)', () {
    test('a wide lone giyeok corner is ר (resh/yod)', () {
      final layer = HebrewLayer();
      drawBaseCorner(layer); // 100 wide, 140 tall — under 2x → wide
      expect(layer.recognizedGlyph, 'ר');
    });

    test('a narrow (tall, thin) lone giyeok corner is ו (vav/final nun)', () {
      final layer = HebrewLayer();
      // Top bar 30 wide, right leg 120 tall — 4x → narrow.
      drawCorner(layer, const Offset(220, 120), const Offset(250, 120),
          const Offset(250, 240));
      expect(layer.recognizedGlyph, 'ו');
    });

    test('adding a second stroke moves past the lone corner to a compound', () {
      final layer = HebrewLayer();
      drawBaseCorner(layer);
      expect(layer.recognizedGlyph, 'ר');
      drawStroke(layer, const Offset(200, 200), const Offset(300, 200)); // → ב
      expect(layer.recognizedGlyph, 'ב');
    });

    test('a nieun corner (ㄴ) on its own is not a lone-corner letter', () {
      final layer = HebrewLayer();
      drawCorner(layer, const Offset(150, 120), const Offset(150, 260),
          const Offset(260, 260)); // ㄴ
      expect(layer.recognizedGlyph, isNull);
    });

    test('the shared groups list every letter and match the legend', () {
      // Base forms the recognizer reports, one per shared shape.
      final bases = {for (final g in HebrewLayer.sharedGroups) g.base};
      expect(bases, containsAll(['ר', 'ו', 'ד']));
      // Every letter in every group is enabled in the legend by name.
      for (final name in [
        'resh', 'yod', 'vav', 'final nun', 'dalet', 'final kaf'
      ]) {
        expect(HebrewLayer.recognizedNames, contains(name));
      }
    });
  });

  group('dalet / final chaf', () {
    // A vertical crossed near its top by a horizontal bar.
    void drawDalet(HebrewLayer layer) {
      drawStroke(layer, const Offset(250, 120), const Offset(250, 320)); // |
      drawStroke(layer, const Offset(180, 150), const Offset(275, 150)); // — top
    }

    test('a vertical crossed near its top by a horizontal bar is ד', () {
      final layer = HebrewLayer();
      drawDalet(layer);
      expect(layer.recognizedGlyph, 'ד');
    });

    test('ד drawn bar-first still reads as ד', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(180, 150), const Offset(275, 150)); // — top
      drawStroke(layer, const Offset(250, 120), const Offset(250, 320)); // |
      expect(layer.recognizedGlyph, 'ד');
    });

    test('a bar crossing mid-stem (not near the top) is not ד', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(250, 120), const Offset(250, 320)); // |
      drawStroke(layer, const Offset(180, 220), const Offset(275, 220)); // — mid
      expect(layer.recognizedGlyph, isNull);
    });

    test('a bar that stops short of the stem (no crossing) is not ד', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(250, 120), const Offset(250, 320)); // |
      drawStroke(layer, const Offset(180, 150), const Offset(240, 150)); // short
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('aleph', () {
    // A descending spine (\) with an upper arm crossing it high and a lower
    // arm crossing it low — two intersections in all.
    void drawAleph(HebrewLayer layer) {
      drawStroke(layer, const Offset(150, 140), const Offset(270, 300)); // \ spine
      drawStroke(layer, const Offset(175, 200), const Offset(245, 150)); // upper arm
      drawStroke(layer, const Offset(175, 290), const Offset(245, 240)); // lower arm
    }

    test('a descending spine crossed high and low by two arms is א', () {
      final layer = HebrewLayer();
      drawAleph(layer);
      expect(layer.recognizedGlyph, 'א');
    });

    test('the three strokes may arrive in any order and still read as א', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(175, 290), const Offset(245, 240)); // lower
      drawStroke(layer, const Offset(150, 140), const Offset(270, 300)); // spine
      drawStroke(layer, const Offset(175, 200), const Offset(245, 150)); // upper
      expect(layer.recognizedGlyph, 'א');
    });

    test('both arms crossing the upper half only is not א', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(150, 140), const Offset(270, 300)); // spine
      drawStroke(layer, const Offset(160, 200), const Offset(225, 150)); // high
      drawStroke(layer, const Offset(180, 215), const Offset(250, 165)); // also high
      expect(layer.recognizedGlyph, isNull);
    });

    test('an arm that misses the spine (only one crossing) is not א', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(150, 140), const Offset(270, 300)); // spine
      drawStroke(layer, const Offset(175, 200), const Offset(245, 150)); // upper arm
      // A stroke off to the right, never meeting the spine.
      drawStroke(layer, const Offset(300, 290), const Offset(360, 240));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('shin', () {
    // A nieun corner (ㄴ) crossed near its base by two ascending arms (/).
    void drawShin(HebrewLayer layer) {
      drawCorner(layer, const Offset(150, 140), const Offset(150, 280),
          const Offset(280, 280)); // ㄴ: left side down + bottom bar
      drawStroke(layer, const Offset(180, 300), const Offset(220, 250)); // / arm
      drawStroke(layer, const Offset(240, 300), const Offset(280, 250)); // / arm
    }

    test('a nieun crossed by two ascending arms is ש', () {
      final layer = HebrewLayer();
      drawShin(layer);
      expect(layer.recognizedGlyph, 'ש');
    });

    test('the three strokes may arrive in any order and still read as ש', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(180, 300), const Offset(220, 250)); // / arm
      drawStroke(layer, const Offset(240, 300), const Offset(280, 250)); // / arm
      drawCorner(layer, const Offset(150, 140), const Offset(150, 280),
          const Offset(280, 280)); // ㄴ
      expect(layer.recognizedGlyph, 'ש');
    });

    test('descending arms (\\) crossing the nieun are not ש', () {
      final layer = HebrewLayer();
      drawCorner(layer, const Offset(150, 140), const Offset(150, 280),
          const Offset(280, 280)); // ㄴ
      drawStroke(layer, const Offset(180, 250), const Offset(220, 300)); // \ arm
      drawStroke(layer, const Offset(240, 250), const Offset(280, 300)); // \ arm
      expect(layer.recognizedGlyph, isNull);
    });

    test('an arm that misses the nieun (only one crossing) is not ש', () {
      final layer = HebrewLayer();
      drawCorner(layer, const Offset(150, 140), const Offset(150, 280),
          const Offset(280, 280)); // ㄴ
      drawStroke(layer, const Offset(180, 300), const Offset(220, 250)); // / arm
      // An ascending arm off to the right, never meeting the ㄴ.
      drawStroke(layer, const Offset(360, 300), const Offset(400, 250));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('qof', () {
    // A head that runs out to the right and back (a top bar + right leg,
    // rightmost point mid-stroke) with a long vertical descender dropping well
    // below it — the head's lowest point sits above the descender's centre.
    void drawQofHead(HebrewLayer layer) {
      drawCorner(layer, const Offset(150, 140), const Offset(250, 140),
          const Offset(250, 200)); // head, bbox x[150,250] y[140,200]
    }

    test('a right-then-left head with a long descender past it is ק', () {
      final layer = HebrewLayer();
      drawQofHead(layer);
      drawStroke(layer, const Offset(170, 160), const Offset(170, 330)); // long |
      expect(layer.recognizedGlyph, 'ק');
    });

    test('ק drawn descender-first still reads as ק', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(170, 160), const Offset(170, 330)); // long |
      drawQofHead(layer);
      expect(layer.recognizedGlyph, 'ק');
    });

    test('the same head with a short leg inside its box is ה, not ק', () {
      final layer = HebrewLayer();
      drawBaseCorner(layer); // ㄱ head, bbox y[120,260]
      // Short leg hanging inside — its centre sits above the head's bottom, so
      // qof (checked first) defers and this settles as ה.
      drawStroke(layer, const Offset(170, 155), const Offset(170, 250));
      expect(layer.recognizedGlyph, 'ה');
    });

    test('a descender clear of the head box is not ק', () {
      final layer = HebrewLayer();
      drawQofHead(layer);
      // Off to the right — the boxes don't overlap.
      drawStroke(layer, const Offset(360, 160), const Offset(360, 330));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('tsadi', () {
    // A body that runs out to the right and back left (a ">" drawn top-left →
    // rightmost point → bottom-left), crossed on its outbound (upper) leg by
    // an ascending diagonal arm.
    void drawTsadiBody(HebrewLayer layer) {
      drawCorner(layer, const Offset(180, 140), const Offset(260, 200),
          const Offset(180, 260)); // > : right then left, rightmost at middle
    }

    test('a right-then-left body crossed on its outbound leg by an arm is צ',
        () {
      final layer = HebrewLayer();
      drawTsadiBody(layer);
      drawStroke(layer, const Offset(190, 210), const Offset(250, 130)); // /
      expect(layer.recognizedGlyph, 'צ');
    });

    test('צ drawn arm-first still reads as צ', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(190, 210), const Offset(250, 130)); // /
      drawTsadiBody(layer);
      expect(layer.recognizedGlyph, 'צ');
    });

    test('a tilted right-then-left body (bow within gimel\'s loose bound) is '
        'still צ, not ג', () {
      final layer = HebrewLayer();
      // A ">" whose chord slants down-right and whose bulge is shallow enough
      // to pass gimel's loose descender test — tsadi must win over gimel.
      drawCorner(layer, const Offset(170, 150), const Offset(258, 208),
          const Offset(235, 225));
      drawStroke(layer, const Offset(205, 215), const Offset(255, 155)); // /
      expect(layer.recognizedGlyph, 'צ');
    });

    test('an arm crossing only the return (left-going) leg is not צ', () {
      final layer = HebrewLayer();
      drawTsadiBody(layer);
      // Ascending arm through the lower return leg, clear of the outbound one.
      drawStroke(layer, const Offset(190, 265), const Offset(250, 195));
      expect(layer.recognizedGlyph, isNull);
    });

    test('a descending arm (not ascending) is not צ', () {
      final layer = HebrewLayer();
      drawTsadiBody(layer);
      drawStroke(layer, const Offset(190, 130), const Offset(250, 210)); // \
      expect(layer.recognizedGlyph, isNull);
    });

    test('an arm that never meets the body is not צ', () {
      final layer = HebrewLayer();
      drawTsadiBody(layer);
      // An ascending diagonal off to the right, never crossing the body.
      drawStroke(layer, const Offset(300, 210), const Offset(360, 130));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('samech', () {
    const center = Offset(200, 180);
    const radius = 55.0;
    Offset polar(double deg) {
      final r = deg * math.pi / 180;
      return center + Offset(math.cos(r) * radius, math.sin(r) * radius);
    }

    // A 270° arc over the top, drawn as one stroke. With [crossing] true it
    // opens and closes with two tails at the bottom that cut across each
    // other — the samech loop lapping its tail over its head, one crossing.
    // With [crossing] false it's the bare open arc, meeting itself nowhere.
    void drawLoop(HebrewLayer layer, {bool crossing = true}) {
      const size = Size(400, 400);
      final points = <Offset>[];
      if (crossing) {
        // Left tail: bottom-left up to the lower-right arc mouth, so it will
        // cross the right tail coming the other way.
        for (var k = 0; k < 6; k++) {
          points.add(Offset.lerp(
              const Offset(170, 265), polar(45), k / 6)!);
        }
      }
      for (var i = 0; i <= 40; i++) {
        points.add(polar(45 - 270 * i / 40)); // 45° over the top to -225°
      }
      if (crossing) {
        // Right tail: lower-left arc mouth down to bottom-right, crossing the
        // left tail near (200, 245).
        for (var k = 1; k <= 6; k++) {
          points.add(Offset.lerp(polar(-225), const Offset(230, 265), k / 6)!);
        }
      }
      layer.handlePointerEvent(PointerDownEvent(position: points.first), size);
      for (var i = 1; i < points.length; i++) {
        layer.handlePointerEvent(PointerMoveEvent(position: points[i]), size);
      }
      layer.handlePointerEvent(PointerUpEvent(position: points.last), size);
    }

    test('a loop crossing itself once is ס', () {
      final layer = HebrewLayer();
      drawLoop(layer);
      expect(layer.recognizedGlyph, 'ס');
    });

    test('an open arc that never laps over itself is not ס', () {
      final layer = HebrewLayer();
      drawLoop(layer, crossing: false);
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('ayin', () {
    // A wide descending left arm (\, top-left → bottom-right) bracketing a
    // rising right arm (/, bottom-left → top-right): the descender's start left
    // of the ascender's start, the ascender's end left of the descender's end.
    void drawAyin(HebrewLayer layer) {
      drawStroke(layer, const Offset(150, 140), const Offset(300, 300)); // \
      drawStroke(layer, const Offset(200, 300), const Offset(290, 160)); // /
    }

    test('a falling left arm bracketing a rising right arm (an X) is ע', () {
      final layer = HebrewLayer();
      drawAyin(layer);
      expect(layer.recognizedGlyph, 'ע');
    });

    test('ע drawn ascending-arm-first still reads as ע', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(200, 300), const Offset(290, 160)); // /
      drawStroke(layer, const Offset(150, 140), const Offset(300, 300)); // \
      expect(layer.recognizedGlyph, 'ע');
    });

    test('a near-vertical falling arm and a curved rising arm still read as ע',
        () {
      final layer = HebrewLayer();
      // Left arm too steep to be a diagonal (≈2.5:1), yet its endpoints fall.
      drawStroke(layer, const Offset(95, 70), const Offset(160, 235)); // \ steep
      // Right arm curved (a bend), yet its endpoints rise; crosses near the
      // bottom. Endpoint rule holds: 95<210 and 75<160.
      drawCorner(layer, const Offset(210, 45), const Offset(200, 150),
          const Offset(75, 220)); // / curved
      expect(layer.recognizedGlyph, 'ע');
    });

    test('an ascending arm whose end kicks right past the descender is ג, not ע',
        () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(170, 120), const Offset(260, 280)); // \
      // The arm's end (280) lands right of the descender's end (260) — gimel's
      // foot, failing ayin's second endpoint test.
      drawStroke(layer, const Offset(200, 290), const Offset(280, 200)); // /
      expect(layer.recognizedGlyph, 'ג');
    });

    test('a short arm above whose end kicks right is ץ, not ע', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(170, 150), const Offset(260, 290)); // \
      // Arm end (280) right of the descender's end (260) — final tsadi's flag.
      drawStroke(layer, const Offset(200, 240), const Offset(280, 160)); // /
      expect(layer.recognizedGlyph, 'ץ');
    });

    test('two diagonals that never cross are not ע', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(150, 140), const Offset(210, 220)); // \
      // A rising arm off to the lower right, never meeting the \.
      drawStroke(layer, const Offset(260, 320), const Offset(350, 180)); // /
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('gimel', () {
    // A descending line (\) crossed once by an ascending diagonal (/) whose
    // body sits below the descender — the foot of ג.
    void drawGimel(HebrewLayer layer) {
      drawStroke(layer, const Offset(180, 160), const Offset(260, 300)); // \
      drawStroke(layer, const Offset(200, 300), const Offset(280, 220)); // / below
    }

    test('a descending line crossed by an ascending arm below it is ג', () {
      final layer = HebrewLayer();
      drawGimel(layer);
      expect(layer.recognizedGlyph, 'ג');
    });

    test('ג drawn arm-first still reads as ג', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(200, 300), const Offset(280, 220)); // /
      drawStroke(layer, const Offset(180, 160), const Offset(260, 300)); // \
      expect(layer.recognizedGlyph, 'ג');
    });

    test('the same descender with the arm above it is ץ, not ג', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(180, 160), const Offset(260, 300)); // \
      drawStroke(layer, const Offset(220, 240), const Offset(300, 160)); // / above-right
      expect(layer.recognizedGlyph, 'ץ');
    });

    test('a gently hooked (curved) descender crossed below is still ג', () {
      final layer = HebrewLayer();
      // A descending diagonal that bows ~30px off its chord — a soft hook,
      // past the strict straightness bound but within the loose one, and not a
      // hard corner.
      const size = Size(400, 400);
      const body = [
        Offset(170, 160),
        Offset(175, 208),
        Offset(196, 243),
        Offset(231, 269),
        Offset(270, 290),
      ];
      layer.handlePointerEvent(PointerDownEvent(position: body.first), size);
      for (var i = 1; i < body.length; i++) {
        layer.handlePointerEvent(PointerMoveEvent(position: body[i]), size);
      }
      layer.handlePointerEvent(PointerUpEvent(position: body.last), size);
      drawStroke(layer, const Offset(210, 300), const Offset(290, 230)); // / below
      expect(layer.recognizedGlyph, 'ג');
    });

    test('two descending diagonals (no ascending arm) are not ג', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(180, 160), const Offset(260, 300)); // \
      drawStroke(layer, const Offset(200, 160), const Offset(280, 300)); // \
      expect(layer.recognizedGlyph, isNull);
    });

    test('an ascending arm that never meets the descender is not ג', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(180, 160), const Offset(230, 300)); // \
      // An ascending diagonal off to the lower right, never crossing the \.
      drawStroke(layer, const Offset(280, 320), const Offset(360, 240)); // /
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('lamed', () {
    // A tall one-stroke ל: from the top, down-left into the body, swinging
    // right and down, then a foot kicking back to the left. The straight line
    // from the start to the foot's centre cuts back across the body once.
    void drawLamed(HebrewLayer layer, {int steps = 15}) {
      const size = Size(400, 400);
      const waypoints = [
        Offset(210, 120), // top start
        Offset(150, 190), // down-left into the body
        Offset(230, 270), // swing right and down
        Offset(150, 290), // foot kicking left
      ];
      final points = <Offset>[waypoints.first];
      for (var leg = 1; leg < waypoints.length; leg++) {
        for (var i = 1; i <= steps; i++) {
          points.add(Offset.lerp(
              waypoints[leg - 1], waypoints[leg], i / steps)!);
        }
      }
      layer.handlePointerEvent(PointerDownEvent(position: points.first), size);
      for (var i = 1; i < points.length; i++) {
        layer.handlePointerEvent(PointerMoveEvent(position: points[i]), size);
      }
      layer.handlePointerEvent(PointerUpEvent(position: points.last), size);
    }

    test('a tall hooked stroke with a leftward foot that the top-to-foot line '
        'recrosses is ל', () {
      final layer = HebrewLayer();
      drawLamed(layer);
      expect(layer.recognizedGlyph, 'ל');
    });

    test('a plain giyeok corner (foot dropping down, not left) is still ר, '
        'not ל', () {
      final layer = HebrewLayer();
      drawBaseCorner(layer);
      expect(layer.recognizedGlyph, 'ר');
    });
  });

  group('mem', () {
    // Feeds a single stroke tracing [waypoints], each leg a run of moves.
    void drawPath(HebrewLayer layer, List<Offset> waypoints, {int steps = 12}) {
      const size = Size(400, 400);
      final points = <Offset>[waypoints.first];
      for (var leg = 1; leg < waypoints.length; leg++) {
        for (var i = 1; i <= steps; i++) {
          points.add(Offset.lerp(waypoints[leg - 1], waypoints[leg], i / steps)!);
        }
      }
      layer.handlePointerEvent(PointerDownEvent(position: points.first), size);
      for (var i = 1; i < points.length; i++) {
        layer.handlePointerEvent(PointerMoveEvent(position: points[i]), size);
      }
      layer.handlePointerEvent(PointerUpEvent(position: points.last), size);
    }

    // The body: up the left wall, then a hood right and back down-left.
    void drawMemBody(HebrewLayer layer) {
      drawPath(layer, const [
        Offset(120, 240), // start, bottom
        Offset(120, 120), // apex — climb ends
        Offset(200, 140), // out to the right
        Offset(150, 220), // back left and down
      ]);
    }

    test('a climbing body with a right-left hood, its lead crossed by a '
        'descending line, is מ', () {
      final layer = HebrewLayer();
      drawMemBody(layer);
      drawStroke(layer, const Offset(90, 150), const Offset(150, 210)); // \
      expect(layer.recognizedGlyph, 'מ');
    });

    test('מ drawn line-first still reads as מ', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(90, 150), const Offset(150, 210)); // \
      drawMemBody(layer);
      expect(layer.recognizedGlyph, 'מ');
    });

    test('the body with no crossing line is not מ', () {
      final layer = HebrewLayer();
      drawMemBody(layer);
      // A descending diagonal off to the right, never meeting the lead.
      drawStroke(layer, const Offset(260, 150), const Offset(320, 210));
      expect(layer.recognizedGlyph, isNot('מ'));
    });

    test('a straight descender crossed by an ascending arm (no hood) is not מ',
        () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(120, 120), const Offset(200, 260)); // \ body
      drawStroke(layer, const Offset(130, 240), const Offset(210, 160)); // /
      expect(layer.recognizedGlyph, isNot('מ'));
    });
  });

  group('tet', () {
    // Feeds a single stroke tracing [waypoints], each leg sampled as a run of
    // moves — used for the multi-turn ט shape.
    void drawPath(HebrewLayer layer, List<Offset> waypoints, {int steps = 12}) {
      const size = Size(400, 400);
      final points = <Offset>[waypoints.first];
      for (var leg = 1; leg < waypoints.length; leg++) {
        for (var i = 1; i <= steps; i++) {
          points.add(Offset.lerp(waypoints[leg - 1], waypoints[leg], i / steps)!);
        }
      }
      layer.handlePointerEvent(PointerDownEvent(position: points.first), size);
      for (var i = 1; i < points.length; i++) {
        layer.handlePointerEvent(PointerMoveEvent(position: points[i]), size);
      }
      layer.handlePointerEvent(PointerUpEvent(position: points.last), size);
    }

    test('an upward climb then a downward cup is ט', () {
      final layer = HebrewLayer();
      // Up the left wall (blue), then a cup down and back up (red).
      drawPath(layer, const [
        Offset(120, 240), // start, bottom
        Offset(120, 100), // apex — climb ends here
        Offset(170, 200), // cup floor
        Offset(220, 100), // cup's right lip, back up top
      ]);
      expect(layer.recognizedGlyph, 'ט');
    });

    test('a plain downward cup (no leading climb) is ט', () {
      final layer = HebrewLayer();
      drawPath(layer, const [
        Offset(120, 100),
        Offset(170, 200),
        Offset(220, 100),
      ]);
      expect(layer.recognizedGlyph, 'ט');
    });

    test('an upward arch (bulging up, endpoints low) is not ט', () {
      final layer = HebrewLayer();
      drawPath(layer, const [
        Offset(120, 200),
        Offset(170, 100),
        Offset(220, 200),
      ]);
      expect(layer.recognizedGlyph, isNot('ט'));
    });

    test('a plain vertical line is not ט', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(150, 100), const Offset(150, 260));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('kaf / nun', () {
    // A leftward-opening hump: top bar right, down the right side, bottom bar
    // back left — both endpoints stacked on the left, bulging right.
    void drawHump(HebrewLayer layer, {required double width, double height = 120,
        int steps = 12}) {
      const size = Size(400, 400);
      const left = 120.0, top = 90.0;
      final corners = [
        const Offset(left, top),
        Offset(left + width, top),
        Offset(left + width, top + height),
        Offset(left, top + height),
      ];
      final points = <Offset>[corners.first];
      for (var leg = 1; leg < corners.length; leg++) {
        for (var i = 1; i <= steps; i++) {
          points.add(Offset.lerp(corners[leg - 1], corners[leg], i / steps)!);
        }
      }
      layer.handlePointerEvent(PointerDownEvent(position: points.first), size);
      for (var i = 1; i < points.length; i++) {
        layer.handlePointerEvent(PointerMoveEvent(position: points[i]), size);
      }
      layer.handlePointerEvent(PointerUpEvent(position: points.last), size);
    }

    test('a wide leftward-opening hump is כ', () {
      final layer = HebrewLayer();
      drawHump(layer, width: 90, height: 120); // under 2x tall → wide
      expect(layer.recognizedGlyph, 'כ');
    });

    test('a narrow (tall, thin) leftward-opening hump is נ', () {
      final layer = HebrewLayer();
      drawHump(layer, width: 40, height: 130); // over 2x tall → narrow
      expect(layer.recognizedGlyph, 'נ');
    });

    test('a hump opening the other way (endpoints on the right) is not כ/נ', () {
      final layer = HebrewLayer();
      // Mirror image: a giyeok-style corner, endpoints not both on the left.
      drawCorner(layer, const Offset(150, 120), const Offset(250, 120),
          const Offset(250, 260));
      expect(layer.recognizedGlyph, isNot('כ'));
    });

    test('a plain vertical line (no rightward bulge) is not כ/נ', () {
      final layer = HebrewLayer();
      drawStroke(layer, const Offset(150, 100), const Offset(150, 260));
      expect(layer.recognizedGlyph, isNull);
    });
  });

  group('pe', () {
    // The outer hump, same as kaf: top bar right, down the right, bottom bar
    // back left — both endpoints on the left, bulging right.
    void drawHump(HebrewLayer layer, {double width = 90, double height = 120,
        int steps = 12}) {
      const size = Size(400, 400);
      const left = 120.0, top = 90.0;
      final corners = [
        const Offset(left, top),
        Offset(left + width, top),
        Offset(left + width, top + height),
        Offset(left, top + height),
      ];
      final points = <Offset>[corners.first];
      for (var leg = 1; leg < corners.length; leg++) {
        for (var i = 1; i <= steps; i++) {
          points.add(Offset.lerp(corners[leg - 1], corners[leg], i / steps)!);
        }
      }
      layer.handlePointerEvent(PointerDownEvent(position: points.first), size);
      for (var i = 1; i < points.length; i++) {
        layer.handlePointerEvent(PointerMoveEvent(position: points[i]), size);
      }
      layer.handlePointerEvent(PointerUpEvent(position: points.last), size);
    }

    // A nieun (ㄴ) whose left leg pokes down through the hump's top bar once,
    // its foot stopping short of the hump's right side.
    void drawTongue(HebrewLayer layer) {
      drawCorner(layer, const Offset(160, 60), const Offset(160, 130),
          const Offset(195, 130));
    }

    test('a leftward hump with a nieun poking in from the top is פ', () {
      final layer = HebrewLayer();
      drawHump(layer);
      drawTongue(layer);
      expect(layer.recognizedGlyph, 'פ');
    });

    test('פ drawn nieun-first still reads as פ', () {
      final layer = HebrewLayer();
      drawTongue(layer);
      drawHump(layer);
      expect(layer.recognizedGlyph, 'פ');
    });

    test('the hump alone (no nieun) is כ, not פ', () {
      final layer = HebrewLayer();
      drawHump(layer);
      expect(layer.recognizedGlyph, 'כ');
    });

    test('a hump with a nieun that misses it (no crossing) is not פ', () {
      final layer = HebrewLayer();
      drawHump(layer);
      // A nieun off to the right, clear of the hump.
      drawCorner(layer, const Offset(260, 60), const Offset(260, 130),
          const Offset(300, 130));
      expect(layer.recognizedGlyph, isNot('פ'));
    });
  });

  group('tav', () {
    // A giyeok (ㄱ): top bar right, then the right leg down.
    void drawGiyeok(HebrewLayer layer) {
      drawCorner(layer, const Offset(150, 80), const Offset(280, 80),
          const Offset(280, 240));
    }

    // A mirrored nieun (ㄴ with the foot kicking left): leg down through the
    // top bar, then the foot to the left.
    void drawLeftNieun(HebrewLayer layer) {
      drawCorner(layer, const Offset(190, 50), const Offset(190, 200),
          const Offset(140, 200));
    }

    test('a giyeok crossed from the top by a left-footed nieun is ת', () {
      final layer = HebrewLayer();
      drawGiyeok(layer);
      drawLeftNieun(layer);
      expect(layer.recognizedGlyph, 'ת');
    });

    test('ת drawn nieun-first still reads as ת', () {
      final layer = HebrewLayer();
      drawLeftNieun(layer);
      drawGiyeok(layer);
      expect(layer.recognizedGlyph, 'ת');
    });

    test('a nieun footing right (not left) is not ת', () {
      final layer = HebrewLayer();
      drawGiyeok(layer);
      // Standard ㄴ — foot to the right, the wrong direction for tav.
      drawCorner(layer, const Offset(190, 50), const Offset(190, 200),
          const Offset(240, 200));
      expect(layer.recognizedGlyph, isNot('ת'));
    });

    test('a left nieun that misses the giyeok (no crossing) is not ת', () {
      final layer = HebrewLayer();
      drawGiyeok(layer);
      // Off to the left, its leg clear of the top bar.
      drawCorner(layer, const Offset(120, 150), const Offset(120, 250),
          const Offset(70, 250));
      expect(layer.recognizedGlyph, isNot('ת'));
    });
  });

  test('a plain line on its own is not a letter', () {
    final layer = HebrewLayer();
    drawStroke(layer, const Offset(150, 200), const Offset(300, 200));
    expect(layer.recognizedGlyph, isNull);
  });

  test('clear() forgets the drawing', () {
    final layer = HebrewLayer();
    drawBaseCorner(layer);
    drawStroke(layer, const Offset(200, 200), const Offset(300, 200));
    expect(layer.recognizedGlyph, 'ב');
    layer.clear();
    expect(layer.recognizedGlyph, isNull);
  });
}
