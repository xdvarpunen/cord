/// One letter of the (Eastern/Dougga) Libyco-Berber alphabet — the ancient
/// script ancestor of Tifinagh, per Wikipedia's "Libyco-Berber alphabet"
/// article (citing Galand, Lionel (2002). Études de Linguistique Berbère.
/// Peeters. pp. 13, 15, 31). Unlike the other two scripts in this app,
/// Libyco-Berber predates Unicode's Tifinagh block and has no assigned
/// codepoints of its own, so each letter is a bundled image
/// (`assets/tifi/libyco_berber/<asset>`, from Wikimedia Commons, CC0 — see
/// `assets/tifi/libyco_berber/SOURCE.txt`) rather than a font glyph. [ahaggar]
/// and [neoTifinagh] are the closest modern equivalents the source table
/// itself gives for comparison, `''` where the source shows none.
class LibycoBerberRow {
  const LibycoBerberRow(this.transliteration, this.asset, this.ahaggar,
      this.neoTifinagh);
  final String transliteration;
  final String asset;
  final String ahaggar;
  final String neoTifinagh;
}

const libycoBerberRows = [
  LibycoBerberRow('b', 'b.png', 'ⵀ', 'ⴱ'),
  LibycoBerberRow('g', 'g.png', 'ⴳ', 'ⴳ'),
  LibycoBerberRow('d', 'd.png', 'ⴷ,ⴸ', 'ⴷ'),
  LibycoBerberRow('h', 'h.png', 'ⵂ', 'ⵀ'),
  LibycoBerberRow('w', 'w.png', 'ⵓ', 'ⵡ'),
  LibycoBerberRow('z¹', 'z1.png', 'ⵋ', 'ⵊ'),
  LibycoBerberRow('ṭ', 'tt.png', 'ⵟ', 'ⵟ'),
  LibycoBerberRow('y', 'y.png', 'ⵉ', 'ⵢ'),
  LibycoBerberRow('k', 'k.png', 'ⴾ', 'ⴽ'),
  LibycoBerberRow('l', 'l.png', 'ⵍ', 'ⵍ'),
  LibycoBerberRow('m', 'm.png', 'ⵎ', 'ⵎ'),
  LibycoBerberRow('n', 'n.png', 'ⵏ', 'ⵏ'),
  LibycoBerberRow('s¹', 's1.png', '', 'ⵚ'),
  LibycoBerberRow('f', 'f.png', 'ⴼ', 'ⴼ'),
  LibycoBerberRow('s²', 's2.png', 'ⵙ', 'ⵙ'),
  LibycoBerberRow('q/ɣ?', 'q.png', 'ⵗ/ⵈ', 'ⵖ/ⵇ'),
  LibycoBerberRow('r', 'r.png', 'ⵔ', 'ⵔ'),
  LibycoBerberRow('s³', 's3.png', 'ⵛ', 'ⵛ'),
  LibycoBerberRow('t', 't.png', 'ⵜ', 'ⵜ'),
  LibycoBerberRow('z²', 'z2.png', 'ⵣ', 'ⵣ'),
  LibycoBerberRow('s⁴', 's4.png', '', ''),
  LibycoBerberRow('z³', 'z3.png', 'ⵌ', 'ⵥ'),
];
