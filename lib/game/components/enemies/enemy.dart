import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/enemy_data.dart';
import '../../data/game_config.dart';
import '../../systems/pathfinding.dart';
import 'status_effect.dart';

class Enemy extends RectangleComponent {
  final EnemyType type;
  final EnemyStats baseStats;
  final List<GridPos> path;
  final double cellSize;

  int _hp;
  int _pathIndex = 0;
  bool _reachedCastle = false;
  bool _isDead = false;
  final List<StatusEffect> _effects = [];

  // Burrower mechanic
  bool _isBurrowed = false;
  double _burrowTimer = 0;
  double _burrowCooldown = 0;
  static const double _burrowDuration = 1.5;
  static const double _burrowCooldownTime = 5.0;
  static const int _burrowSkipCells = 4;
  bool get isBurrowed => _isBurrowed;

  // Animation
  double _animTimer = 0;

  Enemy({
    required this.type,
    required this.baseStats,
    required this.path,
    required this.cellSize,
  }) : _hp = baseStats.hp,
    super(
      size: Vector2.all(cellSize * 0.7),
      paint: Paint()..color = Colors.transparent, // Custom render
      anchor: Anchor.center,
    ) {
    if (path.isNotEmpty) {
      position = _gridToWorld(path[0]);
    }
  }

  int get hp => _hp;
  int get maxHp => baseStats.hp;
  bool get isDead => _isDead;
  bool get reachedCastle => _reachedCastle;
  int get goldReward => baseStats.goldReward;
  int get castleDamage => baseStats.castleDamage;
  List<StatusEffect> get activeEffects => _effects;
  List<GridPos> get remainingPath => path.sublist(_pathIndex);

  double get currentSpeed {
    double speed = baseStats.speed;
    for (final e in _effects) {
      if (e.type == StatusType.slow) speed *= (1 - e.slowFactor);
    }
    return speed.clamp(0.1, 10.0);
  }

  int get currentArmor {
    double armor = baseStats.armor.toDouble() + _bonusArmor;
    for (final e in _effects) {
      if (e.type == StatusType.curse) armor -= e.armorReduction;
    }
    return armor.clamp(0, 999).round();
  }

  bool get isWet => _effects.any((e) => e.type == StatusType.wet && !e.isExpired);

  void takeDamage(int rawDamage, {bool bypassArmor = false}) {
    if (_isDead) return;
    final actual = bypassArmor ? rawDamage : GameConfig.calculateDamage(rawDamage, currentArmor);
    _hp -= actual;
    if (_hp <= 0) {
      _hp = 0;
      _isDead = true;
    }
  }

  int _bonusArmor = 0;

  void heal(int amount) {
    if (_isDead) return;
    _hp = (_hp + amount).clamp(0, maxHp);
  }

  void addBonusArmor(int amount) {
    _bonusArmor += amount;
  }

  void applyEffect(StatusEffect effect) {
    _effects.removeWhere((e) => e.type == effect.type);
    _effects.add(effect);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDead || _reachedCastle) return;

    _animTimer += dt;

    // Update status effects
    for (final effect in _effects) {
      final tickDamage = effect.update(dt);
      if (tickDamage > 0) takeDamage(tickDamage, bypassArmor: true);
    }
    _effects.removeWhere((e) => e.isExpired);

    // Burrower mechanic
    if (type == EnemyType.burrower) {
      _updateBurrower(dt);
    }

    // Move along path
    if (_pathIndex >= path.length - 1) {
      _reachedCastle = true;
      return;
    }

    final target = _gridToWorld(path[_pathIndex + 1]);
    final direction = target - position;
    final dist = direction.length;
    final moveSpeed = currentSpeed * cellSize * dt;

