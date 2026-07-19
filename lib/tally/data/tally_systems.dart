import '../engine/scene.dart';
import '../scenes/card_tally_scene.dart';
import '../scenes/chinese_tally_scene.dart';
import '../scenes/dot_dash_scene.dart';
import '../scenes/hindu_arabic_five_scene.dart';
import '../scenes/tally_scene.dart';

/// One tally-mark system: the metadata for its reference-table entry plus the
/// [Scene] you draw it on. This is the single source of truth for the Tally
/// Marks page — the dropdown, the reference table, and the canvas all read
/// from [tallySystems], and each system's [slug] is what round-trips through
/// the URL's `?system=` query param.
///
/// Facts (base, region, how it's drawn, Unicode) are from Wikipedia's
/// "Tally marks" article: https://en.wikipedia.org/wiki/Tally_marks
class TallySystem {
  const TallySystem({
    required this.slug,
    required this.name,
    required this.base,
    required this.region,
    required this.howToDraw,
    required this.about,
    required this.buildScene,
    this.unicode,
  });

  /// URL-safe id used in `?system=<slug>`.
  final String slug;
  final String name;

  /// Marks per completed cluster (5 for most, 10 for dot-dash).
  final int base;
  final String region;

  /// One-line "how to build a cluster" summary.
  final String howToDraw;

  /// A sentence of background/origin.
  final String about;

  /// The dedicated Unicode character(s), if any exist for this system.
  final String? unicode;

  final Scene Function() buildScene;
}

/// All tally systems the page offers, in dropdown/table order. Add one by
/// dropping a `*_scene.dart` with a `buildXScene()` and appending an entry.
const List<TallySystem> tallySystems = [
  TallySystem(
    slug: 'five-bar-gate',
    name: 'Western (five-bar gate)',
    base: 5,
    region: 'Europe, Anglosphere, Southern Africa',
    howToDraw: 'Four vertical strokes, then a fifth crossing all four '
        'diagonally to close the group of five.',
    about: 'The classic "five-bar gate": the fifth stroke closes out a '
        'group of five.',
    unicode: '𝍷 U+1D377 (one) · 𝍸 U+1D378 (five)',
    buildScene: buildTallyScene,
  ),
  TallySystem(
    slug: 'dot-dash',
    name: 'Dot-and-line (dot-dash)',
    base: 10,
    region: 'Forestry and surveying',
    howToDraw: 'Four dots (1–4), then four sides forming a square (5–8), '
        'then two diagonals (9–10).',
    about: 'A base-ten cluster used in forestry: dots, then sides, then '
        'diagonals build up to ten.',
    buildScene: buildDotDashScene,
  ),
  TallySystem(
    slug: 'zheng',
    name: 'East Asian (正)',
    base: 5,
    region: 'China, Japan, Korea, Taiwan',
    howToDraw: 'Draw the character 正 one stroke at a time in stroke order; '
        'five strokes complete a count of five.',
    about: 'Each completed 正 (zhèng) equals five — chosen for how naturally '
        'it is written stroke by stroke.',
    unicode: '正 U+6B63',
    buildScene: buildChineseTallyScene,
  ),
  TallySystem(
    slug: 'card',
    name: 'Iberian card-game',
    base: 5,
    region: 'France, Iberia & Latin America',
    howToDraw: 'Four strokes forming a box, closed by a diagonal slash for '
        'the fifth.',
    about: 'A boxed variant used mainly for registering card-game scores '
        '(e.g. Truco).',
    buildScene: buildCardTallyScene,
  ),
  TallySystem(
    slug: 'five',
    name: 'Hindu-Arabic five (5)',
    base: 5,
    region: 'App variant — not a historical tally',
    howToDraw: 'Write the digit "5" seven-segment style: top bar, upper-left, '
        'middle, lower-right, bottom.',
    about: 'Not a historical clustering method — included here as a '
        'stroke-checked way to write the numeral five.',
    buildScene: buildHinduArabicFiveScene,
  ),
];

/// The system for [slug], or the first system if [slug] is null/unknown — so
/// a missing or hand-edited `?system=` param can't land the page in an
/// invalid state.
TallySystem tallySystemForSlug(String? slug) {
  for (final system in tallySystems) {
    if (system.slug == slug) return system;
  }
  return tallySystems.first;
}
