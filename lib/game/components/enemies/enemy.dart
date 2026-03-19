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

  double get currentSpeed {
    double speed = baseStats.speed;
    for (final e in _effects) {
      if (e.type == StatusType.slow) speed *= (1 - e.slowFactor);
    }
    return speed.clamp(0.1, 10.0);
  }

  int get currentArmor {
    double armor = baseStats.armor.toDouble();
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

  Vector2 _gridToWorld(GridPos pos) =>
    Vector2((pos.col + 0.5) * cellSize, (pos.row + 0.5) * cellSize);

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
