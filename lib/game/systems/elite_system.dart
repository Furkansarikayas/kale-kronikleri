import 'dart:math' as math;
import '../data/enemy_data.dart';

enum EliteModifier { fast, armored, regenerating, splitting }

class EliteSystem {
  static const double eliteChance = 0.15;

  static final Map<EliteModifier, String> modifierNames = {
    EliteModifier.fast: 'Hızlı',
    EliteModifier.armored: 'Zırhlı',
    EliteModifier.regenerating: 'İyileşen',
    EliteModifier.splitting: 'Bölünen',
  };

  /// Roll whether an enemy should be elite (non-boss only)
  static bool shouldBeElite(EnemyType type, math.Random rng) {
    final stats = EnemyData.getStats(type);
    if (stats.isBoss) return false;
    return rng.nextDouble() < eliteChance;
  }

  /// Pick a random elite modifier
  static EliteModifier rollModifier(math.Random rng) {
    return EliteModifier.values[rng.nextInt(EliteModifier.values.length)];
  }
}
