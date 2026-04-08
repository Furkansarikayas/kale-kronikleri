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

  // Pre-allocated trail circular buffer (avoids per-frame Vector2 allocation)
  late final List<Vector2> _trail;
  int _trailHead = 0;
  int _trailCount = 0;
  final int _maxTrailLength;

  // Bounds for off-screen cleanup (200px margin)
  static const double _boundsMargin = 200.0;
  static final double _maxX = GameConfig.gridColumns * KaleGame.fixedCellSize + _boundsMargin;
  static final double _maxY = GameConfig.gridRows * KaleGame.fixedCellSize + _boundsMargin;

  // Cached paints — single-threaded render, safe to reuse
  static final Paint _fp = Paint();
  static final Paint _sp = Paint()..style = PaintingStyle.stroke;
  static final Paint _tp = Paint()..strokeCap = StrokeCap.round;

  // Pre-extracted RGB for trail rendering (avoid per-frame .withAlpha calls)
  late final int _trailR;
  late final int _trailG;
  late final int _trailB;
  late final int _baseR;
  late final int _baseG;
  late final int _baseB;

  Projectile({
    required Vector2 startPos,
    required this.target,
    required this.damage,
    this.speed = 300.0,
    this.splashRadius = 0.0,
    double projectileRadius = 3.0,
    int trailLength = 3,
    Color color = const Color(0xFFFFFFFF),
    this.shape = ProjectileShape.orb,
    this.trailStyle = TrailStyle.defaultTrail,
  }) : trailColor = Color.fromARGB(100, (color.r * 255).round(), (color.g * 255).round(), (color.b * 255).round()),
       _baseColor = color,
       _maxTrailLength = trailLength,
       super(
    position: startPos.clone(),
    radius: projectileRadius,
    paint: Paint()..color = Colors.transparent,
    anchor: Anchor.center,
  ) {
    _trailR = (trailColor.r * 255).round();
    _trailG = (trailColor.g * 255).round();
    _trailB = (trailColor.b * 255).round();
    _baseR = (color.r * 255).round();
    _baseG = (color.g * 255).round();
    _baseB = (color.b * 255).round();
    _trail = List.generate(_maxTrailLength, (_) => Vector2.zero());
  }

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

    // Circular buffer — no allocation, no list shift
    _trail[_trailHead].setFrom(position);
    _trailHead = (_trailHead + 1) % _maxTrailLength;
    if (_trailCount < _maxTrailLength) _trailCount++;

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
        _fp.color = Color.fromARGB(alpha, _baseR, _baseG, _baseB);
        canvas.drawCircle(Offset.zero, r, _fp);

      case ProjectileShape.bolt:
        final angle = math.atan2(_direction.y, _direction.x);
        canvas.save();
        canvas.rotate(angle);
        final w = radius * (3 + t * 6);
        final h = radius * (1.5 + t * 2);
        _fp.color = Color.fromARGB(alpha, _baseR, _baseG, _baseB);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: h), _fp);
        canvas.restore();

      case ProjectileShape.heavy:
        final r = radius * (1 + t * 5);
        _sp.color = Color.fromARGB(alpha, _baseR, _baseG, _baseB);
        _sp.strokeWidth = radius * (1.0 - t * 0.7);
        canvas.drawCircle(Offset.zero, r, _sp);
    }
  }

  void _renderOrb(Canvas canvas) {
    // Main body — solid color
    _fp.color = _baseColor;
    canvas.drawCircle(Offset.zero, radius, _fp);
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
    // Main body — solid
    _fp.color = _baseColor;
    canvas.drawCircle(Offset.zero, radius, _fp);

    // Dark outer ring
    _sp.color = Color.fromARGB(100, (_baseR * 0.7).round(), (_baseG * 0.7).round(), (_baseB * 0.7).round());
    _sp.strokeWidth = 1.0;
    canvas.drawCircle(Offset.zero, radius, _sp);
  }

  void _renderTrail(Canvas canvas) {
    if (_trailCount < 2) return;
    final px = position.x;
    final py = position.y;
    final len = _trailCount;

    for (int i = 0; i < len - 1; i++) {
      final fade = 1.0 - i / len;
      // Circular buffer index computation
      final idx1 = (_trailHead - len + i) % _maxTrailLength;
      final idx2 = (_trailHead - len + i + 1) % _maxTrailLength;
      final p1 = Offset(_trail[idx1].x - px, _trail[idx1].y - py);
      final p2 = Offset(_trail[idx2].x - px, _trail[idx2].y - py);
      final fa = (fade * 255).round();

      // Single draw call per segment (inner core only — skip outer glow for performance)
      late final Color coreColor;
      late final double coreWidth;

      switch (trailStyle) {
        case TrailStyle.arrow:
          coreColor = Color.fromARGB((fa * 0.7).round().clamp(0, 255), _trailR, _trailG, _trailB);
          coreWidth = fade * radius * 0.7 + 0.3;
        case TrailStyle.fire:
          coreColor = Color.fromARGB((fa * 0.63).round().clamp(0, 255), 255, 160, 40);
          coreWidth = (fade * radius + 0.5) * 0.8;
        case TrailStyle.ice:
          coreColor = Color.fromARGB((fa * 0.55).round().clamp(0, 255), 200, 240, 255);
          coreWidth = (fade * radius + 0.4) * 0.7;
        case TrailStyle.lightning:
          coreColor = Color.fromARGB((fa * 0.78).round().clamp(0, 255), 255, 255, 255);
          coreWidth = 0.8;
        case TrailStyle.poison:
          coreColor = Color.fromARGB((fa * 0.51).round().clamp(0, 255), 80, 255, 80);
          coreWidth = (fade * radius + 0.6) * 0.9;
        case TrailStyle.water:
          coreColor = Color.fromARGB((fa * 0.47).round().clamp(0, 255), 120, 180, 255);
          coreWidth = (fade * radius + 0.4) * 0.7;
        case TrailStyle.dark:
          coreColor = Color.fromARGB((fa * 0.47).round().clamp(0, 255), 140, 50, 220);
          coreWidth = fade * radius + 0.5;
        case TrailStyle.wizard:
          coreColor = Color.fromARGB((fa * 0.55).round().clamp(0, 255), 200, 130, 255);
          coreWidth = (fade * radius + 0.5) * 0.8;
        case TrailStyle.holy:
          coreColor = Color.fromARGB((fa * 0.63).round().clamp(0, 255), 255, 250, 220);
          coreWidth = (fade * radius + 0.4) * 0.8;
        case TrailStyle.cannon:
          coreColor = Color.fromARGB((fa * 0.5).round().clamp(0, 255), _trailR, _trailG, _trailB);
          coreWidth = (fade * radius * 1.2 + 0.8) * 0.8;
        case TrailStyle.defaultTrail:
          coreColor = Color.fromARGB((fa * 0.6).round().clamp(0, 255), _trailR, _trailG, _trailB);
          coreWidth = fade * radius + 0.5;
      }

      _tp.color = coreColor;
      _tp.strokeWidth = coreWidth;
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
