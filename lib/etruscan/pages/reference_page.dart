import 'package:flutter/material.dart';

import 'etruscan_tables.dart';

/// Full-screen Etruscan numeral reference: the five recognized values with
/// their signs and how to draw each. Opened from the Etruscan page's info
/// button on narrow/mobile layouts (on desktop the table is shown inline on
/// the side instead).
class ReferencePage extends StatelessWidget {
  const ReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Etruscan numerals reference')),
      body: const EtruscanTable(),
    );
  }
}
