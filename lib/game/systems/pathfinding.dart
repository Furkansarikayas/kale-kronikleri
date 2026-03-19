import 'dart:collection';
import '../data/game_config.dart';

typedef GridPos = ({int col, int row});

class Pathfinding {
  Pathfinding._();

  static bool _isWalkable(CellType type) {
    return type == CellType.path ||
           type == CellType.pathBuildable ||
           type == CellType.spawn ||
           type == CellType.castle;
  }

  static List<GridPos>? findPath({
    required List<List<CellType>> grid,
    required GridPos start,
    required GridPos end,
  }) {
    final rows = grid.length;
    final cols = grid[0].length;
    if (!_inBounds(start, rows, cols) || !_inBounds(end, rows, cols)) return null;

    final openSet = SplayTreeSet<_Node>((a, b) {
      final cmp = a.f.compareTo(b.f);
      if (cmp != 0) return cmp;
      final cmp2 = a.pos.row.compareTo(b.pos.row);
      if (cmp2 != 0) return cmp2;
      return a.pos.col.compareTo(b.pos.col);
    });

    final gScore = <GridPos, double>{};
    final cameFrom = <GridPos, GridPos>{};
    gScore[start] = 0;
    openSet.add(_Node(start, _heuristic(start, end)));

    final directions = [(0, 1), (0, -1), (1, 0), (-1, 0)];

    while (openSet.isNotEmpty) {
      final current = openSet.first;
      openSet.remove(current);
      if (current.pos == end) return _reconstructPath(cameFrom, end);

      for (final (dr, dc) in directions) {
        final neighbor = (col: current.pos.col + dc, row: current.pos.row + dr);
        if (!_inBounds(neighbor, rows, cols)) continue;
        if (!_isWalkable(grid[neighbor.row][neighbor.col])) continue;

        final tentativeG = (gScore[current.pos] ?? double.infinity) + 1;
        if (tentativeG < (gScore[neighbor] ?? double.infinity)) {
          cameFrom[neighbor] = current.pos;
          gScore[neighbor] = tentativeG;
          openSet.add(_Node(neighbor, tentativeG + _heuristic(neighbor, end)));
        }
      }
    }
    return null;
  }

  static bool _inBounds(GridPos pos, int rows, int cols) =>
      pos.row >= 0 && pos.row < rows && pos.col >= 0 && pos.col < cols;

  static double _heuristic(GridPos a, GridPos b) =>
      ((a.col - b.col).abs() + (a.row - b.row).abs()).toDouble();

  static List<GridPos> _reconstructPath(Map<GridPos, GridPos> cameFrom, GridPos current) {
    final path = [current];
    var node = current;
    while (cameFrom.containsKey(node)) {
      node = cameFrom[node]!;
      path.add(node);
    }
    return path.reversed.toList();
  }
}

class _Node {
  final GridPos pos;
  final double f;
  _Node(this.pos, this.f);
}
