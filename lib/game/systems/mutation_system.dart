import 'dart:math';

enum MutationType {
  fastEnemies('Hızlı Düşmanlar', 'Tüm düşmanlar %30 hızlı'),
  toughEnemies('Dayanıklı Düşmanlar', 'Düşman canı %40 artmış'),
  cheapTowers('Ucuz Kuleler', 'Kule maliyeti %25 azalmış'),
  expensiveTowers('Pahalı Kuleler', 'Kule maliyeti %30 artmış'),
  richRewards('Zengin Ödüller', 'Altın ödülleri %40 artmış'),
  shortWaves('Kısa Dalgalar', 'Dalga arası %50 kısa'),
  armoredAll('Zırhlı Ordu', 'Tüm düşmanlara +5 zırh'),
  bossRush('Boss Akını', 'Her 5 dalgada boss gelir'),
  ;

  final String displayName;
  final String description;
  const MutationType(this.displayName, this.description);
}

class MutationSystem {
  MutationSystem._();

  /// Returns weekly mutations based on a deterministic seed.
  /// Uses ISO week number: year * 100 + weekOfYear
  static List<MutationType> getWeeklyMutations() {
    final now = DateTime.now();
    final seed = _weekSeed(now);
    return getMutationsForSeed(seed);
  }

  static List<MutationType> getMutationsForSeed(int seed) {
    final rng = Random(seed);
    final mutations = List<MutationType>.from(MutationType.values);
    mutations.shuffle(rng);
    return mutations.take(2).toList();
  }

  static int _weekSeed(DateTime date) {
    // ISO 8601 week calculation
    final jan1 = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(jan1).inDays + 1;
    final weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
    return date.year * 100 + weekNumber;
  }

  /// Apply mutation effects to game parameters
  static double enemySpeedMultiplier(List<MutationType> mutations) {
    return mutations.contains(MutationType.fastEnemies) ? 1.3 : 1.0;
  }

  static double enemyHpMultiplier(List<MutationType> mutations) {
    return mutations.contains(MutationType.toughEnemies) ? 1.4 : 1.0;
  }

  static double towerCostMultiplier(List<MutationType> mutations) {
    if (mutations.contains(MutationType.cheapTowers)) return 0.75;
    if (mutations.contains(MutationType.expensiveTowers)) return 1.3;
    return 1.0;
  }

  static double goldRewardMultiplier(List<MutationType> mutations) {
    return mutations.contains(MutationType.richRewards) ? 1.4 : 1.0;
  }

  static double wavePrepMultiplier(List<MutationType> mutations) {
    return mutations.contains(MutationType.shortWaves) ? 0.5 : 1.0;
  }

  static int bonusArmor(List<MutationType> mutations) {
    return mutations.contains(MutationType.armoredAll) ? 5 : 0;
  }

  static bool isBossRush(List<MutationType> mutations) {
    return mutations.contains(MutationType.bossRush);
  }
}
