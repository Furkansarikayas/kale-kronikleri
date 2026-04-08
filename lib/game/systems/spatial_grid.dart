import '../components/enemies/enemy.dart';

/// Grid-based spatial partitioning for fast range queries.
/// Avoids O(N*M) full enemy list scans for tower targeting, splash damage, etc.
class SpatialGrid {
  static const double _cellSize = 128.0; // 2 game cells (64px each)
  static const int _cols = 7; // ceil(768/128) + 1
  static const int _rows = 5; // ceil(448/128) + 1
  static const int _totalCells = _cols * _rows;

  // Flat array of buckets — each bucket is a growable list of enemies
  final List<List<Enemy>> _cells = List.generate(_totalCells, (_) => <Enemy>[]);

  // Reusable result list for queries (caller must use before next query)
  final List<Enemy> _queryResult = [];

  /// Rebuild the grid from the current enemy list. Call once per frame.
  void rebuild(List<Enemy> enemies) {
    // Clear all cells
    for (int i = 0; i < _totalCells; i++) {
      _cells[i].clear();
    }

    // Insert live enemies
    for (int i = 0; i < enemies.length; i++) {
      final e = enemies[i];
      if (e.isDead || e.reachedCastle) continue;
      final col = (e.position.x / _cellSize).floor().clamp(0, _cols - 1);
      final row = (e.position.y / _cellSize).floor().clamp(0, _rows - 1);
      _cells[row * _cols + col].add(e);
    }
  }

  /// Query all live enemies within [range] pixels of ([cx], [cy]).
  /// Returns internal list — use immediately, do not store.
  List<Enemy> queryRange(double cx, double cy, double range) {
    _queryResult.clear();
    final rangeSq = range * range;

    // Compute cell range to check
    final minCol = ((cx - range) / _cellSize).floor().clamp(0, _cols - 1);
    final maxCol = ((cx + range) / _cellSize).floor().clamp(0, _cols - 1);
    final minRow = ((cy - range) / _cellSize).floor().clamp(0, _rows - 1);
    final maxRow = ((cy + range) / _cellSize).floor().clamp(0, _rows - 1);

    for (int r = minRow; r <= maxRow; r++) {
      final rowOffset = r * _cols;
      for (int c = minCol; c <= maxCol; c++) {
        final bucket = _cells[rowOffset + c];
        for (int i = 0; i < bucket.length; i++) {
          final e = bucket[i];
          if (e.isBurrowed) continue;
          final dx = cx - e.position.x;
          final dy = cy - e.position.y;
          if (dx * dx + dy * dy <= rangeSq) {
            _queryResult.add(e);
          }
        }
      }
    }
    return _queryResult;
  }

  /// Query enemies within range, excluding burrowed AND a specific enemy.
  /// Used for splash damage where primary target is excluded.
  List<Enemy> queryRangeExcluding(double cx, double cy, double range, Enemy exclude) {
    _queryResult.clear();
    final rangeSq = range * range;

    final minCol = ((cx - range) / _cellSize).floor().clamp(0, _cols - 1);
    final maxCol = ((cx + range) / _cellSize).floor().clamp(0, _cols - 1);
    final minRow = ((cy - range) / _cellSize).floor().clamp(0, _rows - 1);
    final maxRow = ((cy + range) / _cellSize).floor().clamp(0, _rows - 1);

    for (int r = minRow; r <= maxRow; r++) {
      final rowOffset = r * _cols;
      for (int c = minCol; c <= maxCol; c++) {
        final bucket = _cells[rowOffset + c];
        for (int i = 0; i < bucket.length; i++) {
          final e = bucket[i];
          if (e == exclude || e.isBurrowed) continue;
          final dx = cx - e.position.x;
          final dy = cy - e.position.y;
          if (dx * dx + dy * dy <= rangeSq) {
            _queryResult.add(e);
          }
        }
      }
    }
    return _queryResult;
  }
}
