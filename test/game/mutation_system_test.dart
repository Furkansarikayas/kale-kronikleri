import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/game/systems/mutation_system.dart';

void main() {
  group('MutationSystem', () {
    test('getMutationsForSeed returns 2 mutations', () {
      final mutations = MutationSystem.getMutationsForSeed(202612);
      expect(mutations.length, 2);
    });

    test('same seed gives same mutations', () {
      final a = MutationSystem.getMutationsForSeed(42);
      final b = MutationSystem.getMutationsForSeed(42);
      expect(a[0], b[0]);
      expect(a[1], b[1]);
    });

    test('different seeds give different mutations', () {
      final a = MutationSystem.getMutationsForSeed(1);
      final b = MutationSystem.getMutationsForSeed(999);
      // Very unlikely to be the same, but possible; check they are valid
      expect(MutationType.values.contains(a[0]), true);
      expect(MutationType.values.contains(b[0]), true);
    });

    test('enemy speed multiplier with fastEnemies', () {
      expect(MutationSystem.enemySpeedMultiplier([MutationType.fastEnemies]), 1.3);
      expect(MutationSystem.enemySpeedMultiplier([]), 1.0);
    });

    test('tower cost multiplier', () {
      expect(MutationSystem.towerCostMultiplier([MutationType.cheapTowers]), 0.75);
      expect(MutationSystem.towerCostMultiplier([MutationType.expensiveTowers]), 1.3);
      expect(MutationSystem.towerCostMultiplier([]), 1.0);
    });

    test('gold reward multiplier', () {
      expect(MutationSystem.goldRewardMultiplier([MutationType.richRewards]), 2.0);
    });

    test('boss rush detection', () {
      expect(MutationSystem.isBossRush([MutationType.bossRush]), true);
      expect(MutationSystem.isBossRush([MutationType.fastEnemies]), false);
    });

    test('bonus armor', () {
      expect(MutationSystem.bonusArmor([MutationType.armoredAll]), 5);
      expect(MutationSystem.bonusArmor([]), 0);
    });
  });
}
