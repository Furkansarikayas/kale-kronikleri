import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Subtle pulsing warning shown in the last seconds before a wave spawns.
/// Amber text at bottom-center: "DALGA X YAKLAŞIYOR..."
class WaveIncomingWarning extends PositionComponent {
  final int waveNumber;
  double _timer = 0;

  WaveIncomingWarning({
    required this.waveNumber,
    required Vector2 worldSize,
  }) {
    size = worldSize;
    priority = 98;
  }

  @override
  void render(Canvas canvas) {
    _timer += 0; // updated in update()
    final w = size.x;
    final h = size.y;
    final cx = w / 2;

    // Pulsing alpha: gentle breathe between 0.45 and 1.0
    final pulse = 0.45 + 0.55 * ((math.sin(_timer * 4.0) + 1.0) / 2.0);
    final a = (pulse * 255).round().clamp(0, 255);

    // Amber warning text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'DALGA $waveNumber YAKLAŞIYOR...',
        style: TextStyle(
          color: Color.fromARGB(a, 255, 200, 80),
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          shadows: [
            Shadow(
              color: Color.fromARGB((a * 0.3).round().clamp(0, 255), 200, 150, 30),
              blurRadius: 5,
            ),
            Shadow(
              color: Color.fromARGB((a * 0.4).round().clamp(0, 255), 0, 0, 0),
              blurRadius: 3,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    // Position at bottom-center, above HUD area
    textPainter.paint(canvas, Offset(cx - textPainter.width / 2, h * 0.82));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
  }
}
