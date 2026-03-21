import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../data/game_config.dart';

class Castle extends RectangleComponent {
  int _hp;
  final int maxHp;
  final double _cellSize;

  Castle({required double cellSize, int? maxHp})
      : _hp = maxHp ?? GameConfig.baseCastleHp,
        maxHp = maxHp ?? GameConfig.baseCastleHp,
        _cellSize = cellSize,
        super(
          // Landscape: x = col (horizontal), y = row (vertical)
          position: Vector2((GameConfig.gridColumns - 2) * cellSize, (GameConfig.gridRows ~/ 2 - 1) * cellSize),
          size: Vector2(cellSize * 2, cellSize * 2),
          paint: Paint()..color = const Color(0xFFBA7517),
        );

  int get hp => _hp;
  bool get isDestroyed => _hp <= 0;

  void takeDamage(int damage, {double damageReduction = 0.0}) {
    final actual = (damage * (1 - damageReduction)).round();
    _hp = (_hp - actual).clamp(0, maxHp);
  }

  void heal(int amount) {
    _hp = (_hp + amount).clamp(0, maxHp);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final h = size.y;

    // Draw castle turrets (4 corners)
    final turretSize = w * 0.25;
    final turretPaint = Paint()..color = const Color(0xFF8B6914);
    canvas.drawRect(Rect.fromLTWH(0, 0, turretSize, turretSize), turretPaint);
    canvas.drawRect(Rect.fromLTWH(w - turretSize, 0, turretSize, turretSize), turretPaint);
    canvas.drawRect(Rect.fromLTWH(0, h - turretSize, turretSize, turretSize), turretPaint);
    canvas.drawRect(Rect.fromLTWH(w - turretSize, h - turretSize, turretSize, turretSize), turretPaint);

    // Draw gate
    final gateW = w * 0.3;
    final gateH = h * 0.35;
    canvas.drawRect(
      Rect.fromLTWH((w - gateW) / 2, h - gateH, gateW, gateH),
      Paint()..color = const Color(0xFF5C3D0E),
    );

    // Draw HP bar below castle
    final hpRatio = maxHp > 0 ? _hp / maxHp : 0.0;
    final barY = h + 4;
    final barH = 4.0;
    canvas.drawRect(Rect.fromLTWH(0, barY, w, barH), Paint()..color = const Color(0x88000000));
    final barColor = hpRatio > 0.5
        ? Color.lerp(const Color(0xFFFFFF00), const Color(0xFF00FF00), (hpRatio - 0.5) * 2)!
        : Color.lerp(const Color(0xFFFF0000), const Color(0xFFFFFF00), hpRatio * 2)!;
    canvas.drawRect(Rect.fromLTWH(0, barY, w * hpRatio, barH), Paint()..color = barColor);
  }
}
