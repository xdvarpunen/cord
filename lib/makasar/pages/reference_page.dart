import 'package:flutter/material.dart';

import '../data/script.dart';
import 'makasar_reference.dart';

/// Full-screen reference for the script the page is set to: its characters
/// with their sounds and how each letterform is built, muted where the
/// recognizer has no gesture for one. Opened from the Makasar page's info
/// button on narrow/mobile layouts (on desktop the table is shown inline on
/// the side instead).
class ReferencePage extends StatelessWidget {
  const ReferencePage({required this.script, super.key});

  final WritingScript script;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${script.label} script reference')),
      body: MakasarReference(script: script),
    );
  }
}
