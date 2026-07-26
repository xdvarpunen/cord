import 'package:flutter/material.dart';

import '../palette.dart';

/// Small shared pieces of the page furniture this family of projects uses,
/// kept to the ones this single page needs — the tab shell around `hanzi`'s
/// "Order up", its brand and product pickers and its how-to-write demo did not
/// come across.

/// The card every panel sits in: lifted off the paper by lightness rather
/// than by a shadow, which is how the sibling projects do it — there is no
/// elevation anywhere in the family.
BoxDecoration paperCard({Color? border}) => BoxDecoration(
      color: Colors.white.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: border ?? kInk.withValues(alpha: 0.10)),
    );

/// How wide the reading column gets before it stops growing.
///
/// A word strip and a run of letter chips stretched across a 1600px window
/// read as a spreadsheet; capped, the page keeps the proportions of a page.
const double kContentWidth = 760;

/// Caps and centres the page's content at [kContentWidth].
class ContentColumn extends StatelessWidget {
  const ContentColumn({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: children,
        ),
      ),
    );
  }
}

/// The height of the panel that reads back what you have written.
///
/// Fixed, and it has to be: it sits directly above a canvas, so any change
/// in its height shifts the writing surface out from under the pen. It is
/// tall enough for the characters and the tally under them together, and it
/// stays that tall while empty.
const double kReadingHeight = 104;

/// Wraps a drawing surface so the page it sits in cannot scroll out from
/// under the pen.
///
/// [GameCanvas] takes its input from a raw `Listener`, which never enters
/// the gesture arena. An enclosing `ListView` does enter it, and with no
/// competitor its drag recognizer wins every time — so a downward stroke
/// scrolls the page instead of drawing on it, and the boxes slide away
/// mid-letter.
///
/// Claiming drags here puts a competitor in the arena, and the inner one
/// wins. The `Listener` is unaffected either way: it sees every pointer
/// event regardless of who wins the arena, so the stroke still lands.
class DrawingSurface extends StatelessWidget {
  const DrawingSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
      onVerticalDragEnd: (_) {},
      onHorizontalDragStart: (_) {},
      onHorizontalDragUpdate: (_) {},
      onHorizontalDragEnd: (_) {},
      child: child,
    );
  }
}

/// A hairline rule that runs to the end of whatever room is left.
class Hairline extends StatelessWidget {
  const Hairline({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: kInk.withValues(alpha: 0.12));
}

/// A tappable pill.
///
/// Hand-rolled rather than a Material chip or button, matching the sibling
/// projects: the Material widgets size themselves from an intrinsic width
/// that clips longer labels once an accent is applied, and they bring an
/// elevation and ripple that the rest of this design does not use.
class Pill extends StatelessWidget {
  const Pill({
    required this.label,
    required this.onTap,
    this.accent,
    this.selected = false,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Color? accent;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? kInk;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? tint.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tint.withValues(alpha: selected ? 0.5 : 0.18),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: accent ?? kInk.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
