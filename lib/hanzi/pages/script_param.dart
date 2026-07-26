/// Keeping the selected script in the address bar, without dragging
/// `dart:html` into everything that imports the page.
///
/// cord is a web app and the tally page reaches for `dart:html` directly, but
/// nothing had ever widget-tested a page that did — `flutter test` runs on the
/// VM, where importing `dart:html` is a compile error, not a runtime one. The
/// grid page *is* tested, so the one web-only call goes behind a conditional
/// import: the real thing on the web, a no-op everywhere else.
///
/// Reading the parameter needs no shim. `Uri.base` exists on every platform;
/// off the web it is the working directory, which carries no query and so
/// answers null on its own.
library;

export 'script_param_stub.dart'
    if (dart.library.html) 'script_param_web.dart';
