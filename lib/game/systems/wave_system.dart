import '../data/game_config.dart';
import '../data/wave_data.dart';

class WaveSystem {
  final DifficultyTier difficulty;
  final int? mapSeed;
  int _currentWave = 0;
  List<WaveEntry> _currentComposition = [];

  WaveSystem({required this.difficulty, this.mapSeed});

  int get currentWave => _currentWave;
  /// Tier milestone wave count (used for scaling reference, not as a cap).
  int get tierWaves => difficulty.totalWaves;
  List<WaveEntry> get currentComposition => _currentComposition;

  void startNextWave() {
    _currentWave++;
    _currentComposition = WaveData.getWave(_currentWave, difficulty, seed: mapSeed);
  }
}
