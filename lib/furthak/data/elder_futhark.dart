/// One row of the Elder Futhark rune table (per Wikipedia's "Elder
/// Futhark" article): the rune glyph, its reconstructed Proto-Germanic
/// name and that name's meaning, the Latin transliteration, the IPA sound
/// value, and which of the three traditional ættir (rows of 8) it belongs
/// to (1-3).
class ElderFutharkRow {
  const ElderFutharkRow(
      this.glyph, this.name, this.meaning, this.translit, this.sound, this.aett);
  final String glyph;
  final String name;
  final String meaning;
  final String translit;
  final String sound;
  final int aett;
}

const elderFutharkRows = [
  // First ætt.
  ElderFutharkRow('ᚠ', '*fehu', 'cattle, wealth', 'f', 'ɸ, f', 1),
  ElderFutharkRow('ᚢ', '*ūruz', 'aurochs', 'u', 'u(ː)', 1),
  ElderFutharkRow('ᚦ', '*þurisaz', 'giant, monster', 'þ', 'θ, ð', 1),
  ElderFutharkRow('ᚨ', '*ansuz', 'god', 'a', 'a(ː)', 1),
  ElderFutharkRow('ᚱ', '*raidō', 'ride, journey', 'r', 'r', 1),
  ElderFutharkRow('ᚲ', '*kauną', 'boil', 'k', 'k', 1),
  ElderFutharkRow('ᚷ', '*gebō', 'gift', 'g', 'ɡ', 1),
  ElderFutharkRow('ᚹ', '*wunjō', 'joy', 'w', 'w', 1),
  // Second ætt.
  ElderFutharkRow('ᚺ', '*hagalaz', 'hail', 'h', 'h', 2),
  ElderFutharkRow('ᚾ', '*naudiz', 'need, affliction', 'n', 'n', 2),
  ElderFutharkRow('ᛁ', '*īsaz', 'ice', 'i', 'i(ː)', 2),
  ElderFutharkRow('ᛃ', '*jēra-', 'year, harvest', 'j', 'j', 2),
  ElderFutharkRow('ᛇ', '*ī(h)waz', 'yew-tree', 'ï', 'æː', 2),
  ElderFutharkRow('ᛈ', '*perþō', '(meaning unknown)', 'p', 'p', 2),
  ElderFutharkRow('ᛉ', '*algiz', 'elk', 'z', 'z', 2),
  ElderFutharkRow('ᛊ', '*sōwilō', 'sun', 's', 's', 2),
  // Third ætt.
  ElderFutharkRow('ᛏ', '*tīwaz', 'Tiwaz (a deity)', 't', 't', 3),
  ElderFutharkRow('ᛒ', '*berkanan', 'birch', 'b', 'b', 3),
  ElderFutharkRow('ᛖ', '*ehwaz', 'horse', 'e', 'e(ː)', 3),
  ElderFutharkRow('ᛗ', '*mannaz', 'man, human', 'm', 'm', 3),
  ElderFutharkRow('ᛚ', '*laguz', 'water, liquid', 'l', 'l', 3),
  ElderFutharkRow('ᛜ', '*ingwaz', 'Ing (a deity)', 'ŋ', 'ŋ', 3),
  ElderFutharkRow('ᛞ', '*dagaz', 'day', 'd', 'd', 3),
  ElderFutharkRow('ᛟ', '*ōþala-', 'inheritance, household', 'o', 'o(ː)', 3),
];
