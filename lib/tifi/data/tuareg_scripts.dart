/// One row of the Tuareg-scripts letter table (per Wikipedia's "Tifinagh"
/// article): an IPA label, the bold sound, and the glyph used for that
/// sound in each of 5 regional variants. `''` means the variant has no
/// letter for that sound.
class TuaregRow {
  const TuaregRow(this.ipa, this.sound, this.ahaggar, this.ghat, this.air,
      this.azawagh, this.adrar);
  final String ipa;
  final String sound;
  final String ahaggar;
  final String ghat;
  final String air;
  final String azawagh;
  final String adrar;

  /// The glyph used for this sound in [region], or `''` if that region
  /// has no letter for it. [region] must be one of [tuaregRegions].
  String glyphFor(String region) => switch (region) {
        'Ahaggar' => ahaggar,
        'Ghat' => ghat,
        'Aïr' => air,
        'Azawagh' => azawagh,
        'Adrar' => adrar,
        _ => '',
      };
}

const tuaregRows = [
  TuaregRow('a', 'æ', 'ⴰ', 'ⴰ', 'ⴰ', 'ⴰ', 'ⴰ'),
  TuaregRow('b', 'b', 'ⵀ', 'ⵀ', 'ⵀ', 'ⵀ', 'ⵀ'),
  TuaregRow('d', 'd', 'ⴸ', 'ⴸ', 'ⴹ', 'ⴸ', 'ⴸ'),
  TuaregRow('ḍ', 'dˤ', 'ⴹ', 'ⴹ', '', '', ''),
  TuaregRow('f', 'f', 'ⴼ', 'ⴼ', 'ⴼ', 'ⴼ', 'ⵊ'),
  TuaregRow('g', 'ɡ', 'ⴳ', 'ⴶ', 'ⴶ', 'ⴶ', 'ⴶ'),
  TuaregRow('ġ', 'ɟ', 'ⴶ', 'ⵊ', 'ⵘ', '', ''),
  TuaregRow('h', 'h', 'ⵂ', 'ⵂ', 'ⵂ', 'ⵂ', 'ⵂ'),
  TuaregRow('x', 'x', 'ⵆ', 'ⵆ', 'ⵗ', 'ⵆ', 'ⵆ'),
  TuaregRow('k', 'k', 'ⴾ', 'ⴾ', 'ⴾ', 'ⴾ', 'ⴾ'),
  TuaregRow('l', 'l', 'ⵍ', 'ⵍ', 'ⵍ', 'ⵍ', 'ⵍ'),
  TuaregRow('m', 'm', 'ⵎ', 'ⵎ', 'ⵎ', 'ⵎ', 'ⵎ'),
  TuaregRow('n', 'n', 'ⵏ', 'ⵏ', 'ⵏ', 'ⵏ', 'ⵏ'),
  TuaregRow('ñ', 'ɲ', 'ⵐ', '', '', '', ''),
  TuaregRow('ng', 'ŋ', 'ⵑ', '', '', '', ''),
  TuaregRow('q', 'q', 'ⵈ', 'ⵈ', 'ⵗ', 'ⵆ', 'ⵈ'),
  TuaregRow('ɣ/gh', 'ɣ', 'ⵗ', 'ⵗ', 'ⵘ', 'ⵗ', 'ⵗ'),
  TuaregRow('r', 'r', 'ⵔ', 'ⵔ', 'ⵔ', 'ⵔ', 'ⵔ'),
  TuaregRow('s', 's', 'ⵙ', 'ⵙ', 'ⵙ', 'ⵙ', 'ⵙ'),
  TuaregRow('š', 'ʃ', 'ⵛ', 'ⵛ', 'ⵛ', 'ⵛ', '𐌚'),
  TuaregRow('t', 't', 'ⵜ', 'ⵜ', 'ⵜ', 'ⵜ', 'ⵜ'),
  TuaregRow('ṭ', 'tˤ', 'ⵟ', '', '', '', ''),
  TuaregRow('w', 'w', 'ⵓ', 'ⵓ', 'ⵓ', 'ⵓ', 'ⵓ'),
  TuaregRow('y', 'j', 'ⵢ', 'ⵉ', 'ⵉ', 'ⵢ', 'ⵉ'),
  TuaregRow('z', 'z', 'ⵣ', 'ⵌ', 'ⵣ', 'ⵣ', 'ⵋ'),
  TuaregRow('ẓ', 'zˤ', 'ⵌ', 'ⵣ', '', 'ⵣ', ''),
  TuaregRow('ž/j', 'ʒ', 'ⵋ', '', 'ⵌ', 'ⵌ', ''),
];

const tuaregRegions = ['Ahaggar', 'Ghat', 'Aïr', 'Azawagh', 'Adrar'];
