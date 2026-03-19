import 'package:flutter/material.dart';

class WaveBreak extends StatelessWidget {
  final int nextWave;
  final int totalWaves;
  final int gold;
  final double timeRemaining;
  final VoidCallback onStartNow;
  final VoidCallback? onWatchAd; // null = ad not available

  const WaveBreak({
    super.key,
    required this.nextWave,
    required this.totalWaves,
    required this.gold,
    required this.timeRemaining,
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
            const SizedBox(height: 20),
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
}
