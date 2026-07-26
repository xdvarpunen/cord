import 'package:flutter/material.dart';

import '../data/hanzi_scripts.dart';
import 'character_tables.dart';

/// Full-screen character reference: one tab per script, each listing exactly
/// what the grid can read with that script selected, grouped by stroke count.
///
/// Opened from the [HanziGridPage] info button on narrow layouts; on desktop
/// the [ReferencePanel] sits beside the grid showing the selected script
/// instead. Which tab was last open persists for the app's lifetime (static
/// field) but resets on a full restart — the same idiom as
/// `lib/tifi/pages/reference_page.dart`.
class HanziReferencePage extends StatefulWidget {
  const HanziReferencePage({this.initialScript, super.key});

  /// Script to open on — normally whichever the grid is set to, so the button
  /// opens the reference for what you are actually writing.
  final HanziScript? initialScript;

  @override
  State<HanziReferencePage> createState() => _HanziReferencePageState();
}

class _HanziReferencePageState extends State<HanziReferencePage>
    with SingleTickerProviderStateMixin {
  static int _lastTabIndex = 0;

  late final TabController _tabController = TabController(
    length: hanziScripts.length,
    initialIndex: widget.initialScript == null
        ? _lastTabIndex
        : hanziScripts.indexOf(widget.initialScript!),
    vsync: this,
  )..addListener(() => _lastTabIndex = _tabController.index);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Character reference'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            for (final script in hanziScripts) Tab(text: script.name),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final script in hanziScripts) CharacterTable(script: script),
        ],
      ),
    );
  }
}

/// The reference for one script, without the [Scaffold] — the desktop side
/// panel, which follows the page's dropdown rather than having tabs of its own.
class ReferencePanel extends StatelessWidget {
  const ReferencePanel({required this.script, super.key});

  final HanziScript script;

  @override
  Widget build(BuildContext context) => CharacterTable(script: script);
}
