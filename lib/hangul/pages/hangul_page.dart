import 'package:flutter/material.dart';

import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../scenes/hangul_scene.dart';
import 'hangul_reference.dart';
import 'reference_page.dart';

/// Freehand Hangul jamo recognition, ported from the standalone `hangul`
/// project and self-contained under `lib/hangul/` — it shares no
/// engine/scene/data with the other script features.
///
/// Draw a jamo on the paper — a bare stroke (ㅣ/ㅡ), a stem with tick marks
/// (ㅏ/ㅗ …), a corner (ㄱ/ㄴ), a loop (ㅇ), or one of the multi-stroke
/// consonants — and the recognized letter, its name, and its sound update
/// live below the canvas. Clear wipes it.
///
/// On **desktop** (wide) the jamo reference sits beside the canvas in a 50/50
/// split. On narrow/mobile an info button in the app bar opens the
/// full-screen [ReferencePage] instead.
class HangulPage extends StatefulWidget {
  const HangulPage({super.key});

  @override
  State<HangulPage> createState() => _HangulPageState();
}

/// Below this width the reference legend moves out of the 50/50 side panel and
/// behind the app-bar info button.
const _wideBreakpoint = 720.0;

class _HangulPageState extends State<HangulPage> {
  late final (Scene, HangulLayer) _built = buildHangulScene();
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
        title: const Text('Hangul'),
        actions: [
          if (!wide)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Jamo reference',
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
                          child: const HangulReference(),
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
              'Draw a jamo: a stroke (ㅣ ㅡ), a stem with ticks (ㅏ ㅗ), a '
              'corner (ㄱ ㄴ), a loop (ㅇ), or a compound consonant.',
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
