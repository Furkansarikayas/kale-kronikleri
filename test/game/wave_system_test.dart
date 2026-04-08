import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/game/data/wave_data.dart';
import 'package:kale_kronikleri/game/data/enemy_data.dart';
import 'package:kale_kronikleri/game/data/game_config.dart';
import 'package:kale_kronikleri/game/systems/wave_system.dart';

void main() {
  test('wave 1 has only easy enemies', () {
    final comp = WaveData.getWave(1, DifficultyTier.apprentice);
    for (final e in comp) {
      final stats = EnemyData.getStats(e.type);
      expect(stats.difficulty, EnemyDifficulty.easy);
    }
  });
  test('wave 10 has shadow lord', () {
    final comp = WaveData.getWave(10, DifficultyTier.apprentice);
    expect(comp.any((e) => e.type == EnemyType.shadowLord), true);
  });
  test('wave 30 has dragon emperor (mega-boss every 30)', () {
    final comp = WaveData.getWave(30, DifficultyTier.apprentice);
    expect(comp.any((e) => e.type == EnemyType.dragonEmperor), true);
  });
  test('enemy count increases', () {
    final w1 = WaveData.getWave(1, DifficultyTier.apprentice);
    final w8 = WaveData.getWave(8, DifficultyTier.apprentice);
    expect(w8.fold<int>(0, (s, e) => s + e.count), greaterThan(w1.fold<int>(0, (s, e) => s + e.count)));
  });
  test('WaveSystem tracks wave', () {
    final ws = WaveSystem(difficulty: DifficultyTier.apprentice);
    expect(ws.currentWave, 0);
    ws.startNextWave();
    expect(ws.currentWave, 1);
    expect(ws.currentComposition, isNotEmpty);
  });
  test('WaveSystem infinite — waves never stop', () {
    final ws = WaveSystem(difficulty: DifficultyTier.apprentice);
    for (int i = 0; i < 100; i++) ws.startNextWave();
    expect(ws.currentWave, 100);
    expect(ws.currentComposition, isNotEmpty);
  });
  test('WaveSystem tierWaves matches difficulty', () {
    final ws = WaveSystem(difficulty: DifficultyTier.apprentice);
    expect(ws.tierWaves, 30);
  });
}
