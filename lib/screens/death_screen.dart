import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'widgets/glass_panel.dart';

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
  final List<String> activeSynergies;
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
    this.activeSynergies = const [],
    required this.onContinue,
    required this.onMainMenu,
  });

  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  static const _tips = [
    'Buz + Yıldırım kombosu 2x hasar verir! Islak düşmanları çarp.',
    'Destek kulesi komşu kulelerin hasarını artırır. Merkeze yerleştir!',
    'Kulelerin hedefleme modunu değiştirebilirsin: Yakın, İlk, Güçlü.',
    'Zehir kulesi zaman içinde hasar verir, zırhlı düşmanlara etkili.',
    'Dikenli duvar yol üstüne yerleşir ve temas hasarı verir.',
    'Sinerji için kuleleri yan yana koy (8 yönlü komşuluk).',
    'Meta ağacından kalıcı güçlendirmeler satın al!',
    'Oto-dalga açarak dalgalar arası beklemeyi atlayabilirsin.',
    'Top kulesi alan hasarı verir - düşman gruplarına karşı güçlü.',
    'Büyücü kulesi zincir hasarı ile birden fazla düşmana vurur.',
  ];

  String _getTip() {
    final index = (wavesCompleted + enemiesKilled) % _tips.length;
    return _tips[index];
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            isVictory ? 'assets/images/ui/victory_bg.png' : 'assets/images/ui/defeat_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          // Dark overlay for readability
          Container(color: const Color(0xAA000000)),
          BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Center(
          child: GlassPanel(
            padding: const EdgeInsets.all(32),
            borderColor: _gold,
            borderRadius: 16,
            blur: 12,
            child: SizedBox(
              width: 400,
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
                isVictory ? 'ZAFER!' : 'KALE DÜŞTÜ',
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
              _StatRow(label: 'Düşmanlar', value: '$enemiesKilled'),
              _StatRow(label: 'Kuleler', value: '$towersPlaced'),
              if (totalDamageDealt > 0) _StatRow(label: 'Toplam Hasar', value: _formatNumber(totalDamageDealt)),
              if (activeSynergies.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: _gold.withAlpha(180), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        activeSynergies.join(', '),
                        style: TextStyle(color: _gold.withAlpha(180), fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(color: _gold, height: 24),
              _StatRow(
                label: 'Kazanılan Taş Ruhu',
                value: '+$spiritEarned',
                highlight: true,
              ),
              _StatRow(label: 'Toplam Taş Ruhu', value: '$totalSpirit'),
              // Tip for defeated players
              if (!isVictory) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _gold.withAlpha(15),
                    border: Border.all(color: _gold.withAlpha(60)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: _gold.withAlpha(180), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getTip(),
                          style: TextStyle(color: _cream.withAlpha(200), fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                    child: const Text('ANA MENÜ'),
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
        ),
      ),
        ],
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
