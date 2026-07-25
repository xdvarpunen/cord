import 'package:flutter_test/flutter_test.dart';
import 'package:cord/hangul_grid/compose/square_reading.dart';

/// Reading a grid of syllable squares, on plain lists.
///
/// Shared by the Syllables tab and the Syllable rows tab, which differ only
/// in where they print the answer.

/// Builds the two parallel lists from a compact notation: a space-separated
/// entry per square, `.` for an empty one and `?` for one holding ink that
/// read as nothing. A syllable is written as its letters run together.
(List<List<String>?>, List<bool>) grid(List<String> squares) {
  final jamo = <List<String>?>[];
  final written = <bool>[];
  for (final s in squares) {
    switch (s) {
      case '.':
        jamo.add(null);
        written.add(false);
      case '?':
        jamo.add(null);
        written.add(true);
      default:
        jamo.add(s.split(''));
        written.add(true);
    }
  }
  return (jamo, written);
}

String textOf(List<String> squares) {
  final (jamo, written) = grid(squares);
  return composeSquares(jamo: jamo, written: written)
      .blocks
      .map((b) => b.text)
      .join();
}

/// Which block each square produced, for pages that print a square's reading
/// under the square itself.
List<int?> mappingOf(List<String> squares) {
  final (jamo, written) = grid(squares);
  return composeSquares(jamo: jamo, written: written).blockOfSquare;
}

void main() {
  test('each square is composed on its own', () {
    // The rule the whole file exists for. Run together as one sequence these
    // six letters compose to 가가 — the second onset stolen back as the
    // first square's final. Kept apart they are what was written.
    expect(textOf(['ㄱㅏㄱ', 'ㅇㅏ']), '각아');
    expect(textOf(['ㄱㅏ', 'ㄱㅏ']), '가가');
  });

  test('reads squares left to right and down', () {
    expect(textOf(['ㅇㅏㄴ', 'ㄴㅕㅇ']), '안녕');
  });

  test('a two-letter final stays in its own square', () {
    expect(textOf(['ㄱㅏㅂㅅ']), '값');
    expect(textOf(['ㄷㅏㄹㄱ']), '닭');
  });

  group('empty squares', () {
    test('one between words is a space', () {
      expect(textOf(['ㄱㅏ', '.', 'ㄴㅏ']), '가 나');
    });

    test('a run of them is still one space', () {
      expect(textOf(['ㄱㅏ', '.', '.', '.', 'ㄴㅏ']), '가 나');
    });

    test('leading ones are ignored', () {
      expect(textOf(['.', '.', 'ㄱㅏ']), '가');
    });

    test('trailing ones are the rest of the page, not a break', () {
      expect(textOf(['ㄱㅏ', '.', '.']), '가');
    });

    test('a space stops a final being stolen', () {
      expect(textOf(['ㄱㅏㄱ', '.', 'ㅇㅏ']), '각 아');
    });

    test('an empty grid reads as nothing', () {
      expect(textOf(['.', '.', '.']), isEmpty);
    });
  });

  group('a square that read as nothing', () {
    test('is skipped, not read', () {
      expect(textOf(['ㄱㅏ', '?', 'ㄴㅏ']), '가나');
    });

    test('is not a space — it is a mistake', () {
      // Contrast with the empty square above, which does break.
      expect(textOf(['ㄱㅏ', '?', 'ㄴㅏ']), isNot(contains(' ')));
    });

    test('does not start the word early', () {
      expect(textOf(['?', '.', 'ㄱㅏ']), '가');
    });
  });

  test('a half-written square contributes the letter so far', () {
    expect(textOf(['ㄱ']), 'ㄱ');
    expect(textOf(['ㄱㅏ', 'ㄴ']), '가ㄴ');
  });

  group('which block each square produced', () {
    // Blocks and squares are not one to one: an empty square can add a word
    // break and an unreadable one adds nothing. A page printing a square's
    // reading under the square needs to know which is which.
    test('one block each, in order', () {
      expect(mappingOf(['ㅇㅏㄴ', 'ㄴㅕㅇ']), [0, 1]);
    });

    test('an empty square adds a break the next square skips over', () {
      // Block 1 is the space, so the third square's block is 2.
      expect(mappingOf(['ㄱㅏ', '.', 'ㄴㅏ']), [0, null, 2]);
    });

    test('an unreadable square maps to nothing', () {
      expect(mappingOf(['ㄱㅏ', '?', 'ㄴㅏ']), [0, null, 1]);
    });

    test('leading empties map to nothing and cost no block', () {
      expect(mappingOf(['.', '.', 'ㄱㅏ']), [null, null, 0]);
    });

    test('every mapped index points at a real block', () {
      final (jamo, written) = grid(['ㄱㅏ', '.', '?', 'ㄴㅏ', 'ㄷㅏ']);
      final result = composeSquares(jamo: jamo, written: written);
      for (final index in result.blockOfSquare) {
        if (index == null) continue;
        expect(index, lessThan(result.blocks.length));
      }
    });
  });

  test('written shorter than jamo does not throw', () {
    // Defensive: the two lists are built together in practice, but a
    // mismatch should degrade rather than crash.
    expect(
      () => composeSquares(jamo: [null, null], written: const []),
      returnsNormally,
    );
  });
}
