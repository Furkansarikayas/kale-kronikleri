import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class FloatingText extends TextComponent {
  double _life = 0.8;
  final double _speed = 40.0;

  FloatingText({
    required String text,
    required Vector2 pos,
    Color color = const Color(0xFFFFFFFF),
    double fontSize = 10,
  }) : super(
    text: text,
    position: pos.clone(),
    anchor: Anchor.center,
    textRenderer: TextPaint(
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    position.y -= _speed * dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final alpha = (_life / 0.8).clamp(0.0, 1.0);
    if (alpha < 1.0) {
      canvas.saveLayer(null, Paint()..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255));
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }
  }
}
