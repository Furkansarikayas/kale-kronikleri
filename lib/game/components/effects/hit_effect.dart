import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Particle burst effect shown on enemy hit, tower fire, or special events.
class HitEffect extends PositionComponent {
  final List<_Particle> _particles = [];
  double _life;
  final double maxLife;
  final bool _isExplosion;

  HitEffect({
    required Vector2 pos,
    required Color color,
    int count = 8,
    double speed = 60.0,
    double size = 2.5,
    this.maxLife = 0.4,
  }) : _life = maxLife,
       _isExplosion = false,
       super(position: pos.clone(), anchor: Anchor.center) {
    final rng = math.Random();
    for (int i = 0; i < count; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final spd = speed * (0.5 + rng.nextDouble() * 0.5);
      final hue = (rng.nextDouble() - 0.5) * 30;
      _particles.add(_Particle(
        dx: math.cos(angle) * spd,
        dy: math.sin(angle) * spd,
        size: size * (0.6 + rng.nextDouble() * 0.6),
        color: _shiftHue(color, hue),
        rotation: rng.nextDouble() * math.pi * 2,
        rotSpeed: (rng.nextDouble() - 0.5) * 8,
        gravity: 20 + rng.nextDouble() * 40,
        shape: rng.nextInt(3), // 0=circle, 1=square, 2=diamond
      ));
    }
  }

  /// Explosion effect for cannon/AoE
  factory HitEffect.explosion({required Vector2 pos, double radius = 40}) {
    final effect = HitEffect(
      pos: pos,
      color: const Color(0xFFFF6600),
      count: 16,
      speed: radius * 2.5,
      size: 3.5,
      maxLife: 0.6,
    );
    // Mark as explosion for shockwave ring
    return HitEffect._withExplosion(
      pos: pos,
      color: const Color(0xFFFF6600),
      count: 16,
      speed: radius * 2.5,
      size: 3.5,
      maxLife: 0.6,
    );
  }

  HitEffect._withExplosion({
    required Vector2 pos,
    required Color color,
    int count = 16,
    double speed = 100.0,
    double size = 3.5,
    this.maxLife = 0.6,
  }) : _life = maxLife,
       _isExplosion = true,
       super(position: pos.clone(), anchor: Anchor.center) {
    final rng = math.Random();
    for (int i = 0; i < count; i++) {
      final angle = i * math.pi * 2 / count;
      final spd = speed * (0.6 + rng.nextDouble() * 0.4);
      final colors = [
        const Color(0xFFFF6600),
        const Color(0xFFFF8800),
        const Color(0xFFFFAA00),
        const Color(0xFFFF4400),
      ];
      _particles.add(_Particle(
        dx: math.cos(angle) * spd,
        dy: math.sin(angle) * spd,
        size: size * (0.7 + rng.nextDouble() * 0.5),
        color: colors[rng.nextInt(colors.length)],
        rotation: angle,
        rotSpeed: (rng.nextDouble() - 0.5) * 6,
        gravity: 30,
        shape: rng.nextInt(2),
      ));
    }
  }

  /// Ice shatter effect
  factory HitEffect.ice({required Vector2 pos}) {
    return HitEffect(
      pos: pos,
      color: const Color(0xFF87CEEB),
      count: 7,
      speed: 50,
      size: 2.2,
      maxLife: 0.4,
    );
  }

  /// Fire burst
  factory HitEffect.fire({required Vector2 pos}) {
    return HitEffect(
      pos: pos,
      color: const Color(0xFFFF4500),
      count: 10,
      speed: 55,
      size: 2.8,
      maxLife: 0.45,
    );
  }

  /// Poison splash
  factory HitEffect.poison({required Vector2 pos}) {
    return HitEffect(
      pos: pos,
      color: const Color(0xFF00FF00),
      count: 6,
      speed: 35,
      size: 2.2,
      maxLife: 0.55,
    );
  }

