// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Rewrites `?alphabet=` to [slug] without reloading or pushing a history
/// entry — refresh and share keep the selection, but flipping through the
/// thirty-one alphabets doesn't stuff the back button. The same approach as the
/// Hanzi Grid page's `?script=` and the tally page's `?system=`.
void writeAlphabetParam(String slug) {
  final uri = Uri.base.replace(queryParameters: {'alphabet': slug});
  html.window.history.replaceState(null, '', uri.toString());
}
