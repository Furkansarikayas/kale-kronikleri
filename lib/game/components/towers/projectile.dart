import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Projectile extends CircleComponent {
  final Vector2 target;
  final double speed;
  final int damage;
  final double splashRadius;
  final Color trailColor;
  final Color _baseColor;
  bool _hit = false;
  double _animTimer = 0;

  // Trail positions for visual effect
  final List<Vector2> _trail = [];
  static const int _maxTrailLength = 12;

  Projectile({
    required Vector2 startPos,
    required this.target,
    required this.damage,
    this.speed = 300.0,
    this.splashRadius = 0.0,
    Color color = const Color(0xFFFFFFFF),
  }) : trailColor = color.withAlpha(100),
       _baseColor = color,
       super(
    position: startPos.clone(),
    radius: 3,
    paint: Paint()..color = Colors.transparent,
    anchor: Anchor.center,
  );

  bool get hasHit => _hit;

  @override
  void update(double dt) {
    super.update(dt);
    if (_hit) return;

    _animTimer += dt;

    // Store trail position
    _trail.add(position.clone());
    if (_trail.length > _maxTrailLength) _trail.removeAt(0);

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

  @override
  void render(Canvas canvas) {
    // Glow behind projectile
    canvas.drawCircle(
      Offset.zero, radius * 2.5,
      Paint()..color = _baseColor.withAlpha(25),
    );

    // Draw enhanced trail with glow + core layers
    _renderTrail(canvas);

    // Outer glow ring
    canvas.drawCircle(
      Offset.zero, radius * 1.5,
      Paint()..color = _baseColor.withAlpha(40),
    );

    // Main projectile body with gradient
    final grad = ui.Gradient.radial(
      Offset(-radius * 0.3, -radius * 0.3), radius * 1.2,
      [_lighten(_baseColor, 0.5), _baseColor, _darken(_baseColor, 0.3)],
      [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(Offset.zero, radius, Paint()..shader = grad);

    // Bright core
    canvas.drawCircle(
      Offset(-radius * 0.2, -radius * 0.2), radius * 0.4,
      Paint()..color = const Color(0x88FFFFFF),
    );

    // Animated sparkle
    final sparkleAngle = _animTimer * 10;
    final sparkleR = radius * 0.3;
    for (int i = 0; i < 3; i++) {
      final angle = sparkleAngle + i * math.pi * 2 / 3;
      final sx = math.cos(angle) * radius * 0.6;
      final sy = math.sin(angle) * radius * 0.6;
      canvas.drawCircle(
        Offset(sx, sy), sparkleR,
        Paint()..color = const Color(0x44FFFFFF),
      );
    }
  }

  void _renderTrail(Canvas canvas) {
    if (_trail.length < 2) return;
    for (int i = 0; i < _trail.length - 1; i++) {
      final progress = i / _trail.length;
      final alpha = (1.0 - progress) * 0.6;
      final width = (1.0 - progress) * 3.0 + 0.5;

      final p1 = _trail[i] - position;
      final p2 = _trail[i + 1] - position;

      // Glow layer
      canvas.drawLine(p1.toOffset(), p2.toOffset(), Paint()
        ..color = trailColor.withValues(alpha: alpha * 0.3)
        ..strokeWidth = width * 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 2));

      // Core layer
      canvas.drawLine(p1.toOffset(), p2.toOffset(), Paint()
        ..color = trailColor.withValues(alpha: alpha)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round);
    }
  }

  void markHit() => _hit = true;

  static Color _lighten(Color c, double amount) {
    return Color.fromARGB(
      c.alpha,
      (c.red + (255 - c.red) * amount).round().clamp(0, 255),
      (c.green + (255 - c.green) * amount).round().clamp(0, 255),
      (c.blue + (255 - c.blue) * amount).round().clamp(0, 255),
    );
  }

  static Color _darken(Color c, double amount) {
    return Color.fromARGB(
      c.alpha,
      (c.red * (1 - amount)).round().clamp(0, 255),
      (c.green * (1 - amount)).round().clamp(0, 255),
      (c.blue * (1 - amount)).round().clamp(0, 255),
    );
  }
}
