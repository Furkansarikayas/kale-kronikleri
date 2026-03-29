enum SpellType { fireRain, iceStorm, castleRepair }

class SpellDef {
  final SpellType type;
  final String name;
  final String description;
  final double cooldown;
  final int unlockWave;

  const SpellDef({
    required this.type,
    required this.name,
    required this.description,
    required this.cooldown,
    required this.unlockWave,
  });
}

class SpellSystem {
  static const List<SpellDef> spells = [
    SpellDef(
      type: SpellType.fireRain,
      name: 'Ateş Yağmuru',
      description: 'Tüm düşmanlara alan hasarı',
      cooldown: 35.0,
      unlockWave: 3,
    ),
    SpellDef(
      type: SpellType.iceStorm,
      name: 'Buz Fırtınası',
      description: 'Tüm düşmanları 3 saniye yavaşlat',
      cooldown: 40.0,
      unlockWave: 5,
    ),
    SpellDef(
      type: SpellType.castleRepair,
      name: 'Kale Onarımı',
      description: 'Kale HP %20 iyileştir',
      cooldown: 50.0,
      unlockWave: 8,
    ),
  ];

  final Map<SpellType, double> _cooldowns = {};

  List<SpellType> availableSpells(int currentWave) {
    return spells
        .where((s) => s.unlockWave <= currentWave)
        .map((s) => s.type)
        .toList();
  }

  bool canCast(SpellType spell) {
    return (_cooldowns[spell] ?? 0) <= 0;
  }

  double getCooldown(SpellType spell) {
    return (_cooldowns[spell] ?? 0).clamp(0.0, double.infinity);
  }

  double getMaxCooldown(SpellType spell) {
    return spells.firstWhere((s) => s.type == spell).cooldown;
  }

  void cast(SpellType spell) {
    final def = spells.firstWhere((s) => s.type == spell);
    _cooldowns[spell] = def.cooldown;
  }

  void update(double dt) {
    for (final spell in SpellType.values) {
      if ((_cooldowns[spell] ?? 0) > 0) {
        _cooldowns[spell] = _cooldowns[spell]! - dt;
      }
    }
  }

  static SpellDef getDef(SpellType type) {
    return spells.firstWhere((s) => s.type == type);
  }
}
