import 'package:flutter/material.dart';

import 'script_tables.dart';

/// Full-screen script reference: a "Tuareg" tab (the regional Tifinagh
/// variants) and a "Libyco-Berber" tab (the ancient script ancestor of
/// Tifinagh). The tifi app's third "Neo-Tifinagh" tab is intentionally
/// omitted here. Opened from the [TifinaghPage] info button on narrow/mobile
/// layouts (on desktop the table is shown inline on the side instead). Which
/// tab was last open persists for the app's lifetime (static field), but
/// resets on a full restart.
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
        title: const Text('Script reference'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tuareg'),
            Tab(text: 'Libyco-Berber'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [TuaregTable(), LibycoBerberTable()],
      ),
    );
  }
}
