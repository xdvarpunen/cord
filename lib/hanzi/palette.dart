import 'package:flutter/material.dart';

import 'data/stroke_models.dart';

/// Palette, ported with the rest of this feature from the `hanzi` project,
/// where it lives at the top of `lib/painters/stroke_cell_painter.dart` rather
/// than in a file of its own: warm paper, near-black ink, and accents that
/// carry meaning rather than decoration.
///
/// Local to `lib/hanzi/` on purpose — like every other feature here it shares
/// nothing with its neighbours, and the squares are meant to look like a
/// notebook page rather than like the app's Material surface.
///
/// The tonal scale is [kInk] at reduced alpha, never a lighter colour — that
/// is what keeps every shade in the same warm family as the paper.
const Color kPaper = Color(0xFFFAF7F0); // warm off-white — every background
const Color kInk = Color(0xFF2B2B2B); // near-black — every glyph and label

/// Vermilion. The pen: what you are writing now, the square you are in, and
/// anything destructive.
const Color kPenColor = Color(0xFFC4462F);

/// Teal. Settled and correct: a square that came out as a character.
const Color kStartColor = Color(0xFF1B806A);

/// One colour per writing tradition, for the labels under a square. Chosen to
/// be told apart at 12pt on paper, not to stand for a flag.
const Color kChinaColor = Color(0xFFB03A2E);
const Color kJapanColor = Color(0xFF2A6F97);
const Color kKoreaColor = Color(0xFF6B4E9E);

/// The colour a tradition is written in. From `order_common.dart` upstream.
Color accentOf(Lang lang) => switch (lang) {
      Lang.zh => kChinaColor,
      Lang.ja => kJapanColor,
      Lang.ko => kKoreaColor,
    };

/// The font family for every Han-bearing [TextStyle] here, or null to fall
/// back to whatever the browser resolves for Han.
///
/// Null, and upstream `hanzi` bundles nothing either — it draws every glyph
/// that has to be exact from vector stroke data and leaves plain [Text] to the
/// platform. Han has a fallback everywhere that matters: SimSun and Microsoft
/// YaHei on Windows, PingFang on macOS, Noto Sans CJK on Linux and Android.
/// A Han subset is also far larger than the 2.3 MB Korean one the Hangul Grid
/// page next door already declined to ship. Setting this to a bundled family
/// (and declaring it in `pubspec.yaml`) is the entire change if that ever
/// stops being true.
const String? kHanziFont = null;
