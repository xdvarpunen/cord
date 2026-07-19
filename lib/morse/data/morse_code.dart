// Morse code data and decoder, ported from the `shorthand` project's
// `MorseCodeDecoder` (git history) and self-contained under `lib/morse/` —
// it shares nothing with the other script features.

/// One drawn mark, as classified by [MorseLayer]: a dot (a tap), a dash (a
/// horizontal stroke), or a separator (a vertical stroke — one ends a letter,
/// two make a word space).
enum MorseSymbol { dot, dash, separator }

/// One row of the reference table: a character and its Morse code (using `.`
/// for dot and `-` for dash).
class MorseEntry {
  const MorseEntry(this.char, this.code);

  final String char;
  final String code;

  /// Whether this entry is a digit (used to group the reference table).
  bool get isDigit => char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39;
}

/// International Morse code — the 26 letters followed by the ten digits.
const morseAlphabet = <MorseEntry>[
  MorseEntry('A', '.-'),
  MorseEntry('B', '-...'),
  MorseEntry('C', '-.-.'),
  MorseEntry('D', '-..'),
  MorseEntry('E', '.'),
  MorseEntry('F', '..-.'),
  MorseEntry('G', '--.'),
  MorseEntry('H', '....'),
  MorseEntry('I', '..'),
  MorseEntry('J', '.---'),
  MorseEntry('K', '-.-'),
  MorseEntry('L', '.-..'),
  MorseEntry('M', '--'),
  MorseEntry('N', '-.'),
  MorseEntry('O', '---'),
  MorseEntry('P', '.--.'),
  MorseEntry('Q', '--.-'),
  MorseEntry('R', '.-.'),
  MorseEntry('S', '...'),
  MorseEntry('T', '-'),
  MorseEntry('U', '..-'),
  MorseEntry('V', '...-'),
  MorseEntry('W', '.--'),
  MorseEntry('X', '-..-'),
  MorseEntry('Y', '-.--'),
  MorseEntry('Z', '--..'),
  MorseEntry('1', '.----'),
  MorseEntry('2', '..---'),
  MorseEntry('3', '...--'),
  MorseEntry('4', '....-'),
  MorseEntry('5', '.....'),
  MorseEntry('6', '-....'),
  MorseEntry('7', '--...'),
  MorseEntry('8', '---..'),
  MorseEntry('9', '----.'),
  MorseEntry('0', '-----'),
];

final Map<String, String> _codeToChar = {
  for (final e in morseAlphabet) e.code: e.char,
};

String _decodeLetter(List<MorseSymbol> letter) {
  final code =
      letter.map((s) => s == MorseSymbol.dot ? '.' : '-').join();
  return _codeToChar[code] ?? '?';
}

/// Decodes a stream of drawn symbols into text. A single [MorseSymbol.separator]
/// ends the current letter; two in a row insert a word space; dots and dashes
/// accumulate into the current letter. Ported from `MorseCodeDecoder.decode`
/// (vertical-separation mode).
String decodeMorse(List<MorseSymbol> symbols) {
  final text = StringBuffer();
  final current = <MorseSymbol>[];

  for (var i = 0; i < symbols.length; i++) {
    final symbol = symbols[i];
    if (symbol == MorseSymbol.separator) {
      if (current.isNotEmpty) {
        text.write(_decodeLetter(current));
        current.clear();
      }
      // Two separators in a row = a word space.
      if (i + 1 < symbols.length && symbols[i + 1] == MorseSymbol.separator) {
        text.write(' ');
        i++;
      }
    } else {
      current.add(symbol);
    }
  }
  if (current.isNotEmpty) {
    text.write(_decodeLetter(current));
  }
  return text.toString();
}
