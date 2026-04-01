import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game/systems/audio_system.dart';
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
  final int bossesKilled;
  final int clearedWaves;
  final int runEndBonus;
  final int adjustedBonus;
  final int objectiveBonus;
  final bool objWaves;
  final bool objKills;
  final bool objBoss;
  final List<({String treeName, String nodeName, int cost, bool canAfford})> suggestedUpgrades;
  final bool isFirstRun;
  final int bestWave;
  final bool isNewRecord;
  final VoidCallback onContinue;
  final VoidCallback onQuickRestart;
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
    this.bossesKilled = 0,
    this.clearedWaves = 0,
    this.runEndBonus = 0,
    this.adjustedBonus = 0,
    this.objectiveBonus = 0,
    this.objWaves = false,
    this.objKills = false,
    this.objBoss = false,
    this.suggestedUpgrades = const [],
    this.isFirstRun = false,
    this.bestWave = 0,
    this.isNewRecord = false,
    required this.onContinue,
    required this.onQuickRestart,
    required this.onMainMenu,
  });

  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  String _getTip() {
    if (wavesCompleted <= 3 && towersPlaced < 3) {
      return 'Daha fazla kule yerleştirmeyi dene! İlk dalgalarda en az 3-4 kule olmalı.';
    }
    if (wavesCompleted <= 3) {
      return 'İlk dalgalarda altını biriktir, sonra güçlü kulelere yatırım yap.';
    }
    if (activeSynergies.isEmpty && towersPlaced >= 4) {
      return 'Kuleleri yan yana koyarak sinerji oluştur! Farklı kuleleri komşu yerleştir.';
    }
    if (wavesCompleted >= 5 && wavesCompleted <= 10) {
      return 'Buz + Yıldırım kombosu 2x hasar verir! Islak düşmanları çarp.';
    }
    if (wavesCompleted >= 8 && wavesCompleted <= 15) {
      return 'Destek kulesi komşu kulelerin hasarını artırır. Merkeze yerleştir!';
    }
    if (wavesCompleted >= 10) {
      return 'Tier 4 yükseltmeler çok güçlü! Kuleleri max seviyeye çıkarmayı hedefle.';
    }
    if (totalDamageDealt < wavesCompleted * 200) {
      return 'Daha yüksek hasarlı kuleler dene: Top (AoE), Yıldırım (tek hedef), Büyücü (zincir).';
    }
    return 'Meta ağacından kalıcı güçlendirmeler satın al! Her oyun daha güçlü başla.';
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final totalGain = spiritEarned + adjustedBonus + objectiveBonus;

    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            isVictory ? 'assets/images/ui/victory_bg.webp' : 'assets/images/ui/defeat_bg.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          Container(color: const Color(0xAA000000)),
          BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Center(
          child: SingleChildScrollView(
            child: GlassPanel(
              padding: const EdgeInsets.all(28),
              borderColor: _gold,
              borderRadius: 16,
              blur: 12,
              child: SizedBox(
                width: 420,
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVictory ? Icons.emoji_events : Icons.dangerous,
                  color: isVictory ? _gold : Colors.red,
                  size: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  isVictory ? 'ZAFER!' : (wavesCompleted >= 15 ? 'AZ KALDI!' : 'KALE DÜŞTÜ'),
                  style: TextStyle(
                    color: isVictory ? _gold : Colors.red,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(color: (isVictory ? _gold : Colors.red).withAlpha(100), blurRadius: 16),
                    ],
                  ),
                ),
                if (difficultyName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    difficultyName.toUpperCase(),
                    style: TextStyle(color: _cream.withAlpha(120), fontSize: 11, letterSpacing: 2),
                  ),
                ],
                // New record badge
                if (isNewRecord) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_gold.withAlpha(40), Colors.orange.withAlpha(25)]),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _gold.withAlpha(120)),
                    ),
                    child: Text(
                      '\u{1F525} YENİ REKOR!',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        shadows: [Shadow(color: _gold.withAlpha(100), blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Stats
                _StatRow(label: 'Bu Run', value: '$wavesCompleted. Dalga', icon: Icons.waves),
                _StatRow(label: 'En İyi', value: '$bestWave. Dalga', icon: Icons.emoji_events, highlight: isNewRecord),
                _StatRow(label: 'Düşmanlar', value: '$enemiesKilled', icon: Icons.groups),
                _StatRow(label: 'Kuleler', value: '$towersPlaced', icon: Icons.castle),
                if (totalDamageDealt > 0) _StatRow(label: 'Toplam Hasar', value: _formatNumber(totalDamageDealt), icon: Icons.local_fire_department),
                if (activeSynergies.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: _gold.withAlpha(180), size: 13),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          activeSynergies.join(', '),
                          style: TextStyle(color: _gold.withAlpha(180), fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ],

                // Run objectives
                const SizedBox(height: 12),
                _buildObjectives(),

                const Divider(color: _gold, height: 20),

                // Spirit reward breakdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_gold.withAlpha(20), Colors.transparent]),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _gold.withAlpha(80)),
                  ),
                  child: Column(
                    children: [
                      _StatRow(
                        label: 'Run İçi Spirit',
                        value: '+$spiritEarned',
                        icon: Icons.diamond,
                      ),
                      if (runEndBonus > 0) ...[
                        Divider(color: _cream.withAlpha(30), height: 10),
                        _StatRow(
                          label: 'Dalga Bonusu ($clearedWaves×2)',
                          value: '+${clearedWaves * 2}',
                          icon: Icons.waves,
                        ),
                        _StatRow(
                          label: 'Kill Bonusu ($enemiesKilled÷10)',
                          value: '+${enemiesKilled ~/ 10}',
                          icon: Icons.groups,
                        ),
                        if (bossesKilled > 0)
                          _StatRow(
                            label: 'Boss Bonusu ($bossesKilled×25)',
                            value: '+${bossesKilled * 25}',
                            icon: Icons.whatshot,
                          ),
                        _StatRow(
                          label: 'Sonuç Çarpanı',
                          value: isVictory ? 'Zafer ×1.0' : 'Yenilgi ×0.5',
                          icon: isVictory ? Icons.emoji_events : Icons.trending_down,
                        ),
                        _StatRow(
                          label: 'Run Sonu Bonus',
                          value: '+$adjustedBonus',
                          highlight: true,
                          icon: Icons.star,
                        ),
                      ],
                      if (objectiveBonus > 0)
                        _StatRow(
                          label: 'Hedef Bonusu',
                          value: '+$objectiveBonus',
                          highlight: true,
                          icon: Icons.flag,
                        ),
                      Divider(color: _gold.withAlpha(60), height: 10),
                      _StatRow(
                        label: 'Toplam Kazanç',
                        value: '+$totalGain',
                        highlight: true,
                        icon: Icons.diamond,
                      ),
                      const SizedBox(height: 2),
                      _StatRow(label: 'Toplam Taş Ruhu', value: '$totalSpirit', icon: Icons.account_balance),
                    ],
                  ),
                ),

                // Suggested upgrades
                if (suggestedUpgrades.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildSuggestedUpgrades(),
                ],

                // Tip for defeated players
                if (!isVictory) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _gold.withAlpha(15),
                      border: Border.all(color: _gold.withAlpha(60)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: _gold.withAlpha(180), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _getTip(),
                            style: TextStyle(color: _cream.withAlpha(200), fontSize: 10, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // First-run meta awareness hint
                if (isFirstRun) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withAlpha(15),
                      border: Border.all(color: const Color(0xFF4CAF50).withAlpha(60)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.diamond, color: _gold.withAlpha(200), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Kazandığın Taş Ruhu ile ana menüden kalıcı güçlendirmeler satın alabilirsin! Her koşu daha güçlü başla.',
                            style: TextStyle(color: _cream.withAlpha(200), fontSize: 10, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Buttons
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () { AudioSystem.instance.play(GameSound.buttonClick); onMainMenu(); },
                      style: TextButton.styleFrom(foregroundColor: _cream.withAlpha(180)),
                      child: const Text('ANA MENÜ', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () { AudioSystem.instance.play(GameSound.buttonClick); onContinue(); },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        foregroundColor: _cream,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('TEKRAR OYNA'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () { AudioSystem.instance.play(GameSound.buttonClick); onQuickRestart(); },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _darkBg,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('HIZLI BAŞLA', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
              ),
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildObjectives() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _objChip(Icons.waves, '10 Dalga', objWaves, 10),
        const SizedBox(width: 8),
        _objChip(Icons.groups, '50 Kill', objKills, 10),
        const SizedBox(width: 8),
        _objChip(Icons.whatshot, '1 Boss', objBoss, 15),
      ],
    );
  }

  Widget _objChip(IconData icon, String label, bool done, int reward) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: done ? _gold.withAlpha(25) : _cream.withAlpha(8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: done ? _gold.withAlpha(100) : _cream.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_circle : icon, size: 12, color: done ? _gold : _cream.withAlpha(80)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: done ? _gold : _cream.withAlpha(100), fontSize: 10),
          ),
          if (done) ...[
            const SizedBox(width: 3),
            Text('+$reward', style: const TextStyle(color: _gold, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestedUpgrades() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _cream.withAlpha(8),
        border: Border.all(color: _cream.withAlpha(30)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'Sonraki Güçlendirmeler',
            style: TextStyle(color: _cream.withAlpha(120), fontSize: 10),
          ),
          const SizedBox(height: 6),
          for (final upgrade in suggestedUpgrades)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    upgrade.canAfford ? Icons.lock_open : Icons.lock_outline,
                    size: 12,
                    color: upgrade.canAfford ? _gold : _cream.withAlpha(80),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${upgrade.treeName} — ${upgrade.nodeName}',
                      style: TextStyle(
                        color: upgrade.canAfford ? _cream : _cream.withAlpha(120),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.diamond, size: 10, color: upgrade.canAfford ? _gold : _cream.withAlpha(60)),
                      const SizedBox(width: 2),
                      Text(
                        '${upgrade.cost}',
                        style: TextStyle(
                          color: upgrade.canAfford ? _gold : _cream.withAlpha(80),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
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
  final IconData? icon;

  const _StatRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: highlight ? const Color(0xFFBA7517) : const Color(0xFFF5EDD8).withAlpha(140)),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: highlight ? const Color(0xFFBA7517) : const Color(0xFFF5EDD8).withAlpha(180),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFFBA7517) : const Color(0xFFF5EDD8),
              fontSize: 13,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
