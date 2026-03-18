enum TowerType {
  arrow, ice, fire, lightning, poison, cannon,
  spikeWall, support, water, wizard, dark, holy,
}

class TowerStats {
  final TowerType type;
  final int damage;
  final double range;
  final double fireRate;
  final int cost;
  final int unlockWave;
  final String name;
  final List<String> tierNames;

  const TowerStats({
    required this.type, required this.damage, required this.range,
    required this.fireRate, required this.cost, required this.unlockWave,
    required this.name, required this.tierNames,
  });

  int upgradeCost(int tier) {
    if (tier <= 1) return cost;
    if (tier == 2) return cost * 2;
    return cost * 4;
  }

  int damageAtTier(int tier) {
    double d = damage.toDouble();
    for (int i = 1; i < tier; i++) {
      d *= 1.5;
    }
    return d.floor();
  }

  double rangeAtTier(int tier) => range + (tier - 1) * 0.5;
}

class TowerData {
  TowerData._();

  static const Map<TowerType, TowerStats> _stats = {
    TowerType.arrow: TowerStats(type: TowerType.arrow, damage: 15, range: 4.0, fireRate: 0.6, cost: 50, unlockWave: 0, name: 'Ok Kulesi', tierNames: ['Ok Kulesi', 'Keskin Nisanci', 'Coklu Ok', 'Firtina Yagmuru']),
    TowerType.ice: TowerStats(type: TowerType.ice, damage: 5, range: 3.0, fireRate: 1.0, cost: 60, unlockWave: 0, name: 'Buz Kulesi', tierNames: ['Buz Kulesi', 'Don Halkasi', 'Buzul', 'Mutlak Sifir']),
    TowerType.fire: TowerStats(type: TowerType.fire, damage: 8, range: 3.0, fireRate: 1.5, cost: 70, unlockWave: 0, name: 'Ates Kulesi', tierNames: ['Ates Kulesi', 'Alev Topu', 'Yangin', 'Cehennem Atesi']),
    TowerType.lightning: TowerStats(type: TowerType.lightning, damage: 20, range: 3.0, fireRate: 1.2, cost: 80, unlockWave: 0, name: 'Yildirim Kulesi', tierNames: ['Yildirim', 'Kivilcim', 'Simsek', 'Tanri Ofkesi']),
    TowerType.poison: TowerStats(type: TowerType.poison, damage: 3, range: 2.0, fireRate: 0.8, cost: 65, unlockWave: 3, name: 'Zehir Kulesi', tierNames: ['Zehir Kulesi', 'Curutme', 'Veba', 'Nekroz']),
    TowerType.cannon: TowerStats(type: TowerType.cannon, damage: 40, range: 5.0, fireRate: 2.5, cost: 90, unlockWave: 7, name: 'Topcu Kulesi', tierNames: ['Topcu', 'Havan', 'Kusatma', 'Meteor']),
    TowerType.spikeWall: TowerStats(type: TowerType.spikeWall, damage: 5, range: 0.0, fireRate: 0.0, cost: 40, unlockWave: 0, name: 'Dikenli Duvar', tierNames: ['Dikenli Duvar', 'Cit', 'Barikat', 'Kara Orman']),
    TowerType.support: TowerStats(type: TowerType.support, damage: 0, range: 1.0, fireRate: 0.0, cost: 75, unlockWave: 0, name: 'Destek Kulesi', tierNames: ['Destek', 'Destek II', 'Destek III', 'Destek IV']),
    TowerType.water: TowerStats(type: TowerType.water, damage: 8, range: 3.0, fireRate: 1.0, cost: 70, unlockWave: 5, name: 'Su Kulesi', tierNames: ['Su Kulesi', 'Sel', 'Tsunami', 'Girdap']),
    TowerType.wizard: TowerStats(type: TowerType.wizard, damage: 12, range: 3.0, fireRate: 1.0, cost: 85, unlockWave: 9, name: 'Buyucu Kulesi', tierNames: ['Buyucu', 'Cirak', 'Usta', 'Ars Buyucu']),
    TowerType.dark: TowerStats(type: TowerType.dark, damage: 6, range: 3.0, fireRate: 1.0, cost: 80, unlockWave: 11, name: 'Karanlik Kule', tierNames: ['Karanlik', 'Golge', 'Lanet', 'Ucurum']),
    TowerType.holy: TowerStats(type: TowerType.holy, damage: 10, range: 3.0, fireRate: 1.0, cost: 85, unlockWave: 13, name: 'Kutsal Kule', tierNames: ['Kutsal', 'Rahip', 'Aziz', 'Isik Kalesi']),
  };

  static TowerStats getStats(TowerType type) => _stats[type]!;
  static List<TowerType> get allTypes => TowerType.values;
  static List<TowerType> availableAt(int wave, {bool allUnlocked = false}) {
    if (allUnlocked) return allTypes;
    return allTypes.where((t) => _stats[t]!.unlockWave <= wave).toList();
  }
}
