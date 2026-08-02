import 'package:flutter/material.dart';

import '../data/canvas_mode.dart';
import '../data/script.dart';
import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../scenes/makasar_scene.dart';
import '../scenes/writing_scene.dart';
import '../widgets/lontara_wordmark.dart';
import 'makasar_reference.dart';
import 'reference_page.dart';
import 'script_param.dart';

/// Freehand Lontara letter recognition, ported from the standalone `lontara`
/// project (which still calls its code `makasar`, after the older of the two
/// scripts) and self-contained under `lib/makasar/` — it shares no engine/
/// scene/data with the other script features.
///
/// Two canvases over the same engine, picked by the **Canvas** dropdown
/// ([CanvasMode]):
///
/// - **Draw** — one character at a time on dot-grid paper, with the reading
///   of what it was recognized as on the canvas itself.
/// - **Write** — ruled paper for a whole row of characters, each read on its
///   own and the row read out together.
///
/// Either way the reading is drawn out in letterforms underneath it, which
/// for New Lontara is the only picture of the character there is — no font in
/// the bundle covers the Buginese block.
///
/// The **Script** dropdown picks which script is read and listed, and points
/// both canvases at it as well as the reference: a wedge drawn under New
/// Lontara reads as its own ta rather than as Old Lontara's na. Unlike the
/// Latin and Greek pages' alphabet selectors, this one *wipes* both canvases
/// on a change (the scene layers do it themselves) — a reading taken as one
/// script wouldn't mean anything under the other.
///
/// The page opens on New Lontara, the script still written today; the
/// selection round-trips through the URL's `?script=` query param (like the
/// Hanzi Grid page's), so reloading or sharing the page URL preserves it.
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

/// The script [slug] names, or [WritingScript.bugis] if it names none — the
/// enum's own [WritingScript.name] is the slug, so `?script=makasar` is
/// [WritingScript.makasar] and nothing has to be kept in step by hand. The
/// slugs are the scripts' older names, as the code is: New Lontara is
/// `?script=bugis`.
///
/// New Lontara is the default because it is the script still in use — Old
/// Lontara is the one you go looking for. (Upstream opens on Old Lontara
/// instead, its code being named after it.)
WritingScript scriptForSlug(String? slug) => WritingScript.values.firstWhere(
  (script) => script.name == slug,
  orElse: () => WritingScript.bugis,
);

class _MakasarPageState extends State<MakasarPage> {
  late final (Scene, MakasarLayer) _drawing = buildMakasarScene();
  late final _drawingManager = SceneManager(_drawing.$1);
  late final (Scene, WritingLayer) _writing = buildWritingScene();
  late final _writingManager = SceneManager(_writing.$1);

  /// Which canvas is showing. Both scenes are built either way — each keeps
  /// what was drawn on it, so switching across and back leaves the work where
  /// it was.
  CanvasMode _mode = CanvasMode.draw;

  /// Which script both canvases read and the reference lists. Shared by the
  /// two — see [_select].
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
    final canvas = switch (_mode) {
      CanvasMode.draw => _canvasPanel(
        manager: _drawingManager,
        // Named rather than left as upstream's fixed "Old Lontara": the page
        // opens on New Lontara here, so the hint has to follow the dropdown.
        hint:
            '${_script.label} — an abugida: every letter carries an '
            'inherent "a".',
        onClear: _drawing.$2.clear,
        onUndo: _drawing.$2.undo,
      ),
      CanvasMode.write => _canvasPanel(
        manager: _writingManager,
        hint:
            'Leave a clear space between characters — a letter and its '
            'vowel sign belong together.',
        onClear: _writing.$2.clear,
        onUndo: _writing.$2.undo,
      ),
    };

    return Scaffold(
      appBar: AppBar(
        // The page's name, and the same word in the script it names — which
        // has to be drawn rather than typed, no font here covering the
        // Buginese block.
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Lontara'),
            SizedBox(width: 14),
            LontaraWordmark(),
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
                      Expanded(child: canvas),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: MakasarReference(script: _script),
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

  /// The two pickers: which canvas is showing, and which script it reads.
  /// The script one sits above both canvases because both read whichever
  /// script it names. What the chosen script *is* — how many characters it
  /// holds, and how much of it the canvas reads — is stated once, at the head
  /// of the reference, rather than repeated here.
  Widget _controlBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 24,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _picker<CanvasMode>(
            context,
            label: 'Canvas',
            value: _mode,
            values: CanvasMode.values,
            labelOf: (mode) => mode.label,
            onChanged: (mode) => setState(() => _mode = mode!),
          ),
          _picker<WritingScript>(
            context,
            label: 'Script',
            value: _script,
            values: WritingScript.values,
            labelOf: (script) => script.label,
            onChanged: _select,
          ),
        ],
      ),
    );
  }

  /// One labelled dropdown of the control bar. Both settings are put the same
  /// way, so they read as a pair rather than as two different controls.
  Widget _picker<T>(
    BuildContext context, {
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(width: 12),
        DropdownButton<T>(
          value: value,
          onChanged: onChanged,
          items: [
            for (final choice in values)
              DropdownMenuItem(value: choice, child: Text(labelOf(choice))),
          ],
        ),
      ],
    );
  }

  /// A canvas filling the panel, with the hint and the buttons that act on
  /// that canvas underneath. Both canvases are laid out the same way; only
  /// the scene and the hint differ. Both keep every mark until it is taken
  /// back, so both offer Undo as well as Clear.
  Widget _canvasPanel({
    required SceneManager manager,
    required String hint,
    required VoidCallback onClear,
    required VoidCallback onUndo,
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
                // Always enabled: the layer ignores an undo with nothing to
                // take back, and the page doesn't rebuild as marks are drawn,
                // so a disabled state here would go stale as soon as one was.
                OutlinedButton(onPressed: onUndo, child: const Text('Undo')),
                const SizedBox(width: 8),
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
