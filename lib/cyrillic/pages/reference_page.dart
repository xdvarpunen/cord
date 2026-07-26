import 'package:flutter/material.dart';

import 'cyrillic_reference.dart';

/// Full-screen Cyrillic alphabet reference: the 33 Russian letters, muted
/// where the recognizer doesn't handle them. Opened from the Cyrillic page's
/// info button on narrow/mobile layouts (on desktop the legend is shown
/// inline on the side instead).
class ReferencePage extends StatelessWidget {
  const ReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cyrillic alphabet reference')),
      body: const CyrillicReference(),
    );
  }
}
