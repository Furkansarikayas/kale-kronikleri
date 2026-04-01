import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Brief dramatic banner shown at wave start.
/// Screen flash + sweep lines + wave number text.
class WaveBanner extends PositionComponent {
  final int waveNumber;
  final bool isBossWave;
  double _timer = 0;
  static const double _duration = 1.2;

  WaveBanner({
    required this.waveNumber,
    required Vector2 worldSize,
    this.isBossWave = false,
  }) {
    size = worldSize;
    priority = 99;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    if (_timer >= _duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_timer / _duration).clamp(0.0, 1.0);
    final w = size.x;
    final h = size.y;
    final cx = w / 2;
    final cy = h / 2;

    // 1. Initial screen flash (0.0–0.12s): bright white, fast fade
    if (t < 0.1) {
      final flashT = t / 0.1;
      final flashAlpha = ((1.0 - flashT) * 40).round().clamp(0, 255);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = Color.fromARGB(flashAlpha, 255, 255, 240),
      );
    }

    // 2. Horizontal sweep lines from center outward (0.0–0.3s)
    if (t < 0.25) {
      final sweepT = t / 0.25;
      final lineLen = sweepT * w * 0.5;
      final lineAlpha = ((1.0 - sweepT) * 180).round().clamp(0, 255);
      final color = isBossWave
          ? Color.fromARGB(lineAlpha, 255, 60, 30)
          : Color.fromARGB(lineAlpha, 255, 215, 80);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      // Top sweep line
      canvas.drawLine(Offset(cx - lineLen, cy - 18), Offset(cx + lineLen, cy - 18), paint);
      // Bottom sweep line
      canvas.drawLine(Offset(cx - lineLen, cy + 18), Offset(cx + lineLen, cy + 18), paint);
    }

    // 3. Wave number text (0.0–1.0s): fade in quickly, hold, fade out
    final textAlpha = t < 0.08
        ? t / 0.08 // fade in
        : t > 0.6
            ? (1.0 - t) / 0.4 // fade out
            : 1.0; // hold

    if (textAlpha > 0.01) {
      final a = (textAlpha * 255).round().clamp(0, 255);

      // Text glow behind
      final glowColor = isBossWave
          ? Color.fromARGB((a * 0.3).round().clamp(0, 255), 255, 50, 20)
          : Color.fromARGB((a * 0.3).round().clamp(0, 255), 255, 200, 50);

      // Wave label
      final label = isBossWave ? 'BOSS DALGA' : 'DALGA';
      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Color.fromARGB(a, 255, 255, 255),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
            shadows: [Shadow(color: glowColor, blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(cx - labelPainter.width / 2, cy - 16));

      // Wave number
      final numberPainter = TextPainter(
        text: TextSpan(
          text: '$waveNumber',
          style: TextStyle(
            color: isBossWave
                ? Color.fromARGB(a, 255, 80, 40)
                : Color.fromARGB(a, 255, 220, 80),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: glowColor, blurRadius: 8),
              Shadow(color: Color.fromARGB((a * 0.5).round().clamp(0, 255), 0, 0, 0), blurRadius: 3),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      numberPainter.layout();
      numberPainter.paint(canvas, Offset(cx - numberPainter.width / 2, cy - 4));
    }
  }
}
