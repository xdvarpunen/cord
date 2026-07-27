/// One letter of the Latin script, as shown in the page's legend: its capital
/// and lowercase forms, the letter's own spoken name, and the sound it stands
/// for. [name] is the key the recognizer matches on (see
/// `LatinLayer.recognizedNames`), since it's the one field that's unambiguous —
/// several letters share a sound spelling (C and K, C and S, Ä and Æ), and the
/// glyphs come in pairs.
class LetterRow {
  const LetterRow(this.capital, this.small, this.name, this.sound);

  final String capital;
  final String small;
  final String name;
  final String sound;
}

/// Which alphabet the page is set to. They differ only in which letters they
/// have and the order they put them in, not in the shapes of the ones they
/// share.
///
/// The recognizer reads the same shapes whichever is chosen; [letters] is what
/// it consults before reporting one, so a letter the chosen alphabet hasn't got
/// falls through to whatever the next classifier makes of the same drawing (see
/// `LatinLayer.alphabet`). Draw an Á under [english] and it reads A, the accent
/// ignored.
///
/// Each alphabet spells its letters out as a string of capitals, in its own
/// order. Every letter in [alphabetRows] is a single UTF-16 code unit, so that
/// string is the alphabet, readable at a glance and checkable against a
/// reference. Spelling out the order rather than filtering one shared list is
/// what lets Icelandic interleave its accented letters and Spanish file Ñ
/// between N and O — and it's what lets German put Ä after A, where DIN 5007-1
/// puts it, rather than away past Z.
///
/// Where an accented letter is a letter in its own right the alphabet gives it
/// its own slot (Spanish Ñ, Icelandic Á and Ð); where it's a variant of its base
/// it sits immediately after that base (Spanish Á, German Ä). That's how these
/// languages collate.
enum Alphabet {
  /// The 26 of A–Z, as English and most modern Latin-script languages use it.
  english('English', 'the 26 of A–Z', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),

  /// The 23 of classical Latin. It has no J, U or W: I served for both I and J,
  /// V for both U and V, and W is a later ligature of two of them. Y and Z it
  /// does have, taken from Greek for spelling Greek loanwords.
  latin('Latin', 'no J, U or W', 'ABCDEFGHIKLMNOPQRSTVXYZ'),

  /// The 27 single letters of Albanian, which has no W.
  ///
  /// Its nine digraphs — DH GJ LL NJ RR SH TH XH ZH — count as letters of the
  /// alphabet too, bringing it to 36, but they have no representation here: a
  /// letter is one row of [alphabetRows] and one glyph. Dutch IJ and Hungarian's
  /// digraphs are left out for the same reason.
  albanian('Albanian', 'no W; Ç and Ë of its own', 'ABCÇDEËFGHIJKLMNOPQRSTUVXYZ'),

  /// The 37 of Catalan: A–Z with Ç, nine accented vowels, and Ŀ.
  ///
  /// Ŀ is really half of the digraph Ŀ·L, but unlike the other digraphs here it
  /// has a glyph of its own, so it earns a row.
  catalan('Catalan', 'A–Z with Ç, nine accented vowels and Ŀ',
      'AÀBCÇDEÉÈFGHIÍÏJKLĿMNOÓÒPQRSTUÚÜVWXYZ'),

  /// The 29 of Danish: A–Z with Æ, Ø and Å after Z. Letter for letter and order
  /// for order the same alphabet as [norwegian] — listed apart because both
  /// languages were asked for by name.
  danish('Danish', 'A–Z plus Æ, Ø and Å — the same 29 as Norwegian',
      'ABCDEFGHIJKLMNOPQRSTUVWXYZÆØÅ'),

  /// The 26 of Dutch, with É, Ë and Ï for loanwords and hiatus. Its IJ is a
  /// digraph and so isn't here.
  dutch('Dutch', 'A–Z with É, Ë and Ï', 'ABCDEÉËFGHIÏJKLMNOPQRSTUVWXYZ'),

