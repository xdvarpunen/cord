import 'package:flutter/material.dart';

import 'rune_tables.dart';

/// Full-screen rune reference: a "Younger Futhark" tab (the 16-rune Viking
/// Age alphabet in long-branch forms) and an "Elder Futhark" tab (the 24-rune
/// Proto-Germanic alphabet, grouped into its three ættir). Opened from the
/// [FutharkPage] info button on narrow/mobile layouts (on desktop the table
/// is shown inline on the side instead). Which tab was last open persists for
/// the app's lifetime (static field), but resets on a full restart.
class ReferencePage extends StatefulWidget {
  const ReferencePage({super.key});

  @override
  State<ReferencePage> createState() => _ReferencePageState();
}

class _ReferencePageState extends State<ReferencePage>
    with SingleTickerProviderStateMixin {
  static int _lastTabIndex = 0;

  late final TabController _tabController = TabController(
    length: 2,
    initialIndex: _lastTabIndex,
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
        title: const Text('Rune reference'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Younger Futhark'),
            Tab(text: 'Elder Futhark'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [YoungerFutharkTable(), ElderFutharkTable()],
      ),
    );
  }
}
