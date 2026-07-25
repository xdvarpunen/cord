/// Turns a flat list of jamo into Hangul syllable blocks, and back again.
///
/// Pure Dart — no Flutter import, no state, no I/O. Everything here is
/// exhaustively testable, and the test suite does exactly that: it round-trips
/// all 11,172 syllables through [decompose] and [compose].
///
/// ## Why a fold over a flat buffer, and not a mutating IME automaton
///
/// The obvious design is an automaton that holds a "current block" and mutates
/// it as letters arrive. It works right up until backspace.
///
/// Backspace has to undo the last *letter*, and un-steal. Write ㅇ ㅏ ㄴ ㅈ ㅏ and
/// the screen reads 안자 — two blocks, because the ㅈ was stolen away from 앉 by
/// the ㅏ that followed it. Backspace must now show 앉: **one** block, not two.
/// A mutating automaton has to carry an undo log recording that a steal
/// happened, which coda it took, and how to put it back.
///
/// So the buffer is a flat `List<String>` of jamo and the whole thing is
/// re-folded from scratch on every change. Backspace is `removeLast()`, and
/// the re-fold produces 앉 for the simple reason that that is what those four
/// letters compose to. There is no undo logic to get wrong. Buffers are tens
/// of letters long; recomputing is free.
library;

import 'jamo_tables.dart';

/// One syllable block, or one unfinished fragment of one.
class ComposedBlock {
  const ComposedBlock({
    required this.cho,
    required this.jung,
    required this.jong,
    required this.text,
    required this.firstJamo,
    required this.lastJamo,
  });

  /// Onset index into [kChoseong], or null if none has been written yet.
  final int? cho;

  /// Nucleus index into [kJungseong], or null.
  final int? jung;

  /// Coda index into [kJongseong]. 0 and null both mean "no coda"; null is
  /// used before a nucleus exists, where a coda is not yet meaningful.
  final int? jong;

  /// What this block renders as: one precomposed syllable, one bare
  /// compatibility jamo, or a space.
  final String text;

  /// Inclusive range of buffer positions this block was built from.
  ///
  /// Free to track during the fold, and it buys two things: knowing which
  /// block the next letter will land in, and letting a tap on a block
  /// truncate the buffer back to where that block started.
  final int firstJamo;
  final int lastJamo;

  /// True once the block is a real syllable — an onset and a nucleus at
  /// minimum. A lone ㄱ or a lone ㅏ is not.
  bool get isSyllable => cho != null && jung != null;

  bool get isBreak => text == kWordBreak;
}

/// The result of folding a jamo buffer.
class Composition {
  const Composition(this.text, this.blocks);

  /// Everything written so far, as Korean text.
  final String text;

  final List<ComposedBlock> blocks;

  bool get isEmpty => blocks.isEmpty;
}

/// Mutable scratch block used only inside [compose].
class _Block {
  _Block(this.firstJamo) : lastJamo = firstJamo;

  int? cho;
  int? jung;
  int? jong;
  int firstJamo;
  int lastJamo;

  bool get isBreak => cho == null && jung == null && jong == null;

  /// An onset with a nucleus and no coda — the one state a following vowel
  /// can merge into, and the one a following consonant can close.
  bool get isOpen => cho != null && jung != null && (jong ?? 0) == 0;

  /// An onset, a nucleus and a coda — the one state a following vowel steals
  /// from.
  bool get isClosed => cho != null && jung != null && (jong ?? 0) != 0;

  bool get isOnsetOnly => cho != null && jung == null;

  String get jungGlyph => kJungseong[jung!];
  String get jongGlyph => kJongseong[jong ?? 0];

  /// A block with a coda but no nucleus is unrepresentable by construction —
  /// the coda transitions all require [isOpen], which requires both.
  String get text => switch ((cho, jung)) {
        (final c?, final j?) => syllable(c, j, jong ?? 0),
        (final c?, null) => kChoseong[c],
        (null, final j?) => kJungseong[j],
        _ => kWordBreak,
      };

  ComposedBlock freeze() => ComposedBlock(
        cho: cho,
        jung: jung,
        jong: jong,
        text: text,
        firstJamo: firstJamo,
        lastJamo: lastJamo,
      );
}

