import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'scene.dart';

/// A canvas that runs a game loop: each frame it updates the active scene,
/// then repaints it. Drop this widget anywhere and give it a [SceneManager].
class GameCanvas extends StatefulWidget {
  const GameCanvas({required this.sceneManager, super.key});

  final SceneManager sceneManager;

  @override
  State<GameCanvas> createState() => _GameCanvasState();
}

class _GameCanvasState extends State<GameCanvas>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  final ValueNotifier<int> _repaint = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    widget.sceneManager.current.update(dt);
    _repaint.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _onPointerEvent(PointerEvent event, Size size) =>
      widget.sceneManager.current.handlePointerEvent(event, size);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          onPointerDown: (e) => _onPointerEvent(e, size),
          onPointerMove: (e) => _onPointerEvent(e, size),
          onPointerUp: (e) => _onPointerEvent(e, size),
          child: CustomPaint(
            size: size,
            painter: _ScenePainter(widget.sceneManager, repaint: _repaint),
          ),
        );
      },
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.sceneManager, {required Listenable repaint})
      : super(repaint: repaint);

  final SceneManager sceneManager;

  @override
  void paint(Canvas canvas, Size size) =>
      sceneManager.current.paint(canvas, size);

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) => true;
}
