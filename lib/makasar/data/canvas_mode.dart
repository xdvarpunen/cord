/// Which canvas the page is showing.
///
/// Both read the same characters the same way; what differs is how much
/// is on the paper at once — [draw] gives the whole sheet over to one
/// character, [write] keeps a row of them.
enum CanvasMode {
  draw('Draw'),
  write('Write');

  const CanvasMode(this.label);

  /// What the picker calls it.
  final String label;
}
