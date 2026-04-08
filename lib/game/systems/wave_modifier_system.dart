import 'dart:math';

/// Per-wave challenge modifiers that activate after wave 10.
/// Each wave gets ONE random modifier, forcing the player to adapt.
enum WaveModifier {
  none('', ''),
  iceImmune('Buz Kalkanı', 'Bu dalga düşmanlar yavaşlatılamaz!'),
  fastHealers('Hızlı İyileşme', 'Bu dalga iyileştiriciler 2× güçlü!'),
  deathExplosion('Ölüm Patlaması', 'Bu dalga düşmanlar ölünce kaleye 1 hasar verir!'),
  armoredSurge('Zırh Dalgası', 'Bu dalga tüm düşmanlar +8 zırh!'),
  speedRush('Hız Fırtınası', 'Bu dalga düşmanlar %40 hızlı!'),
  regenWave('Yenilenme', 'Bu dalga düşmanlar yavaşça can yeniliyor!'),
  ;

  final String displayName;
  final String description;
  const WaveModifier(this.displayName, this.description);
}

class WaveModifierSystem {
  WaveModifierSystem._();

  static const int _startWave = 10;

  /// Active modifiers (excluding none)
  static const List<WaveModifier> _pool = [
    WaveModifier.iceImmune,
    WaveModifier.fastHealers,
    WaveModifier.deathExplosion,
    WaveModifier.armoredSurge,
    WaveModifier.speedRush,
    WaveModifier.regenWave,
  ];

  /// Pick a modifier for this wave. Returns none for early waves.
  /// ~60% chance to get a modifier after startWave.
  static WaveModifier roll(int waveNumber, int seed) {
    if (waveNumber < _startWave) return WaveModifier.none;
    final rng = Random(seed + waveNumber * 31);
    // 40% chance of no modifier even after wave 10
    if (rng.nextDouble() < 0.4) return WaveModifier.none;
    return _pool[rng.nextInt(_pool.length)];
  }
}
