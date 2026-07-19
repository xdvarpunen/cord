import 'package:flutter/material.dart';

import 'morse_tables.dart';

/// Full-screen Morse reference: the 26 letters and ten digits with their
/// codes. Opened from the Morse page's info button on narrow/mobile layouts
/// (on desktop the table is shown inline on the side instead).
class ReferencePage extends StatelessWidget {
  const ReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Morse reference')),
      body: const MorseTable(),
    );
  }
}
