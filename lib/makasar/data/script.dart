/// Which of the two South Sulawesi scripts a character listing is showing.
///
/// The app names them as the two ages of one script: [makasar] — the
/// Makasar script the code is named after — is shown as **Old Lontara**,
/// and [bugis] as **New Lontara**. Only [makasar] is recognized from a
/// gesture; New Lontara is reference material, so switching to it changes
/// what is listed and nothing about what the canvas reads.
enum WritingScript {
  makasar('Old Lontara'),
  bugis('New Lontara');

  const WritingScript(this.label);

  /// What the picker calls it.
  final String label;
}
