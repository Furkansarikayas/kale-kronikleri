import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/game/components/map/map_generator.dart';
import 'package:kale_kronikleri/game/data/game_config.dart';
import 'package:kale_kronikleri/game/systems/pathfinding.dart';

void main() {
  test('correct dimensions', () {
    final r = MapGenerator.generate(seed: 42);
    expect(r.grid.length, GameConfig.gridRows);
    expect(r.grid[0].length, GameConfig.gridColumns);
  });
  test('has spawn and castle', () {
    final r = MapGenerator.generate(seed: 42);
    bool hasSpawn = false, hasCastle = false;
    for (final row in r.grid) for (final cell in row) {
      if (cell == CellType.spawn) hasSpawn = true;
      if (cell == CellType.castle) hasCastle = true;
    }
    expect(hasSpawn, true); expect(hasCastle, true);
  });
  test('path exists spawn to castle', () {
    final r = MapGenerator.generate(seed: 42);
    final path = Pathfinding.findPath(grid: r.grid, start: r.spawnPoints.first, end: r.castleEntry);
    expect(path, isNotNull);
    expect(path!.length, greaterThan(5));
  });
  test('different seeds differ', () {
    final r1 = MapGenerator.generate(seed: 1);
    final r2 = MapGenerator.generate(seed: 2);
    bool differs = false;
    for (int r = 0; r < GameConfig.gridRows && !differs; r++)
      for (int c = 0; c < GameConfig.gridColumns && !differs; c++)
        if (r1.grid[r][c] != r2.grid[r][c]) differs = true;
    expect(differs, true);
  });
  test('has pathBuildable', () {
    final r = MapGenerator.generate(seed: 42);
    bool has = false;
    for (final row in r.grid) for (final cell in row) if (cell == CellType.pathBuildable) has = true;
    expect(has, true);
  });
  test('multiple spawns', () {
    final r = MapGenerator.generate(seed: 42, spawnCount: 3);
    expect(r.spawnPoints.length, 3);
    for (final sp in r.spawnPoints) {
      final path = Pathfinding.findPath(grid: r.grid, start: sp, end: r.castleEntry);
      expect(path, isNotNull);
    }
  });
}
