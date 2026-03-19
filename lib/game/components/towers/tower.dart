import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/tower_data.dart';
import '../../data/game_config.dart';
import 'projectile.dart';

class Tower extends RectangleComponent {
  final TowerType type;
  int _tier = 1;
  int _totalSpent = 0;
  double _cooldown = 0;
  double _synergyDamageMultiplier = 1.0;
  double _synergyRangeBonus = 0.0;
  double _synergyFireRateMultiplier = 1.0;
  final int col;
  final int row;
  final double cellSize;

  Tower({
    required this.type,
    required this.col,
    required this.row,
    required this.cellSize,
  }) : super(
    position: Vector2(col * cellSize, row * cellSize),
    size: Vector2.all(cellSize),
    paint: Paint()..color = _towerColor(type),
    anchor: Anchor.topLeft,
  ) {
    _totalSpent = stats.cost;
  }

  TowerStats get stats => TowerData.getStats(type);
  int get tier => _tier;
  int get totalSpent => _totalSpent;

  int get currentDamage => (stats.damageAtTier(_tier) * _synergyDamageMultiplier).round();
  double get currentRange => stats.rangeAtTier(_tier) + _synergyRangeBonus;
  double get currentFireRate => stats.fireRate * _synergyFireRateMultiplier;

  int get sellValue => (totalSpent * GameConfig.sellRefundRatio).round();

  bool get canUpgrade => _tier < 4;
  int get upgradeCost => stats.upgradeCost(_tier + 1);

  bool upgrade() {
    if (!canUpgrade) return false;
    final cost = upgradeCost;
    _tier++;
    _totalSpent += cost;
    return true;
  }

  void applySynergyBonus({double damageMultiplier = 1.0, double rangeBonus = 0.0, double fireRateMultiplier = 1.0}) {
    _synergyDamageMultiplier = damageMultiplier;
    _synergyRangeBonus = rangeBonus;
    _synergyFireRateMultiplier = fireRateMultiplier;
  }

  void clearSynergyBonus() {
    _synergyDamageMultiplier = 1.0;
    _synergyRangeBonus = 0.0;
    _synergyFireRateMultiplier = 1.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_cooldown > 0) _cooldown -= dt;
  }

  bool canFire() => _cooldown <= 0 && type != TowerType.spikeWall && type != TowerType.support;

  Projectile? tryFire(Vector2 targetPos) {
    if (!canFire()) return null;
    _cooldown = currentFireRate;
    return Projectile(
      startPos: position + size / 2,
      target: targetPos,
      damage: currentDamage,
      color: _towerColor(type),
    );
  }

  bool isInRange(Vector2 targetPos) {
    final center = position + size / 2;
    final dist = center.distanceTo(targetPos);
    return dist <= currentRange * cellSize;
  }

  static Color _towerColor(TowerType type) {
    switch (type) {
      case TowerType.arrow: return const Color(0xFF8B7355);
      case TowerType.ice: return const Color(0xFF87CEEB);
      case TowerType.fire: return const Color(0xFFFF4500);
      case TowerType.lightning: return const Color(0xFFFFD700);
      case TowerType.poison: return const Color(0xFF00FF00);
      case TowerType.cannon: return const Color(0xFF8B4513);
      case TowerType.spikeWall: return const Color(0xFF696969);
      case TowerType.support: return const Color(0xFFFFFF00);
      case TowerType.water: return const Color(0xFF4169E1);
      case TowerType.wizard: return const Color(0xFF9400D3);
      case TowerType.dark: return const Color(0xFF2F0040);
      case TowerType.holy: return const Color(0xFFFFFACD);
    }
  }
}
