import 'package:flutter/material.dart';

import '../data/hanzi_glosses.dart';
import '../data/hanzi_scripts.dart';
import '../data/stroke_models.dart';
import '../palette.dart';

/// What the Hanzi Grid can actually recognize, laid out so you can check.
///
/// The recognizer is a stroke reference, not a dictionary: a square is scored
/// against the bundled glyphs and nothing else, so a character that is not
/// here can never be read however well it is written — and one that is not
/// here can be read as one that is. That is worth being able to look up rather
/// than discover one square at a time.
///
/// Shared by the desktop side panel on the grid page and the full-screen
/// tabbed [HanziReferencePage], the same way `lib/tifi/pages/script_tables.dart`
/// serves both of Tifinagh's.

const _mobileBreakpoint = 600.0;

/// One row: a character, everything known about it, and who writes it.
class _Entry {
  const _Entry({
    required this.char,
    required this.strokes,
    required this.langs,
    this.gloss,
  });

  final String char;
  final int strokes;
  final List<Lang> langs;
  final Gloss? gloss;
}

/// The rows for one script, by stroke count and then by the character itself —
/// the order a stroke reference is looked up in, and the order the sections
/// are headed with.
///
/// Cached per script. The stroke table is `const`, so a script's rows cannot
/// change at runtime, and rebuilding them per frame would walk 413 glyphs for
/// nothing.
final Map<String, List<_Entry>> _rowCache = {};

List<_Entry> _rowsOf(HanziScript script) => _rowCache[script.slug] ??= () {
      final byChar = <String, List<({Lang lang, int strokes})>>{};
      for (final entry in glyphsOf(script)) {
        final lang = switch (entry.key.split(':').first) {
          'JA' => Lang.ja,
          'KO' => Lang.ko,
          _ => Lang.zh,
        };
        byChar
            .putIfAbsent(entry.value.char, () => [])
            .add((lang: lang, strokes: entry.value.medians.length));
      }

      final out = [
        for (final e in byChar.entries)
          _Entry(
            char: e.key,
            // Where the traditions disagree about the count — 亀 against 龜 —
            // the smallest is shown; the row is a way in, not a specification.
            strokes:
                e.value.map((v) => v.strokes).reduce((a, b) => a < b ? a : b),
            langs: [
              for (final lang in Lang.values)
                if (e.value.any((v) => v.lang == lang)) lang,
            ],
            gloss: hanziGlosses[e.key],
          ),
      ];
      out.sort((a, b) => a.strokes != b.strokes
          ? a.strokes.compareTo(b.strokes)
          : a.char.compareTo(b.char));
      return out;
    }();

/// How many characters the grid can read with nothing excluded. Quoted on the
/// page so the number is never out of step with the table.
int get hanziCharacterCount => hanziScripts.first.count;

/// Everything one script can read, grouped by how many strokes it takes.
class CharacterTable extends StatelessWidget {
  const CharacterTable({required this.script, super.key});

  final HanziScript script;

  @override
  Widget build(BuildContext context) {
    final entries = _rowsOf(script);
    if (entries.isEmpty) {
      return ColoredBox(
        color: kPaper,
        child: Center(
          child: Text(
            'Nothing bundled for ${script.name}.',
            style: TextStyle(color: kInk.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    final narrow = MediaQuery.sizeOf(context).width < _mobileBreakpoint;
    // Already sorted by stroke count, so a run is a group.
    final groups = <int, List<_Entry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.strokes, () => []).add(entry);
    }
    // Kana are syllables; there is no tradition to attribute them to, and a
    // column of three dots all saying "Japanese" is noise.
    final showLangs = script.slug != 'hiragana' && script.slug != 'katakana';

    return ColoredBox(
      color: kPaper,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  script.slug == 'all'
                      ? '${entries.length} characters — everything the grid '
                          'can read.'
                      : '${entries.length} of the $hanziCharacterCount '
                          'characters the grid carries. With ${script.name} '
                          'selected, only these are considered.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  script.blurb,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: kInk.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          for (final group in groups.entries) ...[
            _StrokeHeading(strokes: group.key),
            for (final entry in group.value)
              _Row(entry: entry, narrow: narrow, showLangs: showLangs),
          ],
        ],
      ),
    );
  }
}

class _StrokeHeading extends StatelessWidget {
  const _StrokeHeading({required this.strokes});

  final int strokes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 5),
      child: Row(
        children: [
          Text(
            strokes == 1 ? '1 STROKE' : '$strokes STROKES',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: kInk.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: kInk.withValues(alpha: 0.10)),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.entry,
    required this.narrow,
    required this.showLangs,
  });

  final _Entry entry;
  final bool narrow;
  final bool showLangs;

  @override
  Widget build(BuildContext context) {
    final gloss = entry.gloss;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: narrow ? 34 : 42,
            child: Text(
              entry.char,
              style: TextStyle(
                fontFamily: kHanziFont,
                fontSize: narrow ? 22 : 26,
                color: kInk,
              ),
            ),
          ),
          SizedBox(
            width: narrow ? 58 : 76,
            child: Text(
              gloss?.reading ?? '',
              style: TextStyle(
                fontSize: narrow ? 12 : 13,
                color: kInk.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              gloss?.meaning ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: narrow ? 12 : 13,
                color: kInk.withValues(alpha: 0.5),
              ),
            ),
          ),
          if (showLangs)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final lang in Lang.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _LangDot(
                      lang: lang,
                      present: entry.langs.contains(lang),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Which traditions the table holds this character for. Korean coverage is
/// thin by nature — animCJK carries a few hundred hanja against thousands of
/// Chinese and Japanese characters — so a missing column is normal and is
/// shown rather than hidden.
class _LangDot extends StatelessWidget {
  const _LangDot({required this.lang, required this.present});

  final Lang lang;
  final bool present;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(lang);
    return Tooltip(
      message: present
          ? '${lang.name} — from ${lang.source}'
          : 'no ${lang.name} data',
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: present ? accent.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: accent.withValues(alpha: present ? 0.45 : 0.12),
          ),
        ),
        child: Text(
          lang.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: present ? accent : kInk.withValues(alpha: 0.18),
          ),
        ),
      ),
    );
  }
}