    if (dist <= moveSpeed) {
      position.setFrom(target);
      _pathIndex++;
    } else {
      direction.normalize();
      position += direction * moveSpeed;
    }
  }

  void _updateBurrower(double dt) {
    if (_isBurrowed) {
      _burrowTimer -= dt;
      if (_burrowTimer <= 0) {
        _isBurrowed = false;
        _burrowCooldown = _burrowCooldownTime;
        final newIndex = (_pathIndex + _burrowSkipCells).clamp(0, path.length - 1);
        _pathIndex = newIndex;
        position.setFrom(_gridToWorld(path[_pathIndex]));
      }
    } else {
      _burrowCooldown -= dt;
      if (_burrowCooldown <= 0 && _pathIndex < path.length - _burrowSkipCells) {
        _isBurrowed = true;
        _burrowTimer = _burrowDuration;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_isDead || _reachedCastle) return;

    final center = Offset(size.x / 2, size.y / 2);
    final r = size.x * 0.45; // slightly larger body
    final primary = _enemyColor(type);
    final bobY = math.sin(_animTimer * 3.0) * 1.2; // Idle bob

    // Burrowed state
    if (_isBurrowed) {
      // Dirt mound with cracks
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.5), width: size.x * 0.75, height: size.y * 0.35),
        Paint()..color = const Color(0xBB886633),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.4), width: size.x * 0.55, height: size.y * 0.18),
        Paint()..color = const Color(0x66AA8844),
      );
      // Dirt particles flying up
      for (int i = 0; i < 3; i++) {
        final px = center.dx + math.sin(_animTimer * 4 + i * 2) * r * 0.4;
        final py = center.dy + r * 0.2 - math.sin(_animTimer * 5 + i) * r * 0.3;
        canvas.drawCircle(Offset(px, py), 1.5, Paint()..color = const Color(0x88775522));
      }
      return;
    }

    // --- SHADOW (bigger, softer) ---
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, size.y - 1), width: size.x * 0.7, height: 5),
      Paint()..color = const Color(0x44000000),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, size.y - 1), width: size.x * 0.5, height: 3),
      Paint()..color = const Color(0x22000000),
    );

    // --- BODY (with bob offset) ---
    final bodyCenter = Offset(center.dx, center.dy + bobY);

    if (baseStats.isBoss) {
      _drawBossBody(canvas, bodyCenter, r, primary);
    } else {
      _drawEnemyBody(canvas, bodyCenter, r, primary);
    }

    // --- TYPE ICON ---
    _drawTypeIcon(canvas, bodyCenter, r, primary);

    // --- HP BAR ---
    final barWidth = size.x * 1.05;
    const barHeight = 4.0;
    const barY = -8.0;
    final hpRatio = _hp / maxHp;
    final barLeft = (size.x - barWidth) / 2;

    // Bar background
    final barBgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(barLeft, barY, barWidth, barHeight),
      const Radius.circular(2),
    );
    canvas.drawRRect(barBgRect, Paint()..color = const Color(0xBB000000));

    // HP fill with vivid gradient
    if (hpRatio > 0) {
      final barColor = hpRatio > 0.5
          ? Color.lerp(const Color(0xFFFFDD00), const Color(0xFF00FF44), (hpRatio - 0.5) * 2)!
          : Color.lerp(const Color(0xFFFF2200), const Color(0xFFFFDD00), hpRatio * 2)!;
      final barGrad = ui.Gradient.linear(
        Offset(0, barY), Offset(0, barY + barHeight),
        [_lighten(barColor, 0.4), barColor, _darken(barColor, 0.15)],
        [0.0, 0.5, 1.0],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barLeft, barY, barWidth * hpRatio, barHeight),
          const Radius.circular(2),
        ),
        Paint()..shader = barGrad,
      );
    }

    // Bright border around HP bar
    canvas.drawRRect(barBgRect, Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6,
    );

    // --- STATUS EFFECT INDICATORS ---
    double indicatorX = barLeft + 1;
    for (final effect in _effects) {
      if (effect.isExpired) continue;
      Color dotColor;
      switch (effect.type) {
        case StatusType.burn: dotColor = const Color(0xFFFF4500); break;
        case StatusType.poison: dotColor = const Color(0xFF00FF00); break;
        case StatusType.slow: dotColor = const Color(0xFF87CEEB); break;
        case StatusType.wet: dotColor = const Color(0xFF4169E1); break;
        case StatusType.curse: dotColor = const Color(0xFFAA00AA); break;
      }
      canvas.drawCircle(Offset(indicatorX + 2, barY - 3.5), 2.2, Paint()..color = dotColor);
      canvas.drawCircle(Offset(indicatorX + 2, barY - 3.5), 2.2, Paint()
        ..color = const Color(0x55000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
      );
      indicatorX += 5.5;
    }

    // --- ARMOR INDICATOR ---
    if (currentArmor > 0) {
      final armorX = barLeft + barWidth - 9;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(armorX, barY - 4.5, 9, 4.5), const Radius.circular(1.5)),
        Paint()..color = const Color(0xBB7788AA),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(armorX, barY - 4.5, 9, 4.5), const Radius.circular(1.5)),
        Paint()..color = const Color(0x44FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 0.5,
      );
      final tp = TextPainter(
        text: TextSpan(text: '$currentArmor', style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 3)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(armorX + (9 - tp.width) / 2, barY - 4.5));
    }
  }

  void _drawEnemyBody(Canvas canvas, Offset center, double r, Color primary) {
    // Gradient body - 3D look with left highlight, right shadow
    final bodyGrad = ui.Gradient.linear(
      Offset(center.dx - r * 0.8, center.dy - r * 0.6),
      Offset(center.dx + r * 0.8, center.dy + r * 0.6),
      [_lighten(primary, 0.45), _lighten(primary, 0.15), primary, _darken(primary, 0.25), _darken(primary, 0.4)],
      [0.0, 0.2, 0.45, 0.75, 1.0],
    );

    // Choose shape based on type
    switch (type) {
      case EnemyType.armoredGiant:
        // Hexagonal for armored look
        final hexPath = Path();
        for (int i = 0; i < 6; i++) {
          final angle = i * math.pi / 3 - math.pi / 6;
          final hx = center.dx + r * 1.05 * math.cos(angle);
          final hy = center.dy + r * 1.05 * math.sin(angle);
          if (i == 0) {
            hexPath.moveTo(hx, hy);
          } else {
            hexPath.lineTo(hx, hy);
          }
        }
        hexPath.close();
        canvas.drawPath(hexPath, Paint()..shader = bodyGrad);
        // Metallic edge
        canvas.drawPath(hexPath, Paint()
          ..color = _lighten(primary, 0.3).withAlpha(100)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
        );
        // Armor plate shine
        canvas.drawCircle(
          Offset(center.dx - r * 0.3, center.dy - r * 0.3),
          r * 0.25,
          Paint()..color = const Color(0x33FFFFFF),
        );
        break;

      case EnemyType.shieldBearer:
        // Squared shield shape
        final shieldRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: r * 2.1, height: r * 2.1),
          Radius.circular(r * 0.2),
        );
        canvas.drawRRect(shieldRect, Paint()..shader = bodyGrad);
        // Shield border highlight
        canvas.drawRRect(shieldRect, Paint()
          ..color = _lighten(primary, 0.35).withAlpha(90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
        );
        // Shield emboss
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: r * 1.4, height: r * 1.4),
            Radius.circular(r * 0.15),
          ),
          Paint()
            ..color = _lighten(primary, 0.15).withAlpha(50)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
        break;

      case EnemyType.cavalry:
        // Teardrop / forward-leaning shape
        final cavPath = Path()
          ..moveTo(center.dx + r * 0.9, center.dy)
          ..quadraticBezierTo(center.dx + r * 0.3, center.dy - r * 1.0, center.dx - r * 0.5, center.dy - r * 0.6)
          ..quadraticBezierTo(center.dx - r * 1.1, center.dy, center.dx - r * 0.5, center.dy + r * 0.6)
          ..quadraticBezierTo(center.dx + r * 0.3, center.dy + r * 1.0, center.dx + r * 0.9, center.dy)
          ..close();
        canvas.drawPath(cavPath, Paint()..shader = bodyGrad);
        canvas.drawPath(cavPath, Paint()
          ..color = _lighten(primary, 0.2).withAlpha(70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
        );
        break;

      case EnemyType.goblin:
        // Smaller triangular imp shape
        final gobPath = Path()
          ..moveTo(center.dx, center.dy - r * 1.0)
          ..quadraticBezierTo(center.dx + r * 1.0, center.dy - r * 0.2, center.dx + r * 0.7, center.dy + r * 0.8)
          ..lineTo(center.dx - r * 0.7, center.dy + r * 0.8)
          ..quadraticBezierTo(center.dx - r * 1.0, center.dy - r * 0.2, center.dx, center.dy - r * 1.0)
          ..close();
        canvas.drawPath(gobPath, Paint()..shader = bodyGrad);
        canvas.drawPath(gobPath, Paint()
          ..color = _lighten(primary, 0.2).withAlpha(60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
        );
        break;

      case EnemyType.troll:
        // Large, bulky oval
        canvas.drawOval(
          Rect.fromCenter(center: center, width: r * 2.2, height: r * 2.4),
          Paint()..shader = bodyGrad,
        );
        canvas.drawOval(
          Rect.fromCenter(center: center, width: r * 2.2, height: r * 2.4),
          Paint()
            ..color = _darken(primary, 0.2).withAlpha(60)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
        break;

      case EnemyType.darkKnight:
        // Diamond/rhombus shape
        final dkPath = Path()
          ..moveTo(center.dx, center.dy - r * 1.1)
          ..lineTo(center.dx + r * 0.9, center.dy)
          ..lineTo(center.dx, center.dy + r * 1.1)
          ..lineTo(center.dx - r * 0.9, center.dy)
          ..close();
        canvas.drawPath(dkPath, Paint()..shader = bodyGrad);
        canvas.drawPath(dkPath, Paint()
          ..color = const Color(0x44FF44FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
        );
        break;

      case EnemyType.undead:
        // Irregular, slightly rounded
        canvas.drawCircle(center, r * 0.95, Paint()..shader = bodyGrad);
        // Ghostly overlay
        canvas.drawCircle(center, r * 0.95, Paint()..color = const Color(0x15FFFFFF));
        // Tattered edges
        for (int i = 0; i < 6; i++) {
          final angle = i * math.pi / 3 + _animTimer * 0.2;
          final ex = center.dx + r * 0.95 * math.cos(angle);
          final ey = center.dy + r * 0.95 * math.sin(angle);
          canvas.drawCircle(Offset(ex, ey), r * 0.15, Paint()..color = primary.withAlpha(60));
        }
        break;

      default:
        // Standard circle (soldier, healer, burrower)
        canvas.drawCircle(center, r, Paint()..shader = bodyGrad);
        // Rim light
        canvas.drawCircle(center, r, Paint()
          ..color = _lighten(primary, 0.2).withAlpha(50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
        );
        break;
    }
  }

  void _drawBossBody(Canvas canvas, Offset center, double r, Color primary) {
    final bigR = r * 1.35;
    final pulse = (math.sin(_animTimer * 2.5) * 0.5 + 0.5);

    // Pulsing outer aura
    final auraR1 = bigR * (1.5 + pulse * 0.15);
    final auraR2 = bigR * (1.3 + pulse * 0.1);
    canvas.drawCircle(center, auraR1, Paint()..color = Color.fromARGB((15 + pulse * 10).round(), primary.red, primary.green, primary.blue));
    canvas.drawCircle(center, auraR2, Paint()..color = Color.fromARGB((25 + pulse * 15).round(), primary.red, primary.green, primary.blue));

    // Boss-specific visual effects
    if (type == EnemyType.dragonEmperor) {
      // Fire particles orbiting
      for (int i = 0; i < 8; i++) {
        final angle = i * math.pi / 4 + _animTimer * 1.5;
        final dist = bigR * (1.2 + math.sin(_animTimer * 3 + i) * 0.15);
        final px = center.dx + dist * math.cos(angle);
        final py = center.dy + dist * math.sin(angle);
        final particleSize = 2.0 + math.sin(_animTimer * 4 + i) * 0.8;
        canvas.drawCircle(Offset(px, py), particleSize, Paint()..color = Color.fromARGB((180 + (pulse * 60).round()).clamp(0, 255), 255, math.Random(i).nextInt(100) + 80, 0));
      }
      // Inner fire glow
      canvas.drawCircle(center, bigR * 0.4, Paint()..color = Color.fromARGB((20 + pulse * 15).round(), 255, 100, 0));
    } else if (type == EnemyType.shadowLord) {
      // Shadow tendrils
      for (int i = 0; i < 6; i++) {
        final angle = i * math.pi / 3 + _animTimer * 0.5;
        final tendrilLen = bigR * (1.0 + math.sin(_animTimer * 2 + i) * 0.3);
        final tendrilPath = Path()
          ..moveTo(center.dx, center.dy)
          ..quadraticBezierTo(
            center.dx + tendrilLen * 0.6 * math.cos(angle + 0.3),
            center.dy + tendrilLen * 0.6 * math.sin(angle + 0.3),
            center.dx + tendrilLen * math.cos(angle),
            center.dy + tendrilLen * math.sin(angle),
          );
        canvas.drawPath(tendrilPath, Paint()
          ..color = Color.fromARGB((40 + pulse * 30).round(), 80, 0, 120)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
        );
      }
      // Dark mist
      canvas.drawCircle(center, bigR * 1.1, Paint()..color = Color.fromARGB((18 + pulse * 12).round(), 50, 0, 80));
    }

    // Main body gradient (3D)
    final bodyGrad = ui.Gradient.linear(
      Offset(center.dx - bigR * 0.6, center.dy - bigR * 0.5),
      Offset(center.dx + bigR * 0.6, center.dy + bigR * 0.5),
      [_lighten(primary, 0.35), _lighten(primary, 0.1), primary, _darken(primary, 0.3), _darken(primary, 0.5)],
      [0.0, 0.2, 0.45, 0.75, 1.0],
    );
    canvas.drawCircle(center, bigR, Paint()..shader = bodyGrad);

    // Boss border (pulsing)
    canvas.drawCircle(center, bigR, Paint()
      ..color = Color.fromARGB((120 + pulse * 60).round(), 255, 215, 0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8,
    );
    // Second glow ring
    canvas.drawCircle(center, bigR + 2, Paint()
      ..color = Color.fromARGB((30 + pulse * 20).round(), 255, 215, 0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
    );

    // Crown (more detailed)
    final crownPaint = Paint()..color = const Color(0xEEFFD700);
    final crownY = center.dy - bigR * 0.72;
    final crownW = bigR * 0.65;
    final crownH = bigR * 0.4;
    final crown = Path()
      ..moveTo(center.dx - crownW, crownY + crownH)
      ..lineTo(center.dx - crownW, crownY)
      ..lineTo(center.dx - crownW * 0.5, crownY + crownH * 0.4)
      ..lineTo(center.dx - crownW * 0.2, crownY - crownH * 0.15)
      ..lineTo(center.dx, crownY + crownH * 0.3)
      ..lineTo(center.dx + crownW * 0.2, crownY - crownH * 0.15)
      ..lineTo(center.dx + crownW * 0.5, crownY + crownH * 0.4)
      ..lineTo(center.dx + crownW, crownY)
      ..lineTo(center.dx + crownW, crownY + crownH)
      ..close();
    canvas.drawPath(crown, crownPaint);
    // Crown outline
    canvas.drawPath(crown, Paint()
      ..color = const Color(0xAACC9900)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8,
    );
    // Crown jewels (bigger, more vivid)
    canvas.drawCircle(Offset(center.dx, crownY + crownH * 0.1), 2.0, Paint()..color = const Color(0xFFFF1111));
    canvas.drawCircle(Offset(center.dx, crownY + crownH * 0.1), 1.0, Paint()..color = const Color(0x88FFFFFF));
    canvas.drawCircle(Offset(center.dx - crownW * 0.5, crownY + crownH * 0.25), 1.5, Paint()..color = const Color(0xFF2288FF));
    canvas.drawCircle(Offset(center.dx + crownW * 0.5, crownY + crownH * 0.25), 1.5, Paint()..color = const Color(0xFF2288FF));
    // Crown tips sparkle
    for (final tipX in [center.dx - crownW, center.dx - crownW * 0.2, center.dx + crownW * 0.2, center.dx + crownW]) {
      canvas.drawCircle(Offset(tipX, crownY - crownH * 0.1), 1.0, Paint()..color = Color.fromARGB((150 + pulse * 80).round().clamp(0, 255), 255, 255, 200));
    }
  }

  void _drawTypeIcon(Canvas canvas, Offset center, double r, Color primary) {
    final iconPaint = Paint()..color = const Color(0xDDFFFFFF);
    final ir = r * 0.55; // larger icon area

    switch (type) {
      case EnemyType.soldier:
        // Sword (thicker)
        canvas.drawLine(
          Offset(center.dx - ir * 0.7, center.dy + ir * 0.7),
          Offset(center.dx + ir * 0.7, center.dy - ir * 0.7),
          iconPaint..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round,
        );
        // Cross guard
        canvas.drawLine(
          Offset(center.dx - ir * 0.3, center.dy - ir * 0.3),
          Offset(center.dx + ir * 0.3, center.dy + ir * 0.3),
          iconPaint..strokeWidth = 2.0,
        );
        // Pommel
        canvas.drawCircle(
          Offset(center.dx - ir * 0.6, center.dy + ir * 0.6),
          ir * 0.12,
          Paint()..color = const Color(0xCCFFDD44),
        );
        break;
      case EnemyType.cavalry:
        // Speed lines (thicker, more dynamic)
        for (int i = 0; i < 3; i++) {
          final y = center.dy - ir * 0.5 + i * ir * 0.5;
          final len = ir * (1.2 - i * 0.15);
          canvas.drawLine(
            Offset(center.dx - len, y),
            Offset(center.dx + ir * 0.6, y),
            iconPaint..strokeWidth = 2.0..strokeCap = StrokeCap.round,
          );
        }
        // Arrowhead
        canvas.drawLine(Offset(center.dx + ir * 0.3, center.dy - ir * 0.35), Offset(center.dx + ir * 0.7, center.dy), iconPaint..strokeWidth = 2.0);
        canvas.drawLine(Offset(center.dx + ir * 0.3, center.dy + ir * 0.35), Offset(center.dx + ir * 0.7, center.dy), iconPaint..strokeWidth = 2.0);
        break;
      case EnemyType.goblin:
        // Pointy ears (thicker)
        canvas.drawLine(Offset(center.dx - ir * 0.6, center.dy - ir * 0.9), Offset(center.dx - ir * 0.2, center.dy + ir * 0.1),
          Paint()..color = _darken(primary, 0.1)..strokeWidth = 2.5..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(center.dx + ir * 0.6, center.dy - ir * 0.9), Offset(center.dx + ir * 0.2, center.dy + ir * 0.1),
          Paint()..color = _darken(primary, 0.1)..strokeWidth = 2.5..strokeCap = StrokeCap.round);
        // Yellow eyes (brighter)
        canvas.drawCircle(Offset(center.dx - ir * 0.25, center.dy), 1.8, Paint()..color = const Color(0xFFFFEE00));
        canvas.drawCircle(Offset(center.dx + ir * 0.25, center.dy), 1.8, Paint()..color = const Color(0xFFFFEE00));
        // Pupil slits
        canvas.drawLine(
          Offset(center.dx - ir * 0.25, center.dy - 1.2),
          Offset(center.dx - ir * 0.25, center.dy + 1.2),
          Paint()..color = const Color(0xFF000000)..strokeWidth = 0.8,
        );
        canvas.drawLine(
          Offset(center.dx + ir * 0.25, center.dy - 1.2),
          Offset(center.dx + ir * 0.25, center.dy + 1.2),
          Paint()..color = const Color(0xFF000000)..strokeWidth = 0.8,
        );
        // Sinister grin
        final grinPath = Path()
          ..moveTo(center.dx - ir * 0.3, center.dy + ir * 0.3)
          ..quadraticBezierTo(center.dx, center.dy + ir * 0.6, center.dx + ir * 0.3, center.dy + ir * 0.3);
        canvas.drawPath(grinPath, Paint()..color = const Color(0xCCFF0000)..style = PaintingStyle.stroke..strokeWidth = 1.2);
        break;
      case EnemyType.armoredGiant:
        // Bold shield cross
        canvas.drawLine(Offset(center.dx - ir * 0.6, center.dy), Offset(center.dx + ir * 0.6, center.dy), iconPaint..strokeWidth = 2.5);
        canvas.drawLine(Offset(center.dx, center.dy - ir * 0.6), Offset(center.dx, center.dy + ir * 0.6), iconPaint..strokeWidth = 2.5);
        // Corner rivets
        for (final offset in [Offset(-ir * 0.4, -ir * 0.4), Offset(ir * 0.4, -ir * 0.4), Offset(-ir * 0.4, ir * 0.4), Offset(ir * 0.4, ir * 0.4)]) {
          canvas.drawCircle(Offset(center.dx + offset.dx, center.dy + offset.dy), 1.5, Paint()..color = const Color(0xCCDDDDDD));
        }
        break;
      case EnemyType.undead:
        // Glowing skull eyes (brighter)
        canvas.drawCircle(Offset(center.dx - ir * 0.28, center.dy - ir * 0.15), ir * 0.22, Paint()..color = const Color(0xEE44FF44));
        canvas.drawCircle(Offset(center.dx + ir * 0.28, center.dy - ir * 0.15), ir * 0.22, Paint()..color = const Color(0xEE44FF44));
        // Glow halo around eyes
        canvas.drawCircle(Offset(center.dx - ir * 0.28, center.dy - ir * 0.15), ir * 0.32, Paint()..color = const Color(0x2200FF00));
        canvas.drawCircle(Offset(center.dx + ir * 0.28, center.dy - ir * 0.15), ir * 0.32, Paint()..color = const Color(0x2200FF00));
        // Jaw
        canvas.drawLine(
          Offset(center.dx - ir * 0.2, center.dy + ir * 0.25),
          Offset(center.dx + ir * 0.2, center.dy + ir * 0.25),
          Paint()..color = const Color(0xAA99AABB)..strokeWidth = 1.5,
        );
        break;
      case EnemyType.shieldBearer:
        // Bold shield outline with inner detail
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: ir * 1.3, height: ir * 1.5),
            Radius.circular(ir * 0.2),
          ),
          iconPaint..style = PaintingStyle.stroke..strokeWidth = 2.0,
        );
        // Inner chevron
        canvas.drawLine(Offset(center.dx - ir * 0.3, center.dy - ir * 0.1), Offset(center.dx, center.dy + ir * 0.3), iconPaint..strokeWidth = 1.5);
        canvas.drawLine(Offset(center.dx + ir * 0.3, center.dy - ir * 0.1), Offset(center.dx, center.dy + ir * 0.3), iconPaint..strokeWidth = 1.5);
        break;
      case EnemyType.healer:
        // Golden cross (brighter, thicker)
        final crossPaint = Paint()..color = const Color(0xFFFFCC00);
        canvas.drawRect(Rect.fromCenter(center: center, width: ir * 0.5, height: ir * 1.3), crossPaint);
        canvas.drawRect(Rect.fromCenter(center: center, width: ir * 1.3, height: ir * 0.5), crossPaint);
        // White glow
        canvas.drawCircle(center, ir * 0.65, Paint()..color = const Color(0x22FFFFFF));
        break;
      case EnemyType.burrower:
        // Drill tip (thicker, more defined)
        canvas.drawLine(Offset(center.dx, center.dy - ir * 0.7), Offset(center.dx, center.dy + ir * 0.7),
          iconPaint..strokeWidth = 2.5..strokeCap = StrokeCap.round);
        // Drill spiral
        canvas.drawLine(Offset(center.dx - ir * 0.45, center.dy + ir * 0.15), Offset(center.dx + ir * 0.45, center.dy + ir * 0.15),
          iconPaint..strokeWidth = 2.0);
        canvas.drawLine(Offset(center.dx - ir * 0.3, center.dy - ir * 0.2), Offset(center.dx + ir * 0.3, center.dy - ir * 0.2),
          iconPaint..strokeWidth = 1.5);
        // Drill point
        canvas.drawCircle(Offset(center.dx, center.dy - ir * 0.6), ir * 0.12, Paint()..color = const Color(0xCCFFDD88));
        break;
      case EnemyType.troll:
        // Red eyes
        canvas.drawCircle(Offset(center.dx - ir * 0.3, center.dy - ir * 0.15), ir * 0.18, Paint()..color = const Color(0xEEFF2200));
        canvas.drawCircle(Offset(center.dx + ir * 0.3, center.dy - ir * 0.15), ir * 0.18, Paint()..color = const Color(0xEEFF2200));
        // Regen X (brighter, thicker)
        canvas.drawLine(Offset(center.dx - ir * 0.45, center.dy + ir * 0.1), Offset(center.dx + ir * 0.45, center.dy + ir * 0.55),
          Paint()..color = const Color(0xCC44FF44)..strokeWidth = 2.5..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(center.dx + ir * 0.45, center.dy + ir * 0.1), Offset(center.dx - ir * 0.45, center.dy + ir * 0.55),
          Paint()..color = const Color(0xCC44FF44)..strokeWidth = 2.5..strokeCap = StrokeCap.round);
        break;
      case EnemyType.darkKnight:
        // Purple aura glow (pulsing)
        final dkPulse = (math.sin(_animTimer * 3.0) * 0.5 + 0.5);
        canvas.drawCircle(center, ir * 0.75, Paint()..color = Color.fromARGB((50 + dkPulse * 40).round(), 200, 0, 255));
        canvas.drawCircle(center, ir * 0.45, Paint()..color = Color.fromARGB((70 + dkPulse * 50).round(), 180, 0, 220));
        // Dark star
        for (int i = 0; i < 4; i++) {
          final angle = i * math.pi / 2 + _animTimer * 0.4;
          canvas.drawLine(
            Offset(center.dx, center.dy),
            Offset(center.dx + ir * 0.6 * math.cos(angle), center.dy + ir * 0.6 * math.sin(angle)),
            Paint()..color = const Color(0xAACC44FF)..strokeWidth = 1.5..strokeCap = StrokeCap.round,
          );
        }
        break;
      case EnemyType.shadowLord:
        // Menacing eye
        canvas.drawOval(
          Rect.fromCenter(center: center, width: ir * 1.0, height: ir * 0.5),
          Paint()..color = const Color(0xEEFF0044),
        );
        canvas.drawCircle(center, ir * 0.15, Paint()..color = const Color(0xFF000000));
        // Eye glow
        canvas.drawOval(
          Rect.fromCenter(center: center, width: ir * 1.3, height: ir * 0.7),
          Paint()..color = const Color(0x33FF0044)..style = PaintingStyle.stroke..strokeWidth = 2,
        );
        break;
      case EnemyType.dragonEmperor:
        // Dragon eye (slit pupil)
        canvas.drawOval(
          Rect.fromCenter(center: center, width: ir * 1.0, height: ir * 0.6),
          Paint()..color = const Color(0xEEFFCC00),
        );
        // Slit pupil
        canvas.drawLine(
          Offset(center.dx, center.dy - ir * 0.25),
          Offset(center.dx, center.dy + ir * 0.25),
          Paint()..color = const Color(0xFF000000)..strokeWidth = 1.8,
        );
        // Fire wisps around
        for (int i = 0; i < 3; i++) {
          final angle = _animTimer * 2 + i * math.pi * 2 / 3;
          final fx = center.dx + ir * 0.7 * math.cos(angle);
          final fy = center.dy + ir * 0.7 * math.sin(angle);
          canvas.drawCircle(Offset(fx, fy), 1.5, Paint()..color = const Color(0xCCFF6600));
        }
        break;
    }
  }

  static Color _lighten(Color c, double amount) {
    return Color.fromARGB(c.alpha,
      (c.red + (255 - c.red) * amount).round().clamp(0, 255),
      (c.green + (255 - c.green) * amount).round().clamp(0, 255),
      (c.blue + (255 - c.blue) * amount).round().clamp(0, 255));
  }

  static Color _darken(Color c, double amount) {
    return Color.fromARGB(c.alpha,
      (c.red * (1 - amount)).round().clamp(0, 255),
      (c.green * (1 - amount)).round().clamp(0, 255),
      (c.blue * (1 - amount)).round().clamp(0, 255));
  }

  Vector2 _gridToWorld(GridPos pos) => Vector2((pos.col + 0.5) * cellSize, (pos.row + 0.5) * cellSize);

  static Color _enemyColor(EnemyType type) {
    switch (type) {
      case EnemyType.soldier: return const Color(0xFFEE3333);       // brighter red
      case EnemyType.cavalry: return const Color(0xFFFF7711);       // vivid orange
      case EnemyType.goblin: return const Color(0xFF44DD22);        // bright toxic green
      case EnemyType.armoredGiant: return const Color(0xFFAABBCC);  // shiny metallic silver
      case EnemyType.undead: return const Color(0xFF7799AA);        // ghostly blue-gray
      case EnemyType.shieldBearer: return const Color(0xFF4488CC);  // steel blue
      case EnemyType.healer: return const Color(0xFFEEEEEE);        // bright white
      case EnemyType.burrower: return const Color(0xFFCC8833);      // earthy amber
      case EnemyType.troll: return const Color(0xFF228833);         // forest green
      case EnemyType.darkKnight: return const Color(0xFF6633AA);    // deep purple
      case EnemyType.shadowLord: return const Color(0xFF440066);    // black/dark purple
      case EnemyType.dragonEmperor: return const Color(0xFFDD3300); // crimson/gold
    }
  }
}
