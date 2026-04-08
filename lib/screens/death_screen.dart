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
  final String buildLabel;
  final String mostUsedTower;
  final String topSynergy;
  final int perfectWaves;
  final int bestCombo;
  final int dailyGoalSpirit;
  final List<({String desc, double fraction, bool done, int reward})> dailyGoals;
  final VoidCallback onContinue;
  final VoidCallback onQuickRestart;
  final VoidCallback onMainMenu;

  /// Show "Watch Ad -> Continue" button (only if ad is loaded and not yet used this run).
  final bool showAdContinue;
  final VoidCallback? onAdContinue;

  /// Show "Watch Ad -> 2x Spirit" button for daily goal rewards.
  final bool showAdDoubleSpirit;
  final VoidCallback? onAdDoubleSpirit;

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
    this.buildLabel = '',
    this.mostUsedTower = '',
    this.topSynergy = '',
    this.perfectWaves = 0,
    this.bestCombo = 0,
    this.dailyGoalSpirit = 0,
    this.dailyGoals = const [],
    required this.onContinue,
    required this.onQuickRestart,
    required this.onMainMenu,
    this.showAdContinue = false,
    this.onAdContinue,
    this.showAdDoubleSpirit = false,
    this.onAdDoubleSpirit,
  });

  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  String _getMotivation() {
    if (wavesCompleted >= 50) return 'Efsanevi bir direnis! Tarihe gectin!';
    if (wavesCompleted >= 30) return 'Muhtesem! Cok az komutan bu kadar dayanabilir.';
    if (wavesCompleted >= 20) return 'Etkileyici! Guclenmeye devam et!';
    if (wavesCompleted >= 10) return 'Iyi savastin! Strateji gelistikce daha ileri gideceksin.';
    if (wavesCompleted >= 5) return 'Guzel baslangic! Her kosu seni daha guclu yapiyor.';
    if (isNewRecord) return 'Yeni rekor! Gelisim yolunda emin adimlarla ilerliyorsun.';
    return 'Her dusus bir ders! Tekrar dene, bu sefer daha guclusun.';
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final totalGain = spiritEarned + adjustedBonus + objectiveBonus + dailyGoalSpirit;

    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/ui/defeat_bg.webp',
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
                    width: 380,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Icon(
                          Icons.dangerous,
                          color: Colors.red,
                          size: 44,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          wavesCompleted >= 30 ? 'EFSANE DIRENIS!' : 'KALE DUSTU',
                          style: TextStyle(
                            color: wavesCompleted >= 30 ? _gold : Colors.red,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            shadows: [
                              Shadow(color: (wavesCompleted >= 30 ? _gold : Colors.red).withAlpha(100), blurRadius: 16),
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
                        // Motivation
                        const SizedBox(height: 8),
                        Text(
                          _getMotivation(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _cream.withAlpha(200), fontSize: 12, fontStyle: FontStyle.italic),
                        ),
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
                              'YENI REKOR!',
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
                        // Key stats
                        const SizedBox(height: 16),
                        _StatRow(label: 'Ulasilan Dalga', value: '$wavesCompleted', icon: Icons.waves, highlight: true),
                        _StatRow(label: 'En Iyi Rekor', value: '${bestWave > wavesCompleted ? bestWave : wavesCompleted}', icon: Icons.emoji_events),
                        _StatRow(label: 'Dusmanlar', value: _formatNumber(enemiesKilled), icon: Icons.groups),
                        if (bossesKilled > 0) _StatRow(label: 'Bosslar', value: '$bossesKilled', icon: Icons.whatshot),
                        if (totalDamageDealt > 0) _StatRow(label: 'Toplam Hasar', value: _formatNumber(totalDamageDealt), icon: Icons.local_fire_department),

                        const Divider(color: _gold, height: 20),

                        // Spirit earned (simple)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [_gold.withAlpha(20), Colors.transparent]),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _gold.withAlpha(80)),
                          ),
                          child: Column(
                            children: [
                              _StatRow(
                                label: 'Kazanilan Ruh',
                                value: '+$totalGain',
                                highlight: true,
                                icon: Icons.diamond,
                              ),
                              const SizedBox(height: 4),
                              _StatRow(
                                label: 'Toplam Tas Ruhu',
                                value: '$totalSpirit',
                                icon: Icons.account_balance,
                              ),
                            ],
                          ),
                        ),

                        // Ad: 2x Spirit for daily goals
                        if (showAdDoubleSpirit && onAdDoubleSpirit != null && dailyGoalSpirit > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withAlpha(40),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                AudioSystem.instance.play(GameSound.buttonClick);
                                onAdDoubleSpirit!();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3E2F5C),
                                foregroundColor: const Color(0xFFCCA0FF),
                                minimumSize: const Size.fromHeight(36),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
                                ),
                              ),
                              icon: const Icon(Icons.play_circle_outline, size: 16),
                              label: Text(
                                'REKLAM IZLE → 2X GOREV RUHU (+$dailyGoalSpirit)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                              ),
                            ),
                          ),
                        ],

                        // First run hint
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
                                    'Kazandigin Tas Ruhu ile ana menudan kalici guclendirmeler satin alabilirsin!',
                                    style: TextStyle(color: _cream.withAlpha(200), fontSize: 10, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Ad Continue button (green glow, optional)
                        if (showAdContinue && onAdContinue != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4CAF50).withAlpha(60),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                AudioSystem.instance.play(GameSound.buttonClick);
                                onAdContinue!();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(44),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
                                ),
                              ),
                              icon: const Icon(Icons.play_circle_outline, size: 20),
                              label: const Text(
                                'REKLAM IZLE → DEVAM ET',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '1 HP ile devam et',
                              style: TextStyle(color: const Color(0xFF4CAF50).withAlpha(180), fontSize: 10),
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
                              child: const Text('ANA MENU', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () { AudioSystem.instance.play(GameSound.buttonClick); onQuickRestart(); },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _gold,
                                foregroundColor: _darkBg,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              ),
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: const Text('TEKRAR OYNA', style: TextStyle(fontWeight: FontWeight.bold)),
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
