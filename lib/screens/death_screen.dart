import 'package:flutter/material.dart';

class DeathScreen extends StatelessWidget {
  final bool isVictory;
  final int wavesCompleted;
  final int totalWaves;
  final int spiritEarned;
  final int totalSpirit;
  final int towersPlaced;
  final int enemiesKilled;
  final int totalDamageDealt;
  final String difficultyName;
  final VoidCallback onContinue;
  final VoidCallback onMainMenu;

  const DeathScreen({
    super.key,
    required this.isVictory,
    required this.wavesCompleted,
    required this.totalWaves,
    required this.spiritEarned,
    required this.totalSpirit,
    required this.towersPlaced,
    required this.enemiesKilled,
    this.totalDamageDealt = 0,
    this.difficultyName = '',
    required this.onContinue,
    required this.onMainMenu,
  });

  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _darkBg,
            border: Border.all(color: _gold, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVictory ? Icons.emoji_events : Icons.dangerous,
                color: isVictory ? _gold : Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                isVictory ? 'ZAFER!' : 'KALE DUSTU',
                style: TextStyle(
                  color: isVictory ? _gold : Colors.red,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              if (difficultyName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  difficultyName.toUpperCase(),
                  style: TextStyle(color: _cream.withAlpha(120), fontSize: 12, letterSpacing: 2),
                ),
              ],
              const SizedBox(height: 24),
              _StatRow(label: 'Dalga', value: '$wavesCompleted / $totalWaves'),
              _StatRow(label: 'Dusmanlar', value: '$enemiesKilled'),
              _StatRow(label: 'Kuleler', value: '$towersPlaced'),
              if (totalDamageDealt > 0) _StatRow(label: 'Toplam Hasar', value: _formatNumber(totalDamageDealt)),
              const Divider(color: _gold, height: 24),
              _StatRow(
                label: 'Kazanilan Tas Ruhu',
                value: '+$spiritEarned',
                highlight: true,
              ),
              _StatRow(label: 'Toplam Tas Ruhu', value: '$totalSpirit'),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: onMainMenu,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: _cream,
                    ),
                    child: const Text('ANA MENU'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _darkBg,
                    ),
                    child: const Text('TEKRAR OYNA'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight ? const Color(0xFFBA7517) : const Color(0xFFF5EDD8).withAlpha(180),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFFBA7517) : const Color(0xFFF5EDD8),
              fontSize: 14,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
