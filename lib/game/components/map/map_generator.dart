import 'dart:math';
import '../../data/game_config.dart';
import '../../systems/pathfinding.dart';

class MapResult {
  final List<List<CellType>> grid;
  final List<GridPos> spawnPoints;
  final GridPos castleEntry;
  MapResult({required this.grid, required this.spawnPoints, required this.castleEntry});
}

class MapGenerator {
  MapGenerator._();

  static MapResult generate({required int seed, int spawnCount = 1}) {
    final rng = Random(seed);
    final rows = GameConfig.gridRows;
    final cols = GameConfig.gridColumns;
    final grid = List.generate(rows, (_) => List.filled(cols, CellType.buildable));

    // Castle (right side, 2x2)
    final castleRow = rows ~/ 2 - 1;
    for (int r = castleRow; r <= castleRow + 1; r++) {
      for (int c = cols - 2; c < cols; c++) {
        grid[r][c] = CellType.castle;
      }
    }
    final castleEntry = (col: cols - 3, row: castleRow);
    grid[castleEntry.row][castleEntry.col] = CellType.path;

    // Spawns (left side)
    final spawnPoints = <GridPos>[];
    final usedRows = <int>{};
    for (int i = 0; i < spawnCount; i++) {
      int spawnRow;
      if (i == 0) {
        spawnRow = rows ~/ 2;
      } else {
        do { spawnRow = 1 + rng.nextInt(rows - 2); }
        while (usedRows.contains(spawnRow) || (spawnRow - rows ~/ 2).abs() < 2);
      }
      usedRows.add(spawnRow);
      grid[spawnRow][0] = CellType.spawn;
      spawnPoints.add((col: 0, row: spawnRow));
    }

    // Carve paths
    for (final spawn in spawnPoints) {
      _carvePath(grid, spawn, castleEntry, rng, rows, cols);
    }

    // Blocked decoration
    for (int i = 0; i < (rows * cols * 0.05).round(); i++) {
      final r = rng.nextInt(rows);
      final c = 2 + rng.nextInt(cols - 4);
      if (grid[r][c] == CellType.buildable) grid[r][c] = CellType.blocked;
    }

    // Mark some path cells as pathBuildable
    int pathCount = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] == CellType.path) {
          pathCount++;
          if (pathCount % 3 == 0) grid[r][c] = CellType.pathBuildable;
        }
      }
    }

    // Validate paths
    for (final spawn in spawnPoints) {
      final path = Pathfinding.findPath(grid: grid, start: spawn, end: castleEntry);
      if (path == null) _carveDirectPath(grid, spawn, castleEntry);
    }

    return MapResult(grid: grid, spawnPoints: spawnPoints, castleEntry: castleEntry);
  }

  static void _carvePath(List<List<CellType>> grid, GridPos from, GridPos to, Random rng, int rows, int cols) {
    var current = from;
    int maxSteps = rows * cols;
    int steps = 0;
    while (current != to && steps < maxSteps) {
      steps++;
      int dc = (to.col - current.col).sign;
      int dr = (to.row - current.row).sign;
      if (rng.nextDouble() < 0.3) {
        if (dc != 0 && dr != 0) { if (rng.nextBool()) dc = 0; else dr = 0; }
        else { if (dc == 0) { dc = rng.nextBool() ? 1 : -1; dr = 0; } else { dr = rng.nextBool() ? 1 : -1; dc = 0; } }
      } else {
        if (dc != 0 && dr != 0) { if (rng.nextBool()) dr = 0; else dc = 0; }
      }
      final next = (col: current.col + dc, row: current.row + dr);
      if (next.row >= 0 && next.row < rows && next.col >= 0 && next.col < cols) {
        final cellType = grid[next.row][next.col];
        if (cellType == CellType.buildable || cellType == CellType.path || cellType == CellType.pathBuildable || cellType == CellType.castle || cellType == CellType.spawn) {
          if (cellType == CellType.buildable) grid[next.row][next.col] = CellType.path;
          current = next;
        }
      }
    }
  }

  static void _carveDirectPath(List<List<CellType>> grid, GridPos from, GridPos to) {
    var c = from.col, r = from.row;
    while (c != to.col) {
      c += (to.col - c).sign;
      if (grid[r][c] == CellType.buildable || grid[r][c] == CellType.blocked) grid[r][c] = CellType.path;
    }
    while (r != to.row) {
      r += (to.row - r).sign;
      if (grid[r][c] == CellType.buildable || grid[r][c] == CellType.blocked) grid[r][c] = CellType.path;
    }
  }
}