  /// The 29 of Faroese, which has no C, Q, W, X or Z.
  faroese('Faroese', 'no C, Q, W, X or Z; Ð, Æ and Ø of its own',
      'AÁBDÐEFGHIÍJKLMNOÓPRSTUÚVYÝÆØ'),

  /// The 29 of Finnish: A–Z with Å, Ä and Ö after Z, where they sort as letters
  /// of their own rather than as accented A's and O's. The same alphabet as
  /// [swedish].
  ///
  /// Finland's own standard also admits Š and Ž for spelling loanwords, which
  /// Swedish doesn't and which aren't here: the recognizer reads no caron.
  finnish('Finnish', 'A–Z plus Å, Ä and Ö — the same 29 as Swedish',
      'ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖ'),

  /// The 42 of French: A–Z with sixteen letters beyond it.
  ///
  /// The one alphabet here that isn't wholly drawable — Œ has no shape yet, and
  /// is listed muted.
  french('French', 'A–Z with sixteen letters beyond it',
      'AÀÂÆBCÇDEÉÈÊËFGHIÎÏJKLMNOÔŒPQRSTUÙÛÜVWXYŸZ'),

  /// The 30 of German: A–Z with the three umlauts Ä, Ö and Ü, and ß.
  ///
  /// Each umlaut sits after its own base letter, as DIN 5007-1 files them, and
  /// ß after Z. They are the *same* marks Finnish and Swedish use over Ä and Ö,
  /// and the recognizer neither knows nor needs to know that the two languages
  /// think of them differently.
  german('German', 'A–Z plus Ä, Ö, Ü and ß', 'AÄBCDEFGHIJKLMNOÖPQRSTUÜVWXYZß'),

  /// The 32 of Icelandic, which has no C, Q, W or Z, and Ð, Þ, Æ and Ö of its
  /// own. Ð and Þ have no shape yet and are listed muted.
  icelandic('Icelandic', 'no C, Q, W or Z; Ð, Þ, Æ and Ö of its own',
      'AÁBDÐEÉFGHIÍJKLMNOÓPRSTUÚVXYÝÞÆÖ'),

  /// The traditional 18 of Irish with the five long vowels — no J, K, Q, V, W,
  /// X, Y or Z, which appear only in loanwords and names.
  irish('Irish', 'the traditional 18, with five fadas',
      'AÁBCDEÉFGHIÍLMNOÓPRSTUÚ'),

  /// The 32 of Italian: A–Z with six accented vowels.
  ///
  /// Italy teaches a 21-letter alphabet, J K W X Y being counted foreign. They
  /// are kept here all the same: unlike [latin]'s missing J, U and W, which
  /// genuinely did not exist, modern Italian writes these in loanwords and
  /// names, and an alphabet that refused them would misread real text.
  italian('Italian', 'A–Z with six accented vowels',
      'AÀBCDEÉÈFGHIÌJKLMNOÒPQRSTUÙVWXYZ'),

  /// The 29 of Norwegian: A–Z with Æ, Ø and Å after Z — Å last, where Finnish
  /// and Swedish put it first of their three. The same alphabet as [danish].
  norwegian('Norwegian', 'A–Z plus Æ, Ø and Å — the same 29 as Danish',
      'ABCDEFGHIJKLMNOPQRSTUVWXYZÆØÅ'),

  /// The 38 of Portuguese: A–Z with Ç and eleven accented vowels. K, W and Y
  /// were readmitted in 2009.
  portuguese('Portuguese', 'A–Z with Ç and eleven accented vowels',
      'AÁÂÃÀBCÇDEÉÊFGHIÍJKLMNOÓÔÕPQRSTUÚVWXYZ'),

  /// The 33 of Spanish: A–Z with Ñ filed between N and O as the letter of its
  /// own that it is, and six accented vowels beside their bases.
  spanish('Spanish', 'A–Z with Ñ, and six accented vowels',
      'AÁBCDEÉFGHIÍJKLMNÑOÓPQRSTUÚÜVWXYZ'),

  /// The 29 of Swedish: A–Z with Å, Ä and Ö after Z. The same alphabet as
  /// [finnish].
  swedish('Swedish', 'A–Z plus Å, Ä and Ö — the same 29 as Finnish',
      'ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖ'),

