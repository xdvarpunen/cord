import 'package:flutter/material.dart';

import '../compose/hangul_composer.dart';
import '../compose/romanize.dart';
import '../compose/square_reading.dart';
import '../engine/game_canvas.dart';
import '../engine/scene.dart';
import '../palette.dart';
import '../recognition/block_recognizer.dart';
import '../scenes/block_scene.dart';
import '../scenes/grid_scene.dart';
import 'common.dart';

/// Squares you write whole Hangul syllables into, with each row read out on a
/// line beneath it — the ruled grid an East Asian exercise notebook is printed
/// with, one syllable per square.
///
/// Ported from the `hangul-word` project's "Syllable rows" tab and
/// self-contained under `lib/hangul_grid/`: its own engine, scenes,
/// recognizer, composer, and palette, sharing nothing with the jamo-by-jamo
/// [HangulPage] next door. What did *not* come across is the tab shell around
/// it — the word list, the target banner, and the other five tabs — so this is
/// the grid on its own, free practice with no word to hit.
///
/// A stroke joins whichever square its centre lands in, squares read left to
/// right and then down a row, and an empty square between two written ones is
/// a space. Each square is cut into onset, vowel, and final by
/// [recognizeBlock] — every gap between its strokes, in each of the six ways a
/// block can be arranged, keeping the cut where each piece is a real letter of
/// the right kind.
class HangulGridPage extends StatefulWidget {
  const HangulGridPage({super.key});

  @override
  State<HangulGridPage> createState() => _HangulGridPageState();
}

class _HangulGridPageState extends State<HangulGridPage> {
  static const _columns = 4;
  static const _rows = 2;

  /// The band under each row. Tall enough for a 22pt syllable with its
  /// romanization under it and air around both, and the same distance the
  /// stroke capture steps its rows by — see [buildBlockScene].
  static const _readHeight = 54.0;

  late final (Scene, BlockPaperLayer, WordGridLayer) _built = buildBlockScene(
    columns: _columns,
    rows: _rows,
    readHeight: _readHeight,
    onChanged: _recognize,
  );
  late final SceneManager _sceneManager = SceneManager(_built.$1);
  BlockPaperLayer get _paper => _built.$2;
  WordGridLayer get _grid => _built.$3;

  List<BlockReading?> _readings = List.filled(_columns * _rows, null);
  List<bool> _written = List.filled(_columns * _rows, false);
  List<ComposedBlock> _blocks = const [];

  void _recognize() {
    final size = _grid.cellSize;
    if (size == null) return;

    final readings = <BlockReading?>[];
    final written = <bool>[];
    for (final strokes in _grid.localCells) {
      written.add(strokes.isNotEmpty);
      readings.add(
        strokes.isEmpty ? null : recognizeBlock(strokes, blockSize: size),
      );
    }

    final composition = composeSquares(
      jamo: [for (final r in readings) r?.jamo],
      written: written,
    );
    // The romanization is split per block rather than romanizing each square
    // on its own, so a square's sound and the whole word's sound are the
    // same reading — 각 before 아 shows as "ga", which is how it is said.
    final sounds = romanizeEachBlock(composition.blocks);

    setState(() {
      _readings = readings;
      _written = written;
      _blocks = composition.blocks;
      _paper
        ..readings = [
          for (var i = 0; i < readings.length; i++)
            (
              text: readings[i]?.text,
              roman: switch (composition.blockOfSquare[i]) {
                final b? => sounds[b],
                null => null,
              },
            ),
        ]
        ..states = [
          for (var i = 0; i < readings.length; i++)
            if (!written[i])
              CellState.empty
            else if (readings[i] == null)
              CellState.unknown
            else
              CellState.recognized,
        ];
    });
  }

  int get _unreadable {
    var count = 0;
    for (var i = 0; i < _written.length; i++) {
      if (_written[i] && _readings[i] == null) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _blocks;
    final text = blocks.map((b) => b.text).join();

    return Scaffold(
      appBar: AppBar(title: const Text('Hangul Grid')),
      body: Container(
        color: kPaper,
        child: ContentColumn(
          children: [
            _Reading(text: text, blocks: blocks),
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill(
                  label: 'Undo stroke',
                  onTap: () => _grid.undo(),
                  enabled: _written.contains(true),
                ),
                Pill(
                  label: 'Clear page',
                  accent: kPenColor,
                  onTap: () => _grid.clear(),
                  enabled: _written.contains(true),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Hairline(),
            const SizedBox(height: 14),
            const _Footnote(),
          ],
        ),
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({required this.text, required this.blocks});

  final String text;
  final List<ComposedBlock> blocks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: kReadingHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: paperCard(),
      child: text.isEmpty
          ? Text(
              'Write a syllable in each square — the row reads out beneath it',
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
                // second line would grow the panel and shift the squares
                // down mid-word.
                Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: const TextStyle(
                    fontFamily: kHangulFont,
                    fontSize: 36,
                    height: 1.2,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  romanizeBlocks(blocks),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: 17,
                    letterSpacing: 0.3,
                    color: kInk.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
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
                  ? 'One square reads as ? — nothing in it came out as a '
                      'syllable. Try leaving more space between the letters.'
                  : '$unreadable squares read as ? — nothing in them came out '
                      'as a syllable. Try leaving more space between the '
                      'letters.',
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
      'One whole syllable per square. Each row reads out on the line under '
      'it, each syllable set beneath the square it came from, with how it '
      'sounds under that. Leave a square empty for a space.',
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Squared paper, the way an exercise notebook rules it: one whole '
            'syllable per square, rows read left to right. A square is cut at '
            'the gaps between its strokes, every way the six arrangements of '
            'a block allow, and the cut kept is the one where each piece is a '
            'real letter of the right kind.',
          ),
          SizedBox(height: 8),
          Text(
            'The row is read out on the line beneath it, syllable under '
            'square, with the sound under that — so it can be read without '
            'reading Hangul yet. The dashed cross in each square is the block '
            'layout drawn out: onset left of the vertical or above the '
            'horizontal, vowel on the other side, final along the bottom.',
          ),
          SizedBox(height: 8),
          Text(
            'The sound under a square is what that syllable contributes, not '
            'what it would say on its own. 각 alone is "gak", but written '
            'before 아 its final moves across and the two come out "ga" and '
            '"ga" — which is how 각아 is really said, and worth seeing rather '
            'than hiding. It is the same reading as the line at the top of '
            'the page, only broken up; the pieces always join back into it.',
          ),
        ],
      ),
    );
  }
}
