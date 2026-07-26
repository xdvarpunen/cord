# cord

A Flutter **web** app (installable PWA) for **freehand recognition of historic
scripts, codes, and numerals**. Draw on a canvas; each feature recognizes the
marks stroke by stroke — geometrically, no ML — and shows the result live. A
frontpage links to every feature and a search box jumps to any of them.

## Features

Each is a self-contained page under `lib/<feature>/`, reached from the frontpage
or by deep link (desktop shows a reference table beside the canvas).

| Feature | Route | What you draw |
|---|---|---|
| **Futhark** | `/futhark` | Younger & Elder runes (dropdown) · `NotoSansRunic` |
| **Tifinagh** | `/tifinagh` | Tuareg regions + Libyco-Berber (dropdown) · `NotoSansTifinagh` + images |
| **Tartessian** | `/tartessian` | Southwestern Paleohispanic signary |
| **Ogham** | `/ogham` | *feda* + *forfeda* on a central stemline |
| **Morse** | `/morse` | tap = dot, `—` stroke = dash, `\|` = separator |
| **Tom-Tom Code** | `/tomtom` | runs of ↑/↓ strokes; `—` separates letters |
| **Tally Marks** | `/tally` | five tally systems (dropdown, `?system=`) |
| **Etruscan Numerals** | `/etruscan` | 𐌠1 𐌡5 𐌢10 𐌣50 𐌟100 → additive total |
| **Suzhou Numerals** | `/suzhou` | 〇 and 〡–〩 rod/*huāmǎ* digits |
| **Hangul** | `/hangul` | jamo: strokes, ticks, corners, loops, compounds |
| **Hangul Grid** | `/hangul-grid` | whole syllables in notebook squares; each row read out |
| **Hanzi Grid** | `/hanzi` | whole Han characters in 米-ruled squares (script dropdown, `?script=`); pinyin + English + confidence, and whose stroke order you used |
| **Hebrew** | `/hebrew` | modern square alef-bet + final forms (no Paleo-Hebrew) |

## Architecture

- **One registry** ([`lib/pages/app_pages.dart`](lib/pages/app_pages.dart)) is
  the single source of truth — frontpage cards, routes, and search are all
  generated from it.
- **Per-feature isolation** — each feature has its own copy of the canvas engine
  (`engine/scene.dart` + `engine/game_canvas.dart`), scenes, and data; none
  imports another's code. Shared code is only the shell (`main.dart`,
  `app_pages.dart`, `home_page.dart`, `search_page.dart`).
- **Engine** — a `Ticker` game loop repaints a stack of `Layer`s: a dot-grid
  `PaperLayer` under a recognizer that captures strokes and paints the readout.
- Fonts are bundled only for Futhark/Tifinagh; the rest draw glyphs as vectors
  or lean on the browser's CJK/Hebrew fallbacks.
  Clean paths (`usePathUrlStrategy`) + a full PWA manifest.

**Add a feature:** create `lib/<feature>/` (copy an existing one's `engine/`,
add a scene + page) and append one `AppPage(...)` to `appPages`.

## Run

Develops in the devcontainer (`.devcontainer/`, Flutter + Chrome). In VS Code,
"Reopen in Container", then `flutter pub get && flutter run -d chrome`. Or:

```sh
docker build -t cord-dev -f .devcontainer/Dockerfile .
docker run --rm -p 8080:8080 -v "$PWD:/workspace" -w /workspace cord-dev \
  bash -c "flutter pub get && flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0"
```

## Deploy

[`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) builds and
publishes to **GitHub Pages** on push to `master` (enable **Settings → Pages →
Source: GitHub Actions**). It sets `--base-href "/<repo>/"` and copies
`index.html` → `404.html` — required because path URLs (`/ogham`) otherwise 404
on deep-link/refresh on a static host.

## License

[MIT](LICENSE). Bundled fonts/assets keep their own licenses (NotoSans* under
OFL; Libyco-Berber images CC0). Hanzi Grid's stroke table is generated from
makemeahanzi, KanjiVG and animCJK, and its readings/meanings from
makemeahanzi's dictionary (CC BY-SA 4.0, share-alike) — see
[`lib/hanzi/data/NOTICE.txt`](lib/hanzi/data/NOTICE.txt). Regenerate the
glosses with `node tool/hanzi_glosses.mjs` (host, needs network).