  // ── The alphabets Latin Extended-A serves ──────────────────────────────────
  //
  // Every one of these files its accented letters where its own dictionaries do,
  // which is why [letters] states an order rather than filtering one. Where a
  // language counts a digraph as a letter of its alphabet — Czech Ch, Slovak DZ
  // DŽ CH, Croatian DŽ LJ NJ, Hungarian's nine, Welsh's eight, Maltese GĦ and IE
  // — it isn't here: a letter is one row and one glyph.

  /// The 41 single letters of Czech, Ch aside.
  czech('Czech', 'A–Z with Á Č Ď É Ě Í Ň Ó Ř Š Ť Ú Ů Ý Ž',
      'AÁBCČDĎEÉĚFGHIÍJKLMNŇOÓPQRŘSŠTŤUÚŮVWXYÝZŽ'),

  /// The 43 single letters of Slovak, DZ DŽ CH aside.
  slovak('Slovak', 'Czech\'s letters with Ä, Ĺ, Ľ, Ô and Ŕ besides',
      'AÁÄBCČDĎEÉFGHIÍJKLĹĽMNŇOÓÔPQRŔSŠTŤUÚVWXYÝZŽ'),

  /// The 32 of Polish. Ą, Ę and Ł wait on marks the recognizer doesn't read.
  polish('Polish', 'A–Z with Ą Ć Ę Ł Ń Ó Ś Ź Ż',
      'AĄBCĆDEĘFGHIJKLŁMNŃOÓPRSŚTUWYZŹŻ'),

  /// The 35 single letters of Hungarian, its nine digraphs aside. Ő and Ű wait on
  /// the double acute.
  hungarian('Hungarian', 'A–Z with Á É Í Ó Ö Ő Ú Ü Ű',
      'AÁBCDEÉFGHIÍJKLMNOÓÖŐPQRSTUÚÜŰVWXYZ'),

  /// The 27 single letters of Croatian, DŽ LJ NJ aside.
  ///
  /// Its Đ is the same capital glyph as Icelandic's Ð — see
  /// `LatinLayer._classifyDStroke`.
  croatian('Croatian', 'A–Z less Q W X Y, with Č Ć Đ Š Ž',
      'ABCČĆDĐEFGHIJKLMNOPRSŠTUVZŽ'),

  /// The 25 of Slovenian — the smallest of these, and wholly drawable.
  slovenian('Slovenian', 'A–Z less Q W X Y, with Č Š Ž',
      'ABCČDEFGHIJKLMNOPRSŠTUVZŽ'),

  /// The 33 of Latvian. Its macrons and its four cedillas wait on marks not read.
  latvian('Latvian', 'A–Z less Q W X, with Ā Č Ē Ģ Ī Ķ Ļ Ņ Š Ū Ž',
      'AĀBCČDEĒFGĢHIĪJKĶLĻMNŅOPRSŠTUŪVZŽ'),

  /// The 32 of Lithuanian. Its ogoneks and Ū wait on marks not read.
  lithuanian('Lithuanian', 'A–Z less Q W X, with Ą Č Ę Ė Į Š Ų Ū Ž',
      'AĄBCČDEĘĖFGHIĮYJKLMNOPRSŠTUŲŪVZŽ'),

  /// The 32 of Estonian — Š and Ž file after S and Z, and Õ Ä Ö Ü after W.
  estonian('Estonian', 'A–Z with Š Ž Õ Ä Ö Ü',
      'ABCDEFGHIJKLMNOPQRSŠZŽTUVWÕÄÖÜXY'),

  /// The 31 of Romanian. Ă waits on the breve, and Ș and Ț on the comma below.
  romanian('Romanian', 'A–Z with Ă Â Î Ș Ț',
      'AĂÂBCDEFGHIÎJKLMNOPQRSȘTȚUVWXYZ'),

