import 'package:flutter/material.dart';

import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../scenes/tomtom_scene.dart';
import 'reference_page.dart';
import 'tomtom_tables.dart';

/// Freehand Tom-Tom code, ported from the `shorthand` project's Tom-Tom
/// interpreter (recovered from its git history) and self-contained under
/// `lib/tomtom/` — it shares no engine/scene/data with the other script
/// features.
///
/// Each letter is a run of near-vertical strokes drawn upward (↑) or downward
/// (↓); a horizontal stroke separates letters. The symbol stream and the
/// decoded text update live as you draw; Clear wipes the canvas.
///
/// On **desktop** (wide) the code reference sits beside the canvas in a 50/50
/// split. On narrow/mobile an info button in the app bar opens the
/// full-screen [ReferencePage] instead.
class TomtomPage extends StatefulWidget {
  const TomtomPage({super.key});

  @override
  State<TomtomPage> createState() => _TomtomPageState();
}

/// Below this width the reference table moves out of the 50/50 side panel and
/// behind the app-bar info button.
const _wideBreakpoint = 720.0;

class _TomtomPageState extends State<TomtomPage> {
  late final (Scene, TomtomLayer) _built = buildTomtomScene();
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
        title: const Text('Tom-Tom Code'),
        actions: [
          if (!wide)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Code reference',
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
                          child: const TomtomTable(),
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
              'Vertical stroke up = ↑  ·  down = ↓  ·  horizontal = separate '
              'letters. A run of ↑/↓ spells one letter.',
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
