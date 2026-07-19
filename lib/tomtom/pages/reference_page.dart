import 'package:flutter/material.dart';

import 'tomtom_tables.dart';

/// Full-screen Tom-Tom reference: the 26 letters with the up/down stroke run
/// that spells each. Opened from the Tom-Tom page's info button on
/// narrow/mobile layouts (on desktop the table is shown inline on the side
/// instead).
class ReferencePage extends StatelessWidget {
  const ReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tom-Tom reference')),
      body: const TomtomTable(),
    );
  }
}
