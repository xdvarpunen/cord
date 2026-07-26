import 'package:flutter/material.dart';

import '../cyrillic/pages/cyrillic_page.dart';
import '../etruscan/pages/etruscan_page.dart';
import '../furthak/pages/futhark_page.dart';
import '../hangul/pages/hangul_page.dart';
import '../hangul_grid/pages/hangul_grid_page.dart';
import '../hanzi/pages/hanzi_grid_page.dart';
import '../hebrew/pages/hebrew_page.dart';
import '../morse/pages/morse_page.dart';
import '../ogham/pages/ogham_page.dart';
import '../suzhou/pages/suzhou_page.dart';
import '../tally/pages/tally_page.dart';
import '../tomtom/pages/tomtom_page.dart';
import '../tartessian/pages/tartessian_page.dart';
import '../tifi/pages/tifinagh_page.dart';
import 'search_page.dart';

/// One entry in the app's page registry: everything the frontpage needs to
/// render a link to a page, plus how to build the page itself.
///
/// This is the single source of truth for the app's pages — both the
/// frontpage's link cards ([HomePage]) and the app's named routes
/// ([CordApp]) are generated from [appPages], so adding a page here wires
/// it up in both places at once.
class AppPage {
  const AppPage({
    required this.route,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  /// The named route this page lives at, e.g. `/one`. Also its deep link.
  final String route;
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
}

/// The pages the frontpage links to. Add a page by dropping a new widget in
/// `lib/pages/` and appending an [AppPage] here — the home screen and the
/// route table both pick it up automatically.
final List<AppPage> appPages = [
  AppPage(
    route: '/search',
    title: 'Search',
    subtitle: 'Find any page or tally system and jump to it.',
    icon: Icons.search,
    builder: (_) => const SearchPage(),
  ),
  AppPage(
    route: '/tally',
    title: 'Tally Marks',
    subtitle: 'Freehand tally-mark counting games.',
    icon: Icons.tag,
    builder: (_) => const TallyPage(),
  ),
  AppPage(
    route: '/futhark',
    title: 'Futhark',
    subtitle: 'Freehand Futhark rune recognition.',
    icon: Icons.gesture,
    builder: (_) => const FutharkPage(),
  ),
  AppPage(
    route: '/tifinagh',
    title: 'Tifinagh',
    subtitle: 'Freehand Tifinagh letter recognition.',
    icon: Icons.translate,
    builder: (_) => const TifinaghPage(),
  ),
  AppPage(
    route: '/tartessian',
    title: 'Tartessian',
    subtitle: 'Freehand Tartessian (Southwestern) sign recognition.',
    icon: Icons.translate,
    builder: (_) => const TartessianPage(),
  ),
  AppPage(
    route: '/ogham',
    title: 'Ogham',
    subtitle: 'Freehand Ogham letter recognition.',
    icon: Icons.gesture,
    builder: (_) => const OghamPage(),
  ),
  AppPage(
    route: '/morse',
    title: 'Morse',
    subtitle: 'Freehand Morse code decoding.',
    icon: Icons.more_horiz,
    builder: (_) => const MorsePage(),
  ),
  AppPage(
    route: '/tomtom',
    title: 'Tom-Tom Code',
    subtitle: 'Freehand Tom-Tom code decoding.',
    icon: Icons.swap_vert,
    builder: (_) => const TomtomPage(),
  ),
  AppPage(
    route: '/etruscan',
    title: 'Etruscan Numerals',
    subtitle: 'Freehand Etruscan numeral recognition.',
    icon: Icons.pin,
    builder: (_) => const EtruscanPage(),
  ),
  AppPage(
    route: '/suzhou',
    title: 'Suzhou Numerals',
    subtitle: 'Freehand Suzhou (huāmǎ) rod numeral recognition.',
    icon: Icons.calculate,
    builder: (_) => const SuzhouPage(),
  ),
  AppPage(
    route: '/hangul',
    title: 'Hangul',
    subtitle: 'Freehand Hangul jamo (Korean letter) recognition.',
    icon: Icons.translate,
    builder: (_) => const HangulPage(),
  ),
  AppPage(
    route: '/hangul-grid',
    title: 'Hangul Grid',
    subtitle: 'Whole Hangul syllables in notebook squares, each row read out.',
    icon: Icons.grid_on,
    builder: (_) => const HangulGridPage(),
  ),
  AppPage(
    route: '/hanzi',
    title: 'Hanzi Grid',
    subtitle: 'Whole Han characters in notebook squares, each row read out.',
    icon: Icons.border_all,
    builder: (_) => const HanziGridPage(),
  ),
  AppPage(
    route: '/cyrillic',
    title: 'Cyrillic',
    subtitle: 'Freehand Cyrillic letter recognition (Russian alphabet).',
    icon: Icons.translate,
    builder: (_) => const CyrillicPage(),
  ),
  AppPage(
    route: '/hebrew',
    title: 'Hebrew',
    subtitle: 'Freehand Hebrew letter recognition (modern square script).',
    icon: Icons.translate,
    builder: (_) => const HebrewPage(),
  ),
];
