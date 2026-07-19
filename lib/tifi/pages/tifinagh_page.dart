import 'package:flutter/material.dart';

import '../data/tuareg_scripts.dart';
import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../scenes/tifinagh_scene.dart';
import 'reference_page.dart';
import 'script_tables.dart';

/// Third link: freehand Tifinagh letter recognition (ported from the tifi
/// app, self-contained under `lib/tifi/` — it shares no engine/scene/data
/// with the tally or furthak pages). A dropdown picks which script variant to
/// recognize; a Clear button wipes the canvas.
///
/// The Neo-Tifinagh variants are intentionally excluded: the dropdown offers
/// the five Tuareg regional variants plus Libyco-Berber, and the reference
/// has no Neo-Tifinagh tab. (The recognizer scene still carries its
/// Neo-Tifinagh classifiers internally, but no region here selects them.)
///
/// On **desktop** (wide) the reference table for the selected script sits
/// beside the canvas in a 50/50 split. On narrow/mobile an info button in the
/// app bar opens the full tabbed [ReferencePage] instead.
class TifinaghPage extends StatefulWidget {
  const TifinaghPage({super.key});

  @override
  State<TifinaghPage> createState() => _TifinaghPageState();
}

/// Below this width the reference table moves out of the 50/50 side panel and
/// behind the app-bar info button.
const _wideBreakpoint = 720.0;

/// The scripts offered — the five Tuareg regional variants plus Libyco-Berber
/// (Neo-Tifinagh deliberately excluded).
final _scripts = [...tuaregRegions, 'Libyco-Berber'];

class _TifinaghPageState extends State<TifinaghPage> {
  late final (Scene, TifinaghLayer) _built = buildTifinaghScene();
  late final _sceneManager = SceneManager(_built.$1);
  String _script = tuaregRegions.first;

  @override
  void initState() {
    super.initState();
    _built.$2.region = _script;
  }

  void _selectScript(String script) => setState(() {
        _script = script;
        _built.$2.region = script;
      });

  void _openReference() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReferencePage()),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final canvas = ClipRect(child: GameCanvas(sceneManager: _sceneManager));
    final table = _script == 'Libyco-Berber'
        ? const LibycoBerberTable()
        : const TuaregTable();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tifinagh'),
        actions: [
          if (!wide)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Script reference',
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
          const Text('Script'),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _script,
              isExpanded: true,
              onChanged: (script) => _selectScript(script!),
              items: [
                for (final script in _scripts)
                  DropdownMenuItem(value: script, child: Text(script)),
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
