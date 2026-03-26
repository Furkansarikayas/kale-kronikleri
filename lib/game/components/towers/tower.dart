import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/tower_data.dart';
import '../../data/game_config.dart';
import '../rendering/tower_sprites.dart';
import 'projectile.dart';

enum TargetingMode { nearest, first, strongest }

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
  double kaleRuhuMultiplier = 1.0;
  bool showRange = false;
  int kills = 0;
  int totalDamageDealt = 0;
  TargetingMode targetingMode = TargetingMode.nearest;

  // Animation state
  double _animTimer = 0;

  Tower({
    required this.type,
    required this.col,
    required this.row,
    required this.cellSize,
  }) : super(
    position: Vector2(col * cellSize, row * cellSize),
    size: Vector2.all(cellSize),
    paint: Paint()..color = Colors.transparent, // We draw everything custom
    anchor: Anchor.topLeft,
  ) {
    _totalSpent = stats.cost;
  }

  TowerStats get stats => TowerData.getStats(type);
  int get tier => _tier;
  int get totalSpent => _totalSpent;

  int get currentDamage => (stats.damageAtTier(_tier) * _synergyDamageMultiplier * artifactDamageMultiplier * supportDamageMultiplier * kaleRuhuMultiplier).round();
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
    _animTimer += dt;
  }

  bool canFire() => _cooldown <= 0 && type != TowerType.spikeWall && type != TowerType.support;

  Projectile? tryFire(Vector2 targetPos) {
    if (!canFire()) return null;
    _cooldown = currentFireRate;
    return Projectile(
      startPos: position + size / 2,
      target: targetPos,
      damage: currentDamage,
      color: _primaryColor(type),
    );
  }

  bool isInRange(Vector2 targetPos) {
    final center = position + size / 2;
    final dist = center.distanceTo(targetPos);
    return dist <= currentRange * cellSize;
  }

  @override
  void render(Canvas canvas) {
    // 1. Draw cached sprite
    final spriteImage = TowerSpriteGenerator.instance.getSprite(type, _tier);
    if (spriteImage != null) {
      final src = Rect.fromLTWH(0, 0, spriteImage.width.toDouble(), spriteImage.height.toDouble());
      // Draw slightly above and larger than cell for visual impact
      final dst = Rect.fromLTWH(-cellSize * 0.15, -cellSize * 0.45, cellSize * 1.3, cellSize * 1.45);
      canvas.drawImageRect(spriteImage, src, dst, Paint()..filterQuality = FilterQuality.medium);
    }

    // 2. Synergy glow overlay (dynamic, stays as Canvas)
    if (_synergyDamageMultiplier > 1.0 || _synergyRangeBonus > 0 || _synergyFireRateMultiplier < 1.0) {
      final glowAlpha = (0.3 + 0.2 * math.sin(_animTimer * 3)).clamp(0.0, 1.0);
      final glowPaint = Paint()
        ..color = Color.fromRGBO(255, 215, 0, glowAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-cellSize * 0.17, -cellSize * 0.47, cellSize * 1.34, cellSize * 1.49),
          const Radius.circular(4),
        ),
        glowPaint,
      );
    }

    // 3. Support aura (dynamic)
    if (supportDamageMultiplier > 1.0 || supportRangeMultiplier > 1.0) {
      final auraPaint = Paint()
        ..color = const Color(0x18FFFF00)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(cellSize / 2, cellSize / 2), cellSize * 0.6, auraPaint);
    }

    // 4. Range indicator (when selected)
    if (showRange) {
      final rangePx = currentRange * cellSize;
      final rangeCenter = Offset(cellSize / 2, cellSize / 2);
      canvas.drawCircle(rangeCenter, rangePx, Paint()
        ..color = const Color(0x1800FF88)
        ..style = PaintingStyle.fill);
      canvas.drawCircle(rangeCenter, rangePx, Paint()
        ..color = const Color(0x4400FF88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }

    // 5. Firing flash (when shooting)
    if (_cooldown > currentFireRate * 0.8) {
      final flashPaint = Paint()
        ..color = const Color(0x4DFFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(cellSize / 2, cellSize * 0.1), cellSize * 0.12, flashPaint);
    }
  }

  static Color _primaryColor(TowerType type) {
    switch (type) {
      case TowerType.arrow: return const Color(0xFF9E5B3C);     // rich mahogany/copper
      case TowerType.ice: return const Color(0xFF22CCEE);        // brilliant cyan/frost
      case TowerType.fire: return const Color(0xFFFF5511);       // bright orange-red
      case TowerType.lightning: return const Color(0xFFFFDD00);  // electric bright yellow
      case TowerType.poison: return const Color(0xFF33FF33);     // toxic neon green
      case TowerType.cannon: return const Color(0xFF4A5568);     // dark steel/gunmetal
      case TowerType.spikeWall: return const Color(0xFF555555);
      case TowerType.support: return const Color(0xFFDDCC00);
      case TowerType.water: return const Color(0xFF00BBCC);      // ocean turquoise
      case TowerType.wizard: return const Color(0xFFAA33DD);     // vibrant violet
      case TowerType.dark: return const Color(0xFF3311AA);       // deep indigo
      case TowerType.holy: return const Color(0xFFFFDD66);       // radiant warm white-gold
    }
  }

}
