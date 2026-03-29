import '../components/enemies/status_effect.dart';

enum ComboType { frozen, meltdown, soulShatter }

class ComboDef {
  final ComboType type;
  final String name;
  final double duration;

  const ComboDef({required this.type, required this.name, required this.duration});
}

class ComboSystem {
  static const List<ComboDef> combos = [
    ComboDef(type: ComboType.frozen, name: 'DONMUŞ', duration: 5.0),
    ComboDef(type: ComboType.meltdown, name: 'ERİME', duration: 4.0),
    ComboDef(type: ComboType.soulShatter, name: 'RUH PARÇALAMA', duration: 5.0),
  ];

  // Track active combos per enemy to avoid re-triggering
  final Map<int, Map<ComboType, double>> _activeTimers = {};
  int _combosTriggered = 0;
  int get combosTriggered => _combosTriggered;

  void update(double dt) {
    final toRemove = <int>[];
    for (final entry in _activeTimers.entries) {
      final timers = entry.value;
      timers.updateAll((_, remaining) => remaining - dt);
      timers.removeWhere((_, remaining) => remaining <= 0);
      if (timers.isEmpty) toRemove.add(entry.key);
    }
    for (final id in toRemove) {
      _activeTimers.remove(id);
    }
  }

  /// Check if any combo should trigger on this enemy.
  /// Returns the combo type if triggered, null otherwise.
  ComboType? checkCombos(List<StatusEffect> effects, int enemyId) {
    final activeTypes = effects
        .where((e) => !e.isExpired)
        .map((e) => e.type)
        .toSet();

    // Frozen: wet + slow
    if (activeTypes.contains(StatusType.wet) && activeTypes.contains(StatusType.slow)) {
      if (!_isComboActive(enemyId, ComboType.frozen)) {
        _activateCombo(enemyId, ComboType.frozen, 5.0);
        return ComboType.frozen;
      }
    }

    // Meltdown: burn + poison
    if (activeTypes.contains(StatusType.burn) && activeTypes.contains(StatusType.poison)) {
      if (!_isComboActive(enemyId, ComboType.meltdown)) {
        _activateCombo(enemyId, ComboType.meltdown, 4.0);
        return ComboType.meltdown;
      }
    }

    // Soul Shatter: curse + wet (lightning proxy via wet status)
    if (activeTypes.contains(StatusType.curse) && activeTypes.contains(StatusType.wet)) {
      if (!_isComboActive(enemyId, ComboType.soulShatter)) {
        _activateCombo(enemyId, ComboType.soulShatter, 5.0);
        return ComboType.soulShatter;
      }
    }

    return null;
  }

  bool _isComboActive(int enemyId, ComboType type) {
    return _activeTimers[enemyId]?.containsKey(type) ?? false;
  }

  void _activateCombo(int enemyId, ComboType type, double duration) {
    _activeTimers.putIfAbsent(enemyId, () => {});
    _activeTimers[enemyId]![type] = duration;
    _combosTriggered++;
  }

  void removeEnemy(int enemyId) {
    _activeTimers.remove(enemyId);
  }
}