/// Folds a buffer of compatibility jamo into syllable blocks.
///
/// Unknown tokens are dropped rather than rendered — the recognizer's output
/// alphabet is exactly the 19 onsets plus the 21 nuclei, so this never fires
/// in practice, but the alternative is emitting text the user did not write.
Composition compose(List<String> jamo) {
  final blocks = <_Block>[];

  /// The block a new letter lands in — the last one, unless it is a word
  /// break, which stops the fold dead so a space really does start fresh.
  _Block? cur() {
    if (blocks.isEmpty) return null;
    final last = blocks.last;
    return last.isBreak ? null : last;
  }

  for (var i = 0; i < jamo.length; i++) {
    final j = jamo[i];

    if (j == kWordBreak) {
      blocks.add(_Block(i));
      continue;
    }

    final vowel = kJungseongIndex[j];
    if (vowel != null) {
      final block = cur();

      // Merge two vowels into a compound one — but only in an open block.
      // 앙 + ㅏ has a coda, so it falls through to the steal below and gives
      // 아아, which is right; merging there would silently drop the ㅇ.
      if (block != null && block.isOpen) {
        final merged = kJungMerge[block.jungGlyph + j];
        if (merged != null) {
          block.jung = kJungseongIndex[merged]!;
          block.lastJamo = i;
          continue;
        }
      }

      // The steal. A vowel after a closed block pulls the coda forward to be
      // its own onset: 각 + ㅏ → 가가. A cluster coda splits and gives up only
      // its second half: 앉 + ㅏ → 안자.
      if (block != null && block.isClosed) {
        final coda = block.jongGlyph;
        final split = kJongSplit[coda];
        final keep = split?.$1;
        final moved = split?.$2 ?? coda;

        block.jong = keep == null ? 0 : kJongseongIndex[keep]!;
        // On a closed block the last jamo is always the consonant that
        // supplied the coda — for a cluster, its second half. That is exactly
        // the letter moving out, so the block now ends one position earlier
        // and the new block starts where the moved letter was written.
        final movedAt = block.lastJamo;
        block.lastJamo = movedAt - 1;

        final next = _Block(movedAt)
          ..cho = kChoseongIndex[moved]!
          ..jung = vowel
          ..lastJamo = i;
        blocks.add(next);
        continue;
      }

      // An onset waiting for its vowel.
      if (block != null && block.isOnsetOnly) {
        block.jung = vowel;
        block.lastJamo = i;
        continue;
      }

      // Nothing to attach to: an orphan vowel, rendered as the bare letter.
      // Deliberately *not* given a silent ㅇ onset — inventing a letter the
      // user did not write is worse than showing the block unfinished.
      blocks.add(_Block(i)..jung = vowel);
      continue;
    }

    final onset = kChoseongIndex[j];
    if (onset == null) continue; // not a letter this app can place

    final block = cur();

    // Close an open block. Tentative: a following vowel may steal it straight
    // back out again. ㄸ, ㅃ and ㅉ have no coda index at all, so they fall
    // through to a new block for free — 가 + ㄸ is 가ㄸ, never a bad 가 with a
    // coda it cannot have.
    if (block != null && block.isOpen) {
      final coda = kJongseongIndex[j];
      if (coda != null) {
        block.jong = coda;
        block.lastJamo = i;
        continue;
      }
    }

    // A second consonant on a closed block clusters with the first: 갑 + ㅅ
    // gives 값.
    if (block != null && block.isClosed) {
      final merged = kJongMerge[block.jongGlyph + j];
      if (merged != null) {
        block.jong = kJongseongIndex[merged]!;
        block.lastJamo = i;
        continue;
      }
    }

    // Anything else starts a new block. Note this is also the path taken
    // after an orphan vowel: ㅏ is not open (it has no onset), so ㅏ + ㄴ is
    // two orphan blocks, not a coda hanging off a naked vowel.
    blocks.add(_Block(i)..cho = onset);
  }

  final frozen = [for (final b in blocks) b.freeze()];
  return Composition(frozen.map((b) => b.text).join(), frozen);
}

/// Splits Korean text back into the letters you would draw to write it.
///
/// The exact inverse of [compose]: cluster codas expand into their two
/// components, because two letters is how you actually write them. Anything
/// that is not a precomposed syllable — a space, a bare jamo, Latin — passes
/// through unchanged.
List<String> decompose(String hangul) {
  final out = <String>[];
  for (final rune in hangul.runes) {
    if (rune < kSyllableBase || rune > kSyllableLast) {
      out.add(String.fromCharCode(rune));
      continue;
    }
    final offset = rune - kSyllableBase;
    out.add(kChoseong[offset ~/ (21 * 28)]);
    out.add(kJungseong[(offset ~/ 28) % 21]);
    final jong = offset % 28;
    if (jong != 0) {
      final glyph = kJongseong[jong];
      final split = kJongSplit[glyph];
      if (split == null) {
        out.add(glyph);
      } else {
        out
          ..add(split.$1)
          ..add(split.$2);
      }
    }
  }
  return out;
}
