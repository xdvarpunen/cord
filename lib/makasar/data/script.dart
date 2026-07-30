/// Which of the two South Sulawesi scripts a character listing is showing.
///
/// Only [WritingScript.makasar] is recognized from a gesture — Bugis is
/// reference material, so switching to it changes what is listed and
/// nothing about what the canvas reads.
enum WritingScript {
  makasar('Makasar'),
  bugis('Bugis (Lontara)');

  const WritingScript(this.label);

  /// What the picker calls it.
  final String label;
}
