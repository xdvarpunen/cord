import 'package:flutter/material.dart';

import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../scenes/cyrillic_scene.dart';
import 'cyrillic_reference.dart';
import 'reference_page.dart';

/// Freehand Cyrillic letter recognition, ported from the standalone
/// `cyrillic` project and self-contained under `lib/cyrillic/` — it shares no
/// engine/scene/data with the other script features.
///
/// Draw a printed (block) capital on the paper — a corner (Г), a stem with
/// bars (Е), crossed diagonals (Х), a loop (О) — and the recognized letter,
/// its name, and its sound update live below the canvas. Ё is the one letter
/// built from taps: draw an Е, then tap its two dots above it. Clear wipes
/// the canvas.
///
/// On **desktop** (wide) the alphabet reference sits beside the canvas in a
/// 50/50 split. On narrow/mobile an info button in the app bar opens the
/// full-screen [ReferencePage] instead.
class CyrillicPage extends StatefulWidget {
  const CyrillicPage({super.key});

  @override
  State<CyrillicPage> createState() => _CyrillicPageState();
}

/// Below this width the reference legend moves out of the 50/50 side panel and
/// behind the app-bar info button.
const _wideBreakpoint = 720.0;

class _CyrillicPageState extends State<CyrillicPage> {
  late final (Scene, CyrillicLayer) _built = buildCyrillicScene();
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
        title: const Text('Cyrillic'),
        actions: [
          if (!wide)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Alphabet reference',
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
                          child: const CyrillicReference(),
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
              'Draw a printed capital: a corner (Г), a stem with bars (Е), '
              'crossed diagonals (Х), a loop (О). Ё is an Е plus two taps.',
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
