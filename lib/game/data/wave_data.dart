import 'dart:math';

import 'enemy_data.dart';
import 'game_config.dart';

class WaveEntry {
  final EnemyType type;
  final int count;
  final double spawnDelay;
  const WaveEntry({required this.type, required this.count, this.spawnDelay = 0.6});
}

/// Controls how enemies distribute across available paths in a wave.
enum WavePathPattern {
  /// Enemies spread evenly across all paths (round-robin)
  spread,
  /// All enemies come from one specific path
  focused,
  /// Enemies come from the two outermost paths (pincer attack)
  pincer,
}

class WavePathSelector {
  WavePathSelector._();

  /// Picks a path pattern for the given wave number.
  /// Boss waves always pincer, early waves always spread,
  /// otherwise varies based on wave number.
  static WavePathPattern selectPattern(int waveNumber, int pathCount, Random rng) {
    if (pathCount <= 1) return WavePathPattern.spread;

    // Boss waves (every 10) → pincer attack
    if (waveNumber % 10 == 0) return WavePathPattern.pincer;

    // First 2 waves → spread so player learns about multiple paths
    if (waveNumber <= 2) return WavePathPattern.spread;

    // Mini-boss waves (every 5) → focused rush
    if (waveNumber % 5 == 0) return WavePathPattern.focused;

    // Otherwise: weighted random
    // 40% spread, 40% focused, 20% pincer
    final roll = rng.nextDouble();
    if (roll < 0.4) return WavePathPattern.spread;
    if (roll < 0.8) return WavePathPattern.focused;
    return WavePathPattern.pincer;
  }

  /// Returns the path index to use for a given enemy spawn index.
  static int pickPath(WavePathPattern pattern, int spawnIndex, int pathCount, int focusedIndex) {
    if (pathCount <= 1) return 0;
    switch (pattern) {
      case WavePathPattern.spread:
        return spawnIndex % pathCount;
      case WavePathPattern.focused:
        return focusedIndex.clamp(0, pathCount - 1);
      case WavePathPattern.pincer:
        // Alternate between first and last path
        return spawnIndex.isEven ? 0 : pathCount - 1;
    }
  }
}

class WaveData {
  WaveData._();

  /// Applies ±20% randomization to [base] count using [rng].
  /// Always returns at least 1. Counts of exactly 1 are left unchanged
  /// (preserves single-boss spawns).
  static int _vary(int base, Random rng) {
    if (base <= 1) return base;
    final low = (base * 0.8).floor().clamp(1, base);
    final high = (base * 1.2).ceil();
    return low + rng.nextInt(high - low + 1);
  }

