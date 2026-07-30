import 'package:flutter/material.dart';

import '../data/script.dart';
import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../scenes/makasar_scene.dart';
import '../scenes/writing_scene.dart';
import 'makasar_reference.dart';
import 'reference_page.dart';
import 'script_param.dart';

/// Freehand Makasar letter recognition, ported from the standalone `makasar`
/// project and self-contained under `lib/makasar/` — it shares no engine/
/// scene/data with the other script features.
///
/// Two tabs over the same canvas engine:
///
/// - **Draw** — one character at a time on dot-grid paper, with the reading
///   of what it was recognized as on the canvas itself.
/// - **Write** — ruled paper for a whole row of characters, each read on its
///   own and the row read out together.
///
/// A dropdown picks the script, and points both canvases at it as well as the
/// reference: a wedge drawn under Bugis reads as its own ta rather than as
/// the Makasar letter na. Unlike the Latin and Greek pages' alphabet
/// selectors, this one *wipes* both canvases on a change (the scene layers
/// do it themselves) — a reading taken as one script wouldn't mean anything
/// under the other.
///
/// The selection round-trips through the URL's `?script=` query param (like
/// the Hanzi Grid page's), so reloading or sharing the page URL preserves it.
///
/// On **desktop** (wide) the script reference sits beside the canvas in a
/// 50/50 split. On narrow/mobile an info button in the app bar opens the
/// full-screen [ReferencePage] instead. Upstream stacked a chip listing of
/// the character set under the canvas and kept the full table on a page of
/// its own; here the table is the one listing, muted the way those chips
/// were, so the canvas keeps its height.
class MakasarPage extends StatefulWidget {
  const MakasarPage({this.initialScript, super.key});

  /// Script to open on, overriding the URL's `?script=` — set when arriving
  /// from the search page so a result opens the right script. Null for normal
  /// navigation (frontpage/deep link), where the URL decides.
  final String? initialScript;

  @override
  State<MakasarPage> createState() => _MakasarPageState();
}

/// Below this width the reference table moves out of the 50/50 side panel and
/// behind the app-bar info button.
const _wideBreakpoint = 720.0;

/// The script [slug] names, or [WritingScript.makasar] if it names none — the
/// enum's own [WritingScript.name] is the slug, so `?script=bugis` is
/// [WritingScript.bugis] and nothing has to be kept in step by hand.
WritingScript scriptForSlug(String? slug) => WritingScript.values.firstWhere(
  (script) => script.name == slug,
  orElse: () => WritingScript.makasar,
);

class _MakasarPageState extends State<MakasarPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  late final (Scene, MakasarLayer) _drawing = buildMakasarScene();
  late final _drawingManager = SceneManager(_drawing.$1);
  late final (Scene, WritingLayer) _writing = buildWritingScene();
  late final _writingManager = SceneManager(_writing.$1);

  /// Which script both canvases read and the reference lists. Shared by the
  /// two tabs — see [_select].
  late WritingScript _script = scriptForSlug(
    widget.initialScript ?? Uri.base.queryParameters['script'],
  );

  @override
  void initState() {
    super.initState();
    _drawing.$2.script = _script;
    _writing.$2.script = _script;
    // Normalize the URL to the script actually shown — so opening `/makasar`
    // (no query) or arriving from search both leave a shareable `?script=`
    // in the address bar. A no-op off the web; see `script_param.dart`.
    writeScriptParam(_script.name);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Points both canvases at [script] as well as the reference. Each wipes
  /// itself, since a reading taken as the other script wouldn't mean anything
  /// under this one.
  void _select(WritingScript? script) {
    if (script == null || script == _script) return;
    setState(() {
      _script = script;
      _drawing.$2.script = script;
      _writing.$2.script = script;
      writeScriptParam(script.name);
    });
  }

  void _openReference() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ReferencePage(script: _script)),
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final tabs = TabBarView(
      controller: _tabs,
      children: [
        _canvasPanel(
          manager: _drawingManager,
          hint: 'Makasar — an abugida: every letter carries an inherent "a".',
          onClear: _drawing.$2.clear,
        ),
        _canvasPanel(
          manager: _writingManager,
          hint:
              'Leave a clear space between characters — a letter and its '
              'vowel sign belong together.',
          onClear: _writing.$2.clear,
          onUndo: _writing.$2.undo,
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Makasar'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Draw'),
            Tab(text: 'Write'),
          ],
        ),
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
                      Expanded(child: tabs),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: MakasarReference(script: _script),
                        ),
                      ),
                    ],
                  )
                : tabs,
          ),
        ],
      ),
    );
  }

  /// The script picker, above both tabs because both read whichever script it
  /// names. What the chosen script *is* — how many characters it holds, and
  /// whether the canvas reads it — is stated once, at the head of the
  /// reference, rather than repeated here.
  Widget _controlBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('Script', style: theme.textTheme.labelMedium),
          const SizedBox(width: 12),
          DropdownButton<WritingScript>(
            value: _script,
            onChanged: _select,
            items: [
              for (final script in WritingScript.values)
                DropdownMenuItem(value: script, child: Text(script.label)),
            ],
          ),
        ],
      ),
    );
  }

  /// A canvas filling the panel, with the hint and the buttons that act on
  /// that canvas underneath. Both tabs are laid out the same way; only the
  /// scene, the hint and whether there is an Undo differ.
  Widget _canvasPanel({
    required SceneManager manager,
    required String hint,
    required VoidCallback onClear,
    VoidCallback? onUndo,
  }) {
    return Column(
      children: [
        Expanded(
          child: ClipRect(child: GameCanvas(sceneManager: manager)),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hint,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                if (onUndo != null) ...[
                  // Always enabled: the layer ignores an undo with nothing to
                  // take back, and the page doesn't rebuild as marks are
                  // drawn, so a disabled state here would go stale as soon as
                  // one was.
                  OutlinedButton(onPressed: onUndo, child: const Text('Undo')),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
