import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/game_config.dart';
import '../../kale_game.dart';

enum ProjectileShape { orb, bolt, heavy }
enum TrailStyle { arrow, fire, ice, lightning, poison, water, dark, wizard, holy, cannon, defaultTrail }

class Projectile extends CircleComponent {
  final Vector2 target;
  final double speed;
  final int damage;
  final double splashRadius;
  final Color trailColor;
  final Color _baseColor;
  final ProjectileShape shape;
  final TrailStyle trailStyle;
  bool _hit = false;
  bool _outOfBounds = false;
  double _animTimer = 0;
  double _impactTimer = 0;
  static const double _impactDuration = 0.15;
  final Vector2 _direction = Vector2(1, 0);

  final List<Vector2> _trail = [];
  final int _maxTrailLength;

  // Bounds for off-screen cleanup (200px margin)
  static const double _boundsMargin = 200.0;
  static final double _maxX = GameConfig.gridColumns * KaleGame.fixedCellSize + _boundsMargin;
  static final double _maxY = GameConfig.gridRows * KaleGame.fixedCellSize + _boundsMargin;

  // Cached paints — single-threaded render, safe to reuse
  static final Paint _fp = Paint();
  static final Paint _sp = Paint()..style = PaintingStyle.stroke;
  static final Paint _tp = Paint()..strokeCap = StrokeCap.round;

  Projectile({
    required Vector2 startPos,
    required this.target,
    required this.damage,
    this.speed = 300.0,
    this.splashRadius = 0.0,
    double projectileRadius = 3.0,
    int trailLength = 6,
    Color color = const Color(0xFFFFFFFF),
    this.shape = ProjectileShape.orb,
    this.trailStyle = TrailStyle.defaultTrail,
  }) : trailColor = color.withAlpha(100),
       _baseColor = color,
       _maxTrailLength = trailLength,
       super(
    position: startPos.clone(),
    radius: projectileRadius,
    paint: Paint()..color = Colors.transparent,
    anchor: Anchor.center,
  );

  bool get hasHit => _hit;
  bool get isDone => _outOfBounds || (_hit && _impactTimer >= _impactDuration);

  @override
  void update(double dt) {
    super.update(dt);
    if (_hit) {
      _impactTimer += dt;
      return;
    }

    _animTimer += dt;

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
    _direction.setFrom(direction);
    position += direction * speed * dt;

    // Off-screen bounds check — mark done if far outside map
    if (position.x < -_boundsMargin || position.x > _maxX ||
        position.y < -_boundsMargin || position.y > _maxY) {
      _outOfBounds = true;
    }
  }

  @override
  void render(Canvas canvas) {
    if (_hit) {
      _renderImpact(canvas);
      return;
    }
    _renderTrail(canvas);
    switch (shape) {
      case ProjectileShape.orb:
        _renderOrb(canvas);
      case ProjectileShape.bolt:
        _renderBolt(canvas);
      case ProjectileShape.heavy:
        _renderHeavy(canvas);
    }
  }

  void _renderImpact(Canvas canvas) {
    final t = (_impactTimer / _impactDuration).clamp(0.0, 1.0);
    final alpha = ((1.0 - t) * 180).round().clamp(0, 255);

    switch (shape) {
      case ProjectileShape.orb:
        final r = radius * (1.5 + t * 4);
        _fp.color = _baseColor.withAlpha(alpha);
        canvas.drawCircle(Offset.zero, r, _fp);

      case ProjectileShape.bolt:
        final angle = math.atan2(_direction.y, _direction.x);
        canvas.save();
        canvas.rotate(angle);
        final w = radius * (3 + t * 6);
        final h = radius * (1.5 + t * 2);
        _fp.color = _baseColor.withAlpha(alpha);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: h), _fp);
        canvas.restore();

