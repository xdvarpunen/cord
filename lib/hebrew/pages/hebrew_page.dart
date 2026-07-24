import 'package:flutter/material.dart';

import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../scenes/hebrew_scene.dart';
import 'hebrew_reference.dart';
import 'reference_page.dart';

/// Freehand Hebrew letter recognition, ported from the standalone `heb`
/// project and self-contained under `lib/hebrew/` — it shares no
/// engine/scene/data with the other script features.
///
/// This is the **modern square alef-bet only**: upstream `heb` also has a
/// Paleo-Hebrew mode behind a script dropdown, and that is deliberately left
/// out here (see `hebrew_letters.dart`), so there's no dropdown — the
/// recognizer stays in its default modern mode.
///
/// Draw a letter on the paper — a corner (ר/ו), a corner crossed by a line
/// (ב/ח), a loop (ס), one of the multi-stroke letters — and the recognized
/// letter, its name, and its sound update live below the canvas. Where a
/// shape is shared by several letters (resh/yod, vav/final nun,
/// dalet/final chaf) the label names the whole group. Clear wipes it.
///
/// On **desktop** (wide) the alef-bet reference sits beside the canvas in a
/// 50/50 split. On narrow/mobile an info button in the app bar opens the
/// full-screen [ReferencePage] instead.
class HebrewPage extends StatefulWidget {
  const HebrewPage({super.key});

  @override
  State<HebrewPage> createState() => _HebrewPageState();
}

/// Below this width the reference legend moves out of the 50/50 side panel and
/// behind the app-bar info button.
const _wideBreakpoint = 720.0;

class _HebrewPageState extends State<HebrewPage> {
  late final (Scene, HebrewLayer) _built = buildHebrewScene();
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
        title: const Text('Hebrew'),
        actions: [
          if (!wide)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Alef-bet reference',
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
                          child: const HebrewReference(),
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
              'Draw a letter: a corner (ר ו), a corner crossed by a line '
              '(ב ח), a loop (ס), or a multi-stroke letter (א ש מ).',
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
