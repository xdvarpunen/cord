import 'package:flutter/material.dart';

import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../scenes/etruscan_scene.dart';
import 'etruscan_tables.dart';
import 'reference_page.dart';

/// Freehand Etruscan numeral recognition, ported from the `shorthand`
/// project's Etruscan numerals interpreter (recovered from its git history)
/// and self-contained under `lib/etruscan/` — it shares no engine/scene/data
/// with the other script features.
///
/// Draw the numeral figures on the paper — `│`=1, `∧`=5, `✕`=10, and the
/// compound 50 and 100 — side by side to build a number; the recognized
/// numerals and their additive total update live as you draw. Clear wipes the
/// canvas.
///
/// On **desktop** (wide) the numeral reference sits beside the canvas in a
/// 50/50 split. On narrow/mobile an info button in the app bar opens the
/// full-screen [ReferencePage] instead.
class EtruscanPage extends StatefulWidget {
  const EtruscanPage({super.key});

  @override
  State<EtruscanPage> createState() => _EtruscanPageState();
}

/// Below this width the reference table moves out of the 50/50 side panel and
/// behind the app-bar info button.
const _wideBreakpoint = 720.0;

class _EtruscanPageState extends State<EtruscanPage> {
  late final (Scene, EtruscanLayer) _built = buildEtruscanScene();
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
        title: const Text('Etruscan Numerals'),
        actions: [
          if (!wide)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Numeral reference',
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
                          child: const EtruscanTable(),
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
              'Vertical = 1  ·  peak ∧ = 5  ·  cross ✕ = 10  ·  ∧ on a stem = '
              '50  ·  ✕ with a stem = 100. Draw numerals side by side.',
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
