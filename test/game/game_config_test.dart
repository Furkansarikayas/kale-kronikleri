import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/game/data/game_config.dart';

void main() {
  test('grid dimensions are 16x10', () {
    expect(GameConfig.gridColumns, 16);
    expect(GameConfig.gridRows, 10);
  });
  test('base castle HP is 20', () {
    expect(GameConfig.baseCastleHp, 20);
  });
  test('base tower slots is 8', () {
    expect(GameConfig.baseTowerSlots, 8);
  });
  test('starting gold is 150', () {
    expect(GameConfig.startingGold, 150);
  });
  test('sell refund ratio is 0.6', () {
    expect(GameConfig.sellRefundRatio, 0.6);
  });
  test('CellType has all required types', () {
    expect(CellType.values.length, 6);
  });
  test('DifficultyTier has correct wave counts', () {
    expect(DifficultyTier.apprentice.totalWaves, 20);
    expect(DifficultyTier.legend.totalWaves, 40);
    expect(DifficultyTier.legend.spiritMultiplier, 8.0);
  });
  test('calculateDamage with armor', () {
    expect(GameConfig.calculateDamage(15, 10), 5);
    expect(GameConfig.calculateDamage(5, 10), 1);
    expect(GameConfig.calculateDamage(0, 5), 0);
  });
}
