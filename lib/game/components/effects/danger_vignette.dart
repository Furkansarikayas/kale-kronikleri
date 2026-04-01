import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Red screen-edge vignette that pulses when castle HP is critically low.
/// Renders only at edges — center stays clear for gameplay readability.
class DangerVignette extends Component {
  double _time = 0;
  double _hpRatio = 1.0;

  static const double _w = 880.0;
  static const double _h = 480.0;
  static const double _skyOffset = 60.0;

  /// Set this each frame from the game loop.
  set hpRatio(double value) => _hpRatio = value.clamp(0.0, 1.0);

  DangerVignette() {
    priority = 101; // Above atmosphere overlay
  }

  @override
  void update(double dt) {
    if (_hpRatio < 0.4) _time += dt;
  }

  @override
  void render(Canvas canvas) {
    if (_hpRatio >= 0.4) return; // No danger — skip entirely

    final topY = -_skyOffset;
    final fullH = _h;

    // Danger intensity: 0.0 at 40% HP → 1.0 at 0% HP
    final danger = (1.0 - _hpRatio / 0.4).clamp(0.0, 1.0);

    // Pulse speed increases with danger: slow at 40%, fast at <20%
    final pulseSpeed = 2.0 + danger * 4.0;
    final pulse = 0.5 + 0.5 * math.sin(_time * pulseSpeed);

    // Base opacity scales with danger and pulse
    final baseAlpha = danger * (0.15 + pulse * 0.15);

    // Red radial vignette from edges inward
    final centerX = _w / 2;
    final centerY = topY + fullH / 2;

    // Vignette radius shrinks as danger increases (tighter at critical HP)
    final innerRadius = _w * (0.5 - danger * 0.15);

    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(centerX, centerY),
        _w * 0.65,
        [
          Colors.transparent,
          Colors.transparent,
          Color.fromARGB((baseAlpha * 180).round().clamp(0, 255), 200, 20, 10),
          Color.fromARGB((baseAlpha * 255).round().clamp(0, 255), 160, 10, 5),
        ],
        [0.0, innerRadius / (_w * 0.65), 0.85, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, topY, _w, fullH), vignette);
  }
}
