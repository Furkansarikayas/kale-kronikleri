import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Brief celebration overlay when a wave is cleared.
/// Green-gold sweep + "cleared" text + optional perfect star.
class WaveClearEffect extends PositionComponent {
  final int waveNumber;
  final bool isPerfect;
  double _timer = 0;
  static const double _duration = 0.8;

  // Cached paint — single-threaded render, safe to reuse
  static final Paint _sweepPaint = Paint()..strokeCap = StrokeCap.round;

  WaveClearEffect({
    required this.waveNumber,
    required Vector2 worldSize,
    this.isPerfect = false,
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

    // 1. Quick green-gold horizontal sweep (0–0.15s)
    if (t < 0.2) {
      final sweepT = t / 0.2;
      final lineLen = sweepT * w * 0.55;
      final lineAlpha = ((1.0 - sweepT) * 160).round().clamp(0, 255);
      _sweepPaint.color = Color.fromARGB(lineAlpha, 100, 255, 120);
      _sweepPaint.strokeWidth = 1.5;
      canvas.drawLine(Offset(cx - lineLen, cy - 14), Offset(cx + lineLen, cy - 14), _sweepPaint);
      canvas.drawLine(Offset(cx - lineLen, cy + 14), Offset(cx + lineLen, cy + 14), _sweepPaint);
    }

    // 2. "DALGA X TEMİZLENDİ" text
    final textAlpha = t < 0.05
        ? t / 0.05
        : t > 0.5
            ? (1.0 - t) / 0.5
            : 1.0;

    if (textAlpha > 0.01) {
      final a = (textAlpha * 255).round().clamp(0, 255);
      final glowColor = Color.fromARGB((a * 0.3).round().clamp(0, 255), 80, 220, 100);

      final textPainter = TextPainter(
        text: TextSpan(
          text: 'DALGA $waveNumber TEMİZLENDİ',
          style: TextStyle(
            color: Color.fromARGB(a, 200, 255, 200),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [
              Shadow(color: glowColor, blurRadius: 6),
              Shadow(color: Color.fromARGB((a * 0.5).round().clamp(0, 255), 0, 0, 0), blurRadius: 3),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - 8));

      // 3. Perfect wave golden star
      if (isPerfect) {
        final starPainter = TextPainter(
          text: TextSpan(
            text: 'KUSURSUZ!',
            style: TextStyle(
              color: Color.fromARGB(a, 255, 220, 80),
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              shadows: [
                Shadow(color: Color.fromARGB((a * 0.4).round().clamp(0, 255), 255, 200, 50), blurRadius: 5),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        starPainter.layout();
        starPainter.paint(canvas, Offset(cx - starPainter.width / 2, cy + 6));
      }
    }
  }
}
