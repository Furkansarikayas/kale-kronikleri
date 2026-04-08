enum TowerType {
  arrow, ice, fire, lightning, poison, cannon,
  spikeWall, support, water, wizard, dark, holy,
}

enum TowerCategory { damage, control, defense, magic }

extension TowerCategoryExt on TowerCategory {
  String get label {
    switch (this) {
      case TowerCategory.damage: return 'Saldiri';
      case TowerCategory.control: return 'Kontrol';
      case TowerCategory.defense: return 'Savunma';
      case TowerCategory.magic: return 'Buyu';
    }
  }

  String get shortLabel {
    switch (this) {
      case TowerCategory.damage: return 'DPS';
      case TowerCategory.control: return 'CC';
      case TowerCategory.defense: return 'DEF';
      case TowerCategory.magic: return 'MGC';
    }
  }
}

class TowerStats {
  final TowerType type;
  final int damage;
  final double range;
  final double fireRate;
  final int cost;
  final int unlockWave;
  final String name;
  final String roleHint;
  final List<String> tierNames;

  const TowerStats({
    required this.type, required this.damage, required this.range,
    required this.fireRate, required this.cost, required this.unlockWave,
    required this.name, this.roleHint = '', required this.tierNames,
  });

  int upgradeCost(int tier) {
    if (tier <= 1) return cost;
    if (tier == 2) return cost * 2;
    if (tier == 3) return cost * 4;
    return cost * 9; // T4 is a major investment (was 6x)
  }

  int damageAtTier(int tier) {
    double d = damage.toDouble();
    for (int i = 1; i < tier; i++) {
      d *= 1.3;
    }
    return d.floor();
  }

  double rangeAtTier(int tier) => range + (tier - 1) * 0.3;
}

class TowerData {
  TowerData._();

  static const Map<TowerType, TowerStats> _stats = {
    TowerType.arrow: TowerStats(type: TowerType.arrow, damage: 15, range: 3.5, fireRate: 0.6, cost: 50, unlockWave: 0, name: 'Ok Kulesi', roleHint: 'Hızlı tek hedef hasarı', tierNames: ['Ok Kulesi', 'Keskin Nişancı', 'Çoklu Ok', 'Fırtına Yağmuru']),
    TowerType.ice: TowerStats(type: TowerType.ice, damage: 5, range: 3.0, fireRate: 1.0, cost: 60, unlockWave: 0, name: 'Buz Kulesi', roleHint: 'Düşmanları yavaşlatır', tierNames: ['Buz Kulesi', 'Don Halkası', 'Buzul', 'Mutlak Sıfır']),
    TowerType.fire: TowerStats(type: TowerType.fire, damage: 8, range: 2.5, fireRate: 1.5, cost: 70, unlockWave: 2, name: 'Ateş Kulesi', roleHint: 'Zamanla yakan alan hasarı', tierNames: ['Ateş Kulesi', 'Alev Topu', 'Yangın', 'Cehennem Ateşi']),
    TowerType.lightning: TowerStats(type: TowerType.lightning, damage: 20, range: 3.0, fireRate: 1.2, cost: 80, unlockWave: 4, name: 'Yıldırım Kulesi', roleHint: 'Güçlü tek vuruş', tierNames: ['Yıldırım', 'Kıvılcım', 'Şimşek', 'Tanrı Öfkesi']),
    TowerType.poison: TowerStats(type: TowerType.poison, damage: 4, range: 2.5, fireRate: 0.8, cost: 60, unlockWave: 3, name: 'Zehir Kulesi', roleHint: 'Uzun süreli zehir hasarı', tierNames: ['Zehir Kulesi', 'Çürütme', 'Veba', 'Nekroz']),
    TowerType.cannon: TowerStats(type: TowerType.cannon, damage: 40, range: 4.0, fireRate: 2.5, cost: 90, unlockWave: 7, name: 'Topçu Kulesi', roleHint: 'Ağır alan patlaması', tierNames: ['Topçu', 'Havan', 'Kuşatma', 'Meteor']),
    TowerType.spikeWall: TowerStats(type: TowerType.spikeWall, damage: 5, range: 0.0, fireRate: 0.0, cost: 40, unlockWave: 2, name: 'Dikenli Duvar', roleHint: 'Geçen düşmana temas hasarı', tierNames: ['Dikenli Duvar', 'Çit', 'Barikat', 'Kara Orman']),
    TowerType.support: TowerStats(type: TowerType.support, damage: 0, range: 1.0, fireRate: 0.0, cost: 65, unlockWave: 4, name: 'Destek Kulesi', roleHint: 'Komşu kuleleri güçlendirir', tierNames: ['Destek', 'Destek II', 'Destek III', 'Destek IV']),
    TowerType.water: TowerStats(type: TowerType.water, damage: 8, range: 2.5, fireRate: 1.0, cost: 70, unlockWave: 5, name: 'Su Kulesi', roleHint: 'Islatır, Yıldırım ile kombo', tierNames: ['Su Kulesi', 'Sel', 'Tsunami', 'Girdap']),
    TowerType.wizard: TowerStats(type: TowerType.wizard, damage: 12, range: 3.0, fireRate: 1.0, cost: 85, unlockWave: 9, name: 'Büyücü Kulesi', roleHint: 'Zincir saldırı, çoklu hedef', tierNames: ['Büyücü', 'Çırak', 'Usta', 'Arş Büyücü']),
    TowerType.dark: TowerStats(type: TowerType.dark, damage: 7, range: 2.5, fireRate: 1.0, cost: 70, unlockWave: 11, name: 'Karanlık Kule', roleHint: 'Zırh kırar, düşmanı zayıflatır', tierNames: ['Karanlık', 'Gölge', 'Lanet', 'Uçurum']),
    TowerType.holy: TowerStats(type: TowerType.holy, damage: 10, range: 3.0, fireRate: 1.0, cost: 85, unlockWave: 13, name: 'Kutsal Kule', roleHint: 'Undead düşmanlara ekstra hasar', tierNames: ['Kutsal', 'Rahip', 'Aziz', 'Işık Kalesi']),
  };

