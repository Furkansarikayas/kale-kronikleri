import '../../data/enemy_data.dart';
import '../../data/game_config.dart';
import '../../systems/pathfinding.dart';
import 'enemy.dart';

class EnemyFactory {
  EnemyFactory._();

  static Enemy create({
    required EnemyType type,
    required List<GridPos> path,
    required double cellSize,
    DifficultyTier difficulty = DifficultyTier.apprentice,
  }) {
    final baseStats = EnemyData.getStats(type).withDifficulty(difficulty);
    return Enemy(
      type: type,
      baseStats: baseStats,
      path: path,
      cellSize: cellSize,
    );
  }
}