  /// The 29 of Turkish. Ğ waits on the breve and Ş on the cedilla.
  ///
  /// Its dotted İ and dotless ı are separate letters, but only İ has a capital of
  /// its own — ı's is plain I.
  turkish('Turkish', 'A–Z less Q W X, with Ç Ğ İ Ö Ş Ü',
      'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ'),

  /// The 27 single letters of Maltese, GĦ and IE aside. Ħ waits on the stroke.
  maltese('Maltese', 'A–Z with Ċ Ġ Ħ Ż',
      'ABĊDEFĠGĦHIJKLMNOPQRSTUVWXŻZ'),

  /// The 28 of Esperanto — no Q W X Y, and five circumflexes of its own. Ŭ waits
  /// on the breve.
  esperanto('Esperanto', 'A–Z less Q W X Y, with Ĉ Ĝ Ĥ Ĵ Ŝ Ŭ',
      'ABCĈDEFGĜHĤIJĴKLMNOPRSŜTUŬVZ'),

  /// The 28 single letters of Welsh, its eight digraphs aside — wholly drawable,
  /// its seven circumflexes included.
  welsh('Welsh', 'A–Z less K Q V X Z, with seven circumflexes',
      'AÂBCDEÊFGHIÎJLMNOÔPRSTUÛWŴYŶ');

  const Alphabet(this.label, this.note, this.letters);

  /// What the dropdown calls this alphabet.
  final String label;

  /// How the legend sums up what makes this alphabet itself.
  final String note;

  /// This alphabet's capitals, in its own order — one code unit each.
  final String letters;

  /// This alphabet's own letters, in its own order.
  ///
  /// Throws rather than skipping if [letters] names a capital [alphabetRows] has
  /// no row for, so a typo in one of those strings fails loudly instead of
  /// quietly shortening an alphabet.
  Iterable<LetterRow> get rows => letters.split('').map((capital) {
        final row = _byCapital[capital];
        if (row == null) {
          throw StateError(
              '$label lists "$capital", which alphabetRows has no row for');
        }
        return row;
      });
}

/// Every letter of every alphabet, looked up by its capital — the index behind
/// [Alphabet.rows].
final Map<String, LetterRow> _byCapital = {
  for (final row in alphabetRows) row.capital: row,
};