  static const Map<TowerType, TowerCategory> _categories = {
    TowerType.arrow: TowerCategory.damage,
    TowerType.fire: TowerCategory.damage,
    TowerType.lightning: TowerCategory.damage,
    TowerType.cannon: TowerCategory.damage,
    TowerType.ice: TowerCategory.control,
    TowerType.poison: TowerCategory.control,
    TowerType.water: TowerCategory.control,
    TowerType.spikeWall: TowerCategory.defense,
    TowerType.support: TowerCategory.defense,
    TowerType.wizard: TowerCategory.magic,
    TowerType.dark: TowerCategory.magic,
    TowerType.holy: TowerCategory.magic,
  };

  static TowerCategory getCategory(TowerType type) => _categories[type]!;

  static TowerStats getStats(TowerType type) => _stats[type]!;
  static List<TowerType> get allTypes => TowerType.values;
  static List<TowerType> availableAt(int wave, {bool allUnlocked = false}) {
    if (allUnlocked) return allTypes;
    return allTypes.where((t) => _stats[t]!.unlockWave <= wave).toList();
  }

  static List<TowerType> availableInCategory(int wave, TowerCategory category, {bool allUnlocked = false}) {
    return availableAt(wave, allUnlocked: allUnlocked)
        .where((t) => _categories[t] == category)
        .toList();
  }

  static List<TowerCategory> availableCategories(int wave, {bool allUnlocked = false}) {
    final available = availableAt(wave, allUnlocked: allUnlocked).toSet();
    return TowerCategory.values
        .where((c) => _categories.entries.any((e) => e.value == c && available.contains(e.key)))
        .toList();
  }

  /// Returns the next tower unlock info: (name, wavesUntil) or null if all unlocked.
  static ({String name, int wavesUntil})? nextUnlock(int currentWave) {
    int bestWave = 999;
    String bestName = '';
    for (final entry in _stats.entries) {
      final unlockWave = entry.value.unlockWave;
      if (unlockWave > currentWave && unlockWave < bestWave) {
        bestWave = unlockWave;
        bestName = entry.value.name;
      }
    }
    if (bestWave == 999) return null;
    return (name: bestName, wavesUntil: bestWave - currentWave);
  }
}
