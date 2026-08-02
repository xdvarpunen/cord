import 'package:flutter/material.dart';

import '../scenes/sinhala_scene.dart';
import 'sinhala_reference.dart';

/// Full-screen reference for the numeral system the page is set to: its
/// symbols with their values and names, ticked where the recognizer knows the
/// glyph. Opened from the Sinhala page's info button on narrow/mobile layouts
/// (on desktop the table is shown inline on the side instead).
class ReferencePage extends StatelessWidget {
  const ReferencePage({required this.system, super.key});

  final RecognitionSystem system;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${system.label} reference')),
      body: SinhalaReference(system: system),
    );
  }
}
