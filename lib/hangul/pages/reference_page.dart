import 'package:flutter/material.dart';

import 'hangul_reference.dart';

/// Full-screen Hangul jamo reference: the basic consonants and vowels with
/// their romanizations. Opened from the Hangul page's info button on
/// narrow/mobile layouts (on desktop the legend is shown inline on the side
/// instead).
class ReferencePage extends StatelessWidget {
  const ReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hangul jamo reference')),
      body: const HangulReference(),
    );
  }
}
