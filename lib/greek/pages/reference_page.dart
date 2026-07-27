import 'package:flutter/material.dart';

import '../data/greek_letters.dart';
import 'greek_reference.dart';

/// Full-screen legend for the alphabet the page is set to: its letters in its
/// own order, muted where the recognizer doesn't handle them. Opened from the
/// Greek page's info button on narrow/mobile layouts (on desktop the legend is
/// shown inline on the side instead).
class ReferencePage extends StatelessWidget {
  const ReferencePage({required this.alphabet, super.key});

  final Alphabet alphabet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${alphabet.label} alphabet reference')),
      body: GreekReference(alphabet: alphabet),
    );
  }
}
