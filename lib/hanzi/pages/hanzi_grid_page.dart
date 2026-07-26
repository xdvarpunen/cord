import 'package:flutter/material.dart';

import '../data/hanzi_glosses.dart';
import '../data/hanzi_scripts.dart';
import '../data/stroke_models.dart';
import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../palette.dart';
import '../recognition/character_recognizer.dart';
import '../scenes/grid_scene.dart';
import '../scenes/hanzi_grid_scene.dart';
import 'character_tables.dart';
import 'common.dart';
import 'reference_page.dart';
import 'script_param.dart';

/// Squares you write whole Han characters into, with each row read out on a
/// line beneath it — the ruled grid an East Asian exercise notebook is printed
/// with, one character per square.
///
/// Ported from the `hanzi` project's "Order up" tab and self-contained under
/// `lib/hanzi/`: its own engine, scenes, recognizer, stroke table, and
/// palette, sharing nothing with the pages around it. What did *not* come
/// across is everything the tab wrapped around the grid — the brand and
/// product pickers, the word to write, the per-cell "stroke 3 out of order"
/// verdicts, and the animated demonstration underneath — so this is the grid
/// on its own, free practice with no character to hit.
///
/// A stroke joins whichever square its centre lands in, squares read left to
/// right and then down a row, and an empty square between two written ones is
/// a space. Each square is compared whole against every glyph in the table
/// with the same number of strokes, on shape and on how the strokes meet.
///
/// The band under each square names the traditions that write that character
/// in the order you just used it in. The same character is stored three times
/// over — once for Chinese, Japanese and Korean, each in its own stroke order
/// — which is what makes that question answerable at all.
///
/// A dropdown picks which script is being written, and that narrows what the
/// recognizer will even consider — see [HanziScript]. It round-trips through
/// the URL's `?script=` query param (like the tally page's `?system=`), so
/// reloading or sharing the page URL preserves it.
class HanziGridPage extends StatefulWidget {
  const HanziGridPage({this.initialScript, super.key});

  /// Script to open on, overriding the URL's `?script=` — set when arriving
  /// from the search page so a result opens the right script. Null for normal
  /// navigation (frontpage/deep link), where the URL decides.
  final String? initialScript;

  @override
  State<HanziGridPage> createState() => _HanziGridPageState();
}

/// What one square came out as.
typedef _Square = ({
  String? char,
  Gloss? gloss,
  List<Lang> orders,
  int strokes,

  /// 0..1, how well the winning glyph fitted. Null when nothing was read.
  double? confidence,

  /// The runners-up, best first — the characters the recognizer also
  /// considered and how close they came.
  List<({String char, double confidence})> others,
});

/// Below this the reference tables move out of the side panel and behind the
/// app-bar info button. The writing column wants 760 of its own, so the split
/// only earns its keep on a genuinely wide window.
const _wideBreakpoint = 1160.0;

class _HanziGridPageState extends State<HanziGridPage> {
  static const _columns = 4;
  static const _rows = 2;

  /// The band under each row. Tall enough for a 22pt character with how it is
  /// said, what it means and how sure that is stacked under it, plus air
  /// around all four — and the same distance the stroke capture steps its rows
  /// by, see [buildHanziGridScene].
  static const _readHeight = 88.0;

  late final (Scene, HanziPaperLayer, WordGridLayer) _built =
      buildHanziGridScene(
    columns: _columns,
    rows: _rows,
    readHeight: _readHeight,
    onChanged: _recognize,
  );
  late final SceneManager _sceneManager = SceneManager(_built.$1);
  HanziPaperLayer get _paper => _built.$2;
  WordGridLayer get _grid => _built.$3;

  List<_Square?> _squares = List.filled(_columns * _rows, null);

  late HanziScript _script = _initialScript();

  /// The script to start on: an explicit [HanziGridPage.initialScript] wins,
  /// otherwise the URL's `?script=` (falling back to Everything).
  HanziScript _initialScript() => hanziScriptForSlug(
        widget.initialScript ?? Uri.base.queryParameters['script'],
      );

