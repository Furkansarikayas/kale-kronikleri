import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight daily/rotating goal system.
/// 2-3 goals per day, reset every 24h based on local time.
class DailyGoals {
  final SharedPreferences _prefs;

  DailyGoals(this._prefs);

  static const _keyLastDate = 'daily_goals_date';
  static const _keyGoalIds = 'daily_goals_ids';
  static const _keyProgress = 'daily_goals_progress';
  static const _keyClaimed = 'daily_goals_claimed';

  /// All possible goals (id, description, target, reward, type).
  static const List<GoalDef> _allGoals = [
    GoalDef(id: 'wave10', desc: 'Dalga 10\'a ulaş', target: 10, reward: 15, type: GoalType.waveReach),
    GoalDef(id: 'wave15', desc: 'Dalga 15\'e ulaş', target: 15, reward: 25, type: GoalType.waveReach),
    GoalDef(id: 'kill100', desc: '100 düşman öldür', target: 100, reward: 10, type: GoalType.kills),
    GoalDef(id: 'kill200', desc: '200 düşman öldür', target: 200, reward: 20, type: GoalType.kills),
    GoalDef(id: 'boss1', desc: '1 Boss yen', target: 1, reward: 20, type: GoalType.bossKills),
    GoalDef(id: 'perfect3', desc: '3 kusursuz dalga', target: 3, reward: 15, type: GoalType.perfectWaves),
    GoalDef(id: 'combo10', desc: 'x10 kombo yap', target: 10, reward: 12, type: GoalType.bestCombo),
    GoalDef(id: 'tower8', desc: '8 kule yerleştir', target: 8, reward: 10, type: GoalType.towersPlaced),
    GoalDef(id: 'synergy2', desc: '2 sinerji oluştur', target: 2, reward: 15, type: GoalType.synergies),
    GoalDef(id: 'run3', desc: '3 koşu tamamla', target: 3, reward: 20, type: GoalType.runs),
  ];

  /// Get today's date string (YYYY-MM-DD).
  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Check if goals need refresh; if so, pick new ones.
  void ensureRefreshed() {
    final lastDate = _prefs.getString(_keyLastDate) ?? '';
    if (lastDate != _today()) {
      _rollNewGoals();
    }
  }

  void _rollNewGoals() {
    final today = _today();
    // Deterministic seed from date so all sessions see same goals
    final seed = today.hashCode;
    final shuffled = List<GoalDef>.from(_allGoals)..shuffle(Random(seed));
    final picked = shuffled.take(3).map((g) => g.id).toList();

    _prefs.setString(_keyLastDate, today);
    _prefs.setStringList(_keyGoalIds, picked);
    _prefs.setStringList(_keyProgress, ['0', '0', '0']);
    _prefs.setStringList(_keyClaimed, ['false', 'false', 'false']);
  }

  /// Current active goals.
  List<ActiveGoal> get activeGoals {
    final ids = _prefs.getStringList(_keyGoalIds) ?? [];
    final progress = _prefs.getStringList(_keyProgress) ?? [];
    final claimed = _prefs.getStringList(_keyClaimed) ?? [];
    if (ids.isEmpty) return [];

    final goals = <ActiveGoal>[];
    for (int i = 0; i < ids.length; i++) {
      final def = _allGoals.firstWhere((g) => g.id == ids[i], orElse: () => _allGoals[0]);
      goals.add(ActiveGoal(
        def: def,
        progress: i < progress.length ? int.tryParse(progress[i]) ?? 0 : 0,
        claimed: i < claimed.length ? claimed[i] == 'true' : false,
      ));
    }
    return goals;
  }

  /// Update progress after a run completes.
  /// Returns total spirit earned from newly completed goals.
  int updateAfterRun({
    required int wavesReached,
    required int enemiesKilled,
    required int bossesKilled,
    required int perfectWaves,
    required int bestCombo,
    required int towersPlaced,
    required int synergiesFormed,
  }) {
    ensureRefreshed();
    final ids = _prefs.getStringList(_keyGoalIds) ?? [];
    final progress = _prefs.getStringList(_keyProgress) ?? [];
    final claimed = _prefs.getStringList(_keyClaimed) ?? [];
    if (ids.isEmpty) return 0;

    int spiritGained = 0;

    for (int i = 0; i < ids.length; i++) {
      if (i >= claimed.length || claimed[i] == 'true') continue;

      final def = _allGoals.firstWhere((g) => g.id == ids[i], orElse: () => _allGoals[0]);
      int current = i < progress.length ? int.tryParse(progress[i]) ?? 0 : 0;

      // Accumulate progress based on goal type
      switch (def.type) {
        case GoalType.waveReach:
          if (wavesReached > current) current = wavesReached;
          break;
        case GoalType.kills:
          current += enemiesKilled;
          break;
        case GoalType.bossKills:
          current += bossesKilled;
          break;
        case GoalType.perfectWaves:
          current += perfectWaves;
          break;
        case GoalType.bestCombo:
          if (bestCombo > current) current = bestCombo;
          break;
        case GoalType.towersPlaced:
          current += towersPlaced;
          break;
        case GoalType.synergies:
          current += synergiesFormed;
          break;
        case GoalType.runs:
          current += 1;
          break;
      }

      // Cap progress at target
      if (current > def.target) current = def.target;

      // Update progress
      while (progress.length <= i) progress.add('0');
      progress[i] = current.toString();

      // Auto-claim if complete
      if (current >= def.target) {
        while (claimed.length <= i) claimed.add('false');
        claimed[i] = 'true';
        spiritGained += def.reward;
      }
    }

    _prefs.setStringList(_keyProgress, progress);
    _prefs.setStringList(_keyClaimed, claimed);
    return spiritGained;
  }
}

enum GoalType { waveReach, kills, bossKills, perfectWaves, bestCombo, towersPlaced, synergies, runs }

class GoalDef {
  final String id;
  final String desc;
  final int target;
  final int reward;
  final GoalType type;

  const GoalDef({required this.id, required this.desc, required this.target, required this.reward, required this.type});
}

class ActiveGoal {
  final GoalDef def;
  final int progress;
  final bool claimed;

  ActiveGoal({required this.def, required this.progress, required this.claimed});

  bool get isComplete => progress >= def.target;
  double get fraction => (progress / def.target).clamp(0.0, 1.0);
}

