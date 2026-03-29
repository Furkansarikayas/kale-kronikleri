import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/game/components/towers/tower.dart';
import 'package:kale_kronikleri/game/components/towers/tower_factory.dart';
import 'package:kale_kronikleri/game/components/towers/projectile.dart';
import 'package:kale_kronikleri/game/data/tower_data.dart';
import 'package:kale_kronikleri/game/data/game_config.dart';
import 'package:flame/components.dart';

void main() {
  group('Tower', () {
    test('initial tier is 1', () {
      final tower = Tower(type: TowerType.arrow, col: 0, row: 0, cellSize: 40);
      expect(tower.tier, 1);
      expect(tower.totalSpent, 50);
    });

    test('upgrade increases tier', () {
      final tower = Tower(type: TowerType.arrow, col: 0, row: 0, cellSize: 40);
      expect(tower.canUpgrade, true);
      tower.upgrade();
      expect(tower.tier, 2);
      expect(tower.totalSpent, 50 + 100); // base + base*2
    });

    test('cannot upgrade past tier 4', () {
      final tower = Tower(type: TowerType.arrow, col: 0, row: 0, cellSize: 40);
      tower.upgrade(); // 2
      tower.upgrade(); // 3
      tower.upgrade(); // 4
      expect(tower.canUpgrade, false);
      expect(tower.upgrade(), false);
    });

    test('sell value is 65% of total spent', () {
      final tower = Tower(type: TowerType.arrow, col: 0, row: 0, cellSize: 40);
      expect(tower.sellValue, 33); // 50 * 0.65
    });

    test('synergy bonus applies', () {
      final tower = Tower(type: TowerType.arrow, col: 0, row: 0, cellSize: 40);
      final baseDmg = tower.currentDamage;
      tower.applySynergyBonus(damageMultiplier: 2.0);
      expect(tower.currentDamage, baseDmg * 2);
      tower.clearSynergyBonus();
      expect(tower.currentDamage, baseDmg);
    });

    test('kaleRuhuMultiplier boosts damage', () {
      final tower = Tower(type: TowerType.arrow, col: 0, row: 0, cellSize: 40);
      final baseDmg = tower.currentDamage;
      tower.kaleRuhuMultiplier = 1.10;
      expect(tower.currentDamage, (baseDmg * 1.10).round());
    });

    test('default targeting mode is nearest', () {
      final tower = Tower(type: TowerType.arrow, col: 0, row: 0, cellSize: 40);
      expect(tower.targetingMode, TargetingMode.nearest);
    });

    test('targeting mode can be changed', () {
      final tower = Tower(type: TowerType.arrow, col: 0, row: 0, cellSize: 40);
      tower.targetingMode = TargetingMode.first;
      expect(tower.targetingMode, TargetingMode.first);
      tower.targetingMode = TargetingMode.strongest;
      expect(tower.targetingMode, TargetingMode.strongest);
    });

    test('spike wall and support cannot fire', () {
      final spike = Tower(type: TowerType.spikeWall, col: 0, row: 0, cellSize: 40);
      expect(spike.canFire(), false);
      final support = Tower(type: TowerType.support, col: 0, row: 0, cellSize: 40);
      expect(support.canFire(), false);
    });

    test('isInRange checks distance', () {
      final tower = Tower(type: TowerType.arrow, col: 5, row: 5, cellSize: 40);
      // Arrow range = 4.0 cells, so 4*40 = 160 pixels
      final center = Vector2(5 * 40 + 20, 5 * 40 + 20);
      expect(tower.isInRange(center), true); // same position
      expect(tower.isInRange(Vector2(center.x + 159, center.y)), true);
      expect(tower.isInRange(Vector2(center.x + 200, center.y)), false);
    });
  });

  group('TowerFactory', () {
    test('creates tower with correct type', () {
      final tower = TowerFactory.create(type: TowerType.fire, col: 3, row: 2, cellSize: 40);
      expect(tower.type, TowerType.fire);
      expect(tower.col, 3);
      expect(tower.row, 2);
    });
  });

  group('Projectile', () {
    test('moves toward target', () {
      final proj = Projectile(
        startPos: Vector2.zero(),
        target: Vector2(100, 0),
        damage: 10,
      );
      proj.update(0.1);
      expect(proj.position.x, greaterThan(0));
      expect(proj.hasHit, false);
    });

    test('marks hit when reaching target', () {
      final proj = Projectile(
        startPos: Vector2.zero(),
        target: Vector2(10, 0),
        damage: 10,
        speed: 500,
      );
      proj.update(1.0); // should reach in 0.02s
      expect(proj.hasHit, true);
    });
  });
}
