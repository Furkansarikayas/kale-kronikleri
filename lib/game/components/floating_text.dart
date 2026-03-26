import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class FloatingText extends TextComponent {
  double _life = 0.8;
  final double _speed;
  final double _scale;
  final bool isCritical;

  FloatingText({
    required String text,
    required Vector2 pos,
    Color color = const Color(0xFFFFFFFF),
    double fontSize = 10,
    this.isCritical = false,
  }) : _scale = (isCritical ? fontSize * 1.5 : fontSize) / 10.0,
       _speed = isCritical ? 55.0 : 45.0,
       super(
    text: isCritical ? '$text!' : text,
    position: pos.clone(),
    anchor: Anchor.center,
    textRenderer: TextPaint(
      style: TextStyle(
        color: isCritical ? const Color(0xFFFFD700) : color,
        fontSize: isCritical ? fontSize * 1.5 : fontSize,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: const Color(0xCC000000), blurRadius: 3, offset: const Offset(1, 1)),
          Shadow(
            color: (isCritical ? const Color(0xFFFFD700) : color).withAlpha(150),
            blurRadius: 6,
          ),
          if (isCritical)
            Shadow(
              color: const Color(0xFFFFD700).withAlpha(120),
              blurRadius: 12,
            ),
        ],
      ),
    ),
  );

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    position.y -= _speed * dt;
    // Slight horizontal drift
    if (_life < 0.4) {
      position.x += dt * 5;
    }
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / 0.8).clamp(0.0, 1.0);

    // Scale up on spawn, fade out at end
    final scaleT = t < 0.2 ? (t / 0.2) : 1.0;
    final alpha = t < 0.3 ? t / 0.3 : 1.0;

    canvas.save();
    canvas.scale(scaleT * _scale / _scale + (1 - scaleT) * 0.5, scaleT * _scale / _scale + (1 - scaleT) * 0.5);

    if (alpha < 1.0) {
      canvas.saveLayer(null, Paint()..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255));
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }

    canvas.restore();
  }
}
