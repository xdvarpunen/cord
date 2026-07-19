import 'package:flutter/material.dart';

import 'script_tables.dart';

/// Full-screen signary reference, opened from the [TartessianPage] info button
/// on narrow/mobile layouts (on desktop the [SignaryTable] is shown inline on
/// the side instead).
class ReferencePage extends StatelessWidget {
  const ReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signary reference')),
      body: const SignaryTable(),
    );
  }
}
