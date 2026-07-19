import 'package:flutter/material.dart';

import 'numeral_tables.dart';

/// Full-screen numeral reference, opened from the [SuzhouPage] info button on
/// narrow/mobile layouts (on desktop the [NumeralTable] is shown inline on the
/// side instead).
class ReferencePage extends StatelessWidget {
  const ReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Numeral reference')),
      body: const NumeralTable(),
    );
  }
}
