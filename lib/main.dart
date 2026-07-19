import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'pages/app_pages.dart';
import 'pages/home_page.dart';

void main() {
  // Clean path-based URLs (`/tally`) instead of hash URLs (`/#/tally`), so
  // each page's path — and the Tally page's `?system=` query — is a real,
  // shareable URL. Static hosts must serve index.html for unknown paths;
  // see the README "Deploying" note for the GitHub Pages fallback.
  usePathUrlStrategy();
  runApp(const CordApp());
}

/// Brand seed color — kept in sync with `web/manifest.json`'s `theme_color`
/// and `web/index.html`'s splash so the PWA and the app agree on one color.
const seedColor = Color(0xFF1F6F6B);

class CordApp extends StatelessWidget {
  const CordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cord',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (_) => const HomePage(),
        // Every page in the registry is reachable by its own route, so the
        // pages are deep-linkable and the frontpage's links can't drift out
        // of sync with what actually exists.
        for (final page in appPages) page.route: page.builder,
      },
    );
  }
}
