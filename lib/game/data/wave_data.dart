import 'enemy_data.dart';
import 'game_config.dart';

class WaveEntry {
  final EnemyType type;
  final int count;
  final double spawnDelay;
  const WaveEntry({required this.type, required this.count, this.spawnDelay = 0.8});
}

class WaveData {
  WaveData._();
  static List<WaveEntry> getWave(int waveNumber, DifficultyTier difficulty) {
    final totalWaves = difficulty.totalWaves;
    final entries = <WaveEntry>[];

    if (waveNumber == totalWaves) {
      entries.add(const WaveEntry(type: EnemyType.dragonEmperor, count: 1, spawnDelay: 0));
      entries.add(const WaveEntry(type: EnemyType.darkKnight, count: 2));
      entries.add(const WaveEntry(type: EnemyType.soldier, count: 5));
      return entries;
    }
    if (waveNumber % 10 == 0) {
      entries.add(const WaveEntry(type: EnemyType.shadowLord, count: 1, spawnDelay: 0));
      entries.add(const WaveEntry(type: EnemyType.armoredGiant, count: 2));
      entries.add(const WaveEntry(type: EnemyType.soldier, count: 4));
      return entries;
    }

    final baseCount = 2 + waveNumber;
    if (waveNumber <= 5) {
      final types = [EnemyType.soldier, EnemyType.soldier, EnemyType.goblin, EnemyType.cavalry, EnemyType.cavalry];
      entries.add(WaveEntry(type: types[(waveNumber - 1) % types.length], count: baseCount, spawnDelay: waveNumber <= 2 ? 1.2 : 0.8));
    } else if (waveNumber <= 10) {
      entries.add(WaveEntry(type: EnemyType.soldier, count: baseCount ~/ 2));
      final med = [EnemyType.armoredGiant, EnemyType.undead, EnemyType.shieldBearer, EnemyType.healer];
      entries.add(WaveEntry(type: med[(waveNumber - 6) % med.length], count: baseCount ~/ 3 + 1));
    } else if (waveNumber <= 15) {
      entries.add(WaveEntry(type: EnemyType.soldier, count: baseCount ~/ 3));
      entries.add(WaveEntry(type: EnemyType.armoredGiant, count: baseCount ~/ 4 + 1));
      final hard = [EnemyType.burrower, EnemyType.troll, EnemyType.darkKnight];
      entries.add(WaveEntry(type: hard[(waveNumber - 11) % hard.length], count: 1 + waveNumber ~/ 8));
    } else {
      entries.add(WaveEntry(type: EnemyType.cavalry, count: baseCount ~/ 3));
      entries.add(WaveEntry(type: EnemyType.armoredGiant, count: baseCount ~/ 4));
      entries.add(WaveEntry(type: EnemyType.darkKnight, count: 1 + waveNumber ~/ 10));
      entries.add(const WaveEntry(type: EnemyType.troll, count: 1));
    }
    return entries;
  }
}
