import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Particle burst effect shown on enemy hit, tower fire, or special events.
class HitEffect extends PositionComponent {
  final List<_Particle> _particles = [];
  double _life;
  final double maxLife;
  final bool _isExplosion;

  // Cached paints — single-threaded render, safe to share
  static final Paint _fp = Paint();
  static final Paint _sp = Paint()..style = PaintingStyle.stroke;

  HitEffect({
    required Vector2 pos,
    required Color color,
    int count = 6,
    double speed = 60.0,
    double size = 2.0,
    this.maxLife = 0.3,
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
        gravity: 20 + rng.nextDouble() * 40,
        shape: rng.nextInt(3),
      ));
    }
  }

  /// Explosion effect for cannon/AoE
  factory HitEffect.explosion({required Vector2 pos, double radius = 40}) {
    return HitEffect._withExplosion(
      pos: pos,
      color: const Color(0xFFFF6600),
      count: 8,
      speed: radius * 2.0,
      size: 2.5,
      maxLife: 0.35,
    );
  }

  HitEffect._withExplosion({
    required Vector2 pos,
    required Color color,
    int count = 8,
    double speed = 80.0,
    double size = 2.5,
    this.maxLife = 0.35,
  }) : _life = maxLife,
       _isExplosion = true,
       super(position: pos.clone(), anchor: Anchor.center) {
    final rng = math.Random();
    const colors = [
      Color(0xFFFF6600),
      Color(0xFFFF8800),
      Color(0xFFFFAA00),
      Color(0xFFFF4400),
    ];
    for (int i = 0; i < count; i++) {
      final angle = i * math.pi * 2 / count;
      final spd = speed * (0.6 + rng.nextDouble() * 0.4);
      _particles.add(_Particle(
        dx: math.cos(angle) * spd,
        dy: math.sin(angle) * spd,
        size: size * (0.7 + rng.nextDouble() * 0.5),
        color: colors[rng.nextInt(colors.length)],
        gravity: 30,
        shape: rng.nextInt(2),
      ));
    }
  }

  factory HitEffect.ice({required Vector2 pos}) {
    return HitEffect(pos: pos, color: const Color(0xFF87CEEB), count: 5, speed: 50, size: 1.8, maxLife: 0.25);
  }

  factory HitEffect.fire({required Vector2 pos}) {
    return HitEffect(pos: pos, color: const Color(0xFFFF4500), count: 7, speed: 55, size: 2.2, maxLife: 0.3);
  }

  factory HitEffect.poison({required Vector2 pos}) {
    return HitEffect(pos: pos, color: const Color(0xFF00FF00), count: 5, speed: 35, size: 1.8, maxLife: 0.35);
  }

  factory HitEffect.lightning({required Vector2 pos}) {
    return HitEffect(pos: pos, color: const Color(0xFFFFD700), count: 6, speed: 100, size: 1.5, maxLife: 0.15);
  }

  factory HitEffect.death({required Vector2 pos, Color color = const Color(0xFFFF0000)}) {
    return HitEffect(pos: pos, color: color, count: 8, speed: 80, size: 2.5, maxLife: 0.35);
  }

  factory HitEffect.bossDeath({required Vector2 pos, Color color = const Color(0xFFFF0000)}) {
    return HitEffect(pos: pos, color: color, count: 12, speed: 100, size: 3.0, maxLife: 0.4);
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
      p.dy += p.gravity * dt;
      p.dx *= 0.94;
      p.dy *= 0.94;
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / maxLife).clamp(0.0, 1.0);

    // Explosion shockwave ring (simplified — no outer glow layer)
    if (_isExplosion && t > 0.3) {
      final ringT = 1.0 - t;
      final ringRadius = ringT * 30;
      final ringAlpha = ((t - 0.3) / 0.7 * 180).round().clamp(0, 255);
      _sp.color = Color.fromARGB(ringAlpha, 255, 150, 0);
      _sp.strokeWidth = 2.5 * t;
      canvas.drawCircle(Offset.zero, ringRadius, _sp);
    }

    // Flash on start
    if (t > 0.85) {
      final flashAlpha = ((t - 0.85) / 0.15 * 60).round().clamp(0, 255);
      _fp.color = Color.fromARGB(flashAlpha, 255, 255, 200);
      canvas.drawCircle(Offset.zero, 8 * t, _fp);
    }

    for (final p in _particles) {
      final alpha = (t * 255).round().clamp(0, 255);
      final currentSize = p.size * (0.3 + t * 0.7);

      // Main particle — solid color, no gradient
      _fp.color = p.color.withAlpha(alpha);
      switch (p.shape) {
        case 1: // Square
          canvas.drawRect(
            Rect.fromCenter(center: Offset(p.x, p.y), width: currentSize * 1.4, height: currentSize * 1.4),
            _fp,
          );
        case 2: // Diamond
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(0.785); // pi/4
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: currentSize, height: currentSize),
            _fp,
          );
          canvas.restore();
        default: // Circle — simple solid fill (no gradient)
          canvas.drawCircle(Offset(p.x, p.y), currentSize, _fp);
      }
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
  double gravity;
  int shape;

  _Particle({
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
    this.gravity = 0,
    this.shape = 0,
  });
}

/// Brief glowing line between two points (wizard chain, etc.).
class ChainEffect extends PositionComponent {
  final Vector2 _to;
  final Color _color;
  double _life;
  static const double _maxLife = 0.15;

  // Cached paints
  static final Paint _linePaint = Paint()..strokeCap = StrokeCap.round;

  ChainEffect({required Vector2 from, required Vector2 to, required Color color})
      : _to = to.clone(),
        _color = color,
        _life = _maxLife,
        super(position: from.clone(), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / _maxLife).clamp(0.0, 1.0);
    final alpha = (t * 200).round().clamp(0, 255);
    final end = (_to - position).toOffset();

    // Core line only (skip glow layer for performance)
    _linePaint.color = _color.withAlpha(alpha);
    _linePaint.strokeWidth = 1.5 * t;
    canvas.drawLine(Offset.zero, end, _linePaint);
  }
}
