import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class SynergyParticles extends PositionComponent {
  final double cellSize;
  final List<_OrbitalParticle> _particles = [];
  double _timer = 0;

  // Cached paints — single-threaded render, safe to reuse
  static final Paint _glowPaint = Paint();
  static final Paint _bodyPaint = Paint();

  SynergyParticles({required this.cellSize}) {
    final rng = Random();
    for (int i = 0; i < 6; i++) {
      _particles.add(_OrbitalParticle(
        angle: i * pi / 3,
        radius: cellSize * 0.45 + rng.nextDouble() * cellSize * 0.15,
        speed: 1.5 + rng.nextDouble() * 0.5,
        size: 1.5 + rng.nextDouble(),
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    for (final p in _particles) {
      p.angle += p.speed * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(cellSize / 2, cellSize / 2);
    for (final p in _particles) {
      final pos = center + Offset(cos(p.angle) * p.radius, sin(p.angle) * p.radius);

      // Outer glow
      _glowPaint.color = const Color(0x20FFD700);
      canvas.drawCircle(pos, p.size * 3, _glowPaint);

      // Particle body
      _bodyPaint.color = const Color.fromRGBO(255, 215, 0, 0.8);
      canvas.drawCircle(pos, p.size, _bodyPaint);
    }
  }
}

class _OrbitalParticle {
  double angle;
  double radius;
  double speed;
  double size;
  _OrbitalParticle({required this.angle, required this.radius, required this.speed, required this.size});
}
