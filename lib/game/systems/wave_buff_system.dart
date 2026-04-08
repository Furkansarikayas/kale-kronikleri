import 'dart:math';

/// A temporary buff that applies for the current run only.
class WaveBuff {
  final String id;
  final String name;
  final String description;
  final String icon; // emoji or icon name
  final double value;

  const WaveBuff({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.value,
  });
}

/// Manages per-run roguelike buff selections offered every N waves.
class WaveBuffSystem {
  WaveBuffSystem._();

  /// How often (in waves) buff choices are presented.
  static const int selectionInterval = 5;

  /// All possible buffs that can be offered.
  static const List<WaveBuff> _allBuffs = [
    WaveBuff(id: 'dmg_boost', name: 'Hasar Artışı', description: '+%10 tüm kule hasarı', icon: '⚔️', value: 0.10),
    WaveBuff(id: 'speed_boost', name: 'Hızlı Atış', description: '+%10 saldırı hızı', icon: '⚡', value: 0.10),
    WaveBuff(id: 'slow_enemy', name: 'Yavaşlat', description: 'Düşmanlar %10 yavaş', icon: '🐢', value: 0.10),
    WaveBuff(id: 'cheap_tower', name: 'Ucuz Kule', description: 'Kule maliyeti %15 düşük', icon: '💰', value: 0.15),
    WaveBuff(id: 'range_boost', name: 'Geniş Menzil', description: '+%10 kule menzili', icon: '🎯', value: 0.10),
    WaveBuff(id: 'castle_heal', name: 'Kale Onarımı', description: 'Kale +4 HP', icon: '🏰', value: 4),
    WaveBuff(id: 'gold_boost', name: 'Altın Avcısı', description: '+%15 altın kazancı', icon: '🪙', value: 0.15),
    WaveBuff(id: 'crit_boost', name: 'Kritik Vuruş', description: '+%5 kritik şans', icon: '💥', value: 0.05),
  ];

  /// Returns true if a buff selection should be shown after [waveNumber].
  static bool shouldOfferBuff(int waveNumber) {
    return waveNumber >= 2 && waveNumber % selectionInterval == 0;
  }

  /// Returns 3 random buff choices. Uses [rng] for determinism if provided.
  static List<WaveBuff> getChoices({Random? rng}) {
    final r = rng ?? Random();
    final shuffled = List<WaveBuff>.from(_allBuffs)..shuffle(r);
    return shuffled.take(3).toList();
  }
}

/// Tracks accumulated buffs for the current run.
class RunBuffState {
  double damageMultiplier = 1.0;
  double fireRateMultiplier = 1.0;
  double enemySpeedMultiplier = 1.0;
  double towerCostMultiplier = 1.0;
  double rangeMultiplier = 1.0;
  double goldMultiplier = 1.0;
  double critBonus = 0.0;
  int castleHealPending = 0;
  final List<WaveBuff> selectedBuffs = [];

  void applyBuff(WaveBuff buff) {
    selectedBuffs.add(buff);
    switch (buff.id) {
      case 'dmg_boost':
        damageMultiplier += buff.value;
      case 'speed_boost':
        fireRateMultiplier *= (1.0 - buff.value); // lower = faster
      case 'slow_enemy':
        enemySpeedMultiplier *= (1.0 - buff.value);
      case 'cheap_tower':
        towerCostMultiplier *= (1.0 - buff.value);
      case 'range_boost':
        rangeMultiplier += buff.value;
      case 'castle_heal':
        castleHealPending += buff.value.round();
      case 'gold_boost':
        // Cap gold boost at 3 stacks (max +75%)
        if (goldMultiplier < 1.75) goldMultiplier += buff.value;
      case 'crit_boost':
        critBonus += buff.value;
    }
  }

  void reset() {
    damageMultiplier = 1.0;
    fireRateMultiplier = 1.0;
    enemySpeedMultiplier = 1.0;
    towerCostMultiplier = 1.0;
    rangeMultiplier = 1.0;
    goldMultiplier = 1.0;
    critBonus = 0.0;
    castleHealPending = 0;
    selectedBuffs.clear();
  }
}
