// This page is web-only (cord is a web app); it uses dart:html to sync the
// selected system into the URL, the same way tifi does.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../data/tally_systems.dart';
import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../widgets/tally_glyph.dart';

/// The Tally Marks page: pick a tally system from the dropdown — each option
/// shown with its drawn glyph — and draw it on the full-page canvas below,
/// with a Clear button beside the dropdown. Marks are recognized
/// geometrically, stroke by stroke (see the `lib/tally/scenes/` layers).
///
/// The selected system round-trips through the URL's `?system=` query param
/// (like tifi's `?region=`), so reloading or sharing the page URL preserves
/// it. The page itself lives at the `/tally` path (see [CordApp]'s routes and
/// `usePathUrlStrategy` in `main`).
class TallyPage extends StatefulWidget {
  const TallyPage({this.initialSystem, super.key});

  /// System to open on, overriding the URL's `?system=` — set when arriving
  /// from the search page so a result opens the right system. Null for normal
  /// navigation (frontpage/deep link), where the URL decides.
  final String? initialSystem;

  @override
  State<TallyPage> createState() => _TallyPageState();
}

class _TallyPageState extends State<TallyPage> {
  late String _slug = _initialSlug();
  late final SceneManager _sceneManager = SceneManager(_current.buildScene());

  TallySystem get _current => tallySystemForSlug(_slug);

  /// The system to start on: an explicit [TallyPage.initialSystem] wins,
  /// otherwise the URL's `?system=` (falling back to the first system).
  String _initialSlug() => widget.initialSystem != null
      ? tallySystemForSlug(widget.initialSystem).slug
      : _slugFromUrl();

  /// The `?system=` query param if it names a known system, else the first
  /// system (see [tallySystemForSlug]).
  static String _slugFromUrl() =>
      tallySystemForSlug(Uri.base.queryParameters['system']).slug;

  @override
  void initState() {
    super.initState();
    // Normalize the URL to the system actually shown — so opening `/tally`
    // (no query) or arriving from search both leave a shareable
    // `?system=<slug>` in the address bar.
    _updateUrl(_slug);
  }

  /// Rewrites `?system=` to [slug] without reloading or pushing a history
  /// entry — refresh/share keeps the selection, but flipping through systems
  /// doesn't stuff the back button (same approach as tifi).
  void _updateUrl(String slug) {
    final uri = Uri.base.replace(queryParameters: {'system': slug});
    html.window.history.replaceState(null, '', uri.toString());
  }

  void _select(String slug) {
    if (slug == _slug) return;
    setState(() {
      _slug = slug;
      _sceneManager.switchTo(_current.buildScene()); // fresh canvas
      _updateUrl(slug);
    });
  }

  /// Reset the current system's canvas to a fresh scene.
  void _clear() =>
      setState(() => _sceneManager.switchTo(_current.buildScene()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tally Marks')),
      body: Column(
        children: [
          _controlBar(context),
          const Divider(height: 1),
          Expanded(
            child: ClipRect(child: GameCanvas(sceneManager: _sceneManager)),
          ),
        ],
      ),
    );
  }

  Widget _controlBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('System'),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _slug,
              isExpanded: true,
              onChanged: (slug) => _select(slug!),
              items: [
                for (final system in tallySystems)
                  DropdownMenuItem(
                    value: system.slug,
                    // The glyph + name pairing from the old reference rows.
                    child: Row(
                      children: [
                        TallyGlyph(system.slug, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(system.name,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _clear,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
