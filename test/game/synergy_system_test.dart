import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/game/systems/synergy_system.dart';
import 'package:kale_kronikleri/game/data/tower_data.dart';

void main() {
  late SynergySystem system;

  setUp(() {
    system = SynergySystem();
  });

  group('SynergySystem', () {
    test('no synergies with no towers', () {
      final result = system.recalculate({});
      expect(result, isEmpty);
    });

    test('no synergy with single tower', () {
      final result = system.recalculate({
        (col: 5, row: 5): TowerType.arrow,
      });
      expect(result, isEmpty);
    });

    test('Dondur-Patlat activates with adjacent ice + arrow', () {
      final result = system.recalculate({
        (col: 5, row: 5): TowerType.ice,
        (col: 6, row: 5): TowerType.arrow,
      });
      expect(result.any((s) => s.name == 'Dondur-Patlat'), true);
    });

    test('no synergy when towers not adjacent', () {
      final result = system.recalculate({
        (col: 0, row: 0): TowerType.ice,
        (col: 10, row: 10): TowerType.arrow, // far apart (but within grid)
      });
      // grid is 16x10, so (10,10) is out of bounds row-wise, but the system handles it
      // Let's use in-bounds but far
      final result2 = system.recalculate({
        (col: 0, row: 0): TowerType.ice,
        (col: 5, row: 5): TowerType.arrow,
      });
      expect(result2.any((s) => s.name == 'Dondur-Patlat'), false);
    });

    test('diagonal adjacency works', () {
      final result = system.recalculate({
        (col: 5, row: 5): TowerType.ice,
        (col: 6, row: 6): TowerType.arrow,
      });
      expect(result.any((s) => s.name == 'Dondur-Patlat'), true);
    });

    test('Buhar synergy (ice + fire)', () {
      final result = system.recalculate({
        (col: 3, row: 3): TowerType.ice,
        (col: 4, row: 3): TowerType.fire,
      });
      expect(result.any((s) => s.name == 'Buhar Hasarı'), true);
    });

    test('Sok Dalgasi synergy (water + lightning)', () {
      final result = system.recalculate({
        (col: 3, row: 3): TowerType.water,
        (col: 3, row: 4): TowerType.lightning,
      });
      expect(result.any((s) => s.name == 'Şok Dalgası'), true);
    });

    test('Denge Patlamasi synergy (dark + holy)', () {
      final result = system.recalculate({
        (col: 7, row: 5): TowerType.dark,
        (col: 8, row: 5): TowerType.holy,
      });
      expect(result.any((s) => s.name == 'Denge Patlaması'), true);
    });

    test('triple synergy Cehennem Hatti needs 3 adjacent fires', () {
      // Two fires - should not trigger triple
      final result2 = system.recalculate({
        (col: 5, row: 5): TowerType.fire,
        (col: 6, row: 5): TowerType.fire,
      });
      expect(result2.any((s) => s.name == 'Cehennem Hattı'), false);

      // Three adjacent fires in a line - middle tower sees 3 fires total (self + 2 neighbors)
      final result3 = system.recalculate({
        (col: 5, row: 5): TowerType.fire,
        (col: 6, row: 5): TowerType.fire,
        (col: 7, row: 5): TowerType.fire,
      });
      expect(result3.any((s) => s.name == 'Cehennem Hattı'), true);
    });

    test('multiple synergies can be active simultaneously', () {
      final result = system.recalculate({
        (col: 5, row: 5): TowerType.ice,
        (col: 6, row: 5): TowerType.arrow,
        (col: 5, row: 6): TowerType.fire,
      });
      // ice+arrow = Dondur-Patlat, ice+fire = Buhar Hasari
      expect(result.any((s) => s.name == 'Dondur-Patlat'), true);
      expect(result.any((s) => s.name == 'Buhar Hasarı'), true);
    });

    test('hasSynergy returns correct value', () {
      system.recalculate({
        (col: 5, row: 5): TowerType.ice,
        (col: 6, row: 5): TowerType.arrow,
      });
      expect(system.hasSynergy(1), true); // Dondur-Patlat has id 1
      expect(system.hasSynergy(99), false);
    });

    test('recalculate clears old synergies', () {
      system.recalculate({
        (col: 5, row: 5): TowerType.ice,
        (col: 6, row: 5): TowerType.arrow,
      });
      expect(system.activeSynergies.isNotEmpty, true);

      system.recalculate({});
      expect(system.activeSynergies.isEmpty, true);
    });
  });
}