/// Every letter any alphabet might hold: A–Z, then the letters beyond it,
/// grouped by the mark that makes them.
///
/// A catalogue rather than an ordering — [Alphabet] states its own order, so the
/// sequence here is for reading only. Each letter is defined once and shared by
/// every alphabet that has it, so Ä is one row whether German or Swedish asks
/// for it, and a change to a letter's name or sound is made in one place.
///
/// Four of these have no shape the recognizer reads yet — Ç, Ð, Þ and Œ — and so
/// are absent from `LatinLayer.recognizedNames`. The legend lists them muted.
const alphabetRows = [
  LetterRow('A', 'a', 'ay', 'a'),
  LetterRow('B', 'b', 'bee', 'b'),
  LetterRow('C', 'c', 'see', 'k, s'),
  LetterRow('D', 'd', 'dee', 'd'),
  LetterRow('E', 'e', 'ee', 'e'),
  LetterRow('F', 'f', 'ef', 'f'),
  LetterRow('G', 'g', 'gee', 'g'),
  LetterRow('H', 'h', 'aitch', 'h'),
  LetterRow('I', 'i', 'eye', 'i'),
  LetterRow('J', 'j', 'jay', 'j'),
  LetterRow('K', 'k', 'kay', 'k'),
  LetterRow('L', 'l', 'el', 'l'),
  LetterRow('M', 'm', 'em', 'm'),
  LetterRow('N', 'n', 'en', 'n'),
  LetterRow('O', 'o', 'oh', 'o'),
  LetterRow('P', 'p', 'pee', 'p'),
  LetterRow('Q', 'q', 'cue', 'kw'),
  LetterRow('R', 'r', 'ar', 'r'),
  LetterRow('S', 's', 'ess', 's'),
  LetterRow('T', 't', 'tee', 't'),
  LetterRow('U', 'u', 'you', 'u'),
  LetterRow('V', 'v', 'vee', 'v'),
  LetterRow('W', 'w', 'double-u', 'w'),
  LetterRow('X', 'x', 'ex', 'ks'),
  LetterRow('Y', 'y', 'wy', 'y'),
  LetterRow('Z', 'z', 'zed', 'z'),

  // Letters of their own, owing nothing to a mark.
  LetterRow('Æ', 'æ', 'ash', 'ae'),
  LetterRow('Ø', 'ø', 'o-slash', 'oe'),
  LetterRow('ß', 'ß', 'sharp s', 'ss'),
  LetterRow('Ð', 'ð', 'eth', 'dh'),
  LetterRow('Þ', 'þ', 'thorn', 'th'),
  LetterRow('Œ', 'œ', 'ethel', 'oe'),

  // Acute — a line rising to the right, above.
  LetterRow('Á', 'á', 'a-acute', 'a'),
  LetterRow('É', 'é', 'e-acute', 'e'),
  LetterRow('Í', 'í', 'i-acute', 'i'),
  LetterRow('Ó', 'ó', 'o-acute', 'o'),
  LetterRow('Ú', 'ú', 'u-acute', 'u'),
  LetterRow('Ý', 'ý', 'y-acute', 'y'),

  // Grave — the same line falling instead.
  LetterRow('À', 'à', 'a-grave', 'a'),
  LetterRow('È', 'è', 'e-grave', 'e'),
  LetterRow('Ì', 'ì', 'i-grave', 'i'),
  LetterRow('Ò', 'ò', 'o-grave', 'o'),
  LetterRow('Ù', 'ù', 'u-grave', 'u'),

  // Circumflex — a Λ above.
  LetterRow('Â', 'â', 'a-circumflex', 'a'),
  LetterRow('Ê', 'ê', 'e-circumflex', 'e'),
  LetterRow('Î', 'î', 'i-circumflex', 'i'),
  LetterRow('Ô', 'ô', 'o-circumflex', 'o'),
  LetterRow('Û', 'û', 'u-circumflex', 'u'),

  // Tilde — three legs to and fro above.
  LetterRow('Ã', 'ã', 'a-tilde', 'an'),
  LetterRow('Ñ', 'ñ', 'n-tilde', 'ny'),
  LetterRow('Õ', 'õ', 'o-tilde', 'on'),

  // Diaeresis — a pair of dots above.
  LetterRow('Ä', 'ä', 'a-diaeresis', 'ae'),
  LetterRow('Ë', 'ë', 'e-diaeresis', 'e'),
  LetterRow('Ï', 'ï', 'i-diaeresis', 'i'),
  LetterRow('Ö', 'ö', 'o-diaeresis', 'oe'),
  LetterRow('Ü', 'ü', 'u-diaeresis', 'ue'),
  LetterRow('Ÿ', 'ÿ', 'y-diaeresis', 'y'),

  // Ring above.
  LetterRow('Å', 'å', 'a-ring', 'aa'),

  // Cedilla.
  LetterRow('Ç', 'ç', 'cedilla', 's'),

  // ── Latin Extended-A ───────────────────────────────────────────────────────
  //
  // Đ is the same capital glyph as Ð above; only the lowercase differs, and only
  // the alphabet decides which letter a drawing is.
  LetterRow('Đ', 'đ', 'd-stroke', 'd'),

  // Marks already read, over bases that hadn't taken them.
  LetterRow('Ć', 'ć', 'c-acute', 'ch'),
  LetterRow('Ĺ', 'ĺ', 'l-acute', 'l'),
  LetterRow('Ń', 'ń', 'n-acute', 'ny'),
  LetterRow('Ŕ', 'ŕ', 'r-acute', 'r'),
  LetterRow('Ś', 'ś', 's-acute', 'sh'),
  LetterRow('Ź', 'ź', 'z-acute', 'zh'),
  LetterRow('Ĉ', 'ĉ', 'c-circumflex', 'ch'),
  LetterRow('Ĝ', 'ĝ', 'g-circumflex', 'j'),
  LetterRow('Ĥ', 'ĥ', 'h-circumflex', 'kh'),
  LetterRow('Ĵ', 'ĵ', 'j-circumflex', 'zh'),
  LetterRow('Ŝ', 'ŝ', 's-circumflex', 'sh'),
  LetterRow('Ŵ', 'ŵ', 'w-circumflex', 'w'),
  LetterRow('Ŷ', 'ŷ', 'y-circumflex', 'y'),
  LetterRow('Ů', 'ů', 'u-ring', 'oo'),

  // Caron — a V above.
  LetterRow('Č', 'č', 'c-caron', 'ch'),
  LetterRow('Ď', 'ď', 'd-caron', 'dy'),
  LetterRow('Ě', 'ě', 'e-caron', 'ye'),
  LetterRow('Ľ', 'ľ', 'l-caron', 'ly'),
  LetterRow('Ň', 'ň', 'n-caron', 'ny'),
  LetterRow('Ř', 'ř', 'r-caron', 'rzh'),
  LetterRow('Š', 'š', 's-caron', 'sh'),
  LetterRow('Ť', 'ť', 't-caron', 'ty'),
  LetterRow('Ž', 'ž', 'z-caron', 'zh'),

  // Dot above — a single tap.
  LetterRow('Ċ', 'ċ', 'c-dot', 'ch'),
  LetterRow('Ė', 'ė', 'e-dot', 'e'),
  LetterRow('Ġ', 'ġ', 'g-dot', 'j'),
  LetterRow('İ', 'i̇', 'i-dot', 'i'),
  LetterRow('Ż', 'ż', 'z-dot', 'zh'),

  // Middle dot — a tap inside L's own box.
  LetterRow('Ŀ', 'ŀ', 'l-middle-dot', 'l'),

  // Comma below — the acute's own line, hung under the letter instead. Romanian's
  // own two, and Latin Extended-B rather than -A, admitted because Romanian needs
  // them.
  LetterRow('Ș', 'ș', 's-comma', 'sh'),
  LetterRow('Ț', 'ț', 't-comma', 'ts'),

  // ── Staged: listed by the alphabets that need them, but not yet drawable ────
  //
  // Each waits on a mark the recognizer doesn't read. See TODO.md.
  LetterRow('Ą', 'ą', 'a-ogonek', 'on'), // ogonek
  LetterRow('Ę', 'ę', 'e-ogonek', 'en'),
  LetterRow('Į', 'į', 'i-ogonek', 'in'),
  LetterRow('Ų', 'ų', 'u-ogonek', 'un'),
  LetterRow('Ā', 'ā', 'a-macron', 'aa'), // macron
  LetterRow('Ē', 'ē', 'e-macron', 'ee'),
  LetterRow('Ī', 'ī', 'i-macron', 'ii'),
  LetterRow('Ū', 'ū', 'u-macron', 'uu'),
  LetterRow('Ă', 'ă', 'a-breve', 'uh'), // breve
  LetterRow('Ğ', 'ğ', 'g-breve', 'gh'),
  LetterRow('Ŭ', 'ŭ', 'u-breve', 'w'),
  LetterRow('Ł', 'ł', 'l-stroke', 'w'), // stroke
  LetterRow('Ħ', 'ħ', 'h-stroke', 'h'),
  LetterRow('Ő', 'ő', 'o-double-acute', 'eu'), // double acute
  LetterRow('Ű', 'ű', 'u-double-acute', 'ue'),
  // Named for the cedilla after Unicode, drawn with the comma below Latvian
  // actually writes — so these four go through `_markedBelow` with Ș and Ț,
  // and Turkish's Ş, a true cedilla, goes with Ç instead.
  LetterRow('Ģ', 'ģ', 'g-cedilla', 'gy'),
  LetterRow('Ķ', 'ķ', 'k-cedilla', 'ky'),
  LetterRow('Ļ', 'ļ', 'l-cedilla', 'ly'),
  LetterRow('Ņ', 'ņ', 'n-cedilla', 'ny'),
  LetterRow('Ş', 'ş', 's-cedilla', 'sh'),
];