  /// Lightning spark
  factory HitEffect.lightning({required Vector2 pos}) {
    return HitEffect(
      pos: pos,
      color: const Color(0xFFFFD700),
      count: 8,
      speed: 100,
      size: 1.8,
      maxLife: 0.2,
    );
  }

  /// Death burst when enemy dies
  factory HitEffect.death({required Vector2 pos, Color color = const Color(0xFFFF0000)}) {
    return HitEffect(
      pos: pos,
      color: color,
      count: 14,
      speed: 80,
      size: 3.0,
      maxLife: 0.55,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    if (_life <= 0) {
      removeFromParent();
      return;
    }
    for (final p in _particles) {
      p.x += p.dx * dt;
      p.y += p.dy * dt;
      p.dy += p.gravity * dt; // Gravity pull
      p.rotation += p.rotSpeed * dt;
      // Friction
      p.dx *= 0.94;
      p.dy *= 0.94;
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / maxLife).clamp(0.0, 1.0);

    // Explosion shockwave ring
    if (_isExplosion && t > 0.3) {
      final ringT = 1.0 - t;
      final ringRadius = ringT * 30;
      final ringAlpha = ((t - 0.3) / 0.7 * 100).round().clamp(0, 255);
      canvas.drawCircle(
        Offset.zero, ringRadius,
        Paint()
          ..color = Color.fromARGB(ringAlpha, 255, 150, 0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * t,
      );
    }

    // Flash on start
    if (t > 0.85) {
      final flashAlpha = ((t - 0.85) / 0.15 * 60).round().clamp(0, 255);
      canvas.drawCircle(
        Offset.zero, 8 * t,
        Paint()..color = Color.fromARGB(flashAlpha, 255, 255, 200),
      );
    }

    for (final p in _particles) {
      final alpha = (t * 255).round().clamp(0, 255);
      final currentSize = p.size * (0.3 + t * 0.7);

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      // Particle glow
      if (currentSize > 1.5) {
        canvas.drawCircle(
          Offset.zero, currentSize * 1.5,
          Paint()..color = p.color.withAlpha((alpha * 0.2).round().clamp(0, 255)),
        );
      }

      // Main particle
      final paint = Paint()..color = p.color.withAlpha(alpha);
      switch (p.shape) {
        case 1: // Square
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: currentSize * 1.4, height: currentSize * 1.4),
            paint,
          );
          break;
        case 2: // Diamond
          final path = Path()
            ..moveTo(0, -currentSize)
            ..lineTo(currentSize * 0.7, 0)
            ..lineTo(0, currentSize)
            ..lineTo(-currentSize * 0.7, 0)
            ..close();
          canvas.drawPath(path, paint);
          break;
        default: // Circle with gradient
          if (currentSize > 1.0) {
            final grad = ui.Gradient.radial(
              Offset(-currentSize * 0.2, -currentSize * 0.2), currentSize,
              [p.color.withAlpha(alpha), p.color.withAlpha((alpha * 0.3).round().clamp(0, 255))],
            );
            canvas.drawCircle(Offset.zero, currentSize, Paint()..shader = grad);
          } else {
            canvas.drawCircle(Offset.zero, currentSize, paint);
          }
      }

      canvas.restore();
    }
  }

  static Color _shiftHue(Color color, double shift) {
    final r = (color.red + shift).round().clamp(0, 255);
    final g = (color.green + shift * 0.5).round().clamp(0, 255);
    final b = (color.blue - shift * 0.3).round().clamp(0, 255);
    return Color.fromARGB(color.alpha, r, g, b);
  }
}

class _Particle {
  double x = 0;
  double y = 0;
  double dx;
  double dy;
  double size;
  Color color;
  double rotation;
  double rotSpeed;
  double gravity;
  int shape;

  _Particle({
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
    this.rotation = 0,
    this.rotSpeed = 0,
    this.gravity = 0,
    this.shape = 0,
  });
}
