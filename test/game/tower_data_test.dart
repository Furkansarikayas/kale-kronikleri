import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/game/data/tower_data.dart';

void main() {
  test('there are 12 tower types', () {
    expect(TowerType.values.length, 12);
  });
  test('arrow tower has correct base stats', () {
    final stats = TowerData.getStats(TowerType.arrow);
    expect(stats.damage, 15);
    expect(stats.range, 4.0);
    expect(stats.fireRate, 0.6);
    expect(stats.cost, 50);
  });
  test('spike wall has 0 range', () {
    final stats = TowerData.getStats(TowerType.spikeWall);
    expect(stats.range, 0.0);
    expect(stats.cost, 40);
  });
  test('upgrade costs follow formula', () {
    final stats = TowerData.getStats(TowerType.arrow);
    expect(stats.upgradeCost(2), 100);
    expect(stats.upgradeCost(3), 200);
  });
  test('tier upgrade multiplies damage by 1.5', () {
    final stats = TowerData.getStats(TowerType.arrow);
    expect(stats.damageAtTier(1), 15);
    expect(stats.damageAtTier(2), 22);
    expect(stats.damageAtTier(3), 33);
  });
  test('unlock waves for locked towers', () {
    expect(TowerData.getStats(TowerType.poison).unlockWave, 3);
    expect(TowerData.getStats(TowerType.water).unlockWave, 5);
    expect(TowerData.getStats(TowerType.cannon).unlockWave, 7);
    expect(TowerData.getStats(TowerType.wizard).unlockWave, 9);
    expect(TowerData.getStats(TowerType.dark).unlockWave, 11);
    expect(TowerData.getStats(TowerType.holy).unlockWave, 13);
  });
  test('initially available towers have unlockWave 0', () {
    expect(TowerData.getStats(TowerType.arrow).unlockWave, 0);
    expect(TowerData.getStats(TowerType.ice).unlockWave, 0);
    expect(TowerData.getStats(TowerType.fire).unlockWave, 0);
    expect(TowerData.getStats(TowerType.lightning).unlockWave, 0);
    expect(TowerData.getStats(TowerType.spikeWall).unlockWave, 0);
    expect(TowerData.getStats(TowerType.support).unlockWave, 0);
  });
  test('availableAt filters by wave', () {
    final wave1 = TowerData.availableAt(1);
    expect(wave1.length, 6);
    final wave10 = TowerData.availableAt(10);
    expect(wave10.length, 10);
    final all = TowerData.availableAt(0, allUnlocked: true);
    expect(all.length, 12);
  });
}
