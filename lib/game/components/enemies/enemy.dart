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

  Enemy({
    required this.type,
    required this.baseStats,
    required this.path,
    required this.cellSize,
  }) : _hp = baseStats.hp,
    super(
      size: Vector2.all(cellSize * 0.7),
      paint: Paint()..color = _enemyColor(type),
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
    // Replace existing effect of same type if new one is stronger
    _effects.removeWhere((e) => e.type == effect.type);
    _effects.add(effect);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDead || _reachedCastle) return;

    // Update status effects
    for (final effect in _effects) {
      final tickDamage = effect.update(dt);
      if (tickDamage > 0) takeDamage(tickDamage, bypassArmor: true);
    }
    _effects.removeWhere((e) => e.isExpired);

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

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_isDead || _reachedCastle) return;

    // Draw type-specific decoration on top of the base rectangle
    final center = Offset(size.x / 2, size.y / 2);
    final innerPaint = Paint()..color = const Color(0x44000000);

    if (baseStats.isBoss) {
      // Boss: draw crown
      final crownPaint = Paint()..color = const Color(0xFFFFD700);
      final crownY = size.y * 0.15;
      final crownH = size.y * 0.25;
      final points = [
        Offset(size.x * 0.15, crownY + crownH),
        Offset(size.x * 0.15, crownY),
        Offset(size.x * 0.3, crownY + crownH * 0.5),
        Offset(size.x * 0.5, crownY),
        Offset(size.x * 0.7, crownY + crownH * 0.5),
        Offset(size.x * 0.85, crownY),
        Offset(size.x * 0.85, crownY + crownH),
      ];
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, crownPaint);
    } else if (baseStats.armor > 0) {
      // Armored: draw shield outline
      canvas.drawCircle(center, size.x * 0.25, Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    } else if (type == EnemyType.healer) {
      // Healer: draw cross
      final crossPaint = Paint()..color = const Color(0xFFFF0000);
      canvas.drawRect(Rect.fromCenter(center: center, width: size.x * 0.15, height: size.y * 0.5), crossPaint);
      canvas.drawRect(Rect.fromCenter(center: center, width: size.x * 0.5, height: size.y * 0.15), crossPaint);
    }

    // Draw HP bar above enemy
    final barWidth = size.x;
    final barHeight = 3.0;
    final barY = -6.0;
    final hpRatio = _hp / maxHp;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, barY, barWidth, barHeight),
      Paint()..color = const Color(0x88000000),
    );
    // HP fill
    final barColor = hpRatio > 0.5
        ? Color.lerp(const Color(0xFFFFFF00), const Color(0xFF00FF00), (hpRatio - 0.5) * 2)!
        : Color.lerp(const Color(0xFFFF0000), const Color(0xFFFFFF00), hpRatio * 2)!;
    canvas.drawRect(
      Rect.fromLTWH(0, barY, barWidth * hpRatio, barHeight),
      Paint()..color = barColor,
    );

    // Status effect indicators
    double indicatorX = 0;
    for (final effect in _effects) {
      if (effect.isExpired) continue;
      Color dotColor;
      switch (effect.type) {
        case StatusType.burn: dotColor = const Color(0xFFFF4500); break;
        case StatusType.poison: dotColor = const Color(0xFF00FF00); break;
        case StatusType.slow: dotColor = const Color(0xFF87CEEB); break;
        case StatusType.wet: dotColor = const Color(0xFF4169E1); break;
        case StatusType.curse: dotColor = const Color(0xFF660066); break;
      }
      canvas.drawCircle(Offset(indicatorX + 2, barY - 3), 2, Paint()..color = dotColor);
      indicatorX += 5;
    }
  }

  // Landscape: x = col (horizontal), y = row (vertical)
  Vector2 _gridToWorld(GridPos pos) => Vector2((pos.col + 0.5) * cellSize, (pos.row + 0.5) * cellSize);

  static Color _enemyColor(EnemyType type) {
    switch (type) {
      case EnemyType.soldier: return const Color(0xFFCC3333);
      case EnemyType.cavalry: return const Color(0xFFFF6600);
      case EnemyType.goblin: return const Color(0xFF33CC33);
      case EnemyType.armoredGiant: return const Color(0xFF999999);
      case EnemyType.undead: return const Color(0xFF666688);
      case EnemyType.shieldBearer: return const Color(0xFF4488CC);
      case EnemyType.healer: return const Color(0xFFFFFFFF);
      case EnemyType.burrower: return const Color(0xFF886633);
      case EnemyType.troll: return const Color(0xFF338833);
      case EnemyType.darkKnight: return const Color(0xFF330033);
      case EnemyType.shadowLord: return const Color(0xFF220022);
      case EnemyType.dragonEmperor: return const Color(0xFFFF0000);
    }
  }
}
