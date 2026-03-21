import 'package:flutter/material.dart';
import '../game/data/enemy_data.dart';
import '../game/data/wave_data.dart';

class WaveBreak extends StatelessWidget {
  final int nextWave;
  final int totalWaves;
  final int gold;
  final double timeRemaining;
  final List<WaveEntry> wavePreview;
  final VoidCallback onStartNow;
  final VoidCallback? onWatchAd; // null = ad not available

  const WaveBreak({
    super.key,
    required this.nextWave,
    required this.totalWaves,
    required this.gold,
    required this.timeRemaining,
    this.wavePreview = const [],
    required this.onStartNow,
    this.onWatchAd,
  });

  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _darkBg.withAlpha(240),
          border: Border.all(color: _gold),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dalga $nextWave / $totalWaves',
              style: const TextStyle(
                color: _gold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hazirlik Suresi',
              style: TextStyle(color: _cream.withAlpha(150), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              '${timeRemaining.ceil()}s',
              style: const TextStyle(
                color: _cream,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on, color: _gold, size: 18),
                const SizedBox(width: 4),
                Text(
                  '$gold Altin',
                  style: const TextStyle(color: _cream, fontSize: 14),
                ),
              ],
            ),
            // Wave preview
            if (wavePreview.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _cream.withAlpha(10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _cream.withAlpha(30)),
                ),
                child: Column(
                  children: [
                    Text('Gelen Dusmanlar', style: TextStyle(color: _cream.withAlpha(150), fontSize: 10)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: wavePreview.map((entry) {
                        final stats = EnemyData.getStats(entry.type);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: _enemyColor(entry.type),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${stats.name} x${entry.count}',
                              style: TextStyle(color: _cream.withAlpha(200), fontSize: 10),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onStartNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _darkBg,
                minimumSize: const Size.fromHeight(40),
              ),
              child: const Text('SIMDI BASLA', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (onWatchAd != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onWatchAd,
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('Reklam Izle (+50 Altin)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _cream,
                  side: BorderSide(color: _cream.withAlpha(80)),
                  minimumSize: const Size.fromHeight(36),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _enemyColor(EnemyType type) {
    switch (type) {
      case EnemyType.soldier: return const Color(0xFFCC3333);
      case EnemyType.cavalry: return const Color(0xFFFF6600);
      case EnemyType.goblin: return const Color(0xFF33CC33);
      case EnemyType.armoredGiant: return const Color(0xFF999999);
      case EnemyType.undead: return const Color(0xFF666688);
      case EnemyType.shieldBearer: return const Color(0xFF4488CC);
      case EnemyType.healer: return const Color(0xFFFFFFFF);
      case EnemyType.burrower: return const Color(0xFF886633);
      case EnemyType.troll: return const Color(0xFF338833);
      case EnemyType.darkKnight: return const Color(0xFF330033);
      case EnemyType.shadowLord: return const Color(0xFF220022);
      case EnemyType.dragonEmperor: return const Color(0xFFFF0000);
    }
  }
}
