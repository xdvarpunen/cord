import 'dart:ui';

import 'package:flutter/gestures.dart';

/// One drawable, updatable layer (e.g. a background band, a sprite).
abstract class Layer {
  void update(double dt) {}
  void handlePointerEvent(PointerEvent event, Size size) {}
  void paint(Canvas canvas, Size size);
}

/// An ordered stack of layers, back-to-front.
class Scene {
  Scene(this.layers);

  final List<Layer> layers;

  void update(double dt) {
    for (final layer in layers) {
      layer.update(dt);
    }
  }

  void handlePointerEvent(PointerEvent event, Size size) {
    for (final layer in layers) {
      layer.handlePointerEvent(event, size);
    }
  }

  void paint(Canvas canvas, Size size) {
    for (final layer in layers) {
      layer.paint(canvas, size);
    }
  }
}

/// Holds the active scene and lets it be swapped at runtime.
class SceneManager {
  SceneManager(this.current);

  Scene current;

  void switchTo(Scene scene) => current = scene;
}
