import 'dart:math';

enum ArtifactRarity { common, rare, epic, legendary }

class ArtifactDef {
  final int id;
  final String name;
  final String description;
  final ArtifactRarity rarity;
  const ArtifactDef({required this.id, required this.name, required this.description, required this.rarity});
}

class ArtifactData {
  ArtifactData._();
  static const List<ArtifactDef> all = [
    ArtifactDef(id: 1, name: 'Ateş Kalbi', description: 'Ateş kuleleri %25 hızlı atar', rarity: ArtifactRarity.common),
    ArtifactDef(id: 2, name: 'Buz Kristali', description: 'Yavaşlatma süresi 2×', rarity: ArtifactRarity.common),
    ArtifactDef(id: 3, name: 'Rüzgar Tılsımı', description: 'Ok menzili %40 artar', rarity: ArtifactRarity.common),
    ArtifactDef(id: 4, name: 'Altın Taç', description: 'Her dalgada +15 bonus altın', rarity: ArtifactRarity.rare),
    ArtifactDef(id: 5, name: 'Gölge Pelerin', description: 'İlk dalga düşmanları %50 yavaş', rarity: ArtifactRarity.rare),
    ArtifactDef(id: 6, name: 'Ejderha Pulu', description: 'Boss hasarı %35 artar', rarity: ArtifactRarity.rare),
    ArtifactDef(id: 7, name: 'Kaos Taşı', description: 'Rastgele sinerji otomatik tetiklenir', rarity: ArtifactRarity.epic),
    ArtifactDef(id: 8, name: 'Ölümsüz Totem', description: '1 kere ölümden dön', rarity: ArtifactRarity.epic),
    ArtifactDef(id: 9, name: 'Tanrı Çekici', description: 'Yıldırım hasarı 3×', rarity: ArtifactRarity.epic),
    ArtifactDef(id: 10, name: 'Kader Aynası', description: 'Tüm sinerjiler %50 güçlenir', rarity: ArtifactRarity.legendary),
    ArtifactDef(id: 11, name: 'Ebedi Alev', description: 'Tüm düşmanlar sürekli yanma alır', rarity: ArtifactRarity.legendary),
    ArtifactDef(id: 12, name: 'Cennet Kalkanı', description: 'Her 5 dalgada tam can yenile', rarity: ArtifactRarity.legendary),
  ];

  static List<ArtifactDef> rollChoices({required int seed, bool improved = false}) {
    final rng = Random(seed);
    final weights = improved
        ? {ArtifactRarity.common: 35, ArtifactRarity.rare: 30, ArtifactRarity.epic: 25, ArtifactRarity.legendary: 10}
        : {ArtifactRarity.common: 50, ArtifactRarity.rare: 30, ArtifactRarity.epic: 15, ArtifactRarity.legendary: 5};
    final choices = <ArtifactDef>[];
    final used = <int>{};
    while (choices.length < 3) {
      final rarity = _rollRarity(rng, weights);
      final pool = all.where((a) => a.rarity == rarity && !used.contains(a.id)).toList();
      if (pool.isEmpty) continue;
      final pick = pool[rng.nextInt(pool.length)];
      choices.add(pick);
      used.add(pick.id);
    }
    return choices;
  }

  static ArtifactRarity _rollRarity(Random rng, Map<ArtifactRarity, int> weights) {
    final total = weights.values.fold(0, (a, b) => a + b);
    var roll = rng.nextInt(total);
    for (final entry in weights.entries) {
      roll -= entry.value;
      if (roll < 0) return entry.key;
    }
    return ArtifactRarity.common;
  }
}
