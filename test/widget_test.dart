import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/game/components/castle.dart';
import 'package:kale_kronikleri/game/components/map/game_map.dart';
import 'package:kale_kronikleri/game/data/game_config.dart';

void main() {
  group('Castle', () {
    test('takes damage correctly', () {
      final castle = Castle(cellSize: 40.0);
      expect(castle.hp, 20);
      castle.takeDamage(5);
      expect(castle.hp, 15);
      expect(castle.isDestroyed, false);
    });

    test('damage reduction works', () {
      final castle = Castle(cellSize: 40.0);
      castle.takeDamage(10, damageReduction: 0.5);
      expect(castle.hp, 15);
    });

    test('cannot go below 0', () {
      final castle = Castle(cellSize: 40.0);
      castle.takeDamage(100);
      expect(castle.hp, 0);
      expect(castle.isDestroyed, true);
    });

    test('heal works', () {
      final castle = Castle(cellSize: 40.0);
      castle.takeDamage(10);
      castle.heal(5);
      expect(castle.hp, 15);
    });

    test('heal cannot exceed max', () {
      final castle = Castle(cellSize: 40.0);
      castle.heal(100);
      expect(castle.hp, 20);
    });
  });

  group('GameMap', () {
    test('canPlaceTower returns true for buildable', () {
      final map = GameMap(cellSize: 40.0);
      map.generate(seed: 42);
      // Find a buildable cell
      bool foundBuildable = false;
      for (int r = 0; r < GameConfig.gridRows; r++) {
        for (int c = 0; c < GameConfig.gridColumns; c++) {
          if (map.grid[r][c] == CellType.buildable) {
            expect(map.canPlaceTower(c, r), true);
            foundBuildable = true;
            break;
          }
        }
        if (foundBuildable) break;
      }
      expect(foundBuildable, true);
    });

    test('canPlaceTower returns false for path', () {
      final map = GameMap(cellSize: 40.0);
      map.generate(seed: 42);
      bool foundPath = false;
      for (int r = 0; r < GameConfig.gridRows; r++) {
        for (int c = 0; c < GameConfig.gridColumns; c++) {
          if (map.grid[r][c] == CellType.path) {
            expect(map.canPlaceTower(c, r), false);
            foundPath = true;
            break;
          }
        }
        if (foundPath) break;
      }
      expect(foundPath, true);
    });

    test('out of bounds returns blocked', () {
      final map = GameMap(cellSize: 40.0);
      map.generate(seed: 42);
      expect(map.cellAt(-1, 0), CellType.blocked);
      expect(map.cellAt(0, -1), CellType.blocked);
      expect(map.cellAt(100, 0), CellType.blocked);
    });

    test('enemyPath is not empty', () {
      final map = GameMap(cellSize: 40.0);
      map.generate(seed: 42);
      expect(map.enemyPath.isNotEmpty, true);
    });
  });
}
