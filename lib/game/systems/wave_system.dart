import '../data/game_config.dart';
import '../data/wave_data.dart';

class WaveSystem {
  final DifficultyTier difficulty;
  int _currentWave = 0;
  List<WaveEntry> _currentComposition = [];

  WaveSystem({required this.difficulty});

  int get currentWave => _currentWave;
  List<WaveEntry> get currentComposition => _currentComposition;
  bool get isComplete => _currentWave >= difficulty.totalWaves;

  void startNextWave() {
    if (isComplete) return;
    _currentWave++;
    _currentComposition = WaveData.getWave(_currentWave, difficulty);
  }
}
