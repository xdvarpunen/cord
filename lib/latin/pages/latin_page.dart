import 'package:flutter/material.dart';

import '../data/latin_letters.dart';
import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../scenes/latin_scene.dart';
import 'alphabet_param.dart';
import 'latin_reference.dart';
import 'reference_page.dart';

/// Freehand Latin letter recognition, ported from the standalone `latin`
/// project and self-contained under `lib/latin/` — it shares no engine/scene/
/// data with the other script features.
///
/// Draw a printed capital on the paper and the recognized letter, its name and
/// its sound are read out on the canvas itself. The marked letters are a base
/// plus a mark drawn clear of it — an acute, a caron, a pair of dots — and
/// either order works: the page re-reads what is on it whenever a stroke or a
/// dot lands.
///
/// A dropdown picks the alphabet, thirty-one of them, each with its own letters
/// **and its own order**. It narrows what may be reported rather than what may
/// be drawn: a drawing the chosen alphabet has no letter for falls through to
/// whatever the next classifier makes of the same strokes, so a U under
/// [Alphabet.latin] — which has no U — comes out as the V that Latin would have
/// written, and an acute over an A under [Alphabet.english] comes out as a
/// plain A. Switching alphabets doesn't wipe the drawing, it re-reads it.
///
/// The selection round-trips through the URL's `?alphabet=` query param (like
/// the Hanzi Grid page's `?script=`), so reloading or sharing the page URL
/// preserves it.
///
/// On **desktop** (wide) the alphabet reference sits beside the canvas in a
/// 50/50 split. On narrow/mobile an info button in the app bar opens the
/// full-screen [ReferencePage] instead.
class LatinPage extends StatefulWidget {
  const LatinPage({this.initialAlphabet, super.key});

  /// Alphabet to open on, overriding the URL's `?alphabet=` — set when arriving
  /// from the search page so a result opens the right alphabet. Null for normal
  /// navigation (frontpage/deep link), where the URL decides.
  final String? initialAlphabet;

  @override
  State<LatinPage> createState() => _LatinPageState();
}

/// Below this width the reference legend moves out of the 50/50 side panel and
/// behind the app-bar info button.
const _wideBreakpoint = 720.0;

/// The alphabet [slug] names, or [Alphabet.english] if it names none — the
/// enum's own [Alphabet.name] is the slug, so `?alphabet=icelandic` is
/// [Alphabet.icelandic] and nothing has to be kept in step by hand.
Alphabet alphabetForSlug(String? slug) => Alphabet.values.firstWhere(
      (alphabet) => alphabet.name == slug,
      orElse: () => Alphabet.english,
    );

class _LatinPageState extends State<LatinPage> {
  late final (Scene, LatinLayer) _built = buildLatinScene();
  late final _sceneManager = SceneManager(_built.$1);

  /// The alphabet to start on: an explicit [LatinPage.initialAlphabet] wins,
  /// otherwise the URL's `?alphabet=` (falling back to English).
  late Alphabet _alphabet = alphabetForSlug(
    widget.initialAlphabet ?? Uri.base.queryParameters['alphabet'],
  );

  @override
  void initState() {
    super.initState();
    _built.$2.alphabet = _alphabet;
    // Normalize the URL to the alphabet actually shown — so opening `/latin`
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
        title: const Text('Latin'),
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
                          child: LatinReference(alphabet: _alphabet),
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
