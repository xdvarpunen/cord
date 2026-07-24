import 'package:flutter/material.dart';

import 'hebrew_reference.dart';

/// Full-screen Hebrew alef-bet reference: the 22 letters, the 5 final forms,
/// and the shapes several letters share. Opened from the Hebrew page's info
/// button on narrow/mobile layouts (on desktop the legend is shown inline on
/// the side instead).
class ReferencePage extends StatelessWidget {
  const ReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hebrew alef-bet reference')),
      body: const HebrewReference(),
    );
  }
}
