import 'package:flutter/material.dart';

import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../scenes/sinhala_scene.dart';
import 'reference_page.dart';
import 'sinhala_reference.dart';
import 'system_param.dart';

/// Freehand Sinhala numeral recognition, ported from the standalone `sinhala`
/// project and self-contained under `lib/sinhala/` — it shares no engine/
/// scene/data with the other script features.
///
/// cord took the **numbers** and left the hodiya behind: the **Numerals**
/// dropdown picks between the two systems Sri Lanka has written numbers with,
/// and drives both halves of the screen — what the canvas matches a drawing
/// against, and which reference sits beside it.
///
/// - **Lith** (ලිත් ඉලක්කම්, the astrological / almanac digits) — decimal, with
///   place value and a zero, like the digits this sentence is numbered in.
/// - **Illakkam** (ඉලක්කම්, the older numerals the Lith digits replaced) — no
///   zero and no place value: every unit, every ten, and then a hundred and a
///   thousand has a symbol of its own, and 123 is written 100, 20, 3.
///
/// The two are kept apart because some glyphs simply *are* the same shape, so
/// only knowing which system you are writing in can part them. Switching does
/// **not** wipe the canvas (unlike the Lontara page's script dropdown): the
/// recognizer re-reads what is already drawn, which is the point — the same
/// stroke can be looked at as one system and then as the other.
///
/// The page opens on Lith, the system with the digits still in use; the
/// selection round-trips through the URL's `?system=` query param (like the
/// tally page's), so reloading or sharing the page URL preserves it.
///
/// On **desktop** (wide) the numeral reference sits beside the canvas in a
/// 50/50 split. On narrow/mobile an info button in the app bar opens the
/// full-screen [ReferencePage] instead — upstream put the same panel behind
/// the same button.
///
/// The recognizer still holds the letter rules internally (see
/// `scenes/sinhala_scene.dart`, kept verbatim but for [numeralSystems]);
/// [RecognitionSystem.letters] is simply never selected here, the same way the
/// Hebrew page never leaves the modern square script.
class SinhalaPage extends StatefulWidget {
  const SinhalaPage({this.initialSystem, super.key});

  /// Numeral system to open on, overriding the URL's `?system=` — set when
  /// arriving from the search page so a result opens the right system. Null
  /// for normal navigation (frontpage/deep link), where the URL decides.
  final String? initialSystem;

  @override
  State<SinhalaPage> createState() => _SinhalaPageState();
}

/// Below this width the reference panel moves out of the 50/50 side panel and
/// behind the app-bar info button.
const _wideBreakpoint = 720.0;

/// The system [slug] names, or [RecognitionSystem.lithNumerals] if it names
/// none — the enum's own [RecognitionSystem.name] is the slug, so
/// `?system=illakkamNumerals` is the Illakkam one and nothing has to be kept
/// in step by hand.
///
/// Only the two numeral systems are on offer, so `?system=letters` falls back
/// like any other unknown slug rather than opening a page half of which cord
/// did not take.
RecognitionSystem systemForSlug(String? slug) => numeralSystems.firstWhere(
      (system) => system.name == slug,
      orElse: () => RecognitionSystem.lithNumerals,
    );

class _SinhalaPageState extends State<SinhalaPage> {
  late final (Scene, SinhalaLetterLayer) _built = buildSinhalaLetterScene();
  late final _sceneManager = SceneManager(_built.$1);

  /// Which system the canvas reads a drawing as, and therefore which reference
  /// sits beside it. One control for both, so what you are reading and what
  /// the canvas is matching against can never disagree.
  late RecognitionSystem _system = systemForSlug(
    widget.initialSystem ?? Uri.base.queryParameters['system'],
  );

  @override
  void initState() {
    super.initState();
    _built.$2.system = _system;
    // Normalize the URL to the system actually shown — so opening `/sinhala`
    // (no query) or arriving from search both leave a shareable `?system=` in
    // the address bar. A no-op off the web; see `system_param.dart`.
    writeSystemParam(_system.name);
  }

  /// Points the canvas at [system] as well as the reference. What is already
  /// drawn stays put and is re-read under the new rules — a stroke that is a
  /// Lith 8 is worth seeing as an Illakkam nothing.
  void _select(RecognitionSystem? system) {
    if (system == null || system == _system) return;
    setState(() {
      _system = system;
      _built.$2.system = system;
      writeSystemParam(system.name);
    });
  }

  void _openReference() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReferencePage(system: _system)),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final canvas = ClipRect(child: GameCanvas(sceneManager: _sceneManager));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sinhala numerals'),
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
                          child: SinhalaReference(system: _system),
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

  /// The one control that matters — which system the canvas reads a drawing
  /// as — and Clear. How many of the chosen system's symbols are recognized is
  /// stated once, at the head of the reference, rather than repeated here.
  Widget _controlBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // A Wrap rather than a Row: on a phone the picker and the button take
      // more width than there is, and the button dropping to its own line
      // beats an overflow.
      child: Wrap(
        spacing: 24,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Numerals', style: theme.textTheme.labelMedium),
              const SizedBox(width: 12),
              DropdownButton<RecognitionSystem>(
                value: _system,
                onChanged: _select,
                items: [
                  for (final system in numeralSystems)
                    DropdownMenuItem(
                      value: system,
                      child: Text(system.label),
                    ),
                ],
              ),
            ],
          ),
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
