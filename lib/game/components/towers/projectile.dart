import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Projectile extends CircleComponent {
  final Vector2 target;
  final double speed;
  final int damage;
  final double splashRadius;
  bool _hit = false;

  Projectile({
    required Vector2 startPos,
    required this.target,
    required this.damage,
    this.speed = 300.0,
    this.splashRadius = 0.0,
    Color color = const Color(0xFFFFFFFF),
  }) : super(
    position: startPos.clone(),
    radius: 3,
    paint: Paint()..color = color,
    anchor: Anchor.center,
  );

  bool get hasHit => _hit;

  @override
  void update(double dt) {
    super.update(dt);
    if (_hit) return;

    final direction = target - position;
    final distance = direction.length;

    if (distance < speed * dt) {
      position.setFrom(target);
      _hit = true;
      return;
    }

    direction.normalize();
    position += direction * speed * dt;
  }

  void markHit() => _hit = true;
}
