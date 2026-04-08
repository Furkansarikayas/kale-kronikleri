import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Full-screen spell effect overlay — color/gradient flash, no image.
class SpellOverlay extends PositionComponent {
  final String assetPath; // kept for API compat, not used
  final Color tintColor;
  final double duration;

  double _timer = 0;

  // Cached paints — avoid per-frame allocation
  static final Paint _gradPaint = Paint();
  static final Paint _tintPaint = Paint();

  SpellOverlay({
    required this.assetPath,
    required this.tintColor,
    this.duration = 1.5,
    required Vector2 worldSize,
  }) {
    size = worldSize;
    priority = 100;
  }

  @override
  void update(double dt) {
    _timer += dt;
    if (_timer >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_timer / duration).clamp(0.0, 1.0);
    // Quick fade in, hold, fade out
    final alpha = progress < 0.15
        ? (progress / 0.15)
        : progress > 0.5
            ? (1.0 - progress) / 0.5
            : 1.0;

    final opacity = (alpha * 0.35).clamp(0.0, 1.0);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    // Radial gradient flash from center
    final center = Offset(size.x / 2, size.y / 2);
    final radius = math.max(size.x, size.y) * 0.7;
    final tr = (tintColor.r * 255).round();
    final tg = (tintColor.g * 255).round();
    final tb = (tintColor.b * 255).round();
    _gradPaint.shader = ui.Gradient.radial(
      center,
      radius,
      [
        Color.fromARGB((opacity * 120).round(), tr, tg, tb),
        Color.fromARGB((opacity * 50).round(), tr, tg, tb),
        Colors.transparent,
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRect(rect, _gradPaint);

    // Edge vignette tint
    _tintPaint.color = Color.fromARGB((opacity * 25).round(), tr, tg, tb);
    canvas.drawRect(rect, _tintPaint);
  }
}
