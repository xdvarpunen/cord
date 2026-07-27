/// Keeping the selected alphabet in the address bar, without dragging
/// `dart:html` into everything that imports the page.
///
/// The same shim the Latin page uses for its `?alphabet=` and the Hanzi Grid
/// page for its `?script=` — `flutter test` runs on the VM, where importing
/// `dart:html` is a *compile* error, so the one web-only call goes behind a
/// conditional import: the real thing on the web, a no-op everywhere else. The
/// Greek page is widget-tested, so it needs it.
///
/// Reading the parameter needs no shim. `Uri.base` exists on every platform;
/// off the web it is the working directory, which carries no query and so
/// answers null on its own.
library;

export 'alphabet_param_stub.dart'
    if (dart.library.html) 'alphabet_param_web.dart';
