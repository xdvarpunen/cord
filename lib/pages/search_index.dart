import 'package:flutter/material.dart';

// Greek has an `Alphabet` of its own, wholly unrelated to Latin's, and the two
// features share nothing — so it comes in under a prefix rather than one of
// them being renamed to suit this file.
import '../greek/data/greek_letters.dart' as greek;
import '../greek/pages/greek_page.dart';
import '../hanzi/data/hanzi_scripts.dart';
import '../hanzi/pages/hanzi_grid_page.dart';
import '../latin/data/latin_letters.dart';
import '../latin/pages/latin_page.dart';
import '../makasar/data/script.dart';
import '../makasar/pages/makasar_page.dart';
import '../makasar/pages/makasar_reference.dart';
import '../tally/data/tally_systems.dart';
import '../tally/pages/tally_page.dart';
import 'app_pages.dart';

/// One searchable, navigable thing shown on the search page: a page, or an
/// item from a page's dropdown (e.g. a tally system). Tapping it opens
/// [builder] at [route].
class SearchEntry {
  const SearchEntry({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.builder,
    this.icon,
    this.glyphSlug,
    this.keywords = '',
  });

  final String title;
  final String subtitle;

  /// Route name to open under — becomes the browser URL for the target.
  final String route;
  final WidgetBuilder builder;

  /// Leading icon, used when [glyphSlug] is null.
  final IconData? icon;

  /// If set, the leading widget is a drawn [TallyGlyph] for this system slug
  /// instead of [icon].
  final String? glyphSlug;

  /// Extra terms to match on that aren't shown (e.g. slug, region synonyms).
  final String keywords;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final haystack = '$title $subtitle $keywords'.toLowerCase();
    return haystack.contains(query.toLowerCase());
  }
}

/// Everything the search page lists: each page (except search itself), then
/// every tally system, every Hanzi Grid script, every Latin alphabet, every
/// Greek one and each of Makasar's two scripts — the five pages that have
/// dropdown content of their own. Built from the same registries the rest of
/// the app uses, so search never goes stale.
///
/// A future page with its own dropdown content adds its items here the same
/// way these five do.
List<SearchEntry> buildSearchIndex() => [
      for (final page in appPages)
        if (page.route != '/search')
          SearchEntry(
            title: page.title,
            subtitle: 'Page',
            route: page.route,
            icon: page.icon,
            builder: page.builder,
          ),
      for (final system in tallySystems)
        SearchEntry(
          title: system.name,
          subtitle: 'Tally Marks · base ${system.base} · ${system.region}',
          route: '/tally',
          glyphSlug: system.slug,
          keywords: '${system.slug} tally marks ${system.region}',
          builder: (_) => TallyPage(initialSystem: system.slug),
        ),
      // "Everything" is skipped: it is what `/hanzi` already opens on, so a
      // row for it would just duplicate the page's own entry above.
      for (final script in hanziScripts)
        if (script.slug != 'all')
          SearchEntry(
            title: script.name,
            subtitle: 'Hanzi Grid · ${script.count} characters',
            route: '/hanzi',
            icon: Icons.border_all,
            keywords: '${script.slug} hanzi han kanji hanja cjk characters '
                'stroke order grid',
            builder: (_) => HanziGridPage(initialScript: script.slug),
          ),
      // None is skipped, unlike Hanzi Grid's "Everything" above: the Latin page
      // opens on English, but "English" is a term someone would search for, and
      // the alphabet called Latin (the classical 23) is a different thing from
      // the page called Latin. Both earn their row.
      for (final alphabet in Alphabet.values)
        SearchEntry(
          title: alphabet.label,
          subtitle:
              'Latin · ${alphabet.rows.length} letters · ${alphabet.note}',
          route: '/latin',
          icon: Icons.abc,
          keywords:
              '${alphabet.name} latin alphabet letters ${alphabet.letters}',
          builder: (_) => LatinPage(initialAlphabet: alphabet.name),
        ),
      // None is skipped here either, and for the same reason as Latin's: the
      // page opens on the classical 24, but "Greek" names both the page and
      // that one alphabet of the three, and the other two are what someone
      // searching "Old Attic" or "archaic" is after.
      for (final alphabet in greek.Alphabet.values)
        SearchEntry(
          title: alphabet.label,
          subtitle:
              'Greek · ${alphabet.rows.length} letters · ${alphabet.note}',
          route: '/greek',
          icon: Icons.translate,
          keywords:
              '${alphabet.name} greek alphabet letters ${alphabet.letters}',
          builder: (_) => GreekPage(initialAlphabet: alphabet.name),
        ),
      // Both again, on the same reasoning: the page opens on Makasar, but
      // Bugis (Lontara) is the sibling script someone would search for by
      // name, and "Makasar" the script is worth its own row beside "Makasar"
      // the page — the row says how much of the script there is.
      for (final script in WritingScript.values)
        SearchEntry(
          title: script.label,
          subtitle: 'Makasar · ${legendFor(script)}',
          route: '/makasar',
          icon: Icons.draw,
          keywords: '${script.name} makasar lontara bugis buginese '
              'makassarese south sulawesi abugida jangang-jangang',
          builder: (_) => MakasarPage(initialScript: script.name),
        ),
    ];
