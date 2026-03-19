import '../data/synergy_data.dart';
import '../data/tower_data.dart';
import '../data/game_config.dart';

/// Manages active synergies based on tower adjacency.
/// Call recalculate() when towers are placed or removed.
class SynergySystem {
  final Map<int, ActiveSynergy> _activeSynergies = {};

  List<ActiveSynergy> get activeSynergies => _activeSynergies.values.toList();

  /// Recalculate all synergies given current tower placements.
  /// [towers] is a map of (col, row) -> TowerType
  List<ActiveSynergy> recalculate(Map<({int col, int row}), TowerType> towers) {
    _activeSynergies.clear();

    for (final entry in towers.entries) {
      final pos = entry.key;
      final counts = _getAdjacentTypeCounts(pos, towers);

      final matches = _findMatchingSynergiesByCounts(counts);
      for (final synergy in matches) {
        if (!_activeSynergies.containsKey(synergy.id)) {
          _activeSynergies[synergy.id] = ActiveSynergy(
            definition: synergy,
            anchorPosition: pos,
          );
        }
      }
    }

    return activeSynergies;
  }

  /// Count tower types in the 8-directional neighborhood including self.
  Map<TowerType, int> _getAdjacentTypeCounts(
    ({int col, int row}) pos,
    Map<({int col, int row}), TowerType> towers,
  ) {
    final counts = <TowerType, int>{};

    // Include self
    final selfType = towers[pos]!;
    counts[selfType] = (counts[selfType] ?? 0) + 1;

    // 8-directional neighbors
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final neighbor = (col: pos.col + dc, row: pos.row + dr);
        if (neighbor.row < 0 || neighbor.row >= GameConfig.gridRows) continue;
        if (neighbor.col < 0 || neighbor.col >= GameConfig.gridColumns) continue;
        final towerType = towers[neighbor];
        if (towerType != null) {
          counts[towerType] = (counts[towerType] ?? 0) + 1;
        }
      }
    }

    return counts;
  }

  /// Find synergies whose required tower counts are satisfied by [available].
  List<SynergyDef> _findMatchingSynergiesByCounts(Map<TowerType, int> available) {
    return SynergyData.all.where((synergy) {
      final required = <TowerType, int>{};
      for (final t in synergy.requiredTowers) {
        required[t] = (required[t] ?? 0) + 1;
      }
      for (final entry in required.entries) {
        if ((available[entry.key] ?? 0) < entry.value) return false;
      }
      return true;
    }).toList();
  }

  bool hasSynergy(int synergyId) => _activeSynergies.containsKey(synergyId);
}

class ActiveSynergy {
  final SynergyDef definition;
  final ({int col, int row}) anchorPosition;

  ActiveSynergy({required this.definition, required this.anchorPosition});

  String get name => definition.name;
  int get id => definition.id;
}
