enum CellType { path, buildable, blocked, castle, spawn, pathBuildable }

enum DifficultyTier {
  apprentice(totalWaves: 20, hpMultiplier: 1.0, speedMultiplier: 1.0, spiritMultiplier: 1.0, runsToUnlock: 0),
  knight(totalWaves: 25, hpMultiplier: 1.2, speedMultiplier: 1.0, spiritMultiplier: 1.5, runsToUnlock: 5),
  lord(totalWaves: 30, hpMultiplier: 1.4, speedMultiplier: 1.2, spiritMultiplier: 2.5, runsToUnlock: 0),
  king(totalWaves: 35, hpMultiplier: 1.6, speedMultiplier: 1.0, spiritMultiplier: 4.0, runsToUnlock: 0),
  legend(totalWaves: 40, hpMultiplier: 2.0, speedMultiplier: 1.5, spiritMultiplier: 8.0, runsToUnlock: 0);

  const DifficultyTier({
    required this.totalWaves,
    required this.hpMultiplier,
    required this.speedMultiplier,
    required this.spiritMultiplier,
    required this.runsToUnlock,
  });

  final int totalWaves;
  final double hpMultiplier;
  final double speedMultiplier;
  final double spiritMultiplier;
  final int runsToUnlock;
}

class GameConfig {
  GameConfig._();
  static const int gridColumns = 16;
  static const int gridRows = 10;
  static const int baseCastleHp = 20;
  static const int startingGold = 150;
  static const double sellRefundRatio = 0.6;
  static const int baseTowerSlots = 8;
  static const double wavePrepTime = 10.0;

  static int calculateDamage(int baseDamage, int armor) {
    if (baseDamage <= 0) return 0;
    final result = baseDamage - armor;
    return result < 1 ? 1 : result;
  }
}
