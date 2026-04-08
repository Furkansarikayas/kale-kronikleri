import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class FloatingText extends TextComponent {
  double _life = 0.8;
  final double _speed;

  // Pool tracking
  static int totalCreated = 0;
  static int totalActive = 0;

  FloatingText({
    required String text,
    required Vector2 pos,
    Color color = const Color(0xFFFFFFFF),
    double fontSize = 10,
    bool isCritical = false,
  }) : _speed = isCritical ? 55.0 : 45.0,
       super(
    text: isCritical ? '$text!' : text,
    position: pos.clone(),
    anchor: Anchor.center,
    textRenderer: TextPaint(
      style: TextStyle(
        color: isCritical ? const Color(0xFFFFD700) : color,
        fontSize: isCritical ? fontSize * 1.5 : fontSize,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(color: Color(0xCC000000), offset: Offset(1, 1)),
        ],
      ),
    ),
  ) {
    totalCreated++;
  }

  @override
  void onMount() {
    super.onMount();
    totalActive++;
  }

  @override
  void onRemove() {
    totalActive--;
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    position.y -= _speed * dt;
    if (_life < 0.4) position.x += dt * 5;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // Scale-up on spawn (no saveLayer, no opacity blend)
    final t = (_life / 0.8).clamp(0.0, 1.0);
    final s = t < 0.2 ? 0.5 + (t / 0.2) * 0.5 : 1.0;
    if (s < 0.99) {
      canvas.save();
      canvas.scale(s, s);
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }
  }
}
