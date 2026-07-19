/// One sign of the Southwestern Paleohispanic ("Tartessian") signary.
///
/// The script is a *semi-syllabary*: the stop consonants (b, t, k) are
/// written with syllabic signs that already carry their following vowel
/// (ka, ke, ki, ko, ku …), yet that vowel is *also* written with its own
/// vowel sign — the script's characteristic "vocalic redundancy". Vowels and
/// the continuant consonants (l, m, n, r, s …) are plain alphabetic signs.
///
/// Decipherment is only partial (about 20 sound values are scholarly
/// consensus, the rest hypothetical), and the signs have no Unicode
/// codepoints, so this table records the *transliteration* and phonetic value
/// only — the actual letterforms are drawn freehand on the canvas and matched
/// by [TartessianLayer]. [recognized] flags the signs the recognizer can
/// already read, so the reference can show what's live.
class TartessianSign {
  const TartessianSign(
    this.transliteration,
    this.value,
    this.category, {
    this.recognized = false,
  });

  /// Latin transliteration used by epigraphers, e.g. `ka`, `bu`, `ś`.
  final String transliteration;

  /// The sound (or sound + inherent vowel) the sign stands for.
  final String value;

  /// Which family the sign belongs to — groups the reference table.
  final String category;

  /// Whether [TartessianLayer] can currently recognize this sign drawn
  /// freehand. Only the signs with a built classifier are `true`.
  final bool recognized;
}

/// The signary, grouped by [TartessianSign.category]. Values follow the
/// commonly cited readings (Rodríguez Ramos / de Hoz); the redundant-vowel
/// stop series are the syllabic signs, the rest are alphabetic.
const tartessianSigns = <TartessianSign>[
  // Vowels — plain alphabetic signs.
  TartessianSign('a', 'a', 'Vowel', recognized: true),
  TartessianSign('e', 'e', 'Vowel', recognized: true),
  TartessianSign('i', 'i', 'Vowel', recognized: true),
  TartessianSign('o', 'o', 'Vowel', recognized: true),
  TartessianSign('u', 'u', 'Vowel', recognized: true),

  // Labial stop series (syllabic, + inherent vowel).
  TartessianSign('ba', 'b + a', 'Labial stop', recognized: true),
  TartessianSign('be', 'b + e', 'Labial stop', recognized: true),
  TartessianSign('bi', 'b + i', 'Labial stop', recognized: true),
  TartessianSign('bo', 'b + o', 'Labial stop', recognized: true),
  TartessianSign('bu', 'b + u', 'Labial stop', recognized: true),

  // Dental stop series (syllabic, + inherent vowel).
  TartessianSign('ta', 't + a', 'Dental stop', recognized: true),
  TartessianSign('te', 't + e', 'Dental stop', recognized: true),
  TartessianSign('ti', 't + i', 'Dental stop', recognized: true),
  TartessianSign('to', 't + o', 'Dental stop', recognized: true),
  TartessianSign('tu', 't + u', 'Dental stop', recognized: true),

  // Velar stop series (syllabic, + inherent vowel). ka reads as g or k.
  TartessianSign('ka', 'k / g + a', 'Velar stop', recognized: true),
  TartessianSign('ke', 'k / g + e', 'Velar stop', recognized: true),
  TartessianSign('ki', 'k / g + i', 'Velar stop', recognized: true),
  TartessianSign('ko', 'k / g + o', 'Velar stop', recognized: true),
  TartessianSign('ku', 'k / g + u', 'Velar stop', recognized: true),

  // Continuants — plain alphabetic signs.
  TartessianSign('l', 'l', 'Continuant'),
  TartessianSign('m', 'm', 'Continuant'),
  TartessianSign('n', 'n', 'Continuant'),
  TartessianSign('r', 'r', 'Continuant'),
  TartessianSign('ri', 'r + i', 'Continuant', recognized: true),
  TartessianSign('ŕ', 'r (second rhotic)', 'Continuant'),
  TartessianSign('s', 's', 'Continuant'),
  TartessianSign('sa', 's + a', 'Continuant', recognized: true),
  TartessianSign('se', 's + e', 'Continuant', recognized: true),
  TartessianSign('ś', 's (second sibilant)', 'Continuant'),
];

/// The distinct categories, in table order.
const tartessianCategories = <String>[
  'Vowel',
  'Labial stop',
  'Dental stop',
  'Velar stop',
  'Continuant',
];
