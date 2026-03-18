import 'tower_data.dart';

class SynergyDef {
  final int id;
  final String name;
  final String description;
  final List<TowerType> requiredTowers;
  final bool isTriple;
  const SynergyDef({required this.id, required this.name, required this.description, required this.requiredTowers, this.isTriple = false});
}

class SynergyData {
  SynergyData._();
  static const List<SynergyDef> all = [
    SynergyDef(id: 1, name: 'Dondur-Patlat', description: 'Donmuş hedefe 2× hasar', requiredTowers: [TowerType.ice, TowerType.arrow]),
    SynergyDef(id: 2, name: 'Buhar Hasarı', description: 'Alan DoT + görüş engeli', requiredTowers: [TowerType.ice, TowerType.fire]),
    SynergyDef(id: 3, name: 'Şok Dalgası', description: 'Islak düşmanlara zincir 2×', requiredTowers: [TowerType.water, TowerType.lightning]),
    SynergyDef(id: 4, name: 'Asit Tuzağı', description: 'Yavaşlama + zırh eritme', requiredTowers: [TowerType.poison, TowerType.spikeWall]),
    SynergyDef(id: 5, name: 'Yanık Asit', description: 'Patlayan zehir bulutları', requiredTowers: [TowerType.poison, TowerType.fire]),
    SynergyDef(id: 6, name: 'Denge Patlaması', description: 'Anlık alan nuke (5sn CD)', requiredTowers: [TowerType.dark, TowerType.holy]),
    SynergyDef(id: 7, name: 'Buz Hapsi', description: '3sn tam dondurma', requiredTowers: [TowerType.water, TowerType.ice]),
    SynergyDef(id: 8, name: 'Cehennem Hattı', description: 'Aralarındaki yol sürekli yanar', requiredTowers: [TowerType.fire, TowerType.fire, TowerType.fire], isTriple: true),
    SynergyDef(id: 9, name: 'Buzul Çağı', description: 'Tüm harita %30 yavaşlama', requiredTowers: [TowerType.ice, TowerType.ice, TowerType.ice], isTriple: true),
    SynergyDef(id: 10, name: 'Kıyamet', description: '15sn\'de bir masif alan hasarı', requiredTowers: [TowerType.arrow, TowerType.fire, TowerType.lightning], isTriple: true),
  ];

  static List<SynergyDef> findMatchingSynergies(Set<TowerType> adjacentTypes) {
    return all.where((synergy) {
      final required = <TowerType, int>{};
      for (final t in synergy.requiredTowers) {
        required[t] = (required[t] ?? 0) + 1;
      }
      final available = <TowerType, int>{};
      for (final t in adjacentTypes) {
        available[t] = (available[t] ?? 0) + 1;
      }
      for (final entry in required.entries) {
        if ((available[entry.key] ?? 0) < entry.value) return false;
      }
      return true;
    }).toList();
  }
}
