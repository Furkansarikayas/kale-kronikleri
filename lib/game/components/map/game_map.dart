import 'package:flame/components.dart';
import '../../data/game_config.dart';
import '../../systems/pathfinding.dart';
import 'grid_cell.dart';
import 'map_generator.dart';

class GameMap extends Component {
  late List<List<CellType>> grid;
  late List<GridPos> spawnPoints;
  late GridPos castleEntry;
  late double cellSize;
  late List<GridPos> enemyPath;
  late List<List<GridPos>> enemyPaths;

  GameMap({required this.cellSize});

  void generate({required int seed, int spawnCount = 1}) {
    final result = MapGenerator.generate(seed: seed, spawnCount: spawnCount);
    grid = result.grid;
    spawnPoints = result.spawnPoints;
    castleEntry = result.castleEntry;

    // Pre-compute paths for all spawn points
    enemyPaths = [];
    for (final spawn in spawnPoints) {
      final path = Pathfinding.findPath(grid: grid, start: spawn, end: castleEntry);
      if (path != null && path.isNotEmpty) {
        enemyPaths.add(path);
      }
    }
    // Legacy: first path for compatibility
    enemyPath = enemyPaths.isNotEmpty ? enemyPaths.first : [];

    // Add cell components
    for (int r = 0; r < GameConfig.gridRows; r++) {
      for (int c = 0; c < GameConfig.gridColumns; c++) {
        add(GridCell(col: c, row: r, cellType: grid[r][c], cellSize: cellSize));
      }
    }

    // Set neighbor types for edge blending
    for (final child in children.whereType<GridCell>()) {
      child.setNeighbors(
        top: child.row > 0 ? grid[child.row - 1][child.col] : CellType.blocked,
        bottom: child.row < GameConfig.gridRows - 1 ? grid[child.row + 1][child.col] : CellType.blocked,
        left: child.col > 0 ? grid[child.row][child.col - 1] : CellType.blocked,
        right: child.col < GameConfig.gridColumns - 1 ? grid[child.row][child.col + 1] : CellType.blocked,
      );
    }
  }

  CellType cellAt(int col, int row) {
    if (row < 0 || row >= GameConfig.gridRows || col < 0 || col >= GameConfig.gridColumns) {
      return CellType.blocked;
    }
    return grid[row][col];
  }

  bool canPlaceTower(int col, int row, {bool isSpikeWall = false}) {
    final cell = cellAt(col, row);
    if (isSpikeWall) return cell == CellType.pathBuildable;
    return cell == CellType.buildable;
  }
}