  @override
  void initState() {
    super.initState();
    // Normalize the URL to the script actually shown — so opening `/hanzi`
    // (no query) or arriving from search both leave a shareable
    // `?script=<slug>` in the address bar. A no-op off the web; see
    // `script_param.dart`.
    writeScriptParam(_script.slug);
  }

  /// Changing script re-reads what is already on the page rather than wiping
  /// it. The strokes are unchanged and still yours; it is only the field they
  /// are being compared against that moved, and seeing the same marks come out
  /// as a different character is the most direct way to understand what the
  /// selector actually does.
  void _selectScript(HanziScript script) {
    if (script.slug == _script.slug) return;
    setState(() {
      _script = script;
      writeScriptParam(script.slug);
    });
    _recognize();
  }

  void _recognize() {
    final squares = <_Square?>[];
    for (final strokes in _grid.localCells) {
      if (strokes.isEmpty) {
        squares.add(null);
        continue;
      }
      // Ranked without regard to order: a character written in an unusual
      // sequence is still that character, and this page has no target to be
      // wrong about. The order question is asked separately below, which is
      // also what keeps a right-shape/wrong-order attempt from being pushed
      // past the cutoff and out of the results entirely.
      final matches = recognizeCharacter(strokes, where: _script.holds);
      if (matches.isEmpty) {
        squares.add((
          char: null,
          gloss: null,
          orders: const <Lang>[],
          strokes: strokes.length,
          confidence: null,
          others: const [],
        ));
        continue;
      }
      final char = matches.first.char;
      squares.add((
        char: char,
        gloss: hanziGlosses[char],
        // Deliberately *not* narrowed to the selected script. Writing a
        // Chinese character in the Japanese order is exactly the thing worth
        // being told, and filtering here would hide it behind the selector.
        orders: [
          for (final variant in variantsFor(strokes, char))
            if (variant.orderMatches) variant.lang,
        ],
        strokes: strokes.length,
        confidence: matches.first.confidence,
        // Kept so the square can be argued with. A reading stated on its own
        // is a verdict; a reading with what it beat is evidence.
        others: [
          for (final m in matches.skip(1).take(3))
            (char: m.char, confidence: m.confidence),
        ],
      ));
    }

    setState(() {
      _squares = squares;
      _paper
        ..readings = [
          for (final square in squares)
            (
              char: square?.char,
              reading: square?.gloss?.reading,
              meaning: square?.gloss?.meaning,
              confidence: square?.confidence,
            ),
        ]
        ..states = [
          for (final square in squares)
            if (square == null)
              CellState.empty
            else if (square.char == null)
              CellState.unknown
            else
              CellState.recognized,
        ];
    });
  }

  /// The characters read so far, with a space where an empty square sits
  /// between two written ones — the same word break the squares themselves
  /// mean.
  String get _line {
    final written = <int>[
      for (var i = 0; i < _squares.length; i++)
        if (_squares[i] != null) i,
    ];
    if (written.isEmpty) return '';

    final out = StringBuffer();
    for (var i = written.first; i <= written.last; i++) {
      final square = _squares[i];
      out.write(square == null ? ' ' : square.char ?? '?');
    }
    return out.toString();
  }

  /// The squares that came out as a character, in reading order.
  List<_Square> get _recognized =>
      [for (final s in _squares) if (s?.char != null) s!];

  /// How the line is said, and what it says — the two lines under it.
  ///
  /// Joined per character rather than run together: these are separate
  /// characters, not a word, and spacing them is what lets a reader line each
  /// one up with the square it came from.
  String get _said =>
      _recognized.map((s) => s.gloss?.reading ?? '·').join('  ');
  String get _means =>
      _recognized.map((s) => s.gloss?.meaning ?? '?').join(' · ');

