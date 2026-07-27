import 'package:flutter/material.dart';

import '../data/greek_letters.dart';
import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../scenes/greek_scene.dart';
import 'alphabet_param.dart';
import 'greek_reference.dart';
import 'reference_page.dart';

/// Freehand Greek letter recognition, ported from the standalone `greek`
/// project and self-contained under `lib/greek/` — it shares no engine/scene/
/// data with the other script features.
///
/// Draw a capital on the paper and the recognized letter, its name and its
/// sound are read out on the canvas itself. There are no accents here yet, so
/// every letter is drawn from strokes alone and nothing is built from a dot.
///
/// A dropdown picks the alphabet, three of them, separated by date rather than
/// by language: the classical 24 of Α–Ω, the 21 Athens wrote before 403 BC, and
/// the archaic 23 that still had Ϝ and Ϙ. It narrows what may be *reported*
/// rather than what may be drawn: a drawing the chosen alphabet has no letter
/// for falls through to whatever the next classifier makes of the same strokes,
/// so an Ω under [Alphabet.oldAttic] — which has no Ω — comes out as the Λ its
/// stroke also describes. Switching alphabets doesn't wipe the drawing, it
/// re-reads it.
///
/// The selection round-trips through the URL's `?alphabet=` query param (like
/// the Latin page's), so reloading or sharing the page URL preserves it.
///
/// On **desktop** (wide) the alphabet reference sits beside the canvas in a
/// 50/50 split. On narrow/mobile an info button in the app bar opens the
/// full-screen [ReferencePage] instead.
class GreekPage extends StatefulWidget {
  const GreekPage({this.initialAlphabet, super.key});

  /// Alphabet to open on, overriding the URL's `?alphabet=` — set when arriving
  /// from the search page so a result opens the right alphabet. Null for normal
  /// navigation (frontpage/deep link), where the URL decides.
  final String? initialAlphabet;

  @override
  State<GreekPage> createState() => _GreekPageState();
}

/// Below this width the reference legend moves out of the 50/50 side panel and
/// behind the app-bar info button.
const _wideBreakpoint = 720.0;

/// The alphabet [slug] names, or [Alphabet.greek] if it names none — the enum's
/// own [Alphabet.name] is the slug, so `?alphabet=oldAttic` is
/// [Alphabet.oldAttic] and nothing has to be kept in step by hand.
Alphabet alphabetForSlug(String? slug) => Alphabet.values.firstWhere(
      (alphabet) => alphabet.name == slug,
      orElse: () => Alphabet.greek,
    );

class _GreekPageState extends State<GreekPage> {
  late final (Scene, GreekLayer) _built = buildGreekScene();
  late final _sceneManager = SceneManager(_built.$1);

  /// The alphabet to start on: an explicit [GreekPage.initialAlphabet] wins,
  /// otherwise the URL's `?alphabet=` (falling back to Greek).
  late Alphabet _alphabet = alphabetForSlug(
    widget.initialAlphabet ?? Uri.base.queryParameters['alphabet'],
  );

  @override
  void initState() {
    super.initState();
    _built.$2.alphabet = _alphabet;
    // Normalize the URL to the alphabet actually shown — so opening `/greek`
    // (no query) or arriving from search both leave a shareable
    // `?alphabet=<slug>` in the address bar. A no-op off the web; see
    // `alphabet_param.dart`.
    writeAlphabetParam(_alphabet.name);
  }

  void _select(Alphabet? alphabet) {
    if (alphabet == null || alphabet == _alphabet) return;
    setState(() {
      _alphabet = alphabet;
      // Re-reads whatever is already on the page rather than wiping it: the
      // strokes are unchanged and still yours, and seeing the same marks come
      // out as a different letter is the most direct way to understand what
      // the selector actually does.
      _built.$2.alphabet = alphabet;
      writeAlphabetParam(alphabet.name);
    });
  }

  void _openReference() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReferencePage(alphabet: _alphabet),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final canvas = ClipRect(child: GameCanvas(sceneManager: _sceneManager));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Greek'),
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
                          child: GreekReference(alphabet: _alphabet),
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

  /// The alphabet picker and the Clear button. What the chosen alphabet *is* —
  /// its letter count and what makes the set itself — is stated once, at the
  /// head of the legend, rather than repeated here: on wide layouts the legend
  /// is right beside this bar, and on narrow it travels with the letters behind
  /// the info button.
  Widget _controlBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('Alphabet', style: theme.textTheme.labelMedium),
          const SizedBox(width: 12),
          DropdownButton<Alphabet>(
            value: _alphabet,
            onChanged: _select,
            items: [
              for (final alphabet in Alphabet.values)
                DropdownMenuItem(
                  value: alphabet,
                  child: Text(alphabet.label),
                ),
            ],
          ),
          const Spacer(),
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
