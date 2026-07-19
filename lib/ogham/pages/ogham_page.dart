import 'package:flutter/material.dart';

import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../scenes/ogham_scene.dart';
import 'ogham_tables.dart';
import 'reference_page.dart';

/// Freehand Ogham letter recognition, ported from the `shorthand` project's
/// Ogham processor (recovered from its git history) and self-contained under
/// `lib/ogham/` — it shares no engine/scene/data with the other script
/// features.
///
/// Letters are drawn on a central horizontal stemline: strokes above it,
/// below it, or across it spell the consonants (1–5 strokes each), and
/// notches tapped on the line spell the vowels. Marks are recognized live as
/// you draw, and Clear wipes the canvas.
///
/// On **desktop** (wide) the letter reference sits beside the canvas in a
/// 50/50 split. On narrow/mobile an info button in the app bar opens the
/// full-screen [ReferencePage] instead.
class OghamPage extends StatefulWidget {
  const OghamPage({super.key});

  @override
  State<OghamPage> createState() => _OghamPageState();
}

/// Below this width the reference table moves out of the 50/50 side panel and
/// behind the app-bar info button.
const _wideBreakpoint = 720.0;

class _OghamPageState extends State<OghamPage> {
  late final (Scene, OghamLayer) _built = buildOghamScene();
  late final _sceneManager = SceneManager(_built.$1);

  void _openReference() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReferencePage()),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final canvas = ClipRect(child: GameCanvas(sceneManager: _sceneManager));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ogham'),
        actions: [
          if (!wide)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Letter reference',
              onPressed: _openReference,
            ),
        ],
      ),
      body: Column(
        children: [
          _controlBar(context),
          const Divider(height: 1),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      Expanded(child: canvas),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: const OghamTable(),
                        ),
                      ),
                    ],
                  )
                : canvas,
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
          const Expanded(
            child: Text(
              'Draw on the stemline — strokes below spell B L F S N, above '
              'H D T C Q, across M G NG Z R; tap notches on the line for the '
              'vowels A O U E I.',
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => _built.$2.clear(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
