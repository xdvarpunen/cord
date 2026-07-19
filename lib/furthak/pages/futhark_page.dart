import 'package:flutter/material.dart';

import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../scenes/futhark_scene.dart';
import 'reference_page.dart';
import 'rune_tables.dart';

/// Second link: freehand Futhark rune recognition (ported from the furthak
/// app, self-contained under `lib/furthak/` — it shares no engine/scene/data
/// with the tally page). A dropdown picks the alphabet to recognize
/// (Younger / Elder), a Clear button wipes the canvas, and marks are
/// recognized live as you draw.
///
/// On **desktop** (wide) the rune reference table for the selected alphabet
/// sits beside the canvas in a 50/50 split. On narrow/mobile there's no room
/// for it, so an info button in the app bar opens the full tabbed
/// [ReferencePage] instead.
class FutharkPage extends StatefulWidget {
  const FutharkPage({super.key});

  @override
  State<FutharkPage> createState() => _FutharkPageState();
}

/// Below this width the reference table moves out of the 50/50 side panel and
/// behind the app-bar info button.
const _wideBreakpoint = 720.0;

class _FutharkPageState extends State<FutharkPage> {
  late final (Scene, FutharkLayer) _built = buildFutharkScene();
  late final _sceneManager = SceneManager(_built.$1);
  FutharkAlphabet _alphabet = FutharkAlphabet.younger;

  void _selectAlphabet(FutharkAlphabet alphabet) => setState(() {
        _alphabet = alphabet;
        // The layer re-classifies the strokes already on the canvas.
        _built.$2.alphabet = alphabet;
      });

  void _openReference() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReferencePage()),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final canvas = ClipRect(child: GameCanvas(sceneManager: _sceneManager));
    final table = _alphabet == FutharkAlphabet.younger
        ? const YoungerFutharkTable()
        : const ElderFutharkTable();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Futhark'),
        actions: [
          if (!wide)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Rune reference',
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
                          child: table,
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
          const Text('Alphabet'),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<FutharkAlphabet>(
              value: _alphabet,
              isExpanded: true,
              onChanged: (alphabet) => _selectAlphabet(alphabet!),
              items: [
                for (final alphabet in FutharkAlphabet.values)
                  DropdownMenuItem(
                    value: alphabet,
                    child: Text(alphabet.label),
                  ),
              ],
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
