import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/game/components/enemies/enemy.dart';
import 'package:kale_kronikleri/game/components/enemies/enemy_factory.dart';
import 'package:kale_kronikleri/game/components/enemies/status_effect.dart';
import 'package:kale_kronikleri/game/data/enemy_data.dart';
import 'package:kale_kronikleri/game/data/game_config.dart';
import 'package:kale_kronikleri/game/data/tower_data.dart';
import 'package:kale_kronikleri/game/systems/pathfinding.dart';

void main() {
  final testPath = <GridPos>[
    (col: 0, row: 5),
    (col: 1, row: 5),
    (col: 2, row: 5),
    (col: 3, row: 5),
    (col: 4, row: 5),
  ];

  group('StatusEffect', () {
    test('burn deals damage over time', () {
      final burn = StatusEffect.burn(dps: 5, duration: 3.0);
      expect(burn.isExpired, false);
      final dmg = burn.update(1.0);
      expect(dmg, 5);
    });

    test('slow reduces speed factor', () {
      final slow = StatusEffect.slow(factor: 0.5);
      expect(slow.slowFactor, 0.5);
    });

    test('expires after duration', () {
      final burn = StatusEffect.burn(duration: 1.0);
      burn.update(0.5);
      expect(burn.isExpired, false);
      burn.update(0.6);
      expect(burn.isExpired, true);
    });
  });

  group('Enemy', () {
    test('initial HP matches stats', () {
      final enemy = EnemyFactory.create(
        type: EnemyType.soldier, path: testPath, cellSize: 40,
      );
      expect(enemy.hp, 30);
      expect(enemy.isDead, false);
    });

    test('takes damage with armor', () {
      final enemy = EnemyFactory.create(
        type: EnemyType.armoredGiant, path: testPath, cellSize: 40,
      );
      final initialHp = enemy.hp;
      enemy.takeDamage(20); // 20 - 15 armor = 5
      expect(enemy.hp, initialHp - 5);
    });

    test('minimum damage is 1', () {
      final enemy = EnemyFactory.create(
        type: EnemyType.armoredGiant, path: testPath, cellSize: 40,
      );
      final initialHp = enemy.hp;
      enemy.takeDamage(1); // 1 - 15 = min 1
      expect(enemy.hp, initialHp - 1);
    });

    test('dies when HP reaches 0', () {
      final enemy = EnemyFactory.create(
        type: EnemyType.soldier, path: testPath, cellSize: 40,
      );
      enemy.takeDamage(100);
      expect(enemy.isDead, true);
      expect(enemy.hp, 0);
    });

    test('slow effect reduces speed', () {
      final enemy = EnemyFactory.create(
        type: EnemyType.soldier, path: testPath, cellSize: 40,
      );
      final baseSpeed = enemy.currentSpeed;
      enemy.applyEffect(StatusEffect.slow(factor: 0.5));
      expect(enemy.currentSpeed, baseSpeed * 0.5);
    });

    test('curse reduces armor', () {
      final enemy = EnemyFactory.create(
        type: EnemyType.armoredGiant, path: testPath, cellSize: 40,
      );
      expect(enemy.currentArmor, 15);
      enemy.applyEffect(StatusEffect.curse(armorReduce: 10.0));
      expect(enemy.currentArmor, 5);
    });

    test('wet status is tracked', () {
      final enemy = EnemyFactory.create(
        type: EnemyType.soldier, path: testPath, cellSize: 40,
      );
      expect(enemy.isWet, false);
      enemy.applyEffect(StatusEffect.wet());
      expect(enemy.isWet, true);
    });

    test('bypass armor on DoT', () {
      final enemy = EnemyFactory.create(
        type: EnemyType.armoredGiant, path: testPath, cellSize: 40,
      );
      final initialHp = enemy.hp;
      enemy.takeDamage(5, bypassArmor: true);
      expect(enemy.hp, initialHp - 5);
    });

    test('difficulty scaling works', () {
      final easy = EnemyFactory.create(
        type: EnemyType.soldier, path: testPath, cellSize: 40,
        difficulty: DifficultyTier.apprentice,
      );
      final hard = EnemyFactory.create(
        type: EnemyType.soldier, path: testPath, cellSize: 40,
        difficulty: DifficultyTier.legend,
      );
      expect(hard.maxHp, greaterThan(easy.maxHp));
    });
  });

  group('EnemyFactory', () {
    test('creates enemy with correct type', () {
      final enemy = EnemyFactory.create(
        type: EnemyType.cavalry, path: testPath, cellSize: 40,
      );
      expect(enemy.type, EnemyType.cavalry);
      expect(enemy.goldReward, 6);
    });
  });

  group('EnemyData.getWeaknesses', () {
    test('cavalry is weak to ice and spikeWall', () {
      final weaknesses = EnemyData.getWeaknesses(EnemyType.cavalry);
      expect(weaknesses, contains(TowerType.ice));
      expect(weaknesses, contains(TowerType.spikeWall));
    });

    test('soldier has no weaknesses', () {
      final weaknesses = EnemyData.getWeaknesses(EnemyType.soldier);
      expect(weaknesses, isEmpty);
    });

    test('all enemy types have weakness data', () {
      for (final type in EnemyType.values) {
        // Should not throw
        EnemyData.getWeaknesses(type);
      }
    });
  });
}
