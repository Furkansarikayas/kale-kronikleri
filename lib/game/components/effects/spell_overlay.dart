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
    final grad = ui.Gradient.radial(
      center,
      radius,
      [
        tintColor.withAlpha((opacity * 120).round()),
        tintColor.withAlpha((opacity * 50).round()),
        Colors.transparent,
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = grad);

    // Edge vignette tint
    canvas.drawRect(
      rect,
      Paint()..color = tintColor.withAlpha((opacity * 25).round()),
    );
  }
}
