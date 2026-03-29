import '../data/game_config.dart';
import '../data/wave_data.dart';

class WaveSystem {
  final DifficultyTier difficulty;
  final int? mapSeed;
  int _currentWave = 0;
  int _extraWaves = 0;
  List<WaveEntry> _currentComposition = [];

  WaveSystem({required this.difficulty, this.mapSeed});

  int get currentWave => _currentWave;
  int get totalWaves => difficulty.totalWaves + _extraWaves;
  List<WaveEntry> get currentComposition => _currentComposition;
  bool get isComplete => _currentWave >= totalWaves;

  void startNextWave() {
    if (isComplete) return;
    _currentWave++;
    _currentComposition = WaveData.getWave(_currentWave, difficulty, seed: mapSeed);
  }

  /// Extend game by additional waves (infinite mode)
  void extendWaves(int count) {
    _extraWaves += count;
  }
}
