import 'package:shared_preferences/shared_preferences.dart';

class SaveManager {
  final SharedPreferences _prefs;
  SaveManager._(this._prefs);

  static Future<SaveManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SaveManager._(prefs);
  }

  int get stoneSpirit => _prefs.getInt('stone_spirit') ?? 0;
  Future<void> addStoneSpirit(int amount) async => _prefs.setInt('stone_spirit', stoneSpirit + amount);

  int get totalRuns => _prefs.getInt('total_runs') ?? 0;
  Future<void> incrementRuns() async => _prefs.setInt('total_runs', totalRuns + 1);

  int get bestWave => _prefs.getInt('best_wave') ?? 0;
  Future<void> updateBestWave(int wave) async { if (wave > bestWave) await _prefs.setInt('best_wave', wave); }

  int get metaSavas => _prefs.getInt('meta_savas') ?? 0;
  int get metaKesif => _prefs.getInt('meta_kesif') ?? 0;
  int get metaKale => _prefs.getInt('meta_kale') ?? 0;
  int get metaEfsane => _prefs.getInt('meta_efsane') ?? 0;

  int _getMetaLevel(String tree) => _prefs.getInt('meta_$tree') ?? 0;

  Future<bool> unlockMetaNode(String tree, {required int cost}) async {
    if (stoneSpirit < cost) return false;
    await _prefs.setInt('stone_spirit', stoneSpirit - cost);
    await _prefs.setInt('meta_$tree', _getMetaLevel(tree) + 1);
    return true;
  }

  List<int> get discoveredSynergies {
    final raw = _prefs.getStringList('discovered_synergies') ?? [];
    return raw.map(int.parse).toList();
  }

  Future<void> discoverSynergy(int id) async {
    final current = discoveredSynergies;
    if (!current.contains(id)) {
      current.add(id);
      await _prefs.setStringList('discovered_synergies', current.map((e) => e.toString()).toList());
    }
  }

  int get totalKills => _prefs.getInt('total_kills') ?? 0;
  int get bestDifficulty => _prefs.getInt('best_difficulty') ?? 0;
  Future<void> addKills(int count) async => _prefs.setInt('total_kills', totalKills + count);
  Future<void> updateBestDifficulty(int diff) async { if (diff > bestDifficulty) await _prefs.setInt('best_difficulty', diff); }

  bool get soundEnabled => _prefs.getBool('sound_enabled') ?? true;
  bool get musicEnabled => _prefs.getBool('music_enabled') ?? true;
  Future<void> setSoundEnabled(bool v) async => _prefs.setBool('sound_enabled', v);
  Future<void> setMusicEnabled(bool v) async => _prefs.setBool('music_enabled', v);
}
