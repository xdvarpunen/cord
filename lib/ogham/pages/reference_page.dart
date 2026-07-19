import 'package:flutter/material.dart';

import 'ogham_tables.dart';

/// Full-screen Ogham reference: the twenty primary letters grouped into their
/// four *aicmí*, followed by the *forfeda*. Opened from the Ogham page's info
/// button on narrow/mobile layouts (on desktop the table is shown inline on
/// the side instead).
class ReferencePage extends StatelessWidget {
  const ReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ogham reference')),
      body: const OghamTable(),
    );
  }
}
