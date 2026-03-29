import '../components/map/biome_data.dart';

enum CellType { path, buildable, blocked, castle, spawn, pathBuildable }

enum DifficultyTier {
  apprentice(displayName: 'Çırak', totalWaves: 20, hpMultiplier: 1.0, speedMultiplier: 1.0, spiritMultiplier: 1.0, runsToUnlock: 0, biomeType: BiomeType.forest),
  knight(displayName: 'Şövalye', totalWaves: 25, hpMultiplier: 1.2, speedMultiplier: 1.0, spiritMultiplier: 1.5, runsToUnlock: 5, biomeType: BiomeType.desert),
  lord(displayName: 'Lord', totalWaves: 30, hpMultiplier: 1.4, speedMultiplier: 1.2, spiritMultiplier: 2.5, runsToUnlock: 10, biomeType: BiomeType.snow),
  king(displayName: 'Kral', totalWaves: 35, hpMultiplier: 1.6, speedMultiplier: 1.3, spiritMultiplier: 4.0, runsToUnlock: 20, biomeType: BiomeType.volcano),
  legend(displayName: 'Efsane', totalWaves: 40, hpMultiplier: 2.0, speedMultiplier: 1.5, spiritMultiplier: 8.0, runsToUnlock: 40, biomeType: BiomeType.dark);

  const DifficultyTier({
    required this.displayName,
    required this.totalWaves,
    required this.hpMultiplier,
    required this.speedMultiplier,
    required this.spiritMultiplier,
    required this.runsToUnlock,
    required this.biomeType,
  });

  final String displayName;
  final int totalWaves;
  final double hpMultiplier;
  final double speedMultiplier;
  final double spiritMultiplier;
  final int runsToUnlock;
  final BiomeType biomeType;

  BiomeData get biome => BiomeData.fromDifficulty(name);
}

class GameConfig {
  GameConfig._();
  static const int gridColumns = 12;
  static const int gridRows = 7;
  static const int baseCastleHp = 60;
  static const int startingGold = 200;
  static const double sellRefundRatio = 0.65;
  static const int baseTowerSlots = 8;
  static const double wavePrepTime = 15.0;

  static int calculateDamage(int baseDamage, int armor) {
    if (baseDamage <= 0) return 0;
    final result = baseDamage - armor;
    return result < 1 ? 1 : result;
  }
}
