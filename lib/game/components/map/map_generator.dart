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

    // Spawns — distributed across map height zones
    final spawnPoints = <GridPos>[];
    final zoneRows = _distributeSpawns(spawnCount, rows, rng);
    for (final spawnRow in zoneRows) {
      grid[spawnRow][0] = CellType.spawn;
      spawnPoints.add((col: 0, row: spawnRow));
    }

    // Carve paths — each spawn gets a biased path that stays in its zone
    for (int i = 0; i < spawnPoints.length; i++) {
      _carveZonedPath(grid, spawnPoints[i], castleEntry, rng, rows, cols, i, spawnPoints.length);
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

  /// Distributes spawn rows across vertical zones so paths are visually distinct.
  /// 2 spawns → top third + bottom third
  /// 3 spawns → top + middle + bottom
  static List<int> _distributeSpawns(int count, int rows, Random rng) {
    if (count <= 1) {
      return [rows ~/ 2];
    }
    if (count == 2) {
      // Top zone: rows 1..(rows/3), Bottom zone: rows (2*rows/3)..(rows-2)
      final topZone = 1 + rng.nextInt((rows ~/ 3).clamp(1, rows - 2));
      int bottomZone;
      do {
        bottomZone = (rows * 2 ~/ 3) + rng.nextInt((rows ~/ 3).clamp(1, rows - 2));
      } while (bottomZone >= rows - 1 || bottomZone == topZone);
      return [topZone, bottomZone];
    }
    // 3 spawns: top + middle + bottom
    final top = 1 + rng.nextInt((rows ~/ 4).clamp(1, rows - 2));
    final mid = rows ~/ 2 + (rng.nextBool() ? 0 : (rng.nextBool() ? -1 : 1));
    int bottom;
    do {
      bottom = rows - 2 - rng.nextInt((rows ~/ 4).clamp(1, rows - 2));
    } while (bottom <= mid || bottom >= rows - 1);
    return [top, mid.clamp(2, rows - 3), bottom];
  }

  /// Carves a path that tends to stay in its vertical zone for the first 60% of
  /// the map, then converges toward the castle entry. This ensures visually
  /// distinct routes from each spawn point.
  static void _carveZonedPath(
    List<List<CellType>> grid, GridPos from, GridPos to,
    Random rng, int rows, int cols, int zoneIndex, int totalZones,
  ) {
    var current = from;
    int maxSteps = rows * cols * 2;
    int steps = 0;
    // Zone center row — path tries to stay near this in the first portion
    final zoneCenter = from.row;
    // Convergence column — after this, path heads straight to castle
    final convergeCol = (cols * 0.6).round();

    while (current != to && steps < maxSteps) {
      steps++;
      int dc = (to.col - current.col).sign;
      int dr = (to.row - current.row).sign;

      final inZonePhase = current.col < convergeCol;

      if (inZonePhase) {
        // Bias horizontal movement to spread paths apart
        if (rng.nextDouble() < 0.65) {
          // Move horizontally
          dr = 0;
          dc = 1; // always toward castle
        } else {
          // Move vertically but bias toward zone center
          dc = 0;
          final drift = zoneCenter - current.row;
          if (drift != 0) {
            dr = drift.sign;
          } else {
            dr = rng.nextBool() ? 1 : -1;
          }
          // Random wander adds variety
          if (rng.nextDouble() < 0.4) {
            dr = rng.nextBool() ? 1 : -1;
          }
        }
      } else {
        // Convergence phase — head toward castle entry
        if (rng.nextDouble() < 0.3) {
          // Small random deviation for organic look
          if (dc != 0 && dr != 0) {
            if (rng.nextBool()) dc = 0; else dr = 0;
          } else {
            if (dc == 0) { dc = rng.nextBool() ? 1 : -1; dr = 0; }
            else { dr = rng.nextBool() ? 1 : -1; dc = 0; }
          }
        } else {
          if (dc != 0 && dr != 0) { if (rng.nextBool()) dr = 0; else dc = 0; }
        }
      }

      final next = (col: current.col + dc, row: current.row + dr);
      if (next.row >= 0 && next.row < rows && next.col >= 0 && next.col < cols) {
        final cellType = grid[next.row][next.col];
        if (cellType == CellType.buildable || cellType == CellType.path ||
            cellType == CellType.pathBuildable || cellType == CellType.castle ||
            cellType == CellType.spawn) {
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
