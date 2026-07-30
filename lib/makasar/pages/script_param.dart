/// Keeping the selected script in the address bar, without dragging
/// `dart:html` into everything that imports the page.
///
/// The same shim the Hanzi Grid page uses for its own `?script=` and the Latin
/// and Greek pages for their `?alphabet=` — `flutter test` runs on the VM,
/// where importing `dart:html` is a *compile* error, so the one web-only call
/// goes behind a conditional import: the real thing on the web, a no-op
/// everywhere else. The Makasar page is widget-tested, so it needs it.
///
/// Reading the parameter needs no shim. `Uri.base` exists on every platform;
/// off the web it is the working directory, which carries no query and so
/// answers null on its own.
library;

export 'script_param_stub.dart' if (dart.library.html) 'script_param_web.dart';
