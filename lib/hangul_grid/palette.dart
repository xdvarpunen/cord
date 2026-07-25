import 'package:flutter/material.dart';

/// Palette, ported with the rest of this feature from the `hangul-word`
/// project (which borrowed it from `hanzi`): warm paper, near-black ink, and
/// two accents that carry meaning rather than decoration.
///
/// Local to `lib/hangul_grid/` on purpose — like every other feature here it
/// shares nothing with its neighbours, and the squares are meant to look like
/// a notebook page rather than like the app's Material surface.
///
/// The tonal scale is [kInk] at reduced alpha, never a lighter colour — that
/// is what keeps every shade in the same warm family as the paper.
const Color kPaper = Color(0xFFFAF7F0); // warm off-white — every background
const Color kInk = Color(0xFF2B2B2B); // near-black — every glyph and label

/// Vermilion. The pen: what you are writing now, the block you are in, and
/// anything destructive.
const Color kPenColor = Color(0xFFC4462F);

/// Teal. Settled and correct: a committed letter, a matched target.
const Color kStartColor = Color(0xFF1B806A);

/// The Korean font family for every Hangul-bearing [TextStyle] here, or null
/// to fall back to whatever the browser resolves for Hangul.
///
/// Null in cord, where upstream `hangul-word` bundles a 2.3 MB NotoSansKR
/// subset: Korean *does* have a fallback everywhere that matters — Malgun
/// Gothic on Windows, Apple SD Gothic Neo on macOS, Noto Sans CJK KR on Linux
/// and Android — so bundling is a consistency upgrade, not a correctness fix,
/// and this is a web app that already ships two other font files. The Hangul
/// page next door renders its jamo the same way. Setting this to a bundled
/// family (and declaring it in `pubspec.yaml`) is the entire change if that
/// ever stops being true.
const String? kHangulFont = null;
