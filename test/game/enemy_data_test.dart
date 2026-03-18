import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/game/data/enemy_data.dart';
import 'package:kale_kronikleri/game/data/game_config.dart';

void main() {
  test('12 enemy types', () {
    expect(EnemyType.values.length, 12);
  });
  test('soldier stats', () {
    final s = EnemyData.getStats(EnemyType.soldier);
    expect(s.hp, 30); expect(s.armor, 0); expect(s.speed, 1.0);
    expect(s.goldReward, 5); expect(s.castleDamage, 1);
  });
  test('shadow lord is boss', () {
    final s = EnemyData.getStats(EnemyType.shadowLord);
    expect(s.hp, 500); expect(s.isBoss, true); expect(s.castleDamage, 5);
  });
  test('difficulty scales HP', () {
    final s = EnemyData.getStats(EnemyType.soldier);
    final scaled = s.withDifficulty(DifficultyTier.legend);
    expect(scaled.hp, 60);
  });
  test('undead splits', () {
    final s = EnemyData.getStats(EnemyType.undead);
    expect(s.splitCount, 3); expect(s.splitHp, 15);
  });
}
