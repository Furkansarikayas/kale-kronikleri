import 'dart:math' as math;
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

  double artifactDamageMultiplier = 1.0;
  double artifactRangeMultiplier = 1.0;
  double artifactFireRateMultiplier = 1.0;
  double supportDamageMultiplier = 1.0;
  double supportRangeMultiplier = 1.0;
  bool showRange = false;

  Tower({
    required this.type,
    required this.col,
    required this.row,
    required this.cellSize,
  }) : super(
    // Landscape: x = col (horizontal), y = row (vertical)
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

  int get currentDamage => (stats.damageAtTier(_tier) * _synergyDamageMultiplier * artifactDamageMultiplier * supportDamageMultiplier).round();
  double get currentRange => (stats.rangeAtTier(_tier) + _synergyRangeBonus) * artifactRangeMultiplier * supportRangeMultiplier;
  double get currentFireRate => stats.fireRate * _synergyFireRateMultiplier * artifactFireRateMultiplier;

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

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(size.x / 2, size.y / 2);

    // Draw type-specific icon
    _drawTowerIcon(canvas, center);

    // Draw range circle when selected
    if (showRange && currentRange > 0) {
      final rangePixels = currentRange * cellSize;
      canvas.drawCircle(
        center, rangePixels,
        Paint()
          ..color = const Color(0x22FFFFFF)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center, rangePixels,
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Draw tier indicator dots
    if (_tier > 1) {
      for (int i = 0; i < _tier; i++) {
        canvas.drawCircle(
          Offset(size.x * 0.2 + i * 6, size.y - 4),
          2,
          Paint()..color = const Color(0xFFFFD700),
        );
      }
    }
  }

  void _drawTowerIcon(Canvas canvas, Offset center) {
    final iconPaint = Paint()..color = const Color(0x88FFFFFF);
    final r = size.x * 0.2;

    switch (type) {
      case TowerType.arrow:
        // Draw arrow pointing up-right
        final path = Path()
          ..moveTo(center.dx - r, center.dy + r)
          ..lineTo(center.dx + r, center.dy - r)
          ..lineTo(center.dx + r, center.dy - r * 0.3)
          ..lineTo(center.dx + r * 0.3, center.dy - r);
        canvas.drawPath(path, iconPaint..style = PaintingStyle.stroke..strokeWidth = 2);
        break;
      case TowerType.ice:
        // Snowflake: * shape
        for (int i = 0; i < 3; i++) {
          final angle = i * 3.14159 / 3;
          canvas.drawLine(
            Offset(center.dx - r * 0.8 * _cos(angle), center.dy - r * 0.8 * _sin(angle)),
            Offset(center.dx + r * 0.8 * _cos(angle), center.dy + r * 0.8 * _sin(angle)),
            iconPaint..style = PaintingStyle.stroke..strokeWidth = 1.5,
          );
        }
        break;
      case TowerType.fire:
        // Flame shape
        final path = Path()
          ..moveTo(center.dx, center.dy - r)
          ..quadraticBezierTo(center.dx + r, center.dy - r * 0.3, center.dx + r * 0.5, center.dy + r)
          ..quadraticBezierTo(center.dx, center.dy + r * 0.3, center.dx - r * 0.5, center.dy + r)
          ..quadraticBezierTo(center.dx - r, center.dy - r * 0.3, center.dx, center.dy - r);
        canvas.drawPath(path, iconPaint..style = PaintingStyle.fill);
        break;
      case TowerType.lightning:
        // Lightning bolt
        final path = Path()
          ..moveTo(center.dx + r * 0.2, center.dy - r)
          ..lineTo(center.dx - r * 0.3, center.dy)
          ..lineTo(center.dx + r * 0.1, center.dy)
          ..lineTo(center.dx - r * 0.2, center.dy + r);
        canvas.drawPath(path, iconPaint..style = PaintingStyle.stroke..strokeWidth = 2);
        break;
      case TowerType.cannon:
        // Circle (cannonball)
        canvas.drawCircle(center, r * 0.6, iconPaint..style = PaintingStyle.fill);
        break;
      case TowerType.spikeWall:
        // Spikes
        for (int i = 0; i < 3; i++) {
          final x = center.dx - r + i * r;
          canvas.drawLine(Offset(x, center.dy + r * 0.5), Offset(x, center.dy - r * 0.5), iconPaint..style = PaintingStyle.stroke..strokeWidth = 2);
        }
        break;
      case TowerType.support:
        // Shield with plus sign (buff aura)
        canvas.drawCircle(center, r * 0.7, iconPaint..style = PaintingStyle.stroke..strokeWidth = 1.5);
        canvas.drawLine(Offset(center.dx, center.dy - r * 0.4), Offset(center.dx, center.dy + r * 0.4), iconPaint..strokeWidth = 2);
        canvas.drawLine(Offset(center.dx - r * 0.4, center.dy), Offset(center.dx + r * 0.4, center.dy), iconPaint..strokeWidth = 2);
        break;
      case TowerType.wizard:
        // Star shape
        for (int i = 0; i < 4; i++) {
          final angle = i * 3.14159 / 4 + 3.14159 / 8;
          canvas.drawLine(
            Offset(center.dx - r * 0.6 * _cos(angle), center.dy - r * 0.6 * _sin(angle)),
            Offset(center.dx + r * 0.6 * _cos(angle), center.dy + r * 0.6 * _sin(angle)),
            iconPaint..style = PaintingStyle.stroke..strokeWidth = 1.5,
          );
        }
        break;
      case TowerType.poison:
        // Skull-like circle with dots
        canvas.drawCircle(center, r * 0.5, iconPaint..style = PaintingStyle.stroke..strokeWidth = 1.5);
        canvas.drawCircle(Offset(center.dx - r * 0.2, center.dy - r * 0.1), r * 0.1, iconPaint..style = PaintingStyle.fill);
        canvas.drawCircle(Offset(center.dx + r * 0.2, center.dy - r * 0.1), r * 0.1, iconPaint..style = PaintingStyle.fill);
        break;
      case TowerType.water:
        // Water drop shape
        final path = Path()
          ..moveTo(center.dx, center.dy - r * 0.8)
          ..quadraticBezierTo(center.dx + r * 0.7, center.dy + r * 0.2, center.dx, center.dy + r * 0.7)
          ..quadraticBezierTo(center.dx - r * 0.7, center.dy + r * 0.2, center.dx, center.dy - r * 0.8);
        canvas.drawPath(path, iconPaint..style = PaintingStyle.fill);
        break;
      case TowerType.dark:
        // Crescent moon
        canvas.drawCircle(center, r * 0.5, iconPaint..style = PaintingStyle.fill);
        canvas.drawCircle(Offset(center.dx + r * 0.2, center.dy - r * 0.1), r * 0.4, Paint()..color = _towerColor(TowerType.dark));
        break;
      case TowerType.holy:
        // Sun rays
        canvas.drawCircle(center, r * 0.3, iconPaint..style = PaintingStyle.fill);
        for (int i = 0; i < 8; i++) {
          final angle = i * 3.14159 / 4;
          canvas.drawLine(
            Offset(center.dx + r * 0.4 * _cos(angle), center.dy + r * 0.4 * _sin(angle)),
            Offset(center.dx + r * 0.7 * _cos(angle), center.dy + r * 0.7 * _sin(angle)),
            iconPaint..style = PaintingStyle.stroke..strokeWidth = 1,
          );
        }
        break;
    }
  }

  static double _cos(double a) => math.cos(a);
  static double _sin(double a) => math.sin(a);

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
