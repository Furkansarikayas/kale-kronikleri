import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../data/game_config.dart';

class Castle extends RectangleComponent {
  int _hp;
  final int maxHp;

  Castle({required double cellSize, int? maxHp})
      : _hp = maxHp ?? GameConfig.baseCastleHp,
        maxHp = maxHp ?? GameConfig.baseCastleHp,
        super(
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
}
