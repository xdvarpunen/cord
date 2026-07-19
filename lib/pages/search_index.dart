import 'package:flutter/material.dart';

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
/// every tally system (the Tally page's dropdown content). Built from the
/// same registries the rest of the app uses, so search never goes stale.
///
/// A future page with its own dropdown content adds its items here the same
/// way the tally systems do.
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
    ];