  /// Returns the wave composition for [waveNumber] under [difficulty].
  ///
  /// When [seed] is provided, enemy counts receive ±20% variation seeded
  /// deterministically from `seed + waveNumber`, so the same map seed always
  /// produces the same randomised wave but different seeds give different
  /// compositions. Without a seed the counts are the original deterministic
  /// values (backwards-compatible).
  static List<WaveEntry> getWave(int waveNumber, DifficultyTier difficulty, {int? seed}) {
    final totalWaves = difficulty.totalWaves;
    final entries = <WaveEntry>[];
    // Build a per-wave RNG only when a seed is supplied.
    final Random? rng = seed != null ? Random(seed + waveNumber) : null;

    // Helper: optionally vary a count.
    int v(int base) => rng != null ? _vary(base, rng) : base;

    // Final boss wave
    if (waveNumber == totalWaves) {
      entries.add(const WaveEntry(type: EnemyType.dragonEmperor, count: 1, spawnDelay: 0));
      entries.add(WaveEntry(type: EnemyType.darkKnight, count: v(3)));
      entries.add(WaveEntry(type: EnemyType.healer, count: v(1 + totalWaves ~/ 15)));
      entries.add(WaveEntry(type: EnemyType.soldier, count: v(5 + totalWaves ~/ 5)));
      return entries;
    }

    // Mid-boss waves (every 10)
    if (waveNumber % 10 == 0) {
      entries.add(const WaveEntry(type: EnemyType.shadowLord, count: 1, spawnDelay: 0));
      entries.add(WaveEntry(type: EnemyType.armoredGiant, count: v(2 + waveNumber ~/ 15)));
      entries.add(WaveEntry(type: EnemyType.healer, count: v(waveNumber ~/ 10)));
      entries.add(WaveEntry(type: EnemyType.soldier, count: v(4 + waveNumber ~/ 5)));
      return entries;
    }

    // Mini-boss waves (every 5)
    if (waveNumber > 5 && waveNumber % 5 == 0) {
      entries.add(WaveEntry(type: EnemyType.troll, count: v(1 + waveNumber ~/ 15)));
      entries.add(WaveEntry(type: EnemyType.darkKnight, count: v(waveNumber ~/ 10)));
      entries.add(WaveEntry(type: EnemyType.shieldBearer, count: v(2 + waveNumber ~/ 8)));
      entries.add(WaveEntry(type: EnemyType.cavalry, count: v(3 + waveNumber ~/ 6)));
      return entries;
    }

    final baseCount = 3 + waveNumber;

    // Early waves (1-5): introduce basic enemies
    if (waveNumber <= 5) {
      final primary = [EnemyType.soldier, EnemyType.soldier, EnemyType.goblin, EnemyType.cavalry, EnemyType.cavalry];
      final delay = waveNumber <= 2 ? 1.0 : 0.7;
      entries.add(WaveEntry(type: primary[(waveNumber - 1) % primary.length], count: v(baseCount), spawnDelay: delay));
      // Wave 4+ adds a small secondary group for variety
      if (waveNumber >= 4) {
        final secondary = [EnemyType.cavalry, EnemyType.goblin];
        entries.add(WaveEntry(type: secondary[(waveNumber - 4) % secondary.length], count: v(baseCount ~/ 3), spawnDelay: delay));
      }
    }
    // Mid waves (6-10): introduce medium enemies
    else if (waveNumber <= 10) {
      entries.add(WaveEntry(type: EnemyType.soldier, count: v(baseCount ~/ 2)));
      final med = [EnemyType.armoredGiant, EnemyType.undead, EnemyType.shieldBearer, EnemyType.healer];
      entries.add(WaveEntry(type: med[(waveNumber - 6) % med.length], count: v(baseCount ~/ 3 + 1)));
    }
    // Hard waves (11-20): introduce hard enemies
    else if (waveNumber <= 20) {
      entries.add(WaveEntry(type: EnemyType.soldier, count: v(baseCount ~/ 3)));
      entries.add(WaveEntry(type: EnemyType.armoredGiant, count: v(baseCount ~/ 4 + 1)));
      final hard = [EnemyType.burrower, EnemyType.troll, EnemyType.darkKnight, EnemyType.burrower];
      entries.add(WaveEntry(type: hard[(waveNumber - 11) % hard.length], count: v(1 + waveNumber ~/ 8)));
      // Healers start appearing in groups
      if (waveNumber >= 14) {
        entries.add(WaveEntry(type: EnemyType.healer, count: v(1 + (waveNumber - 14) ~/ 3)));
      }
    }
    // Late game (21+): everything mixed, higher counts
    else {
      entries.add(WaveEntry(type: EnemyType.cavalry, count: v(baseCount ~/ 3)));
      entries.add(WaveEntry(type: EnemyType.armoredGiant, count: v(baseCount ~/ 4)));
      entries.add(WaveEntry(type: EnemyType.darkKnight, count: v(1 + waveNumber ~/ 10)));
      entries.add(WaveEntry(type: EnemyType.troll, count: v(1 + (waveNumber - 20) ~/ 5)));
      entries.add(WaveEntry(type: EnemyType.burrower, count: v(1 + (waveNumber - 20) ~/ 6)));
      entries.add(WaveEntry(type: EnemyType.healer, count: v(1 + (waveNumber - 20) ~/ 4)));
      // Undead hordes
      if (waveNumber % 3 == 0) {
        entries.add(WaveEntry(type: EnemyType.undead, count: v(3 + waveNumber ~/ 8)));
      }
    }
    return entries;
  }
}
