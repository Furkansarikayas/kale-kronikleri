import '../../data/tower_data.dart';
import 'tower.dart';

class TowerFactory {
  TowerFactory._();

  static Tower create({
    required TowerType type,
    required int col,
    required int row,
    required double cellSize,
  }) {
    return Tower(
      type: type,
      col: col,
      row: row,
      cellSize: cellSize,
    );
  }
}
