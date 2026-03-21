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

    // Final boss wave
    if (waveNumber == totalWaves) {
      entries.add(const WaveEntry(type: EnemyType.dragonEmperor, count: 1, spawnDelay: 0));
      entries.add(const WaveEntry(type: EnemyType.darkKnight, count: 3));
      entries.add(WaveEntry(type: EnemyType.healer, count: 1 + totalWaves ~/ 15));
      entries.add(WaveEntry(type: EnemyType.soldier, count: 5 + totalWaves ~/ 5));
      return entries;
    }

    // Mid-boss waves (every 10)
    if (waveNumber % 10 == 0) {
      entries.add(const WaveEntry(type: EnemyType.shadowLord, count: 1, spawnDelay: 0));
      entries.add(WaveEntry(type: EnemyType.armoredGiant, count: 2 + waveNumber ~/ 15));
      entries.add(WaveEntry(type: EnemyType.healer, count: waveNumber ~/ 10));
      entries.add(WaveEntry(type: EnemyType.soldier, count: 4 + waveNumber ~/ 5));
      return entries;
    }

    // Mini-boss waves (every 5)
    if (waveNumber > 5 && waveNumber % 5 == 0) {
      entries.add(WaveEntry(type: EnemyType.troll, count: 1 + waveNumber ~/ 15));
      entries.add(WaveEntry(type: EnemyType.darkKnight, count: waveNumber ~/ 10));
      entries.add(WaveEntry(type: EnemyType.shieldBearer, count: 2 + waveNumber ~/ 8));
      entries.add(WaveEntry(type: EnemyType.cavalry, count: 3 + waveNumber ~/ 6));
      return entries;
    }

    final baseCount = 2 + waveNumber;

    // Early waves (1-5): introduce basic enemies
    if (waveNumber <= 5) {
      final types = [EnemyType.soldier, EnemyType.soldier, EnemyType.goblin, EnemyType.cavalry, EnemyType.cavalry];
      entries.add(WaveEntry(type: types[(waveNumber - 1) % types.length], count: baseCount, spawnDelay: waveNumber <= 2 ? 1.2 : 0.8));
    }
    // Mid waves (6-10): introduce medium enemies
    else if (waveNumber <= 10) {
      entries.add(WaveEntry(type: EnemyType.soldier, count: baseCount ~/ 2));
      final med = [EnemyType.armoredGiant, EnemyType.undead, EnemyType.shieldBearer, EnemyType.healer];
      entries.add(WaveEntry(type: med[(waveNumber - 6) % med.length], count: baseCount ~/ 3 + 1));
    }
    // Hard waves (11-20): introduce hard enemies
    else if (waveNumber <= 20) {
      entries.add(WaveEntry(type: EnemyType.soldier, count: baseCount ~/ 3));
      entries.add(WaveEntry(type: EnemyType.armoredGiant, count: baseCount ~/ 4 + 1));
      final hard = [EnemyType.burrower, EnemyType.troll, EnemyType.darkKnight, EnemyType.burrower];
      entries.add(WaveEntry(type: hard[(waveNumber - 11) % hard.length], count: 1 + waveNumber ~/ 8));
      // Healers start appearing in groups
      if (waveNumber >= 14) {
        entries.add(WaveEntry(type: EnemyType.healer, count: 1 + (waveNumber - 14) ~/ 3));
      }
    }
    // Late game (21+): everything mixed, higher counts
    else {
      entries.add(WaveEntry(type: EnemyType.cavalry, count: baseCount ~/ 3));
      entries.add(WaveEntry(type: EnemyType.armoredGiant, count: baseCount ~/ 4));
      entries.add(WaveEntry(type: EnemyType.darkKnight, count: 1 + waveNumber ~/ 10));
      entries.add(WaveEntry(type: EnemyType.troll, count: 1 + (waveNumber - 20) ~/ 5));
      entries.add(WaveEntry(type: EnemyType.burrower, count: 1 + (waveNumber - 20) ~/ 6));
      entries.add(WaveEntry(type: EnemyType.healer, count: 1 + (waveNumber - 20) ~/ 4));
      // Undead hordes
      if (waveNumber % 3 == 0) {
        entries.add(WaveEntry(type: EnemyType.undead, count: 3 + waveNumber ~/ 8));
      }
    }
    return entries;
  }
}
