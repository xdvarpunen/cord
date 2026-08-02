// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Rewrites `?system=` to [slug] without reloading or pushing a history
/// entry — refresh and share keep the selection, but flipping between the two
/// numeral systems doesn't stuff the back button. The same approach as the
/// Lontara and Hanzi Grid pages' `?script=` and the tally page's own
/// `?system=`.
void writeSystemParam(String slug) {
  final uri = Uri.base.replace(queryParameters: {'system': slug});
  html.window.history.replaceState(null, '', uri.toString());
}
