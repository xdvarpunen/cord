# cord

A minimal Flutter **web** app: a frontpage that links to several pages,
installable as a PWA. Built to be a clean starting point — the same
canvas-free scaffold you'd grow a real multi-page app from.

## What's here

- A **frontpage** ([`lib/pages/home_page.dart`](lib/pages/home_page.dart))
  that renders one tappable card per page and navigates to it.
- **Search** ([`lib/pages/search_page.dart`](lib/pages/search_page.dart)) —
  the top link. Every page and every page's dropdown content (each tally
  system) is listed up front and filtered live by a text box; tapping a
  result jumps straight to that page/selection. The index
  ([`lib/data/search_index.dart`](lib/data/search_index.dart)) is built from
  the same registries the app already uses, so it never goes stale.
- **Tally Marks** ([`lib/pages/tally_page.dart`](lib/pages/tally_page.dart)) —
  the first link. Five freehand tally-mark counting games (ported from the
  `tally_mobile` app) drawn on a canvas/game-loop engine, each stroke checked
  geometrically. See [Tally Marks](#tally-marks) below.
- **Futhark** ([`lib/furthak/pages/futhark_page.dart`](lib/furthak/pages/futhark_page.dart)) —
  the second link. Freehand Futhark rune recognition (ported from the
  `furthak` app), with a Younger/Elder dropdown and, on desktop, the rune
  reference table beside the canvas in a 50/50 split. Fully self-contained
  under [`lib/furthak/`](lib/furthak/) — it shares no engine/scene/data with
  the tally page.
- **Tifinagh** ([`lib/tifi/pages/tifinagh_page.dart`](lib/tifi/pages/tifinagh_page.dart)) —
  the third link. Freehand Tifinagh letter recognition (ported from the
  `tifi` app, **without the Neo-Tifinagh variants**), with a script dropdown
  (five Tuareg regional variants + Libyco-Berber) and, on desktop, the
  reference table beside the canvas in a 50/50 split. Fully self-contained
  under [`lib/tifi/`](lib/tifi/) — shares nothing with the tally or furthak
  pages.
- A **page registry** ([`lib/pages/app_pages.dart`](lib/pages/app_pages.dart))
  that is the single source of truth: both the frontpage's link cards and
  the app's named routes ([`lib/main.dart`](lib/main.dart)) are generated
  from it, so pages are deep-linkable and can't drift out of sync.
- **PWA support**: a full [`web/manifest.json`](web/manifest.json) with
  regular + maskable icons, iOS home-screen meta tags and a themed splash in
  [`web/index.html`](web/index.html). Flutter's build generates the service
  worker, so a production build is installable and offline-capable.

## Tally Marks

The first drawing link is the **Tally Marks** page: a **dropdown** (each
option shown with its drawn glyph) picks which tally system you're drawing, a
**Clear** button beside it resets the canvas, and the canvas fills the rest
of the page. Marks are recognized stroke by stroke (shape, relative position,
segment intersection). The five systems (facts from
[Wikipedia](https://en.wikipedia.org/wiki/Tally_marks)):

- **Western (five-bar gate)** — 4 verticals, then one crossing all 4 (of 5).
- **Dot-and-line (dot-dash)** — 4 dots, 4 sides, 2 diagonals (of 10).
- **East Asian (正)** — draw 正 stroke-by-stroke, each checked in order.
- **Iberian card-game** — 4 lines forming a box, closed with a diagonal slash.
- **Hindu-Arabic five (5)** — draw the digit "5" seven-segment style (an app
  variant, not a historical tally).

The dropdown glyphs are drawn as vectors ([`lib/widgets/tally_glyph.dart`](lib/widgets/tally_glyph.dart)),
so no glyph/CJK font is bundled. Everything on the page —
[`lib/data/tally_systems.dart`](lib/data/tally_systems.dart) — is the single
source for the dropdown, the canvas, and the search index.

**URL binding:** the page lives at `/tally`, and the selected system
round-trips through `?system=<slug>` (e.g. `/tally?system=zheng`), so a
reload or shared link restores both. Clean paths come from
`usePathUrlStrategy()` in [`lib/main.dart`](lib/main.dart).

The canvas runs on a small reusable engine ([`lib/engine/`](lib/engine/)) — a
`Ticker`-driven game loop repainting an ordered stack of `Layer`s — with one
scene per system in [`lib/scenes/`](lib/scenes/) over a shared dot-grid
`PaperLayer`. Same engine and rules as the `tally_hand` / `tally_mobile`
projects.

## Adding a page

1. Drop a new widget in `lib/pages/` (copy one of `page_*.dart`).
2. Append an `AppPage(...)` entry to `appPages` in
   [`lib/pages/app_pages.dart`](lib/pages/app_pages.dart).

That's it — the home screen gets a new card and the route is registered.

## Running it

This project develops inside a devcontainer (`.devcontainer/`) that provides
Flutter (stable) + Chromium, since neither is required on the host.

**VS Code:** open the folder, "Reopen in Container", then:

```sh
flutter pub get
flutter run -d chrome
```

**Plain Docker** (no VS Code):

```sh
docker build -t cord-dev -f .devcontainer/Dockerfile .
docker run --rm -p 8080:8080 -v "$PWD:/workspace" -w /workspace cord-dev \
  bash -c "flutter pub get && flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0"
```

Then open `http://localhost:8080`.

### Production build (installable PWA)

```sh
flutter build web --release
```

Serve the contents of `build/web/` over HTTPS (or `localhost`) — the browser
will offer to install `cord` as an app.

### Deploying (clean paths need an SPA fallback)

`cord` uses path-based URLs (`/tally`), so the host must serve `index.html`
for unknown paths or a deep link / refresh on `/tally` 404s. On **GitHub
Pages** the one-liner is to copy the built entry point to `404.html`, which
Pages serves for any unmatched path:

```sh
cp build/web/index.html build/web/404.html
```

(Netlify/Vercel/most static hosts have a "rewrite all to /index.html"
setting instead.)

## Project layout

```
lib/
  main.dart                 # MaterialApp: theme + routes generated from the registry
  pages/                    # app shell (not tied to any one feature)
    app_pages.dart          # AppPage registry — single source of truth for pages
    home_page.dart          # frontpage: a link card per registered page
    search_page.dart        # top link: live-filtered index of pages + items
    search_index.dart       # SearchEntry list built from pages + tally systems
  tally/                    # Tally Marks page — self-contained, shares nothing with the others
    engine/                 # its OWN copy of scene.dart + game_canvas.dart
    data/tally_systems.dart # the 5 tally systems (dropdown + scenes)
    scenes/                 # writing_scene (PaperLayer) + the 5 tally scenes
    pages/tally_page.dart   # glyph dropdown + Clear + canvas
    widgets/tally_glyph.dart # vector glyph for each tally system
  furthak/                  # Futhark page — self-contained, shares nothing with the others
    engine/                 # its OWN copy of scene.dart + game_canvas.dart
    data/                   # younger_futhark.dart, elder_futhark.dart
    scenes/futhark_scene.dart   # FutharkLayer rune recognizer + PaperLayer
    pages/
      futhark_page.dart     # dropdown + Clear + canvas; desktop 50/50 side table
      rune_tables.dart      # Younger/Elder reference tables (shared within furthak)
      reference_page.dart   # full tabbed reference (mobile info button)
  tifi/                     # Tifinagh page — self-contained, shares nothing with the others
    engine/                 # its OWN copy of scene.dart + game_canvas.dart
    data/                   # tuareg_scripts.dart, libyco_berber_scripts.dart (no neo)
    scenes/tifinagh_scene.dart  # TifinaghLayer recognizer + PaperLayer
    pages/
      tifinagh_page.dart    # dropdown + Clear + canvas; desktop 50/50 side table
      script_tables.dart    # Tuareg / Libyco-Berber tables (shared within tifi)
      reference_page.dart   # full tabbed reference (mobile info button)
assets/
  furthak/                  # NotoSansRunic (OFL) — runic glyphs
  tifi/                     # NotoSansTifinagh (OFL) + libyco_berber/ images (CC0)
web/                        # Flutter web bootstrap: index.html, manifest.json, icons
.devcontainer/              # Dockerfile + devcontainer.json (Flutter + Chromium)
```