  int get _unreadable =>
      _squares.where((s) => s != null && s.char == null).length;
  bool get _anything => _squares.any((s) => s != null);

  void _openReference() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HanziReferencePage(initialScript: _script),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hanzi Grid'),
        actions: [
          if (!wide)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Character reference',
              onPressed: _openReference,
            ),
        ],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _paperColumn()),
                const VerticalDivider(width: 1),
                SizedBox(width: 400, child: ReferencePanel(script: _script)),
              ],
            )
          : _paperColumn(),
    );
  }

  Widget _paperColumn() {
    return Container(
        color: kPaper,
        child: ContentColumn(
          children: [
            _ScriptBar(script: _script, onChanged: _selectScript),
            const SizedBox(height: 12),
            _Reading(line: _line, said: _said, means: _means),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cell = constraints.maxWidth / _columns;
                return Container(
                  height: (cell + _readHeight) * _rows,
                  foregroundDecoration: BoxDecoration(
                    border: Border.all(color: kInk.withValues(alpha: 0.14)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(10)),
                  child: DrawingSurface(
                    child: GameCanvas(sceneManager: _sceneManager),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _Hint(unreadable: _unreadable),
            _Readout(squares: _recognized),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill(
                  label: 'Undo stroke',
                  onTap: () => _grid.undo(),
                  enabled: _anything,
                ),
                Pill(
                  label: 'Clear page',
                  accent: kPenColor,
                  onTap: () => _grid.clear(),
                  enabled: _anything,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Hairline(),
            const SizedBox(height: 14),
            const _Footnote(),
          ],
        ),
    );
  }
}

/// Which script you are writing — and so which characters the recognizer is
/// allowed to answer with.
///
/// Fixed height, because it sits above the canvas: anything that changes
/// height here shifts the writing surface out from under the pen. The count
/// beside the name is the point of the control, so it is on the closed
/// dropdown and not only in the open menu.
class _ScriptBar extends StatelessWidget {
  const _ScriptBar({required this.script, required this.onChanged});

  final HanziScript script;
  final ValueChanged<HanziScript> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: paperCard(),
      child: Row(
        children: [
          Text(
            'Writing',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: kInk.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: script.slug,
                isExpanded: true,
                borderRadius: BorderRadius.circular(10),
                onChanged: (slug) => onChanged(hanziScriptForSlug(slug)),
                selectedItemBuilder: (_) => [
                  for (final option in hanziScripts)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _ScriptLabel(script: option),
                    ),
                ],
                items: [
                  for (final option in hanziScripts)
                    DropdownMenuItem(
                      value: option.slug,
                      child: _ScriptLabel(script: option),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScriptLabel extends StatelessWidget {
  const _ScriptLabel({required this.script});

  final HanziScript script;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          child: Text(
            script.label,
            style: const TextStyle(
              fontFamily: kHanziFont,
              fontSize: 17,
              color: kInk,
            ),
          ),
        ),
        Text(
          script.name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kInk,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${script.count}',
          style: TextStyle(fontSize: 12, color: kInk.withValues(alpha: 0.45)),
        ),
      ],
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({
    required this.line,
    required this.said,
    required this.means,
  });

  final String line;

  /// The pinyin, and the English. Three lines rather than one because the
  /// characters alone are unreadable to the person practising them.
  final String said;
  final String means;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: kReadingHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: paperCard(),
      child: line.trim().isEmpty
          ? Text(
              'Write a character in each square — the row reads out beneath it',
              style: TextStyle(
                color: kInk.withValues(alpha: 0.4),
                fontSize: 13.5,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // One line each, running off the end rather than wrapping: a
                // second line would grow the panel and shift the squares down
                // mid-word.
                Text(
                  line,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: const TextStyle(
                    fontFamily: kHanziFont,
                    fontSize: 36,
                    height: 1.2,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  said,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: 17,
                    letterSpacing: 0.3,
                    color: kInk.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  means,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: 13,
                    color: kInk.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
    );
  }
}

/// One card per square that came out as a character: how sure the reading is,
/// what else it could have been, and whose stroke order you used.
///
/// The band under a square has room for a number; it has no room for the case
/// against it. That is what this is for — a reading stated on its own is a
/// verdict, and the recognizer's cutoff is generous enough that a verdict is
/// the wrong thing to state. Written out here, a 41% square with a rival two
/// points behind it looks exactly as uncertain as it is.
class _Readout extends StatelessWidget {
  const _Readout({required this.squares});

  final List<_Square> squares;

  /// Above this the reading is worth trusting. Kept in step with the bar the
  /// band paints — see `HanziPaperLayer`.
  static const _convincing = 0.66;

  @override
  Widget build(BuildContext context) {
    if (squares.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT EACH SQUARE SAYS',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: kInk.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 8),
          for (final square in squares) _Card(square: square),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.square});

  final _Square square;

  @override
  Widget build(BuildContext context) {
    final confidence = square.confidence ?? 0;
    final sure = confidence >= _Readout._convincing;
    final gloss = square.gloss;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: paperCard(
        border: (sure ? kStartColor : kPenColor).withValues(alpha: 0.22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                square.char!,
                style: const TextStyle(
                  fontFamily: kHanziFont,
                  fontSize: 30,
                  color: kInk,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gloss == null
                          ? '${square.strokes} strokes'
                          : '${gloss.reading} · ${gloss.meaning}',
                      style: const TextStyle(fontSize: 14, color: kInk),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${square.strokes} stroke'
                      '${square.strokes == 1 ? '' : 's'} drawn',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: kInk.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              _Confidence(value: confidence, sure: sure),
            ],
          ),
          const SizedBox(height: 9),
          _Order(orders: square.orders),
          if (square.others.isNotEmpty) ...[
            const SizedBox(height: 7),
            _Others(others: square.others),
          ],
        ],
      ),
    );
  }
}

/// The percentage, with the bar the band paints repeated at a readable size.
class _Confidence extends StatelessWidget {
  const _Confidence({required this.value, required this.sure});

  final double value;
  final bool sure;

  @override
  Widget build(BuildContext context) {
    final tint = sure ? kStartColor : kPenColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${(value * 100).round()}%',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: tint,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 76,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: kInk.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(tint.withValues(alpha: 0.75)),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'shape match',
          style: TextStyle(
            fontSize: 10,
            color: kInk.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

/// Whose stroke order you used, spelled out.
class _Order extends StatelessWidget {
  const _Order({required this.orders});

  final List<Lang> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      // The shape was right but the sequence was not one any source writes —
      // the most useful thing this page can tell you, so it says it in words.
      return Row(
        children: [
          Icon(Icons.swap_vert, size: 15, color: kPenColor.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'written in an order no tradition uses',
              style: TextStyle(
                fontSize: 12.5,
                color: kPenColor.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 15,
          color: kStartColor.withValues(alpha: 0.8),
        ),
        Text(
          orders.length == Lang.values.length
              ? 'every tradition writes it this way —'
              : 'written in the',
          style: TextStyle(fontSize: 12.5, color: kInk.withValues(alpha: 0.6)),
        ),
        for (final lang in orders) _LangChip(lang: lang),
        if (orders.length != Lang.values.length)
          Text(
            'order',
            style: TextStyle(fontSize: 12.5, color: kInk.withValues(alpha: 0.6)),
          ),
      ],
    );
  }
}

/// One tradition, named in English with its own character beside it.
///
/// Two `Text`s rather than one interpolated string so the English stands on
/// its own — 日 means nothing to a reader who has not got that far yet, which
/// is the whole reason this page says "Japanese" at all.
class _LangChip extends StatelessWidget {
  const _LangChip({required this.lang});

  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(lang);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lang.label,
            style: TextStyle(
              fontFamily: kHanziFont,
              fontSize: 12,
              color: accent.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            lang.name,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// What else it could have been. The gap between the winner and these is the
/// real measure of whether the square is settled.
class _Others extends StatelessWidget {
  const _Others({required this.others});

  final List<({String char, double confidence})> others;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'or maybe',
          style: TextStyle(fontSize: 11.5, color: kInk.withValues(alpha: 0.4)),
        ),
        const SizedBox(width: 8),
        for (final other in others)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  other.char,
                  style: TextStyle(
                    fontFamily: kHanziFont,
                    fontSize: 16,
                    color: kInk.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${(other.confidence * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: kInk.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.unreadable});

  final int unreadable;

  @override
  Widget build(BuildContext context) {
    if (unreadable > 0) {
      return Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: kPenColor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              unreadable == 1
                  ? 'One square reads as ? — nothing in the table has that '
                      'shape with that many strokes. Only the characters '
                      'bundled here can be found.'
                  : '$unreadable squares read as ? — nothing in the table has '
                      'those shapes with that many strokes. Only the '
                      'characters bundled here can be found.',
              style: TextStyle(
                color: kInk.withValues(alpha: 0.65),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }
    return Text(
      'One whole character per square. Each row reads out on the line under '
      'it, each character set beneath the square it came from, with how it is '
      'said, what it means, and how sure the reading is under that. Leave a '
      'square empty for a space.',
      style: TextStyle(
        color: kInk.withValues(alpha: 0.5),
        fontSize: 12,
        height: 1.4,
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote();

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(
        color: kInk.withValues(alpha: 0.55),
        fontSize: 11.5,
        height: 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Squared paper, the way an exercise book rules it: one whole '
            'character per square, rows read left to right. The eight faint '
            'guides in each square are the 米 the paper is named after — a box '
            'set in from the edges, halved both ways and crossed corner to '
            'corner. They are there to write over: the margin is what stops a '
            'character sprawling to the edges.',
          ),
          const SizedBox(height: 8),
          const Text(
            'A square is read whole rather than cut up. Every glyph in the '
            'table with the same number of strokes is scored against it, on '
            'the shape of each stroke and on how the strokes meet — whether '
            'they cross, touch end to end, or one lands in the middle of '
            'another. That last part is what tells 田 from 由, where the '
            'strokes sit in nearly the same places and only the crossing '
            'differs.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Under each character is the pinyin and a one-word meaning, and '
            'the same two lines run along the top of the page — so the grid '
            'can be read without reading Han yet, which is rather the point '
            'of practising it. The readings come from the same project the '
            'stroke shapes do. Kana are glossed with their romaji instead: '
            'they are syllables, not words, so there is nothing to translate.',
          ),
          const SizedBox(height: 8),
          const Text(
            'The percentage is how closely your strokes fitted the glyph that '
            'won — not a probability, and not a mark out of ten. It is worth '
            'reading next to what it beat: a square at 41% with another '
            'character two points behind it has not really decided anything, '
            'while one at 90% with nothing near it has. Both are spelled out '
            'under the grid, which is also where the bar under each square '
            'turns from teal to red.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Under the grid is whose stroke order you used. The same character '
            'is stored once per tradition — Chinese, Japanese and Korean, each '
            'in its own order — so a disagreement can be shown rather than '
            'averaged away. If it says no tradition uses that order, the shape '
            'was right and only the sequence was not.',
          ),
          const SizedBox(height: 8),
          Text(
            'This is a stroke reference, not a dictionary: $hanziCharacterCount '
            'characters, chosen to cover the stroke types and the places the '
            'three traditions part company. A character it does not hold reads '
            'as ?, however well it was written — and worse, one it does not '
            'hold can be read as a different one that it does, which is '
            'exactly what the percentage is there to expose. The whole set is '
            'in the character reference, grouped by stroke count. One reading '
            'and one sense are shown; most characters have more of both.',
          ),
        ],
      ),
    );
  }
}