      case ProjectileShape.heavy:
        final r = radius * (1 + t * 5);
        _sp.color = _baseColor.withAlpha(alpha);
        _sp.strokeWidth = radius * (1.0 - t * 0.7);
        canvas.drawCircle(Offset.zero, r, _sp);
    }
  }

  void _renderOrb(Canvas canvas) {
    // Glow behind
    _fp.color = _baseColor.withAlpha(25);
    canvas.drawCircle(Offset.zero, radius * 2.0, _fp);

    // Main body — solid color (no gradient)
    _fp.color = _baseColor;
    canvas.drawCircle(Offset.zero, radius, _fp);

    // Bright core
    _fp.color = const Color(0x88FFFFFF);
    canvas.drawCircle(Offset(-radius * 0.2, -radius * 0.2), radius * 0.4, _fp);
  }

  void _renderBolt(Canvas canvas) {
    final angle = math.atan2(_direction.y, _direction.x);
    canvas.save();
    canvas.rotate(angle);

    // Bolt body
    final path = Path()
      ..moveTo(radius * 2.5, 0)
      ..lineTo(0, radius * 0.8)
      ..lineTo(-radius * 1.5, 0)
      ..lineTo(0, -radius * 0.8)
      ..close();
    _fp.color = _baseColor;
    canvas.drawPath(path, _fp);

    // Bright core line
    _tp.color = const Color(0x66FFFFFF);
    _tp.strokeWidth = radius * 0.5;
    canvas.drawLine(Offset(-radius, 0), Offset(radius * 2, 0), _tp);

    canvas.restore();
  }

  void _renderHeavy(Canvas canvas) {
    // Glow
    _fp.color = _baseColor.withAlpha(35);
    canvas.drawCircle(Offset.zero, radius * 2, _fp);

    // Main body — solid
    _fp.color = _baseColor;
    canvas.drawCircle(Offset.zero, radius, _fp);

    // Dark outer ring
    _sp.color = _darken(_baseColor, 0.3).withAlpha(100);
    _sp.strokeWidth = 1.0;
    canvas.drawCircle(Offset.zero, radius, _sp);

    // Metallic highlight
    _fp.color = const Color(0x66FFFFFF);
    canvas.drawCircle(Offset(-radius * 0.25, -radius * 0.25), radius * 0.3, _fp);
  }

  void _renderTrail(Canvas canvas) {
    if (_trail.length < 2) return;

    for (int i = 0; i < _trail.length - 1; i++) {
      final progress = i / _trail.length;
      final fade = 1.0 - progress;
      final p1 = (_trail[i] - position).toOffset();
      final p2 = (_trail[i + 1] - position).toOffset();

      // All trail styles: outer glow + inner core using cached paints
      late final Color outerColor;
      late final Color innerColor;
      late final double outerWidth;
      late final double innerWidth;

      switch (trailStyle) {
        case TrailStyle.arrow:
          final w = fade * radius * 0.7 + 0.3;
          outerColor = trailColor.withAlpha((fade * 178).round().clamp(0, 255));
          outerWidth = w * 1.2;
          innerColor = Color.fromARGB((fade * 60).round().clamp(0, 255), 255, 255, 240);
          innerWidth = 0.6;

        case TrailStyle.fire:
          final w = fade * radius + 0.5;
          outerColor = Color.fromARGB((fade * 40).round().clamp(0, 255), 255, 100, 20);
          outerWidth = w * 3;
          innerColor = Color.fromARGB((fade * 160).round().clamp(0, 255), 255, 160, 40);
          innerWidth = w * 0.8;

        case TrailStyle.ice:
          final w = fade * radius + 0.4;
          outerColor = Color.fromARGB((fade * 32).round().clamp(0, 255), 180, 230, 255);
          outerWidth = w * 2.5;
          innerColor = Color.fromARGB((fade * 140).round().clamp(0, 255), 200, 240, 255);
          innerWidth = w * 0.7;

        case TrailStyle.lightning:
          final w = fade * radius * 0.6 + 0.3;
          outerColor = Color.fromARGB((fade * 100).round().clamp(0, 255), 255, 255, 100);
          outerWidth = w * 2;
          innerColor = Color.fromARGB((fade * 200).round().clamp(0, 255), 255, 255, 255);
          innerWidth = 0.8;

        case TrailStyle.poison:
          final w = fade * radius + 0.6;
          outerColor = Color.fromARGB((fade * 36).round().clamp(0, 255), 30, 200, 30);
          outerWidth = w * 3;
          innerColor = Color.fromARGB((fade * 130).round().clamp(0, 255), 80, 255, 80);
          innerWidth = w * 0.9;

        case TrailStyle.water:
          final w = fade * radius + 0.4;
          outerColor = Color.fromARGB((fade * 32).round().clamp(0, 255), 80, 140, 255);
          outerWidth = w * 2.5;
          innerColor = Color.fromARGB((fade * 120).round().clamp(0, 255), 120, 180, 255);
          innerWidth = w * 0.7;

        case TrailStyle.dark:
          final w = fade * radius + 0.5;
          outerColor = Color.fromARGB((fade * 48).round().clamp(0, 255), 50, 10, 80);
          outerWidth = w * 3.5;
          innerColor = Color.fromARGB((fade * 120).round().clamp(0, 255), 140, 50, 220);
          innerWidth = w;

        case TrailStyle.wizard:
          final w = fade * radius + 0.5;
          outerColor = Color.fromARGB((fade * 32).round().clamp(0, 255), 170, 50, 220);
          outerWidth = w * 2.8;
          innerColor = Color.fromARGB((fade * 140).round().clamp(0, 255), 200, 130, 255);
          innerWidth = w * 0.8;

        case TrailStyle.holy:
          final w = fade * radius + 0.4;
          outerColor = Color.fromARGB((fade * 40).round().clamp(0, 255), 255, 240, 180);
          outerWidth = w * 2.5;
          innerColor = Color.fromARGB((fade * 160).round().clamp(0, 255), 255, 250, 220);
          innerWidth = w * 0.8;

        case TrailStyle.cannon:
          final w = fade * radius * 1.2 + 0.8;
          outerColor = Color.fromARGB((fade * 44).round().clamp(0, 255), 80, 60, 40);
          outerWidth = w * 3.5;
          innerColor = trailColor.withAlpha((fade * 127).round().clamp(0, 255));
          innerWidth = w * 0.8;

        case TrailStyle.defaultTrail:
          final w = fade * radius + 0.5;
          outerColor = trailColor.withAlpha((fade * 61).round().clamp(0, 255));
          outerWidth = w * 3;
          innerColor = trailColor.withAlpha((fade * 153).round().clamp(0, 255));
          innerWidth = w;
      }

      // Draw outer glow
      _tp.color = outerColor;
      _tp.strokeWidth = outerWidth;
      canvas.drawLine(p1, p2, _tp);

      // Draw inner core
      _tp.color = innerColor;
      _tp.strokeWidth = innerWidth;
      canvas.drawLine(p1, p2, _tp);
    }
  }

  void markHit() => _hit = true;

  static Color _darken(Color c, double amount) {
    return Color.fromARGB(
      c.alpha,
      (c.red * (1 - amount)).round().clamp(0, 255),
      (c.green * (1 - amount)).round().clamp(0, 255),
      (c.blue * (1 - amount)).round().clamp(0, 255),
    );
  }
}
