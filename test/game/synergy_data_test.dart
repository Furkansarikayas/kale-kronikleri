import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/game/data/synergy_data.dart';
import 'package:kale_kronikleri/game/data/tower_data.dart';

void main() {
  test('11 synergies', () {
    expect(SynergyData.all.length, 11);
  });
  test('ice+arrow synergy', () {
    final s = SynergyData.all.first;
    expect(s.requiredTowers, containsAll([TowerType.ice, TowerType.arrow]));
    expect(s.name, 'Dondur-Patlat');
  });
  test('4 triple synergies', () {
    final triples = SynergyData.all.where((s) => s.isTriple);
    expect(triples.length, 4);
  });
  test('findSynergies finds ice+arrow', () {
    final result = SynergyData.findMatchingSynergies({TowerType.ice, TowerType.arrow});
    expect(result.length, 1);
    expect(result.first.name, 'Dondur-Patlat');
  });
  test('findSynergies returns empty for no match', () {
    final result = SynergyData.findMatchingSynergies({TowerType.cannon, TowerType.support});
    expect(result, isEmpty);
  });
}
