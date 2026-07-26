// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Rewrites `?script=` to [slug] without reloading or pushing a history entry
/// — refresh and share keep the selection, but flipping through scripts
/// doesn't stuff the back button. The same approach as the tally page's
/// `?system=`, and tifi's `?region=` before it.
void writeScriptParam(String slug) {
  final uri = Uri.base.replace(queryParameters: {'script': slug});
  html.window.history.replaceState(null, '', uri.toString());
}
