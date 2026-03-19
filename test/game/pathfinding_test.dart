import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/game/systems/pathfinding.dart';
import 'package:kale_kronikleri/game/data/game_config.dart';

void main() {
  test('finds path on simple grid', () {
    final grid = List.generate(3, (r) => List.generate(5, (c) => CellType.path));
    grid[1][2] = CellType.blocked;
    final path = Pathfinding.findPath(grid: grid, start: (col: 0, row: 1), end: (col: 4, row: 1));
    expect(path, isNotNull);
    expect(path!.first, (col: 0, row: 1));
    expect(path.last, (col: 4, row: 1));
    expect(path.contains((col: 2, row: 1)), isFalse);
  });

  test('returns null when no path', () {
    final grid = List.generate(3, (r) => List.generate(5, (c) => CellType.path));
    for (int r = 0; r < 3; r++) grid[r][2] = CellType.blocked;
    final path = Pathfinding.findPath(grid: grid, start: (col: 0, row: 1), end: (col: 4, row: 1));
    expect(path, isNull);
  });

  test('buildable cells blocked for enemies', () {
    final grid = List.generate(3, (r) => List.generate(5, (c) => CellType.path));
    grid[1][2] = CellType.buildable;
    final path = Pathfinding.findPath(grid: grid, start: (col: 0, row: 1), end: (col: 4, row: 1));
    expect(path, isNotNull);
    expect(path!.contains((col: 2, row: 1)), isFalse);
  });

  test('pathBuildable cells are walkable', () {
    final grid = List.generate(3, (r) => List.generate(5, (c) => CellType.buildable));
    grid[1][0] = CellType.path;
    grid[1][1] = CellType.pathBuildable;
    grid[1][2] = CellType.path;
    grid[1][3] = CellType.pathBuildable;
    grid[1][4] = CellType.path;
    final path = Pathfinding.findPath(grid: grid, start: (col: 0, row: 1), end: (col: 4, row: 1));
    expect(path, isNotNull);
    expect(path!.length, 5);
  });
}
